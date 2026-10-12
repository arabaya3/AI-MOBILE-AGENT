import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/network/api_exception.dart';
import 'package:teia_ai/core/providers.dart';
import 'package:teia_ai/core/session/session_manager.dart';
import 'package:teia_ai/core/storage/token_store.dart';
import 'package:teia_ai/features/auth/application/auth_controller.dart';

import '../../support/container.dart';
import '../../support/fake_backend.dart';

void main() {
  late FakeBackend backend;

  setUp(() => backend = FakeBackend());

  test('restores and verifies a stored session with /auth/me', () async {
    backend.json('GET /auth/me', 200, userJson('u1'));
    final store = InMemoryTokenStore('t1');
    final c = await makeContainer(backend, store: store);
    addTearDown(c.dispose);

    await c.read(authControllerProvider.notifier).initialize();
    final state = c.read(authControllerProvider);
    expect(state, isA<AuthSignedIn>());
    expect((state as AuthSignedIn).user.id, 'u1');
    expect(
      backend.requestsTo('GET /auth/me').single.headers['Authorization'],
      'Bearer t1',
    );
  });

  test('offline restore keeps the token and offers retry', () async {
    final store = InMemoryTokenStore('t1');
    final c = await makeContainer(backend, store: store);
    addTearDown(c.dispose);
    backend.json('GET /auth/me', 503, {'detail': 'down'});

    await c.read(authControllerProvider.notifier).initialize();
    expect(c.read(authControllerProvider), isA<AuthUnverified>());
    expect(await store.read(), 't1');

    backend.json('GET /auth/me', 200, userJson('u1'));
    await c.read(authControllerProvider.notifier).retry();
    expect(c.read(authControllerProvider), isA<AuthSignedIn>());
  });

  test('a rejected stored token requires sign-in and is erased', () async {
    backend.json('GET /auth/me', 401, {
      'detail': 'Invalid authentication credentials',
    });
    final store = InMemoryTokenStore('stale');
    final c = await makeContainer(backend, store: store);
    addTearDown(c.dispose);

    await c.read(authControllerProvider.notifier).initialize();
    final state = c.read(authControllerProvider);
    expect(state, isA<AuthSignedOut>());
    expect((state as AuthSignedOut).reason, SessionEndReason.expired);
    expect(await store.read(), isNull);
  });

  test(
    'unreadable secure storage offers retry instead of signing out',
    () async {
      final store = ControlledTokenStore('t')..failReads = true;
      final c = await makeContainer(backend, store: store);
      addTearDown(c.dispose);
      final init = c.read(authControllerProvider.notifier).initialize();
      await store.completeNext();
      await init;
      final state = c.read(authControllerProvider);
      expect(state, isA<AuthUnverified>());
      expect((state as AuthUnverified).storageUnavailable, isTrue);
    },
  );

  test('login stores the token only after success and verifies it', () async {
    backend.json('POST /auth/login', 200, {
      'access_token': 'new',
      'token_type': 'bearer',
      'expires_in': 86400,
    });
    backend.json('GET /auth/me', 200, userJson('u2'));
    final store = InMemoryTokenStore();
    final c = await makeContainer(backend, store: store);
    addTearDown(c.dispose);
    await c.read(authControllerProvider.notifier).initialize();

    final error = await c
        .read(authControllerProvider.notifier)
        .login('u2@example.com', 'Password123!');
    expect(error, isNull);
    expect(c.read(authControllerProvider), isA<AuthSignedIn>());
    expect(await store.read(), 'new');
    expect(
      backend
          .requestsTo('POST /auth/login')
          .single
          .headers
          .containsKey('Authorization'),
      isFalse,
    );
  });

  test(
    'failed login reports credentials or inactive account and stores nothing',
    () async {
      final store = InMemoryTokenStore();
      final c = await makeContainer(backend, store: store);
      addTearDown(c.dispose);
      await c.read(authControllerProvider.notifier).initialize();
      final auth = c.read(authControllerProvider.notifier);

      backend.json('POST /auth/login', 401, {'detail': 'Invalid credentials'});
      expect(
        await auth.login('a@example.com', 'wrong-pass'),
        isA<InvalidCredentialsException>(),
      );
      backend.json('POST /auth/login', 403, {'detail': 'Inactive account'});
      expect(
        await auth.login('a@example.com', 'Password123!'),
        isA<ForbiddenException>().having(
          (e) => e.message,
          'message',
          'Inactive account',
        ),
      );
      expect(await store.read(), isNull);
      expect(c.read(authControllerProvider), isA<AuthSignedOut>());
    },
  );

  test(
    'a second login tap while one is in flight sends no second request',
    () async {
      final held = backend.hold('POST /auth/login');
      backend.json('GET /auth/me', 200, userJson('u1'));
      final c = await makeContainer(backend);
      addTearDown(c.dispose);
      await c.read(authControllerProvider.notifier).initialize();
      final auth = c.read(authControllerProvider.notifier);

      final first = auth.login('u1@example.com', 'Password123!');
      final second = auth.login('u1@example.com', 'Password123!');
      await settle();
      held.release(200, {
        'access_token': 't',
        'token_type': 'bearer',
        'expires_in': 1,
      });
      await Future.wait([first, second]);
      expect(backend.requestsTo('POST /auth/login'), hasLength(1));
    },
  );

  test(
    'a /me response for a previous account is discarded after switching accounts',
    () async {
      final staleMe = backend.hold('GET /auth/me');
      final store = InMemoryTokenStore('old');
      final c = await makeContainer(backend, store: store);
      addTearDown(c.dispose);
      final init = c.read(authControllerProvider.notifier).initialize();
      await settle();

      await c.read(sessionManagerProvider).signOut();
      backend.json('POST /auth/login', 200, {
        'access_token': 'new',
        'token_type': 'bearer',
        'expires_in': 1,
      });
      backend.json('GET /auth/me', 200, userJson('newuser'));
      await c
          .read(authControllerProvider.notifier)
          .login('newuser@example.com', 'Password123!');
      staleMe.release(200, userJson('olduser'));
      await init;
      await settle();

      final state = c.read(authControllerProvider) as AuthSignedIn;
      expect(state.user.id, 'newuser');
    },
  );

  test('sign-out clears the token and cancels in-flight requests', () async {
    backend.json('GET /auth/me', 200, userJson('u1'));
    final store = InMemoryTokenStore('t1');
    final c = await makeContainer(backend, store: store);
    addTearDown(c.dispose);
    await c.read(authControllerProvider.notifier).initialize();

    backend.hold('GET /spaces');
    final pending = c
        .read(apiClientProvider)
        .request<Object>('/spaces', includeSpace: false);
    await settle();
    await c.read(authControllerProvider.notifier).signOut();

    await expectLater(pending, throwsA(isA<RequestCancelledException>()));
    expect(await store.read(), isNull);
    expect(
      (c.read(authControllerProvider) as AuthSignedOut).reason,
      SessionEndReason.signedOut,
    );
  });

  test('an expiry during use signs out with the expired reason', () async {
    backend.json('GET /auth/me', 200, userJson('u1'));
    backend.json('GET /chat/sessions', 401, {
      'detail': 'Invalid authentication credentials',
    });
    final c = await makeContainer(backend, store: InMemoryTokenStore('t1'));
    addTearDown(c.dispose);
    await c.read(authControllerProvider.notifier).initialize();

    await expectLater(
      c.read(apiClientProvider).request<Object>('/chat/sessions'),
      throwsA(isA<SessionExpiredException>()),
    );
    await settle();
    expect(
      (c.read(authControllerProvider) as AuthSignedOut).reason,
      SessionEndReason.expired,
    );
  });
}
