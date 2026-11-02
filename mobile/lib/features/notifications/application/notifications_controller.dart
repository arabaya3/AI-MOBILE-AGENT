import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/notifications_api.dart';

enum LiveStatus { off, connecting, live, waiting }

/// Whether to keep a live connection; tests that do not exercise it turn it off.
final notificationsLiveEnabledProvider = Provider<bool>((ref) => true);

/// Reconnect delays: bounded, the last one repeats.
final notificationsBackoffProvider = Provider<List<Duration>>(
  (ref) => const [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ],
);

class NotificationsState {
  const NotificationsState({
    this.items,
    this.unread = 0,
    this.error,
    this.live = LiveStatus.off,
  });

  /// Null until the first load.
  final List<AppNotification>? items;
  final int unread;
  final ApiException? error;
  final LiveStatus live;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? unread,
    ApiException? error,
    bool clearError = false,
    LiveStatus? live,
  }) => NotificationsState(
    items: items ?? this.items,
    unread: unread ?? this.unread,
    error: clearError ? null : (error ?? this.error),
    live: live ?? this.live,
  );
}

/// In-app notifications for the signed-in account.
///
/// The list is always loaded from the server and reloaded after every (re)connect, so events missed
/// while offline are reconciled. Live events are de-duplicated by id. Everything is discarded on
/// sign-out or account change; the stream pauses while the app is in the background.
class NotificationsController extends Notifier<NotificationsState> {
  String? _scope;
  int _generation = 0;
  int _attempt = 0;
  CancelToken? _token;
  StreamSubscription<AppNotification>? _subscription;
  Timer? _retry;

  NotificationsApi get _api => ref.read(notificationsApiProvider);

  bool _current(int generation) =>
      _sameScope(_scope) && generation == _generation;

  /// Account-level results (list, read state) survive reconnects but never an account change.
  bool _sameScope(String? scope) =>
      ref.mounted && scope != null && ref.read(authScopeProvider) == scope;

  @override
  NotificationsState build() {
    _scope = ref.watch(authScopeProvider);
    ref.listen(appForegroundProvider, (_, foreground) {
      if (foreground) {
        _attempt = 0;
        _connect();
      } else {
        _disconnect();
        state = state.copyWith(live: LiveStatus.off);
      }
    });
    ref.onDispose(_disconnect);
    if (_scope == null) return const NotificationsState(items: []);
    Future.microtask(_connect);
    return const NotificationsState();
  }

  Future<void> refresh() async {
    final scope = _scope;
    try {
      final results = await Future.wait([_api.list(), _api.unreadCount()]);
      if (!_sameScope(scope)) return;
      state = state.copyWith(
        items: results[0] as List<AppNotification>,
        unread: results[1] as int,
        clearError: true,
      );
    } on ApiException catch (e) {
      if (!_sameScope(scope) || e is RequestCancelledException) return;
      state = state.copyWith(error: e);
    }
  }

  void _connect() {
    if (_scope == null || !ref.read(appForegroundProvider)) return;
    if (!ref.read(notificationsLiveEnabledProvider)) {
      if (state.items == null) unawaited(refresh());
      return;
    }
    _disconnect();
    final generation = ++_generation;
    final token = _token = CancelToken();
    state = state.copyWith(live: LiveStatus.connecting);
    _subscription = _api
        .stream(
          cancelToken: token,
          onConnected: () {
            if (!_current(generation)) return;
            _attempt = 0;
            state = state.copyWith(live: LiveStatus.live);
            // Authoritative reload: covers anything that happened while disconnected.
            unawaited(refresh());
          },
        )
        .listen(
          (notification) {
            if (_current(generation)) _receive(notification);
          },
          onError: (Object error) => _scheduleRetry(generation),
          onDone: () => _scheduleRetry(generation),
          cancelOnError: true,
        );
    // The list is shown even if the live link cannot be established.
    if (state.items == null) unawaited(refresh());
  }

  void _receive(AppNotification notification) {
    final items = state.items ?? const <AppNotification>[];
    if (items.any((n) => n.id == notification.id)) return;
    state = state.copyWith(
      items: [notification, ...items],
      unread: state.unread + (notification.read ? 0 : 1),
    );
  }

  void _scheduleRetry(int generation) {
    if (!_current(generation)) return;
    final delays = ref.read(notificationsBackoffProvider);
    final delay = delays[min(_attempt, delays.length - 1)];
    _attempt++;
    state = state.copyWith(live: LiveStatus.waiting);
    _retry?.cancel();
    _retry = Timer(delay, () {
      if (_current(generation)) _connect();
    });
  }

  void _disconnect() {
    _generation++;
    _retry?.cancel();
    _retry = null;
    _token?.cancel();
    _token = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  Future<void> markRead(String id) async {
    final scope = _scope;
    final target = state.items?.where((n) => n.id == id).firstOrNull;
    if (target == null || target.read) return;
    await _api.markRead(id);
    if (!_sameScope(scope)) return;
    state = state.copyWith(
      items: [
        for (final n in state.items ?? const <AppNotification>[])
          n.id == id ? n.markedRead() : n,
      ],
      unread: max(0, state.unread - 1),
    );
  }

  Future<void> markAllRead() async {
    final scope = _scope;
    await _api.markAllRead();
    if (!_sameScope(scope)) return;
    state = state.copyWith(
      items: [
        for (final n in state.items ?? const <AppNotification>[])
          n.markedRead(),
      ],
      unread: 0,
    );
  }
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );
