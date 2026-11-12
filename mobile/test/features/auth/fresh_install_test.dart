import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teia_ai/core/providers.dart';
import 'package:teia_ai/core/storage/token_store.dart';
import 'package:teia_ai/features/auth/application/auth_controller.dart';

import '../../support/container.dart';
import '../../support/fake_backend.dart';

/// A keystore whose deletes fail until [deleteWorks] is set; reads still return the old token.
class FlakyStore implements TokenStore {
  FlakyStore(this.value);

  String? value;
  bool deleteWorks = false;
  final log = <String>[];

  @override
  Future<String?> read() async {
    log.add('read');
    return value;
  }

  @override
  Future<void> write(String token) async => value = token;

  @override
  Future<void> delete() async {
    log.add('delete');
    if (!deleteWorks) throw StateError('keystore locked');
    value = null;
  }
}

FakeBackend backend() =>
    FakeBackend()..json('GET /auth/me', 200, userJson('u1'));

void main() {
  test(
    'fresh install whose cleanup fails never restores or uses the old token',
    () async {
      final b = backend();
      final store = FlakyStore('previous-install-token');
      final c = await makeContainer(
        b,
        store: store,
        prefs: {installMarkerKey: false},
      );
      addTearDown(c.dispose);

      await c.read(authControllerProvider.notifier).initialize();
      await settle();

      final state = c.read(authControllerProvider);
      expect(state, isA<AuthUnverified>());
      expect((state as AuthUnverified).storageUnavailable, isTrue);
      expect(store.log, ['delete']); // never read
      expect(c.read(sessionManagerProvider).token, isNull);
      expect(b.adapter.requests, isEmpty); // no authenticated request
      expect(
        c.read(sharedPreferencesProvider).getBool(installMarkerKey),
        isFalse,
      );
    },
  );

  test('retry repeats cleanup first, then starts normally', () async {
    final b = backend();
    final store = FlakyStore('previous-install-token');
    final c = await makeContainer(
      b,
      store: store,
      prefs: {installMarkerKey: false},
    );
    addTearDown(c.dispose);
    final auth = c.read(authControllerProvider.notifier);
    await auth.initialize();

    store.deleteWorks = true;
    await auth.retry();
    await settle();

    expect(store.log, ['delete', 'delete', 'read']);
    expect(store.value, isNull);
    expect(c.read(authControllerProvider), isA<AuthSignedOut>());
    expect(b.adapter.requests, isEmpty);
    expect(c.read(sharedPreferencesProvider).getBool(installMarkerKey), isTrue);
  });

  test('a marked install restores its session normally', () async {
    final b = backend();
    final store = FlakyStore('current-token');
    final c = await makeContainer(b, store: store);
    addTearDown(c.dispose);

    await c.read(authControllerProvider.notifier).initialize();
    await settle();

    expect(store.log, ['read']); // no cleanup
    expect(c.read(authControllerProvider), isA<AuthSignedIn>());
    expect(
      b.requestsTo('GET /auth/me').single.headers['Authorization'],
      'Bearer current-token',
    );
  });

  test('the marker is not saved when the deletion fails', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = FlakyStore('old');
    await expectLater(
      forgetTokenFromPreviousInstall(prefs, store),
      throwsStateError,
    );
    expect(prefs.getBool(installMarkerKey), isNull);
    expect(store.value, 'old');
  });
}
