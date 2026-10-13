import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teia_ai/core/providers.dart';
import 'package:teia_ai/core/storage/token_store.dart';
import 'package:teia_ai/features/documents/application/documents_controller.dart';
import 'package:teia_ai/features/documents/presentation/document_details_screen.dart';
import 'package:teia_ai/features/documents/presentation/documents_screen.dart';

import '../features/documents/documents_controller_test.dart' show docJson;
import '../support/fake_adapter.dart';
import '../support/fake_backend.dart';
import '../support/test_app.dart';

FakeBackend docsBackend({
  bool uploader = true,
  List<Map<String, dynamic>>? docs,
}) => FakeBackend()
  ..json('GET /auth/me', 200, userJson('u1', firstName: 'Lina'))
  ..json('GET /spaces', 200, [spaceJson('s1')])
  ..json('GET /spaces/s1/me', 200, {
    ...membershipJson('s1'),
    'can_upload_documents': uploader,
  })
  ..json('GET /chat/sessions', 200, <Object>[])
  ..json('GET /chat/models', 200, ['teia-stub-1'])
  ..json(
    'GET /documents/accessible',
    200,
    docs ??
        [
          docJson('d1', name: 'birds.txt'),
          docJson(
            'd3',
            name: 'locked.pdf',
            state: 'failed',
            error: 'encrypted',
          ),
        ],
  );

/// Processing documents keep a poll timer alive; backgrounding the app cancels it.
Future<void> stopPolling(WidgetTester tester, ProviderContainer c) async {
  c.read(appForegroundProvider.notifier).set(false);
  await tester.pump();
}

Future<void> openDocuments(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('open-documents')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const ValueKey('open-documents')));
  await settleApp(tester);
  expect(find.byType(DocumentsScreen), findsOneWidget);
}

