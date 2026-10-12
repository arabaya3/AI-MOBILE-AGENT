import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_manager.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';

sealed class AuthState {
  const AuthState();
}

class AuthStarting extends AuthState {
  const AuthStarting();
}

class AuthVerifying extends AuthState {
  const AuthVerifying();
}

/// A stored session exists but could not be verified (offline, server error or
/// unreadable secure storage). The token is kept until the user decides.
class AuthUnverified extends AuthState {
  const AuthUnverified({this.error, this.storageUnavailable = false});

  final ApiException? error;
  final bool storageUnavailable;
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut([this.reason = SessionEndReason.none]);

  final SessionEndReason reason;
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user, this.epoch);

  final CurrentUser user;
  final int epoch;

  /// Changes whenever the account or session changes; user-scoped state keys off it.
  String get scopeKey => '${user.id}#$epoch';
}

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

class AuthController extends Notifier<AuthState> {
  bool _loginInFlight = false;

  SessionManager get _session => ref.read(sessionManagerProvider);

  @override
  AuthState build() {
    ref.listen(sessionSnapshotProvider, (previous, next) {
      if (next.isActive || state is AuthSignedOut) return;
      ref.read(apiClientProvider).cancelAll();
      state = AuthSignedOut(next.endReason);
    });
    return const AuthStarting();
  }

  Future<void> initialize() async {
    state = const AuthStarting();
    switch (await _session.restore()) {
      case RestoreResult.restored:
        await _verify();
      case RestoreResult.empty:
        state = const AuthSignedOut();
      case RestoreResult.storageUnavailable:
        state = const AuthUnverified(storageUnavailable: true);
      case RestoreResult.superseded:
        break;
    }
  }

  Future<void> retry() async {
    final current = state;
    if (current is AuthUnverified && current.storageUnavailable) {
      await initialize();
    } else if (_session.token != null) {
      await _verify();
    }
  }

  /// Returns the failure to show, or null on success. Ignores taps while a login is in flight.
  Future<ApiException?> login(String email, String password) async {
    if (_loginInFlight) return null;
    _loginInFlight = true;
    final startedAt = _session.epoch;
    try {
      final token = await ref.read(authApiProvider).login(email, password);
      // A sign-out or another sign-in happened meanwhile: drop this late token.
      if (_session.epoch != startedAt || !ref.mounted) return null;
      ref.read(apiClientProvider).cancelAll();
      await _session.start(token);
      return await _verify();
    } on ApiException catch (e) {
      return e;
    } finally {
      _loginInFlight = false;
    }
  }

  /// Local sign-out only: the server has no revocation endpoint, so an issued
  /// JWT stays valid until it expires (`JWT_EXPIRATION_HOURS`).
  Future<void> signOut() async {
    ref.read(apiClientProvider).cancelAll();
    await _session.signOut();
    if (_session.token == null) {
      state = const AuthSignedOut(SessionEndReason.signedOut);
    }
  }

  Future<ApiException?> _verify() async {
    final epoch = _session.epoch;
    state = const AuthVerifying();
    try {
      final user = await ref.read(authApiProvider).me();
      if (_session.epoch != epoch || _session.token == null) return null;
      state = AuthSignedIn(user, epoch);
      return null;
    } on SessionExpiredException catch (e) {
      if (_session.epoch == epoch + 1 || _session.token == null) {
        state = const AuthSignedOut(SessionEndReason.expired);
      }
      return e;
    } on ApiException catch (e) {
      if (_session.epoch == epoch) state = AuthUnverified(error: e);
      return e;
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Non-null only while signed in; changes on account or session change.
final authScopeProvider = Provider<String?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthSignedIn ? auth.scopeKey : null;
});

final currentUserProvider = Provider<CurrentUser?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthSignedIn ? auth.user : null;
});
