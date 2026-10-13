import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'network/api_client.dart';
import 'session/session_manager.dart';
import 'storage/token_store.dart';

/// Overridden in bootstrap and tests.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider'),
);
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider'),
);
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final manager = SessionManager(ref.watch(tokenStoreProvider));
  ref.onDispose(manager.dispose);
  return manager;
});

/// Current session snapshot, available synchronously to late subscribers.
class SessionSnapshotNotifier extends Notifier<SessionSnapshot> {
  @override
  SessionSnapshot build() {
    final manager = ref.watch(sessionManagerProvider);
    final sub = manager.changes.listen((snapshot) => state = snapshot);
    ref.onDispose(sub.cancel);
    return manager.current;
  }
}

final sessionSnapshotProvider =
    NotifierProvider<SessionSnapshotNotifier, SessionSnapshot>(
      SessionSnapshotNotifier.new,
    );

/// The validated space sent as `X-Space-Id`. Only the space controller writes it,
/// and only after confirming the user can access that space.
class SelectedSpaceId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? spaceId) => state = spaceId;
}

final selectedSpaceIdProvider = NotifierProvider<SelectedSpaceId, String?>(
  SelectedSpaceId.new,
);

/// Emits a space id when the backend rejects it as inaccessible.
final spaceRejectionsProvider = Provider<StreamController<String>>((ref) {
  // Closed in onDispose.
  // ignore: close_sinks
  final controller = StreamController<String>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

final dioProvider = Provider<Dio>(
  (ref) => createDio(ref.watch(appConfigProvider)),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(sessionManagerProvider);
  return ApiClient(
    dio: ref.watch(dioProvider),
    readToken: () => session.token,
    readSpaceId: () => ref.read(selectedSpaceIdProvider),
    onSessionExpired: session.expire,
    onSpaceRejected: ref.watch(spaceRejectionsProvider).add,
  );
});

/// Whether the app is in the foreground; the app widget keeps it current.
/// Background polling stops while this is false.
class AppForeground extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

final appForegroundProvider = NotifierProvider<AppForeground, bool>(
  AppForeground.new,
);
