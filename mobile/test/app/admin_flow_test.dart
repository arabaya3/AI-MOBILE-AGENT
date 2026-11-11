import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/app/router.dart';
import 'package:teia_ai/core/preferences/app_preferences.dart';
import 'package:teia_ai/core/storage/token_store.dart';
import 'package:teia_ai/features/admin/application/admin_access.dart';
import 'package:teia_ai/features/admin/presentation/admin_home_screen.dart';
import 'package:teia_ai/features/admin/presentation/members_screens.dart';
import 'package:teia_ai/features/home/presentation/home_screen.dart';

import '../support/fake_backend.dart';
import '../support/test_app.dart';

Map<String, dynamic> member(
  String id, {
  bool admin = false,
  String status = 'active',
  bool upload = false,
  Map<String, Object?> overrides = const {},
}) => {
  'user_id': id,
  'email': '$id@example.com',
  'role': admin ? 'admin' : 'member',
  'status': status,
  'can_upload_documents': upload,
  'created_at': '2026-10-12T00:00:00',
  'updated_at': '2026-10-12T00:00:00',
  'overrides': overrides,
};

Map<String, dynamic> adminSpace({Map<String, Object?> policy = const {}}) => {
  ...spaceJson('s1'),
  'policy': {
    'allowed_models': ['teia-stub-1'],
    'allowed_tools': <String>[],
    ...policy,
  },
};

Map<String, dynamic> invite(String id, String status, {int sends = 1}) => {
  'id': id,
  'email': '$id@example.com',
  'status': status,
  'expires_at': '2026-11-18T00:00:00',
  'created_at': '2026-11-11T00:00:00',
  'last_sent_at': '2026-11-11T00:00:00',
  'send_count': sends,
};

Map<String, dynamic> request(
  String id, {
  String type = 'upload_access',
  String user = 'mia',
  String status = 'pending',
  Map<String, Object?> payload = const {},
}) => {
  'id': id,
  'space_id': 's1',
  'user_id': user,
  'user_email': '$user@example.com',
  'type': type,
  'payload': payload,
  'status': status,
  'created_at': '2026-11-10T09:00:00',
};

FakeBackend adminBackend({String role = 'admin'}) => FakeBackend()
  ..json('GET /auth/me', 200, userJson('u1'))
  ..json('GET /spaces', 200, [adminSpace()])
  ..json('GET /spaces/s1/me', 200, membershipJson('s1', role: role))
  ..json('GET /spaces/s1/members', 200, [
    member('u1', admin: true),
    member('mia', overrides: {'daily_token_limit': 0}),
    member('old', status: 'revoked'),
  ])
  ..json('GET /spaces/s1/invites', 200, [
    invite('i1', 'pending'),
    invite('i2', 'expired', sends: 2),
  ])
  ..json('GET /spaces/s1/requests', 200, [
    request('r1'),
    request('r2', type: 'model_access', payload: {'model': 'teia-stub-2'}),
    request('r3', status: 'approved'),
  ])
  ..json('GET /spaces/s1/catalog', 200, {
    'models': [
      {'id': 'teia-stub-1'},
      {'id': 'teia-stub-2'},
    ],
    'tools': [
      {'id': 'calculator'},
      {'id': 'web_search_tavily'},
    ],
  })
  ..json('GET /chat/sessions', 200, <Object>[])
  ..json('GET /notifications/', 200, <Object>[])
  ..json('GET /notifications/unread-count', 200, {'count': 0});

Future<ProviderContainer> pumpAdmin(
  WidgetTester tester,
  FakeBackend backend, {
  Size size = const Size(360, 740),
  double textScale = 1.0,
}) => pumpTeiaApp(
  tester,
  backend,
  store: InMemoryTokenStore('t'),
  size: size,
  textScale: textScale,
);

Future<void> go(WidgetTester tester, ProviderContainer c, String path) async {
  unawaited(c.read(routerProvider).push(path));
  await settleApp(tester);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await settleApp(tester);
}

Future<void> confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('confirm-action')));
  await settleApp(tester);
}

