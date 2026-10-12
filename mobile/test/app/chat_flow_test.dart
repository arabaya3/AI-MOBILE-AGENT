import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/storage/token_store.dart';
import 'package:teia_ai/features/chat/presentation/chat_list_screen.dart';
import 'package:teia_ai/features/chat/presentation/conversation_screen.dart';

import '../support/fake_adapter.dart';
import '../support/fake_backend.dart';
import '../support/test_app.dart';

Map<String, dynamic> msg(String id, String role, String content) => {
  'id': id,
  'role': role,
  'content': content,
  'created_at': '2026-10-12T10:00:00',
};

Map<String, dynamic> detail(List<Map<String, dynamic>> history) => {
  'session': {
    'id': 'c1',
    'title': 'Planning',
    'created_at': '2026-10-12T10:00:00',
    'updated_at': '2026-10-12T10:00:00',
  },
  'history': history,
};

FakeBackend signedInBackend() => FakeBackend()
  ..json('GET /auth/me', 200, userJson('u1', firstName: 'Lina'))
  ..json('GET /spaces', 200, [spaceJson('s1')])
  ..json('GET /spaces/s1/me', 200, membershipJson('s1'))
  ..json('GET /chat/sessions', 200, <Object>[])
  ..json('GET /chat/models', 200, ['teia-stub-1', 'teia-stub-2']);

Future<void> openNewConversation(WidgetTester tester) async {
  await tester.tap(find.text('Open conversations'));
  await settleApp(tester);
  expect(find.byType(ChatListScreen), findsOneWidget);
  await tester.tap(find.text('New conversation'));
  await settleApp(tester);
  expect(find.byType(ConversationScreen), findsOneWidget);
}

Future<void> sendPrompt(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.pump();
  await tester.tap(find.byTooltip('Send'));
  await settleApp(tester);
}

void main() {
  testWidgets(
    'streams a reply, renders Markdown and enables confirmed actions',
    (tester) async {
      final backend = signedInBackend()
        ..on(
          'POST /chat/query/stream',
          (_) => sseBody([
            (
              'meta',
              {
                'session_id': 'c1',
                'user_message_id': 'm1',
                'sources': <Object>[],
              },
            ),
            ('delta', {'text': '## Plan\n\n- first **item**'}),
            (
              'done',
              {'session_id': 'c1', 'user_message_id': 'm1', 'message_id': 'm2'},
            ),
          ], chunkSize: 5),
        )
        ..json(
          'GET /chat/sessions/c1',
          200,
          detail([
            msg('m1', 'user', 'Make a plan'),
            msg('m2', 'assistant', '## Plan\n\n- first **item**'),
          ]),
        );
      await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
      await openNewConversation(tester);

      await sendPrompt(tester, 'Make a plan');
      expect(find.text('Plan'), findsOneWidget);
      expect(find.textContaining('first'), findsWidgets);
      expect(find.byTooltip('Helpful'), findsOneWidget);
      expect(find.byTooltip('Continue in a new conversation'), findsOneWidget);
      expect(
        backend.bodyOf(
          backend.requestsTo('POST /chat/query/stream').single,
        )['model'],
        'teia-stub-1',
      );
    },
  );

  testWidgets(
    'shows a provider failure without its marker and offers to send again',
    (tester) async {
      final backend = signedInBackend()
        ..on(
          'POST /chat/query/stream',
          (_) => sseBody([
            (
              'meta',
              {
                'session_id': 'c1',
                'user_message_id': 'm1',
                'sources': <Object>[],
              },
            ),
            (
              'error',
              {
                'detail': 'The model provider could not complete the reply.',
                'code': 'provider_error',
                'partial': false,
              },
            ),
          ]),
        )
        ..json('GET /chat/sessions/c1', 200, detail([msg('m1', 'user', 'hi')]));
      await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
      await openNewConversation(tester);
      await sendPrompt(tester, 'hi');

      expect(
        find.text(
          "The model couldn't finish this reply. Nothing was saved for it.",
        ),
        findsOneWidget,
      );
      expect(find.text('Send again'), findsOneWidget);
      expect(find.textContaining('[stream_error]'), findsNothing);
      expect(backend.requestsTo('POST /chat/query/stream'), hasLength(1));
    },
  );

  testWidgets('stop ends the reply on the device and explains it was not saved', (
    tester,
  ) async {
    final source = StreamController<Uint8List>();
    final backend = signedInBackend()
      ..on('POST /chat/query/stream', (_) => streamBody(200, source.stream))
      ..json(
        'GET /chat/sessions/c1',
        200,
        detail([msg('m1', 'user', 'long one')]),
      );
    await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
    await openNewConversation(tester);
    await sendPrompt(tester, 'long one');
    source.add(
      Uint8List.fromList(
        utf8.encode(
          'event: meta\ndata: {"session_id":"c1","user_message_id":"m1","sources":[]}\n\nevent: delta\ndata: {"text":"partial words"}\n\n',
        ),
      ),
    );
    await settleApp(tester);
    expect(find.byTooltip('Stop'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop'));
    await settleApp(tester);
    expect(find.textContaining('You stopped this reply'), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    final streamRequest = backend.requestsTo('POST /chat/query/stream').single;
    expect(streamRequest.cancelToken?.isCancelled, isTrue);
    unawaited(source.close());
  });

  testWidgets(
    'a stored provider-error message from an old backend is never shown as an answer',
    (tester) async {
      final backend = signedInBackend()
        ..json('GET /chat/sessions', 200, [detail(const [])['session']])
        ..json(
          'GET /chat/sessions/c1',
          200,
          detail([
            msg('m1', 'user', 'hi'),
            msg('m2', 'assistant', '\n\n[stream_error] 401 invalid key'),
          ]),
        );
      await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
      await tester.tap(find.text('Open conversations'));
      await settleApp(tester);
      await tester.tap(find.text('Planning'));
      await settleApp(tester);

      expect(
        find.text('This reply failed and contains no answer.'),
        findsOneWidget,
      );
      expect(find.textContaining('invalid key'), findsNothing);
      expect(find.byTooltip('Helpful'), findsNothing);
    },
  );

  for (final lang in ['en', 'ar']) {
    for (final mode in ['light', 'dark']) {
      testWidgets(
        'conversation lays out in $lang/$mode at 2x text with the keyboard open',
        (tester) async {
          final backend = signedInBackend()
            ..json('GET /chat/sessions', 200, [detail(const [])['session']])
            ..json(
              'GET /chat/sessions/c1',
              200,
              detail([
                msg('m1', 'user', 'اشرح الخطة باختصار please'),
                msg(
                  'm2',
                  'assistant',
                  '## الخطة\n\n- أولًا **مهم**\n- Second point with a [link](https://example.com)\n\n```\ncode()\n```',
                ),
              ]),
            );
          await pumpTeiaApp(
            tester,
            backend,
            store: InMemoryTokenStore('t'),
            textScale: 2.0,
            prefs: {'app_locale': lang, 'theme_mode': mode},
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('open-chat')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.byKey(const ValueKey('open-chat')));
          await settleApp(tester);
          await tester.tap(find.byType(ListTile).first);
          await settleApp(tester);

          tester.view.viewInsets = FakeViewPadding(
            bottom: 300 * tester.view.devicePixelRatio,
          );
          await tester.showKeyboard(find.byType(TextField).last);
          await settleApp(tester);
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 600),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
        },
      );
    }
  }
}