void main() {
  testWidgets('lists documents with clear states, filters and search', (
    tester,
  ) async {
    final c = await pumpTeiaApp(
      tester,
      docsBackend(
        docs: [
          docJson('d1', name: 'birds.txt'),
          docJson('d2', name: 'budget.pdf', state: 'processing'),
          docJson(
            'd3',
            name: 'locked.pdf',
            state: 'failed',
            error: 'encrypted',
          ),
        ],
      ),
      store: InMemoryTokenStore('t'),
    );
    await openDocuments(tester);
    expect(find.text('birds.txt'), findsOneWidget);
    expect(find.text('Ready'), findsWidgets);
    expect(find.text('Processing…'), findsOneWidget);
    expect(find.text('Failed'), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Failed'));
    await tester.pump();
    expect(find.text('locked.pdf'), findsOneWidget);
    expect(find.text('birds.txt'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.enterText(find.byType(TextField).first, 'BUD');
    await tester.pump();
    expect(find.text('budget.pdf'), findsOneWidget);
    expect(find.text('birds.txt'), findsNothing);
    await stopPolling(tester, c);
  });

  testWidgets('members without upload rights see no upload action', (
    tester,
  ) async {
    await pumpTeiaApp(
      tester,
      docsBackend(uploader: false),
      store: InMemoryTokenStore('t'),
    );
    await openDocuments(tester);
    expect(find.text('Upload'), findsNothing);
  });

  testWidgets(
    'upload shows byte progress, then server processing, then the result',
    (tester) async {
      final backend = docsBackend(docs: []);
      final response = Completer<Object>();
      backend.onAny(
        (o) => o.method == 'PUT'
            ? response.future.then((b) => jsonBody(201, b))
            : null,
      );
      final bytes = utf8.encode('x' * 4000);
      await pumpTeiaApp(
        tester,
        backend,
        store: InMemoryTokenStore('t'),
        overrides: [
          pickDocumentProvider.overrideWithValue(
            () async => UploadSource(
              name: 'census.txt',
              length: bytes.length,
              open: () => Stream.value(bytes),
            ),
          ),
        ],
      );
      await openDocuments(tester);
      await tester.tap(find.text('Upload'));
      await settleApp(tester);
      expect(
        find.textContaining('The server is reading and indexing'),
        findsOneWidget,
      );
      expect(find.text('Stop waiting'), findsOneWidget);

      response.complete(docJson('d9', name: 'census.txt'));
      await settleApp(tester);
      expect(find.text('Ready to use in chat.'), findsOneWidget);
    },
  );

  testWidgets('a local check refuses oversized files before uploading', (
    tester,
  ) async {
    final backend = docsBackend(docs: []);
    await pumpTeiaApp(
      tester,
      backend,
      store: InMemoryTokenStore('t'),
      overrides: [
        pickDocumentProvider.overrideWithValue(
          () async => UploadSource(
            name: 'big.pdf',
            length: 26 * 1024 * 1024,
            open: () => const Stream.empty(),
          ),
        ),
      ],
    );
    await openDocuments(tester);
    await tester.tap(find.text('Upload'));
    await settleApp(tester);
    expect(find.text('Files must be 25 MB or smaller.'), findsOneWidget);
    expect(backend.adapter.requests.where((r) => r.method == 'PUT'), isEmpty);
  });

  testWidgets(
    'details: retry when allowed, and open downloads through the API only',
    (tester) async {
      final failed = {
        ...docJson('d4', name: 'report.txt', state: 'failed', error: 'timeout'),
        'can_retry': true,
      };
      final backend = docsBackend(docs: [failed])
        ..json('GET /documents/d4', 200, failed)
        ..json(
          'POST /documents/d4/retry',
          200,
          docJson('d4', name: 'report.txt'),
        )
        ..on('GET /documents/d4/download', (_) => textBody(200, 'report body'));
      String? opened;
      await pumpTeiaApp(
        tester,
        backend,
        store: InMemoryTokenStore('t'),
        overrides: [
          openLocalFileProvider.overrideWithValue((path) async {
            opened = path;
            return true;
          }),
        ],
      );
      await openDocuments(tester);
      await tester.tap(find.text('report.txt'));
      await settleApp(tester);
      expect(
        find.text('Processing took too long and was stopped.'),
        findsOneWidget,
      );
      backend.json('GET /documents/d4', 200, docJson('d4', name: 'report.txt'));
      await tester.tap(find.text('Try processing again'));
      await settleApp(tester);
      expect(backend.requestsTo('POST /documents/d4/retry'), hasLength(1));

      await tester.tap(find.text('Open document'));
      for (var i = 0; i < 5; i++) {
        await settleApp(tester);
      }
      expect(opened, isNotNull);
      expect(opened!.endsWith('report.txt'), isTrue);
      await tester.runAsync(
        () async => expect(await File(opened!).readAsString(), 'report body'),
      );
      final download = backend.requestsTo('GET /documents/d4/download').single;
      expect(download.followRedirects, isFalse);
      expect(download.headers['Authorization'], 'Bearer t');
    },
  );

  testWidgets('a document the user can no longer read shows as unavailable', (
    tester,
  ) async {
    final backend = docsBackend(docs: [docJson('d5', name: 'gone.txt')])
      ..json('GET /documents/d5', 404, {'detail': 'Document not found'});
    await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
    await openDocuments(tester);
    await tester.tap(find.text('gone.txt'));
    await settleApp(tester);
    expect(find.text('Document unavailable'), findsOneWidget);
  });

  testWidgets(
    'stored citations survive history reload, revoked ones show nothing, images are not fetched',
    (tester) async {
      final backend = docsBackend()
        ..json('GET /chat/sessions', 200, [
          {
            'id': 'c1',
            'title': 'Census',
            'created_at': '2026-10-13T00:00:00',
            'updated_at': '2026-10-13T00:00:00',
          },
        ])
        ..json('GET /chat/sessions/c1', 200, {
          'session': {
            'id': 'c1',
            'title': 'Census',
            'created_at': '2026-10-13T00:00:00',
            'updated_at': '2026-10-13T00:00:00',
          },
          'history': [
            {
              'id': 'm1',
              'role': 'user',
              'content': 'heron?',
              'created_at': '2026-10-13T00:00:00',
            },
            {
              'id': 'm2',
              'role': 'assistant',
              'content': 'Answer ![pixel](https://tracker.example/p.png)',
              'created_at': '2026-10-13T00:00:01',
              'citations': [
                {
                  'available': true,
                  'document_id': 'd1',
                  'filename': 'birds.pdf',
                  'chunk_index': 0,
                  'page': 3,
                  'excerpt': 'The heron colony nests near the marsh.',
                },
                {'available': false},
              ],
            },
          ],
        });
      await pumpTeiaApp(tester, backend, store: InMemoryTokenStore('t'));
      await tester.tap(find.byKey(const ValueKey('open-chat')));
      await settleApp(tester);
      await tester.tap(find.text('Census'));
      await settleApp(tester);

      expect(find.text('birds.pdf · Page 3'), findsOneWidget);
      expect(find.text('Source unavailable'), findsOneWidget);
      expect(find.textContaining('Image not loaded'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      await tester.tap(find.text('Source unavailable'));
      await settleApp(tester);
      expect(
        find.textContaining('You no longer have access to this source'),
        findsOneWidget,
      );
      expect(find.textContaining('heron colony'), findsNothing);
    },
  );

  testWidgets(
    'chat explains when a selected document disappears instead of widening the search',
    (tester) async {
      var listing = [docJson('d1', name: 'birds.txt')];
      final backend = docsBackend()
        ..on('GET /documents/accessible', (_) => jsonBody(200, listing));
      final c = await pumpTeiaApp(
        tester,
        backend,
        store: InMemoryTokenStore('t'),
      );
      await tester.tap(find.byKey(const ValueKey('open-chat')));
      await settleApp(tester);
      await tester.tap(find.text('New conversation'));
      await settleApp(tester);
      expect(find.text('Searching all your ready documents'), findsOneWidget);

      await tester.tap(find.byTooltip('Choose documents'));
      await settleApp(tester);
      await tester.tap(find.text('birds.txt'));
      await tester.tap(find.text('Done'));
      await settleApp(tester);
      expect(find.text('Searching all your ready documents'), findsNothing);

      listing = [];
      await tester.runAsync(
        () => c.read(documentsControllerProvider.notifier).refresh(),
      );
      await settleApp(tester);
      expect(
        find.textContaining(
          'Removed from your selection because it\'s no longer available: birds.txt',
        ),
        findsOneWidget,
      );
    },
  );

  for (final lang in ['en', 'ar']) {
    for (final mode in ['light', 'dark']) {
      testWidgets(
        'documents lay out in $lang/$mode at 2x text with the keyboard open',
        (tester) async {
          await pumpTeiaApp(
            tester,
            docsBackend(),
            store: InMemoryTokenStore('t'),
            textScale: 2.0,
            prefs: {'app_locale': lang, 'theme_mode': mode},
          );
          await openDocuments(tester);
          tester.view.viewInsets = FakeViewPadding(
            bottom: 300 * tester.view.devicePixelRatio,
          );
          await tester.showKeyboard(find.byType(TextField).first);
          await settleApp(tester);
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(Scrollable).last,
            const Offset(0, -400),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
        },
      );
    }
  }
}