void main() {
  testWidgets('ordinary members see no entry and cannot open admin routes', (
    tester,
  ) async {
    final backend = adminBackend(role: 'member');
    final c = await pumpAdmin(tester, backend);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('open-admin')), findsNothing);
    await go(tester, c, '/admin/members');
    expect(find.byType(MembersScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(backend.requestsTo('GET /spaces/s1/members'), isEmpty);
    expect(c.read(adminScopeProvider), isNull);
  });

  testWidgets('admins open Manage space after a fresh membership check', (
    tester,
  ) async {
    final backend = adminBackend();
    await pumpAdmin(tester, backend);
    final checks = backend.requestsTo('GET /spaces/s1/me').length;
    await tapKey(tester, 'open-admin');
    expect(find.byType(AdminHomeScreen), findsOneWidget);
    expect(backend.requestsTo('GET /spaces/s1/me').length, checks + 1);
    // Counts: 2 active members, 1 open invitation, 2 pending requests.
    expect(find.text('Space s1'), findsOneWidget);
    for (final key in ['admin-members', 'admin-invites', 'admin-requests']) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
  });

  testWidgets(
    'losing the admin role while a screen is open closes it and clears admin state',
    (tester) async {
      final backend = adminBackend();
      final c = await pumpAdmin(tester, backend);
      await go(tester, c, '/admin/members');
      expect(find.byType(MembersScreen), findsOneWidget);
      expect(c.read(adminScopeProvider), isNotNull);

      // The role is removed elsewhere; the next admin call is refused.
      backend
        ..json('GET /spaces/s1/me', 200, membershipJson('s1'))
        ..json('PATCH /spaces/s1/members/mia', 403, {
          'detail': 'Space admin required',
        });
      await tapKey(tester, 'member-mia');
      await tapKey(tester, 'member-upload');
      await settleApp(tester);
      await settleApp(tester);

      expect(find.byType(MemberDetailScreen), findsNothing);
      expect(find.byType(MembersScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(c.read(adminScopeProvider), isNull);
      expect(find.byKey(const ValueKey('open-admin')), findsNothing);
    },
  );

  testWidgets(
    'limits show unlimited, blocked, inherited and explicit values distinctly',
    (tester) async {
      final backend = adminBackend()
        ..json('GET /spaces', 200, [
          adminSpace(
            policy: {'daily_token_limit': 50000, 'monthly_token_limit': null},
          ),
        ]);
      final c = await pumpAdmin(tester, backend);
      await go(tester, c, '/admin/limits');
      expect(find.text('50,000'), findsOneWidget);
      expect(find.text('No limit'), findsNWidgets(5));

      await go(tester, c, '/admin/members/mia');
      expect(
        find.text('0 (blocked)'),
        findsOneWidget,
      ); // explicit 0 for this member
      expect(find.text('Space default: No limit'), findsWidgets);
    },
  );

  testWidgets('a member limit can be cleared back to the space default', (
    tester,
  ) async {
    final backend = adminBackend()
      ..json('PATCH /spaces/s1/members/mia', 200, member('mia'));
    final c = await pumpAdmin(tester, backend);
    await go(tester, c, '/admin/members/mia');
    await tapKey(tester, 'member-limit-daily_token_limit');
    await tester.tap(find.byKey(const ValueKey('limit-clear')));
    await tester.tap(find.byKey(const ValueKey('limit-save')));
    await settleApp(tester);
    final sent = backend.requestsTo('PATCH /spaces/s1/members/mia').single;
    expect(backend.bodyOf(sent), {
      'overrides': {'daily_token_limit': null},
    });
  });

  testWidgets('a zero space limit needs confirmation and sends 0', (
    tester,
  ) async {
    final backend = adminBackend()
      ..json('PATCH /spaces/s1/policy', 200, adminSpace());
    final c = await pumpAdmin(tester, backend);
    await go(tester, c, '/admin/limits');
    await tapKey(tester, 'space-limit-daily_request_limit');
    await tester.tap(find.byKey(const ValueKey('limit-set')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('limit-value')), '0');
    await tester.tap(find.byKey(const ValueKey('limit-save')));
    await settleApp(tester);
    expect(find.text('Block this for everyone?'), findsOneWidget);
    expect(backend.requestsTo('PATCH /spaces/s1/policy'), isEmpty);
    await confirm(tester);
    expect(
      backend.bodyOf(backend.requestsTo('PATCH /spaces/s1/policy').single),
      {'daily_request_limit': 0},
    );
  });

  testWidgets(
    'demoting needs confirmation and the last-admin rule is explained',
    (tester) async {
      final backend = adminBackend()
        ..json('PATCH /spaces/s1/members/u1', 409, {
          'detail': 'A space must keep at least one active admin',
        });
      final c = await pumpAdmin(tester, backend);
      await go(tester, c, '/admin/members/u1');
      expect(find.text('This is you.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('member-admin')));
      await settleApp(tester);
      expect(find.text('Remove your own admin role?'), findsOneWidget);
      await confirm(tester);
      expect(
        backend.bodyOf(
          backend.requestsTo('PATCH /spaces/s1/members/u1').single,
        ),
        {'role': 'member'},
      );
      expect(find.textContaining('at least one active admin'), findsOneWidget);
    },
  );

  testWidgets('removing access is confirmed; cancelling sends nothing', (
    tester,
  ) async {
    final backend = adminBackend()
      ..json(
        'PATCH /spaces/s1/members/mia',
        200,
        member('mia', status: 'revoked'),
      );
    final c = await pumpAdmin(tester, backend);
    await go(tester, c, '/admin/members/mia');
    await tapKey(tester, 'member-revoke');
    await tester.tap(find.text('Cancel'));
    await settleApp(tester);
    expect(backend.requestsTo('PATCH /spaces/s1/members/mia'), isEmpty);
    await tapKey(tester, 'member-revoke');
    await confirm(tester);
    expect(
      backend.bodyOf(backend.requestsTo('PATCH /spaces/s1/members/mia').single),
      {'status': 'revoked'},
    );
  });

  testWidgets(
    'an invitation is sent once even when tapped twice, and no link is shown',
    (tester) async {
      final backend = adminBackend();
      final held = backend.hold('POST /spaces/s1/invites');
      final c = await pumpAdmin(tester, backend);
      await go(tester, c, '/admin/invites');
      expect(find.textContaining('token'), findsNothing);
      expect(find.text('Waiting'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('new-invite')));
      await settleApp(tester);
      await tester.enterText(find.byType(TextFormField), 'new@example.com');
      await tester.tap(find.byKey(const ValueKey('send-invite')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('send-invite')),
        warnIfMissed: false,
      );
      await tester.pump();
      held.release(200, invite('new', 'pending'));
      await settleApp(tester);
      expect(backend.requestsTo('POST /spaces/s1/invites'), hasLength(1));
      expect(find.text('Invitation sent to new@example.com.'), findsOneWidget);
    },
  );

  testWidgets('an uncertain invitation result reloads the list and says so', (
    tester,
  ) async {
    final backend = adminBackend()
      ..on(
        'POST /spaces/s1/invites',
        (r) => throw DioException.connectionError(
          requestOptions: r,
          reason: 'offline',
        ),
      );
    final c = await pumpAdmin(tester, backend);
    await go(tester, c, '/admin/invites');
    final loads = backend.requestsTo('GET /spaces/s1/invites').length;
    await tester.tap(find.byKey(const ValueKey('new-invite')));
    await settleApp(tester);
    await tester.enterText(find.byType(TextFormField), 'new@example.com');
    await tester.tap(find.byKey(const ValueKey('send-invite')));
    await settleApp(tester);
    expect(find.textContaining("couldn't confirm the change"), findsOneWidget);
    expect(
      backend.requestsTo('GET /spaces/s1/invites').length,
      greaterThan(loads),
    );
  });

  testWidgets('a failed invitation email is reported, not hidden', (
    tester,
  ) async {
    final backend = adminBackend()
      ..json('POST /spaces/s1/invites', 503, {
        'detail': 'Invitation email could not be sent',
      });
    final c = await pumpAdmin(tester, backend);
    await go(tester, c, '/admin/invites');
    await tester.tap(find.byKey(const ValueKey('new-invite')));
    await settleApp(tester);
    await tester.enterText(find.byType(TextFormField), 'new@example.com');
    await tester.tap(find.byKey(const ValueKey('send-invite')));
    await settleApp(tester);
    expect(find.textContaining('no invitation was created'), findsOneWidget);
  });

  testWidgets('revoking an invitation is confirmed', (tester) async {
    final backend = adminBackend()
      ..json('POST /spaces/s1/invites/i1/revoke', 200, invite('i1', 'revoked'));
    final c = await pumpAdmin(tester, backend);
    await go(tester, c, '/admin/invites');
    await tester.tap(find.byKey(const ValueKey('invite-menu-i1')));
    await settleApp(tester);
    await tester.tap(find.text('Revoke').last);
    await settleApp(tester);
    expect(find.text('Revoke this invitation?'), findsOneWidget);
    await confirm(tester);
    expect(
      backend.requestsTo('POST /spaces/s1/invites/i1/revoke'),
      hasLength(1),
    );
  });

  testWidgets('approving sends the decision and note and refreshes members', (
    tester,
  ) async {
    final backend = adminBackend()
      ..json(
        'POST /spaces/s1/requests/r1/review',
        200,
        request('r1', status: 'approved'),
      );
    final c = await pumpAdmin(tester, backend);
    await go(tester, c, '/admin/requests');
    final requestLoads = backend.requestsTo('GET /spaces/s1/requests').length;
    await tester.tap(find.byKey(const ValueKey('admin-request-r1')));
    await settleApp(tester);
    await tester.enterText(
      find.byKey(const ValueKey('review-note')),
      'Welcome',
    );
    await tester.tap(find.byKey(const ValueKey('approve-request')));
    await settleApp(tester);
    expect(
      backend.bodyOf(
        backend.requestsTo('POST /spaces/s1/requests/r1/review').single,
      ),
      {'decision': 'approved', 'note': 'Welcome'},
    );
    expect(
      backend.requestsTo('GET /spaces/s1/requests').length,
      greaterThan(requestLoads),
    );
    expect(find.text('Approved. The member was notified.'), findsOneWidget);
  });

  testWidgets('a request reviewed elsewhere is explained and reloaded', (
    tester,
  ) async {
    final backend = adminBackend()
      ..json('POST /spaces/s1/requests/r2/review', 409, {
        'detail': 'This request was already reviewed',
      });
    final c = await pumpAdmin(tester, backend);
    await go(tester, c, '/admin/requests');
    await tester.tap(find.byKey(const ValueKey('admin-request-r2')));
    await settleApp(tester);
    expect(find.text('Model: teia-stub-2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('decline-request')));
    await settleApp(tester);
    expect(find.textContaining('already reviewed'), findsOneWidget);
  });

  testWidgets('an admin cannot review their own request in the app', (
    tester,
  ) async {
    final backend = adminBackend()
      ..json('GET /spaces/s1/requests', 200, [request('own', user: 'u1')]);
    final c = await pumpAdmin(tester, backend);
    await go(tester, c, '/admin/requests');
    await tester.tap(find.byKey(const ValueKey('admin-request-own')));
    await settleApp(tester);
    expect(find.byKey(const ValueKey('approve-request')), findsNothing);
    expect(find.textContaining('reviewed by another admin'), findsOneWidget);
  });

  testWidgets('allowed models are saved from the catalog with one action', (
    tester,
  ) async {
    final backend = adminBackend()
      ..json('PATCH /spaces/s1/policy', 200, adminSpace());
    final c = await pumpAdmin(tester, backend);
    await go(tester, c, '/admin/models');
    expect(find.byKey(const ValueKey('save-policy')), findsNothing);
    await tapKey(tester, 'model-teia-stub-2');
    await tapKey(tester, 'tool-calculator');
    await tester.tap(find.byKey(const ValueKey('save-policy')));
    await settleApp(tester);
    expect(
      backend.bodyOf(backend.requestsTo('PATCH /spaces/s1/policy').single),
      {
        'allowed_models': ['teia-stub-1', 'teia-stub-2'],
        'allowed_tools': ['calculator'],
      },
    );
  });

  testWidgets(
    'document access: hiding is confirmed; grants toggle per member',
    (tester) async {
      final backend = adminBackend()
        ..json('GET /documents/accessible', 200, [
          {
            'id': 'd1',
            'filename': 'Plan.pdf',
            'file_type': 'pdf',
            'state': 'ready',
            'is_hidden': false,
            'uploaded_by_user_id': 'u1',
          },
        ])
        ..json('POST /documents/permissions/status', 200, {
          'any_user_ids': <String>[],
          'all_user_ids': <String>[],
        })
        ..json('POST /documents/permissions', 200, {'granted': 1})
        ..json('PATCH /documents/d1/visibility', 200, {'id': 'd1'});
      final c = await pumpAdmin(tester, backend);
      await go(tester, c, '/admin/documents');
      await tester.tap(find.byKey(const ValueKey('admin-doc-d1')));
      await settleApp(tester);
      await tester.tap(find.byKey(const ValueKey('doc-access-mia')));
      await settleApp(tester);
      expect(
        backend.bodyOf(
          backend.requestsTo('POST /documents/permissions').single,
        ),
        {
          'user_id': 'mia',
          'document_ids': ['d1'],
        },
      );
      expect(
        backend
            .requestsTo('POST /documents/permissions')
            .single
            .headers['X-Space-Id'],
        's1',
      );
      await tester.tap(find.byKey(const ValueKey('doc-hidden')));
      await settleApp(tester);
      expect(find.text('Hide this document?'), findsOneWidget);
      await confirm(tester);
      expect(
        backend.bodyOf(
          backend.requestsTo('PATCH /documents/d1/visibility').single,
        ),
        {'is_hidden': true},
      );
    },
  );

  testWidgets(
    'members request a tool from the catalog, minus tools they have',
    (tester) async {
      final backend = adminBackend(role: 'member')
        ..json('GET /spaces/s1/me', 200, {
          ...membershipJson('s1'),
          'effective_tools': ['calculator'],
        })
        ..json('GET /chat/models', 200, ['teia-stub-1'])
        ..json('GET /chat/models/all', 200, ['teia-stub-1'])
        ..json('GET /requests/', 200, <Object>[])
        ..json('GET /spaces/requests/mine', 200, <Object>[])
        ..json('POST /spaces/s1/requests', 201, {
          ...request('t1', type: 'tool_access', user: 'u1'),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      final c = await pumpAdmin(tester, backend);
      await go(tester, c, '/requests');
      await tester.tap(find.byKey(const ValueKey('new-request')));
      await settleApp(tester);
      await tester.tap(find.byKey(const ValueKey('request-kind-tool')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('request-tool')));
      await settleApp(tester);
      expect(find.text('calculator'), findsNothing);
      await tester.tap(find.text('web_search_tavily').last);
      await settleApp(tester);
      await tester.tap(find.text('Send request'));
      await settleApp(tester);
      expect(
        backend.bodyOf(backend.requestsTo('POST /spaces/s1/requests').single),
        {
          'type': 'tool_access',
          'payload': {'tool': 'web_search_tavily'},
        },
      );
    },
  );

  for (final (locale, dark) in [
    ('en', false),
    ('ar', false),
    ('ar', true),
    ('en', true),
  ]) {
    testWidgets(
      'admin screens lay out in $locale/${dark ? 'dark' : 'light'} at 2x text on a compact phone',
      (tester) async {
        final backend = adminBackend()
          ..json('GET /spaces/s1/usage', 200, {
            'start': '2026-10-12T00:00:00',
            'end': '2026-11-11T00:00:00',
            'totals': {'total_tokens': 1234, 'requests': 5, 'cost_usd': null},
            'by_model': <String, Object>{},
          })
          ..json('GET /documents/accessible', 200, <Object>[]);
        final c = await pumpAdmin(
          tester,
          backend,
          size: const Size(320, 640),
          textScale: 2.0,
        );
        await c.read(localeProvider.notifier).select(Locale(locale));
        await c
            .read(themeModeProvider.notifier)
            .select(dark ? ThemeMode.dark : ThemeMode.light);
        await settleApp(tester);
        for (final path in [
          '/admin',
          '/admin/members',
          '/admin/members/mia',
          '/admin/invites',
          '/admin/requests',
          '/admin/models',
          '/admin/limits',
          '/admin/documents',
          '/admin/usage',
        ]) {
          await go(tester, c, path);
          expect(tester.takeException(), isNull, reason: path);
        }
      },
    );
  }
}
