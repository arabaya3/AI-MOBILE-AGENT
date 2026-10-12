import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/session/session_manager.dart';

import '../../support/fake_backend.dart';

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('an older deletion can never erase a newer token', () async {
    final store = ControlledTokenStore('old');
    final session = SessionManager(store);

    final signOut = session.signOut();
    final signIn = session.start('new');
    expect(session.token, 'new');

    await settle();
    expect(store.log, ['delete']);
    await store.completeNext();
    await settle();
    expect(store.log, ['delete', 'write:new']);
    await store.completeNext();
    await Future.wait([signOut, signIn]);

    expect(store.value, 'new');
    expect(session.token, 'new');
  });

  test(
    'a restore that finishes after sign-out does not resurrect the session',
    () async {
      final store = ControlledTokenStore('stored');
      final session = SessionManager(store);

      final restore = session.restore();
      final signOut = session.signOut();
      await store.completeNext(); // read returns 'stored'
      await settle();
      await store.completeNext(); // delete
      expect(await restore, RestoreResult.superseded);
      await signOut;

      expect(session.token, isNull);
      expect(store.value, isNull);
    },
  );

  test(
    'a restore that finishes after a new sign-in keeps the new token',
    () async {
      final store = ControlledTokenStore('old');
      final session = SessionManager(store);

      final restore = session.restore();
      final signIn = session.start('fresh');
      await store.completeNext();
      await settle();
      await store.completeNext();
      expect(await restore, RestoreResult.superseded);
      await signIn;
      expect(session.token, 'fresh');
      expect(store.value, 'fresh');
    },
  );

  test('a delayed 401 for an older token cannot end a newer session', () async {
    final store = ControlledTokenStore('a');
    final session = SessionManager(store);
    final restore = session.restore();
    await store.completeNext();
    await restore;

    final signIn = session.start('b');
    expect(await session.expire('a'), isFalse);
    expect(session.token, 'b');
    await store.completeNext();
    await signIn;
  });

  test('concurrent expiries end the session once and delete once', () async {
    final store = ControlledTokenStore('t');
    final session = SessionManager(store);
    final restore = session.restore();
    await store.completeNext();
    await restore;

    final events = <SessionSnapshot>[];
    final sub = session.changes.listen(events.add);
    final results = [
      session.expire('t'),
      session.expire('t'),
      session.expire('t'),
    ];
    await settle();
    await store.completeNext();
    expect(await Future.wait(results), [true, false, false]);
    expect(
      events.where((e) => e.endReason == SessionEndReason.expired),
      hasLength(1),
    );
    expect(store.log.where((op) => op == 'delete'), hasLength(1));
    await sub.cancel();
  });

  test(
    'every change bumps the epoch and late readers see the current snapshot',
    () async {
      final store = ControlledTokenStore();
      final session = SessionManager(store);
      final start = session.start('x');
      expect(session.current.token, 'x');
      expect(session.current.epoch, 1);
      final out = session.signOut();
      expect(session.current.epoch, 2);
      expect(session.current.endReason, SessionEndReason.signedOut);
      await store.completeNext();
      await settle();
      await store.completeNext();
      await Future.wait([start, out]);
    },
  );

  test(
    'unreadable secure storage is reported, not treated as signed out',
    () async {
      final store = ControlledTokenStore('t')..failReads = true;
      final session = SessionManager(store);
      final restore = session.restore();
      await store.completeNext();
      expect(await restore, RestoreResult.storageUnavailable);
      expect(session.token, isNull);
    },
  );

  test(
    'a failed write keeps the session usable and flags persistence',
    () async {
      final store = ControlledTokenStore()..failWrites = true;
      final session = SessionManager(store);
      final start = session.start('t');
      await store.completeNext();
      await start;
      expect(session.token, 't');
      expect(session.current.persistenceFailed, isTrue);
    },
  );

  test(
    'a failed deletion overwrites the stored token so it cannot be restored',
    () async {
      final store = ControlledTokenStore('t')..failDeletes = true;
      final session = SessionManager(store);
      final restore = session.restore();
      await store.completeNext();
      await restore;

      final out = session.signOut();
      await settle();
      await store.completeNext(); // delete fails
      await settle();
      await store.completeNext(); // overwrite with empty
      await out;
      expect(store.value, '');

      final again = SessionManager(store);
      final second = again.restore();
      await store.completeNext();
      expect(await second, RestoreResult.empty);
    },
  );
}
