import 'dart:async';

import '../storage/token_store.dart';

enum SessionStatus { signedOut, signedIn, expired }

/// Owns the access token. Expiry is coordinated so concurrent 401s sign out exactly once.
class SessionManager {
  SessionManager(this._store);

  final TokenStore _store;
  final _changes = StreamController<SessionStatus>.broadcast();

  String? _token;
  SessionStatus _status = SessionStatus.signedOut;

  String? get token => _token;
  SessionStatus get status => _status;
  Stream<SessionStatus> get changes => _changes.stream;

  Future<void> restore() async {
    _token = await _store.read();
    _set(_token == null ? SessionStatus.signedOut : SessionStatus.signedIn);
  }

  Future<void> start(String token) async {
    await _store.write(token);
    _token = token;
    _set(SessionStatus.signedIn);
  }

  Future<void> signOut() async {
    _token = null;
    await _store.delete();
    _set(SessionStatus.signedOut);
  }

  /// Returns true only for the call that actually ended the session.
  /// A rejection of an older token (after re-login) is ignored.
  Future<bool> expire(String? rejectedToken) async {
    if (rejectedToken == null || rejectedToken != _token) return false;
    _token = null;
    _set(SessionStatus.expired);
    await _store.delete();
    return true;
  }

  void _set(SessionStatus status) {
    _status = status;
    _changes.add(status);
  }

  Future<void> dispose() => _changes.close();
}
