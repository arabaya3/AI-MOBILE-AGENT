import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_manager.dart';
import '../../auth/application/auth_controller.dart';
import '../data/spaces_api.dart';

final spacesApiProvider = Provider<SpacesApi>(
  (ref) => SpacesApi(ref.watch(apiClientProvider)),
);

enum SpaceNotice { none, accessLost }

sealed class SpaceState {
  const SpaceState();
}

class SpaceIdle extends SpaceState {
  const SpaceIdle();
}

class SpaceLoading extends SpaceState {
  const SpaceLoading();
}

class SpaceLoadFailed extends SpaceState {
  const SpaceLoadFailed(this.error);

  final ApiException error;
}

class SpaceChoosing extends SpaceState {
  const SpaceChoosing(this.spaces, {this.notice = SpaceNotice.none});

  /// Empty when the account has no accessible space.
  final List<Space> spaces;
  final SpaceNotice notice;
}

class SpaceSelected extends SpaceState {
  const SpaceSelected(this.space, this.membership, this.spaces);

  final Space space;
  final SpaceMembership membership;
  final List<Space> spaces;
}

/// Resolves, validates and switches the active space for the signed-in account.
class SpaceController extends Notifier<SpaceState> {
  int _generation = 0;
  String? _userId;

  /// Last accessible list for this account; survives transient loading states.
  List<Space> _spaces = const [];

  SpacesApi get _api => ref.read(spacesApiProvider);

  @override
  SpaceState build() {
    final scope = ref.watch(authScopeProvider);
    _generation++;
    final previousUser = _userId;
    _userId = ref.read(currentUserProvider)?.id;
    _spaces = const [];

    final auth = ref.read(authControllerProvider);
    if (scope == null &&
        previousUser != null &&
        auth is AuthSignedOut &&
        auth.reason != SessionEndReason.none) {
      unawaited(_forgetSelection(previousUser));
    }
    final sub = ref.read(spaceRejectionsProvider).stream.listen(_onRejected);
    ref.onDispose(sub.cancel);

    // Providers may not modify each other during build, so the header clears just after.
    Future.microtask(() => _publish(null));
    if (scope == null) return const SpaceIdle();
    Future.microtask(refresh);
    return const SpaceLoading();
  }

  /// Reloads accessible spaces and restores the stored selection only if it is still valid.
  Future<void> refresh({
    String? prefer,
    SpaceNotice notice = SpaceNotice.none,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    final generation = ++_generation;
    state = const SpaceLoading();
    try {
      final spaces = (await _api.listMine()).where((s) => s.isActive).toList();
      if (generation != _generation) return;
      _spaces = spaces;
      final stored = _storedSelection(userId);
      final wanted = prefer ?? stored;
      final pick =
          spaces.where((s) => s.id == wanted).firstOrNull ??
          (spaces.length == 1 ? spaces.single : null);
      if (stored != null && spaces.every((s) => s.id != stored)) {
        await _forgetSelection(userId);
        if (generation != _generation) return;
        if (notice == SpaceNotice.none) notice = SpaceNotice.accessLost;
      }
      if (pick == null) {
        _publish(null);
        state = SpaceChoosing(spaces, notice: notice);
        return;
      }
      await _activate(pick, spaces, generation, notice);
    } on ApiException catch (e) {
      if (generation == _generation && e is! RequestCancelledException) {
        _publish(null);
        state = SpaceLoadFailed(e);
      }
    }
  }

  /// User-initiated switch; only spaces from the current accessible list are allowed.
  Future<void> select(String spaceId) async {
    final spaces = _spaces;
    final space = spaces
        .where((s) => s.id == spaceId && s.isActive)
        .firstOrNull;
    if (space == null) return;
    final generation = ++_generation;
    state = const SpaceLoading();
    await _activate(space, spaces, generation, SpaceNotice.none);
  }

  /// Leaves the current space without choosing another one.
  void clearSelection() {
    final current = state;
    if (current is! SpaceSelected) return;
    _generation++;
    ref.read(apiClientProvider).cancelSpaceScoped();
    _publish(null);
    state = SpaceChoosing(current.spaces);
  }

  Future<void> _activate(
    Space space,
    List<Space> spaces,
    int generation,
    SpaceNotice notice,
  ) async {
    ref.read(apiClientProvider).cancelSpaceScoped();
    _publish(null);
    try {
      final membership = await _api.membership(space.id);
      if (generation != _generation) return;
      if (!membership.isActive) {
        throw const ForbiddenException(message: 'Space access denied');
      }
      await ref
          .read(sharedPreferencesProvider)
          .setString(_key(_userId!), space.id);
      if (generation != _generation) return;
      _publish(space.id);
      state = SpaceSelected(space, membership, spaces);
    } on ApiException catch (e) {
      if (generation != _generation || e is RequestCancelledException) return;
      if (e is ForbiddenException || e is NotFoundException) {
        await _forgetSelection(_userId!);
        if (generation != _generation) return;
        _spaces = spaces.where((s) => s.id != space.id).toList();
        state = SpaceChoosing(_spaces, notice: SpaceNotice.accessLost);
      } else {
        state = SpaceLoadFailed(e);
      }
    }
  }

  void _onRejected(String spaceId) {
    final current = state;
    if (current is SpaceSelected && current.space.id == spaceId) {
      unawaited(refresh(notice: SpaceNotice.accessLost));
    }
  }

  void _publish(String? spaceId) =>
      ref.read(selectedSpaceIdProvider.notifier).set(spaceId);

  String? _storedSelection(String userId) =>
      ref.read(sharedPreferencesProvider).getString(_key(userId));

  Future<void> _forgetSelection(String userId) =>
      ref.read(sharedPreferencesProvider).remove(_key(userId));

  static String _key(String userId) => 'active_space.$userId';
}

final spaceControllerProvider = NotifierProvider<SpaceController, SpaceState>(
  SpaceController.new,
);

/// Non-null only while a validated space is selected; space-scoped state keys off it.
final spaceScopeProvider = Provider<String?>((ref) {
  final auth = ref.watch(authScopeProvider);
  final space = ref.watch(spaceControllerProvider);
  return auth != null && space is SpaceSelected
      ? '$auth/${space.space.id}'
      : null;
});

class AvailableSpace {
  const AvailableSpace(this.space, {required this.requestPending});

  final Space space;
  final bool requestPending;
}

/// Spaces the user may ask to join, with any pending join request.
final availableSpacesProvider =
    FutureProvider.autoDispose<List<AvailableSpace>>((ref) async {
      if (ref.watch(authScopeProvider) == null) return const [];
      final api = ref.watch(spacesApiProvider);
      final results = await Future.wait([
        api.listAvailable(),
        api.myRequests(),
      ]);
      final spaces = results[0] as List<Space>;
      final pending = {
        for (final r in results[1] as List<SpaceAccessRequest>)
          if (r.isPendingJoin) r.spaceId,
      };
      return [
        for (final s in spaces)
          AvailableSpace(s, requestPending: pending.contains(s.id)),
      ];
    });
