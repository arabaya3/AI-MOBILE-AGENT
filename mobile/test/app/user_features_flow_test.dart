import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/files/private_files.dart';
import 'package:teia_ai/core/storage/token_store.dart';
import 'package:teia_ai/features/requests/presentation/requests_screen.dart';
import 'package:teia_ai/features/usage/presentation/usage_screen.dart';

import '../support/fake_adapter.dart';
import '../support/fake_backend.dart';
import '../support/test_app.dart';

Map<String, dynamic> overview({
  double? cost,
  int unknown = 0,
  int days = 30,
}) => {
  'window': {
    'start': '2026-10-03T10:00:00',
    'end': '2026-11-02T10:00:00',
    'days': days,
    'timezone': 'UTC',
    'kind': 'rolling',
  },
  'requests': {
    'total': 3 + unknown,
    'with_reported_usage': 3,
    'with_unknown_usage': unknown,
    'unknown_breakdown': unknown > 0 ? {'cancelled': unknown} : <String, int>{},
  },
  'tokens': {'input': 1200, 'output': 300, 'total': 1500},
  'cost': {
    'basis': 'estimated',
    'currency': 'USD',
    'amount': cost,
    'complete': unknown == 0 && cost != null,
    'requests_without_cost': unknown,
  },
  'by_model': [
    {
      'model': 'teia-stub-1',
      'requests': 3,
      'input_tokens': 1200,
      'output_tokens': 300,
      'total_tokens': 1500,
      'cost_usd': cost,
      'cost_complete': cost != null,
    },
  ],
  'tools': <Object>[],
  'limits': [
    {
      'key': 'daily_tokens',
      'unit': 'tokens',
      'window_hours': 24,
      'limit': 5000,
      'used': 4200,
      'remaining': 800,
      'reserved_for_unknown': 4000,
    },
    {
      'key': 'monthly_conversations',
      'unit': 'conversations',
      'window_hours': 720,
      'limit': null,
      'used': 2,
      'remaining': null,
      'reserved_for_unknown': 0,
    },
  ],
};

FakeBackend appBackend() => FakeBackend()
  ..json('GET /auth/me', 200, userJson('u1', firstName: 'Lina'))
  ..json('GET /spaces', 200, [spaceJson('s1')])
  ..json('GET /spaces/s1/me', 200, membershipJson('s1'))
  ..json('GET /chat/sessions', 200, <Object>[])
  ..json('GET /chat/models', 200, ['teia-stub-1'])
  ..json('GET /chat/models/all', 200, ['teia-stub-1', 'teia-stub-2'])
  ..json('GET /documents/accessible', 200, <Object>[])
  ..json('GET /notifications/', 200, <Object>[])
  ..json('GET /notifications/unread-count', 200, {'count': 0})
  ..json('GET /requests/', 200, <Object>[])
  ..json('GET /spaces/requests/mine', 200, <Object>[]);

Future<void> openFromHome(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(target);
  await settleApp(tester);
}

typedef Shared = ({String path, String mime});

