import 'dart:async';

import '../storage/token_store.dart';

enum SessionEndReason { none, signedOut, expired }

enum RestoreResult { restored, empty, superseded, storageUnavailable }

/// Immutable view of the session; [epoch] changes on every sign-in, sign-out or expiry.
class SessionSnapshot {
  const SessionSnapshot({
    required this.token,
    required this.epoch,
    required this.endReason,
    this.persistenceFailed = false,
  });

  final String? token;
  final int epoch;
  final SessionEndReason endReason;

  /// The token works for this run but could not be saved or erased on the device.
  final bool persistenceFailed;

  bool get isActive => token != null;
}

/// Owns the access token.
///
/// In-memory state changes synchronously; storage operations run strictly in
/// that same order, so an older deletion can never erase a newer token, and a
/// restore that finishes after a sign-in/sign-out is discarded.
class SessionManager {
  SessionManager(this._store);

  final TokenStore _store;
  final _changes = StreamController<SessionSnapshot>.broadcast();
  Future<void> _storageQueue = Future.value();

  SessionSnapshot _current = const SessionSnapshot(
    token: null,
    epoch: 0,
    endReason: SessionEndReason.none,
  );

  SessionSnapshot get current => _current;
  String? get token => _current.token;
  int get epoch => _current.epoch;
  Stream<SessionSnapshot> get changes => _changes.stream;

  Future<RestoreResult> restore() async {
    final startedAt = _current.epoch;
    String? stored;
    try {
      stored = await _serial(_store.read);
    } catch (_) {
      return startedAt == _current.epoch
          ? RestoreResult.storageUnavailable
          : RestoreResult.superseded;
    }
    if (startedAt != _current.epoch) return RestoreResult.superseded;
    if (stored == null || stored.isEmpty) return RestoreResult.empty;
    _set(token: stored, endReason: SessionEndReason.none);
    return RestoreResult.restored;
  }

  Future<void> start(String token) async {
    final epoch = _set(token: token, endReason: SessionEndReason.none);
    try {
      await _serial(() => _store.write(token));
    } catch (_) {
      _markPersistenceFailed(epoch);
    }
  }

  Future<void> signOut() => _end(SessionEndReason.signedOut);

  /// Ends the session only if [rejectedToken] is still the current token.
  /// Returns true for the single call that actually ended it.
  Future<bool> expire(String? rejectedToken) async {
    if (rejectedToken == null || rejectedToken != _current.token) return false;
    await _end(SessionEndReason.expired);
    return true;
  }

  Future<void> _end(SessionEndReason reason) async {
    final epoch = _set(token: null, endReason: reason);
    try {
      await _serial(_store.delete);
    } catch (_) {
      try {
        // Never leave a usable token behind: overwrite it if deletion fails.
        await _serial(() => _store.write(''));
      } catch (_) {
        _markPersistenceFailed(epoch);
      }
    }
  }

  int _set({required String? token, required SessionEndReason endReason}) {
    _current = SessionSnapshot(
      token: token,
      epoch: _current.epoch + 1,
      endReason: endReason,
    );
    _changes.add(_current);
    return _current.epoch;
  }

  void _markPersistenceFailed(int epoch) {
    if (_current.epoch != epoch) return;
    _current = SessionSnapshot(
      token: _current.token,
      epoch: epoch,
      endReason: _current.endReason,
      persistenceFailed: true,
    );
    _changes.add(_current);
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _storageQueue.then((_) => operation());
    _storageQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> dispose() => _changes.close();
}
