import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/network/api_client.dart';
import 'package:teia_ai/core/providers.dart';
import 'package:teia_ai/core/storage/token_store.dart';
import 'package:teia_ai/features/auth/application/auth_controller.dart';
import 'package:teia_ai/features/spaces/application/space_controller.dart';

import '../../support/container.dart';
import '../../support/fake_backend.dart';

Future<ProviderContainer> signedIn(
  FakeBackend backend, {
  String user = 'u1',
  Map<String, Object> prefs = const {},
}) async {
  backend.json('GET /auth/me', 200, userJson(user));
  final c = await makeContainer(
    backend,
    store: InMemoryTokenStore('t-$user'),
    prefs: prefs,
  );
  c.listen(spaceControllerProvider, (_, _) {});
  await c.read(authControllerProvider.notifier).initialize();
  await settle();
  return c;
}

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.json('GET /spaces/s1/me', 200, membershipJson('s1'));
    backend.json('GET /spaces/s2/me', 200, membershipJson('s2', role: 'admin'));
  });

  test(
    'restores a stored selection only after validating membership',
    () async {
      backend.json('GET /spaces', 200, [spaceJson('s1'), spaceJson('s2')]);
      final c = await signedIn(backend, prefs: {'active_space.u1': 's2'});
      addTearDown(c.dispose);

      final state = c.read(spaceControllerProvider);
      expect(state, isA<SpaceSelected>());
      expect((state as SpaceSelected).space.id, 's2');
      expect(c.read(selectedSpaceIdProvider), 's2');
      expect(backend.requestsTo('GET /spaces/s2/me'), hasLength(1));
    },
  );

  test(
    'a stored space that is no longer accessible is never selected',
    () async {
      backend.json('GET /spaces', 200, [spaceJson('s1'), spaceJson('s3')]);
      final c = await signedIn(backend, prefs: {'active_space.u1': 's2'});
      addTearDown(c.dispose);

      final state = c.read(spaceControllerProvider);
      expect(state, isA<SpaceChoosing>());
      expect((state as SpaceChoosing).notice, SpaceNotice.accessLost);
      expect(c.read(selectedSpaceIdProvider), isNull);
      expect(
        c.read(sharedPreferencesProvider).getString('active_space.u1'),
        isNull,
      );
    },
  );

  test(
    'a single accessible space is selected; none shows the empty state',
    () async {
      backend.json('GET /spaces', 200, [spaceJson('s1')]);
      final one = await signedIn(backend);
      addTearDown(one.dispose);
      expect(one.read(spaceControllerProvider), isA<SpaceSelected>());

      final other = FakeBackend()..json('GET /spaces', 200, <Object>[]);
      final none = await signedIn(other);
      addTearDown(none.dispose);
      final state = none.read(spaceControllerProvider);
      expect(state, isA<SpaceChoosing>());
      expect((state as SpaceChoosing).spaces, isEmpty);
    },
  );

  test('inactive spaces and revoked memberships are not selectable', () async {
    backend.json('GET /spaces', 200, [
      spaceJson('s1', active: false),
      spaceJson('s2'),
    ]);
    backend.json(
      'GET /spaces/s2/me',
      200,
      membershipJson('s2', status: 'revoked'),
    );
    final c = await signedIn(backend, prefs: {'active_space.u1': 's2'});
    addTearDown(c.dispose);
    final state = c.read(spaceControllerProvider);
    expect(state, isA<SpaceChoosing>());
    expect(c.read(selectedSpaceIdProvider), isNull);
  });

  test(
    'switching discards a late membership response from the previous choice',
    () async {
      backend.json('GET /spaces', 200, [spaceJson('s1'), spaceJson('s2')]);
      final c = await signedIn(backend);
      addTearDown(c.dispose);
      expect(c.read(spaceControllerProvider), isA<SpaceChoosing>());

      final slow = backend.hold('GET /spaces/s1/me');
      final controller = c.read(spaceControllerProvider.notifier);
      final first = controller.select('s1');
      await settle();
      await controller.select('s2');
      slow.release(200, membershipJson('s1'));
      await first;
      await settle();

      expect((c.read(spaceControllerProvider) as SpaceSelected).space.id, 's2');
      expect(c.read(selectedSpaceIdProvider), 's2');
    },
  );

  test(
    'selecting a space that is not in the accessible list does nothing',
    () async {
      backend.json('GET /spaces', 200, [spaceJson('s1'), spaceJson('s2')]);
      final c = await signedIn(backend);
      addTearDown(c.dispose);
      await c.read(spaceControllerProvider.notifier).select('forged');
      expect(c.read(selectedSpaceIdProvider), isNull);
      expect(backend.requestsTo('GET /spaces/forged/me'), isEmpty);
    },
  );

  test(
    'X-Space-Id is sent only after validation and cleared on switch-away',
    () async {
      backend.json('GET /spaces', 200, [spaceJson('s1'), spaceJson('s2')]);
      backend.json('GET /chat/sessions', 200, <Object>[]);
      final c = await signedIn(backend);
      addTearDown(c.dispose);
      final api = c.read(apiClientProvider);

      await api.request<Object>('/chat/sessions');
      await c.read(spaceControllerProvider.notifier).select('s1');
      await api.request<Object>('/chat/sessions');
      c.read(spaceControllerProvider.notifier).clearSelection();
      await api.request<Object>('/chat/sessions');

      final headers = backend
          .requestsTo('GET /chat/sessions')
          .map((r) => r.headers[ApiClient.spaceHeader])
          .toList();
      expect(headers, [null, 's1', null]);
    },
  );

  test(
    'a backend rejection of the selected space re-resolves with a notice',
    () async {
      backend.json('GET /spaces', 200, [spaceJson('s1')]);
      final c = await signedIn(backend);
      addTearDown(c.dispose);
      expect(c.read(spaceControllerProvider), isA<SpaceSelected>());

      backend.json('GET /spaces', 200, <Object>[]);
      backend.json('GET /chat/sessions', 403, {
        'detail': 'Space access denied',
      });
      await expectLater(
        c.read(apiClientProvider).request<Object>('/chat/sessions'),
        throwsA(anything),
      );
      await settle();

      final state = c.read(spaceControllerProvider);
      expect(state, isA<SpaceChoosing>());
      expect((state as SpaceChoosing).notice, SpaceNotice.accessLost);
      expect(c.read(selectedSpaceIdProvider), isNull);
    },
  );

  test('selections are stored per account and cleared on sign-out', () async {
    backend.json('GET /spaces', 200, [spaceJson('s1'), spaceJson('s2')]);
    final c = await signedIn(
      backend,
      prefs: {'active_space.u1': 's1', 'active_space.u2': 's2'},
    );
    addTearDown(c.dispose);
    expect((c.read(spaceControllerProvider) as SpaceSelected).space.id, 's1');

    await c.read(authControllerProvider.notifier).signOut();
    await settle();
    expect(c.read(spaceControllerProvider), isA<SpaceIdle>());
    expect(c.read(selectedSpaceIdProvider), isNull);
    final prefs = c.read(sharedPreferencesProvider);
    expect(prefs.getString('active_space.u1'), isNull);
    expect(prefs.getString('active_space.u2'), 's2');

    backend.json('POST /auth/login', 200, {
      'access_token': 't-u2',
      'token_type': 'bearer',
      'expires_in': 1,
    });
    backend.json('GET /auth/me', 200, userJson('u2'));
    await c
        .read(authControllerProvider.notifier)
        .login('u2@example.com', 'Password123!');
    await settle();
    expect((c.read(spaceControllerProvider) as SpaceSelected).space.id, 's2');
  });

  test('available spaces mark pending join requests', () async {
    backend.json('GET /spaces', 200, <Object>[]);
    backend.json('GET /spaces/available', 200, [
      spaceJson('s5'),
      spaceJson('s6'),
    ]);
    backend.json('GET /spaces/requests/mine', 200, [
      {
        'id': 'r1',
        'space_id': 's5',
        'user_id': 'u1',
        'type': 'join',
        'status': 'pending',
        'created_at': '2026-10-12T00:00:00',
      },
    ]);
    final c = await signedIn(backend);
    addTearDown(c.dispose);
    final items = await c.read(availableSpacesProvider.future);
    expect(
      {for (final i in items) i.space.id: i.requestPending},
      {'s5': true, 's6': false},
    );
  });
}