void main() {
  testWidgets(
    'usage never shows unknown cost as zero and labels limits honestly',
    (tester) async {
      final backend = appBackend()
        ..on(
          'GET /chat/usage/overview',
          (r) => jsonBody(
            200,
            overview(
              unknown: 1,
              days: int.parse('${r.queryParameters['days']}'),
            ),
          ),
        );
      await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
      await openFromHome(tester, 'open-usage');
      expect(find.byType(UsageScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('usage-cost')), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.textContaining(r'$0'), findsNothing);
      expect(
        find.textContaining('This does not mean it was free'),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 reply has no reported usage'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('4,200 of 5,000 used · 800 left'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Includes 4,000 counted for replies'),
        findsOneWidget,
      );
      expect(find.text('2 used · no limit'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('7 days'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('7 days'));
      await settleApp(tester);
      expect(
        backend
            .requestsTo('GET /chat/usage/overview')
            .last
            .queryParameters['days'],
        7,
      );
    },
  );

  testWidgets('measured cost is shown as an estimate in dollars', (
    tester,
  ) async {
    final backend = appBackend()
      ..json('GET /chat/usage/overview', 200, overview(cost: 0.0123));
    await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
    await openFromHome(tester, 'open-usage');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('usage-cost'))).data,
      r'US$0.0123',
    );
    expect(find.textContaining('not a provider invoice'), findsOneWidget);
  });

  testWidgets(
    'invoice is downloaded through the API and handed to the share sheet',
    (tester) async {
      Shared? shared;
      final backend = appBackend()
        ..json('GET /chat/usage/overview', 200, overview(cost: 1.5))
        ..on(
          'GET /chat/usage/invoice/pdf',
          (_) => textBody(200, '%PDF-1.4 fake'),
        );
      await pumpTeiaApp(
        tester,
        backend,
        store: InMemoryTokenStore('t'),
        overrides: [
          shareFileProvider.overrideWithValue((path, mime, _) async {
            shared = (path: path, mime: mime);
            return ShareOutcome.shared;
          }),
        ],
      );
      await openFromHome(tester, 'open-usage');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('usage-invoice')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('usage-invoice')));
      for (var i = 0; i < 4; i++) {
        await settleApp(tester);
      }
      expect(shared?.mime, 'application/pdf');
      expect(shared!.path.endsWith('teia-usage-30d.pdf'), isTrue);
      await tester.runAsync(
        () async =>
            expect(await File(shared!.path).readAsString(), '%PDF-1.4 fake'),
      );
      final request = backend.requestsTo('GET /chat/usage/invoice/pdf').single;
      expect(request.uri.queryParameters['days'], '30');
      expect(request.followRedirects, isFalse);
    },
  );

  testWidgets('a refused invoice download is explained', (tester) async {
    final backend = appBackend()
      ..json('GET /chat/usage/overview', 200, overview(cost: 1.5))
      ..json('GET /chat/usage/invoice/pdf', 403, {
        'detail': 'Space access denied',
      });
    await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
    await openFromHome(tester, 'open-usage');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('usage-invoice')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('usage-invoice')));
    for (var i = 0; i < 3; i++) {
      await settleApp(tester);
    }
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets(
    'requests show outcome and notes; submitting sends only the needed fields',
    (tester) async {
      final backend = appBackend()
        ..json('GET /spaces/requests/mine', 200, [
          {
            'id': 'r1',
            'space_id': 's1',
            'user_id': 'u1',
            'type': 'model_access',
            'payload': {'model': 'teia-stub-2'},
            'status': 'declined',
            'review_note': 'Budget is fixed this quarter',
            'created_at': '2026-11-01T09:00:00',
            'reviewed_at': '2026-11-01T10:00:00',
          },
        ])
        ..on(
          'POST /spaces/s1/requests',
          (r) => jsonBody(201, {
            'id': 'r2',
            'space_id': 's1',
            'user_id': 'u1',
            'type': 'upload_access',
            'payload': {'can_upload_documents': true},
            'status': 'pending',
            'created_at': DateTime.now().toUtc().toIso8601String().replaceFirst(
              'Z',
              '',
            ),
          }),
        );
      await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
      await openFromHome(tester, 'open-requests');
      expect(find.byType(RequestsScreen), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Budget is fixed this quarter'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('new-request')));
      await settleApp(tester);
      await tester.tap(find.text('Document uploads'));
      await tester.pump();
      await tester.tap(find.text('Send request'));
      await tester.tap(find.text('Send request'), warnIfMissed: false);
      await settleApp(tester);
      final posts = backend.requestsTo('POST /spaces/s1/requests');
      expect(posts, hasLength(1));
      expect(backend.bodyOf(posts.single), {
        'type': 'upload_access',
        'payload': <String, dynamic>{},
      });
      expect(find.text('Request sent.'), findsOneWidget);
    },
  );

  testWidgets(
    'an uncertain request is not resent; the list is reloaded instead',
    (tester) async {
      final backend = appBackend()
        ..on(
          'POST /spaces/s1/requests',
          (r) => throw DioException.connectionError(
            requestOptions: r,
            reason: 'reset',
          ),
        );
      await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
      await openFromHome(tester, 'open-requests');
      final listsBefore = backend
          .requestsTo('GET /spaces/requests/mine')
          .length;
      await tester.tap(find.byKey(const ValueKey('new-request')));
      await settleApp(tester);
      await tester.enterText(
        find.byType(TextField).last,
        'Please add a glossary',
      );
      await tester.tap(find.text('Send request'));
      await settleApp(tester);
      expect(
        find.textContaining("couldn't confirm the request"),
        findsOneWidget,
      );
      expect(backend.requestsTo('POST /spaces/s1/requests'), hasLength(1));
      expect(
        backend.requestsTo('GET /spaces/requests/mine').length,
        greaterThan(listsBefore),
      );
    },
  );

  testWidgets(
    'conversation can be renamed, shared as a file, and deleted after confirmation',
    (tester) async {
      Shared? shared;
      final session = {
        'id': 'c1',
        'title': 'Planning',
        'created_at': '2026-11-01T10:00:00',
        'updated_at': '2026-11-01T10:00:00',
      };
      final backend = appBackend()
        ..json('GET /chat/sessions', 200, [session])
        ..json('GET /chat/sessions/c1', 200, {
          'session': session,
          'history': <Object>[],
        })
        ..on(
          'PATCH /chat/sessions/c1',
          (r) => jsonBody(200, {...session, 'title': 'Budget review'}),
        )
        ..on(
          'GET /chat/sessions/c1/export',
          (_) => textBody(200, '# Planning\n\nhello'),
        )
        ..on(
          'DELETE /chat/sessions/c1',
          (_) => ResponseBody.fromString('', 204),
        );
      await pumpTeiaApp(
        tester,
        backend,
        store: InMemoryTokenStore('t'),
        overrides: [
          shareFileProvider.overrideWithValue((path, mime, _) async {
            shared = (path: path, mime: mime);
            return ShareOutcome.dismissed;
          }),
        ],
      );
      await openFromHome(tester, 'open-chat');
      await tester.tap(find.text('Planning'));
      await settleApp(tester);

      await tester.tap(find.byTooltip('More'));
      await settleApp(tester);
      await tester.tap(find.text('Rename'));
      await settleApp(tester);
      await tester.enterText(find.byType(TextField).last, 'Budget review');
      await tester.tap(find.text('Save'));
      await settleApp(tester);
      expect(
        backend.bodyOf(backend.requestsTo('PATCH /chat/sessions/c1').single),
        {'title': 'Budget review'},
      );

      await tester.tap(find.byTooltip('More'));
      await settleApp(tester);
      await tester.tap(find.text('Share as file'));
      for (var i = 0; i < 3; i++) {
        await settleApp(tester);
      }
      expect(shared?.mime, 'text/markdown');
      await tester.runAsync(
        () async => expect(
          await File(shared!.path).readAsString(),
          '# Planning\n\nhello',
        ),
      );

      await tester.tap(find.byTooltip('More'));
      await settleApp(tester);
      await tester.tap(find.text('Delete').last);
      await settleApp(tester);
      expect(find.textContaining('Usage records are kept'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settleApp(tester);
      expect(backend.requestsTo('DELETE /chat/sessions/c1'), hasLength(1));
      expect(find.text('Conversation deleted.'), findsOneWidget);
    },
  );

  testWidgets('cancelling deletion sends nothing', (tester) async {
    final session = {
      'id': 'c1',
      'title': 'Planning',
      'created_at': '2026-11-01T10:00:00',
      'updated_at': '2026-11-01T10:00:00',
    };
    final backend = appBackend()
      ..json('GET /chat/sessions', 200, [session])
      ..json('GET /chat/sessions/c1', 200, {
        'session': session,
        'history': <Object>[],
      });
    await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
    await openFromHome(tester, 'open-chat');
    await tester.tap(find.text('Planning'));
    await settleApp(tester);
    await tester.tap(find.byTooltip('More'));
    await settleApp(tester);
    await tester.tap(find.text('Delete').last);
    await settleApp(tester);
    await tester.tap(find.text('Cancel'));
    await settleApp(tester);
    expect(backend.requestsTo('DELETE /chat/sessions/c1'), isEmpty);
  });

  testWidgets('opening an approval refreshes permissions and shows requests', (
    tester,
  ) async {
    final backend = appBackend()
      ..json('GET /notifications/', 200, [
        {
          'id': 'n1',
          'user_id': 'u1',
          'space_id': 's1',
          'type': 'request_approved',
          'title': 'Request Approved',
          'message': 'Your upload_access request for Team has been approved.',
          'metadata': {
            'space_name': 'Team',
            'request_type': 'upload_access',
            'request_id': 'r1',
          },
          'read': false,
          'created_at': '2026-11-02T08:00:00',
        },
      ])
      ..json('GET /notifications/unread-count', 200, {'count': 1})
      ..json('POST /notifications/n1/read', 200, {'success': true});
    await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
    expect(find.text('1'), findsOneWidget);
    final membershipChecks = backend.requestsTo('GET /spaces/s1/me').length;
    await tester.tap(find.byKey(const ValueKey('notifications-bell')));
    await settleApp(tester);
    expect(
      find.text('Your Document uploads request in Team was approved.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Request approved'));
    await settleApp(tester);
    expect(
      backend.requestsTo('GET /spaces/s1/me').length,
      greaterThan(membershipChecks),
    );
    expect(backend.requestsTo('POST /notifications/n1/read'), hasLength(1));
    expect(find.byType(RequestsScreen), findsOneWidget);
  });

  testWidgets(
    'a notification for a space the user lost is explained, not opened',
    (tester) async {
      final backend = appBackend()
        ..json('GET /notifications/', 200, [
          {
            'id': 'n2',
            'user_id': 'u1',
            'space_id': 'gone',
            'type': 'quota_warning',
            'title': 'Quota Warning',
            'message': 'x',
            'metadata': {'space_name': 'Old team'},
            'read': true,
            'created_at': '2026-11-02T08:00:00',
          },
        ]);
      await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
      await tester.tap(find.byKey(const ValueKey('notifications-bell')));
      await settleApp(tester);
      await tester.tap(find.text('Usage limit approaching'));
      await settleApp(tester);
      expect(find.text('This is no longer available to you.'), findsOneWidget);
      expect(find.byType(UsageScreen), findsNothing);
    },
  );

  testWidgets('reply language is saved to the account', (tester) async {
    final backend = appBackend()
      ..on(
        'PATCH /auth/me',
        (r) => jsonBody(200, {
          ...userJson('u1', firstName: 'Lina'),
          'preferred_language': 'ar',
        }),
      );
    await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
    await tester.tap(find.byTooltip('Account'));
    await settleApp(tester);
    final reply = find.byKey(const ValueKey('reply-language'));
    await tester.scrollUntilVisible(
      reply,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final arabic = find.descendant(of: reply, matching: find.text('العربية'));
    await tester.ensureVisible(arabic);
    await tester.pumpAndSettle();
    await tester.tap(arabic);
    await settleApp(tester);
    expect(backend.bodyOf(backend.requestsTo('PATCH /auth/me').single), {
      'preferred_language': 'ar',
    });
  });

  for (final lang in ['en', 'ar']) {
    for (final mode in ['light', 'dark']) {
      testWidgets(
        'usage, requests and notifications lay out in $lang/$mode at 2x text',
        (tester) async {
          final backend = appBackend()
            ..json('GET /chat/usage/overview', 200, overview(unknown: 2));
          await pumpTeiaApp(
            tester,
            backend,
            store: InMemoryTokenStore('t'),
            textScale: 2.0,
            prefs: {'app_locale': lang, 'theme_mode': mode},
          );
          for (final key in ['open-usage', 'open-requests']) {
            await openFromHome(tester, key);
            expect(tester.takeException(), isNull);
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -600),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
            await tester.tap(find.byType(BackButton));
            await settleApp(tester);
          }
          await tester.tap(find.byKey(const ValueKey('notifications-bell')));
          await settleApp(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
