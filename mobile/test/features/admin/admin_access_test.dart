import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/network/api_exception.dart';
import 'package:teia_ai/core/storage/token_store.dart';
import 'package:teia_ai/features/admin/application/admin_access.dart';
import 'package:teia_ai/features/auth/application/auth_controller.dart';
import 'package:teia_ai/features/spaces/application/space_controller.dart';

import '../../support/container.dart';
import '../../support/fake_backend.dart';

FakeBackend backend({String role = 'admin'}) => FakeBackend()
  ..json('GET /auth/me', 200, userJson('u1'))
  ..json('GET /spaces', 200, [spaceJson('s1'), spaceJson('s2')])
  ..json('GET /spaces/s1/me', 200, membershipJson('s1', role: role))
  ..json('GET /spaces/s2/me', 200, membershipJson('s2', role: 'admin'));

Future<ProviderContainer> signedIn(FakeBackend b) async {
  final c = await makeContainer(
    b,
    store: InMemoryTokenStore('t'),
    prefs: {'active_space.u1': 's1'},
  );
  addTearDown(c.dispose);
  c.listen(spaceControllerProvider, (_, _) {});
  c.listen(adminScopeProvider, (_, _) {});
  await c.read(authControllerProvider.notifier).initialize();
  await settle();
  return c;
}

void main() {
  test('admin scope exists only for an active admin membership', () async {
    final admin = await signedIn(backend());
    expect(admin.read(spaceControllerProvider), isA<SpaceSelected>());
    expect(admin.read(adminScopeProvider), endsWith('/s1'));

    final member = await signedIn(backend(role: 'member'));
    expect(member.read(spaceControllerProvider), isA<SpaceSelected>());
    expect(member.read(adminScopeProvider), isNull);
  });

  test(
    'revalidating after a role change drops the admin scope in place',
    () async {
      final b = backend();
      final c = await signedIn(b);
      b.json('GET /spaces/s1/me', 200, membershipJson('s1'));
      await c.read(spaceControllerProvider.notifier).revalidate();
      final state = c.read(spaceControllerProvider);
      expect(state, isA<SpaceSelected>());
      expect((state as SpaceSelected).space.id, 's1');
      expect(c.read(adminScopeProvider), isNull);
    },
  );

  test('a 403 from an admin call re-checks the membership', () async {
    final b = backend()
      ..json('GET /spaces/s1/members', 403, {'detail': 'Space admin required'});
    final c = await signedIn(b);
    final checks = b.requestsTo('GET /spaces/s1/me').length;
    b.json('GET /spaces/s1/me', 200, membershipJson('s1'));
    await expectLater(
      c.read(adminMembersProvider.future),
      throwsA(isA<ForbiddenException>()),
    );
    await settle();
    expect(b.requestsTo('GET /spaces/s1/me').length, checks + 1);
    expect(c.read(adminScopeProvider), isNull);
  });

  test('a result that arrives after a space switch is dropped', () async {
    final b = backend();
    final held = b.hold('GET /spaces/s1/members');
    final c = await signedIn(b);
    final ref = c.read(_refProvider);
    final pending = runAdmin(ref, (api, id) => api.members(id));
    await settle();
    await c.read(spaceControllerProvider.notifier).select('s2');
    held.release(200, <Object>[]);
    expect(await pending, isNull);
  });

  test('without admin access no admin call is made', () async {
    final b = backend(role: 'member');
    final c = await signedIn(b);
    await expectLater(
      c.read(adminMembersProvider.future),
      throwsA(isA<AdminAccessLost>()),
    );
    expect(b.requestsTo('GET /spaces/s1/members'), isEmpty);
  });
}

final _refProvider = Provider<Ref>((ref) => ref);
