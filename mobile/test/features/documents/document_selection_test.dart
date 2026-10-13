import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/features/auth/application/auth_controller.dart';
import 'package:teia_ai/features/chat/application/conversation_controller.dart';
import 'package:teia_ai/features/chat/data/chat_api.dart';
import 'package:teia_ai/features/chat/data/chat_stream_event.dart';
import 'package:teia_ai/features/documents/application/document_selection.dart';
import 'package:teia_ai/features/documents/application/documents_controller.dart';
import 'package:teia_ai/features/documents/data/documents_api.dart';
import 'package:teia_ai/features/spaces/application/space_controller.dart';

import '../../support/container.dart';
import '../../support/fake_adapter.dart';
import '../../support/fake_backend.dart';
import 'documents_controller_test.dart' show docJson, testScope;

Future<ProviderContainer> selectionContainer(FakeBackend backend) async {
  final c = await makeContainer(
    backend,
    overrides: [
      spaceScopeProvider.overrideWith((ref) => ref.watch(testScope)),
      authScopeProvider.overrideWith((ref) => 'u1#1'),
    ],
  );
  addTearDown(c.dispose);
  c.listen(documentSelectionProvider, (_, _) {});
  return c;
}

DocumentItem item(Map<String, dynamic> json) => DocumentItem.fromJson(json);

void main() {
  test(
    'only ready documents can be selected, and stale ones are removed with an explanation',
    () async {
      var listing = [
        docJson('a', name: 'a.pdf'),
        docJson('b', name: 'b.pdf'),
        docJson('p', state: 'processing'),
      ];
      final backend = FakeBackend()
        ..on('GET /documents/accessible', (_) => jsonBody(200, listing));
      final c = await selectionContainer(backend);
      await settle();
      final selection = c.read(documentSelectionProvider.notifier);
      selection.toggle(item(listing[0]));
      selection.toggle(item(listing[1]));
      selection.toggle(item(listing[2]));
      expect(c.read(documentSelectionProvider).ids, ['a', 'b']);

      listing = [
        docJson('a', name: 'a.pdf', state: 'failed', error: 'indexing_failed'),
      ];
      await c.read(documentsControllerProvider.notifier).refresh();
      await settle();
      final state = c.read(documentSelectionProvider);
      expect(state.ids, isEmpty);
      expect(state.removed, ['a.pdf', 'b.pdf']);
      selection.acknowledgeRemoval();
      expect(c.read(documentSelectionProvider).removed, isEmpty);
    },
  );

  test('selection resets when the account or space changes', () async {
    final backend = FakeBackend()
      ..json('GET /documents/accessible', 200, [docJson('a')]);
    final c = await selectionContainer(backend);
    await settle();
    c.read(documentSelectionProvider.notifier).toggle(item(docJson('a')));
    c.read(testScope.notifier).set('u1#1/s2');
    await settle();
    expect(c.read(documentSelectionProvider).ids, isEmpty);
  });

  test(
    'a turn keeps its exact document selection and maps not-ready errors',
    () async {
      final backend = FakeBackend()
        ..json('GET /chat/sessions', 200, <Object>[])
        ..on(
          'POST /chat/query/stream',
          (_) => sseBody([
            (
              'error',
              {
                'detail': 'A selected document is not ready yet',
                'code': 'document_not_ready',
              },
            ),
          ]),
        );
      final c = await selectionContainer(backend);
      const args = (scope: 'u1#1/s1', sessionId: null);
      c.listen(conversationProvider(args), (_, _) {});
      final chat = c.read(conversationProvider(args).notifier);
      chat.send('heron?', documentIds: ['a', 'b']);
      await settle();
      final turn = c.read(conversationProvider(args)).turn!;
      expect(turn.documentIds, ['a', 'b']);
      expect(turn.failure, TurnFailure.documentNotReady);
      final request = backend.requestsTo('POST /chat/query/stream').single;
      expect(backend.bodyOf(request)['document_ids'], ['a', 'b']);
    },
  );

  test(
    'no selection sends no document_ids, which the server treats as all ready documents',
    () async {
      final backend = FakeBackend()
        ..json('GET /chat/sessions', 200, <Object>[])
        ..on(
          'POST /chat/query/stream',
          (_) => sseBody([
            ('error', {'detail': 'x', 'code': 'internal'}),
          ]),
        );
      final c = await selectionContainer(backend);
      const args = (scope: 'u1#1/s1', sessionId: null);
      c.listen(conversationProvider(args), (_, _) {});
      c.read(conversationProvider(args).notifier).send('hi');
      await settle();
      expect(
        backend
            .bodyOf(backend.requestsTo('POST /chat/query/stream').single)
            .containsKey('document_ids'),
        isFalse,
      );
    },
  );

  test('persisted citations parse, and unavailable ones carry nothing', () {
    final message = ChatMessage.fromJson({
      'id': 'm2',
      'role': 'assistant',
      'content': 'answer',
      'created_at': '2026-10-13T00:00:00',
      'citations': [
        {
          'available': true,
          'document_id': 'd',
          'filename': 'r.pdf',
          'chunk_index': 0,
          'page': 3,
          'excerpt': 'text',
        },
        {'available': false},
      ],
    });
    expect(message.citations.first.page, 3);
    expect(message.citations.first.text, 'text');
    expect(message.citations.last.available, isFalse);
    expect(message.citations.last.filename, isEmpty);
    expect(message.citations.last.text, isEmpty);

    final streamed = Citation.fromJson({
      'chunk_id': 'd:0:0',
      'document_id': 'd',
      'filename': 'r.pdf',
      'text': 't',
      'metadata': {'page': 2},
    });
    expect(streamed.page, 2);
    expect(
      Citation.fromJson({
        'chunk_id': 'x',
        'metadata': {'type': 'text'},
      }).page,
      isNull,
    );
  });
}
