import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/network/api_client.dart';
import 'package:teia_ai/core/providers.dart';
import 'package:teia_ai/features/auth/application/auth_controller.dart';
import 'package:teia_ai/features/chat/application/conversation_controller.dart';
import 'package:teia_ai/features/chat/data/chat_api.dart';
import 'package:teia_ai/features/spaces/application/space_controller.dart';

import '../../support/container.dart';
import '../../support/fake_adapter.dart';
import '../../support/fake_backend.dart';

class TestScope extends Notifier<String?> {
  @override
  String? build() => 'u1#1/s1';

  void set(String? value) => state = value;
}

final testScope = NotifierProvider<TestScope, String?>(TestScope.new);
final testAuthScope = NotifierProvider<TestScope, String?>(TestScope.new);

Map<String, dynamic> msg(String id, String role, String content) => {
  'id': id,
  'role': role,
  'content': content,
  'created_at': '2026-10-12T00:00:00',
};

Map<String, dynamic> detail(List<Map<String, dynamic>> history) => {
  'session': {
    'id': 'c1',
    'title': 'T',
    'created_at': '2026-10-12T00:00:00',
    'updated_at': '2026-10-12T00:00:00',
  },
  'history': history,
};

Future<ProviderContainer> chatContainer(FakeBackend backend) async {
  final c = await makeContainer(
    backend,
    overrides: [
      spaceScopeProvider.overrideWith((ref) => ref.watch(testScope)),
      authScopeProvider.overrideWith((ref) => ref.watch(testAuthScope)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

const args = (scope: 'u1#1/s1', sessionId: null);

ConversationController controller(ProviderContainer c) {
  c.listen(conversationProvider(args), (_, _) {});
  return c.read(conversationProvider(args).notifier);
}

ConversationState stateOf(ProviderContainer c) =>
    c.read(conversationProvider(args));

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend()..json('GET /chat/sessions', 200, <Object>[]);
  });

  test('a completed stream is reconciled with authoritative history', () async {
    backend.on(
      'POST /chat/query/stream',
      (_) => sseBody([
        (
          'meta',
          {
            'session_id': 'c1',
            'user_message_id': 'm1',
            'sources': [
              {
                'chunk_id': 'd:0:0',
                'document_id': 'd',
                'filename': 'a.pdf',
                'text': 'snippet',
              },
            ],
          },
        ),
        ('delta', {'text': 'Hel'}),
        ('delta', {'text': 'lo'}),
        (
          'done',
          {'session_id': 'c1', 'user_message_id': 'm1', 'message_id': 'm2'},
        ),
      ], chunkSize: 7),
    );
    backend.json(
      'GET /chat/sessions/c1',
      200,
      detail([msg('m1', 'user', 'hi'), msg('m2', 'assistant', 'Hello')]),
    );
    final c = await chatContainer(backend);

    expect(controller(c).send('hi'), isTrue);
    await settle();

    final s = stateOf(c);
    expect(s.sessionId, 'c1');
    expect(s.turn, isNull);
    expect(s.history.map((m) => m.id), ['m1', 'm2']);
    expect(s.sourcesByMessage['m2']?.single.filename, 'a.pdf');
    expect(backend.requestsTo('GET /chat/sessions/c1'), hasLength(1));
  });

  test(
    'a provider marker split across deltas is never shown and fails the turn',
    () async {
      backend.on(
        'POST /chat/query/stream',
        (_) => sseBody([
          ('meta', {'session_id': 'c1', 'sources': <Object>[]}),
          ('delta', {'text': 'partial answer\n\n[stream_'}),
          ('delta', {'text': 'error] upstream 500'}),
          ('done', <String, Object>{}),
        ]),
      );
      backend.json(
        'GET /chat/sessions/c1',
        200,
        detail([msg('m1', 'user', 'hi')]),
      );
      final c = await chatContainer(backend);
      final ctrl = controller(c);
      ctrl.send('hi');
      final shown = <String>[];
      stateOf(
        c,
      ).turn!.text.addListener(() => shown.add(stateOf(c).turn!.text.value));
      await settle();

      final turn = stateOf(c).turn!;
      expect(turn.phase, TurnPhase.failed);
      expect(turn.failure, TurnFailure.provider);
      expect(turn.text.value, 'partial answer');
      expect(turn.partial, isTrue);
      expect(shown.every((t) => !t.contains('[stream')), isTrue);
    },
  );

  test('visible text hides any trailing fragment of the marker', () {
    expect(visibleStreamText('abc\n\n[str').text, 'abc');
    expect(visibleStreamText('abc\n').text, 'abc');
    expect(visibleStreamText('a [b] c').text, 'a [b] c');
    expect(visibleStreamText('x\n\n[stream_error] boom').providerError, isTrue);
  });

  test(
    'typed and legacy quota errors, and policy errors, are classified',
    () async {
      final c = await chatContainer(backend);
      final ctrl = controller(c);
      for (final (body, expected) in [
        (
          {'detail': 'Daily token limit reached', 'code': 'quota_exceeded'},
          TurnFailure.quota,
        ),
        ({'detail': '429: Daily token limit reached'}, TurnFailure.quota),
        (
          {'detail': 'Model not allowed in this space', 'code': 'policy'},
          TurnFailure.policy,
        ),
      ]) {
        backend.on(
          'POST /chat/query/stream',
          (_) => sseBody([('error', body)]),
        );
        ctrl.dismissTurn();
        ctrl.send('hi');
        await settle();
        expect(stateOf(c).turn!.failure, expected, reason: '$body');
      }
    },
  );

  test(
    'a stream that ends without done is interrupted, not successful',
    () async {
      backend.on(
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
          ('delta', {'text': 'cut off'}),
        ]),
      );
      backend.json(
        'GET /chat/sessions/c1',
        200,
        detail([msg('m1', 'user', 'hi')]),
      );
      final c = await chatContainer(backend);
      controller(c).send('hi');
      await settle();
      final s = stateOf(c);
      expect(s.turn!.phase, TurnPhase.interrupted);
      expect(s.history.map((m) => m.role), [ChatRole.user]);
      expect(s.showPendingPrompt, isFalse);
    },
  );

  test(
    'an interrupted turn clears when the server saved the reply anyway',
    () async {
      backend.on(
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
          ('delta', {'text': 'full answer'}),
        ]),
      );
      backend.json(
        'GET /chat/sessions/c1',
        200,
        detail([
          msg('m1', 'user', 'hi'),
          msg('m2', 'assistant', 'full answer'),
        ]),
      );
      final c = await chatContainer(backend);
      controller(c).send('hi');
      await settle();
      final s = stateOf(c);
      expect(s.turn, isNull);
      expect(s.history.map((m) => m.id), ['m1', 'm2']);
      expect(backend.requestsTo('POST /chat/query/stream'), hasLength(1));
    },
  );

  test('malformed events fail the turn without crashing', () async {
    backend.on(
      'POST /chat/query/stream',
      (_) => streamBody(
        200,
        Stream.value(
          Uint8List.fromList(
            utf8.encode(
              'event: meta\ndata: {"session_id":"c1","sources":[]}\n\nevent: delta\ndata: not-json\n\n',
            ),
          ),
        ),
      ),
    );
    backend.json('GET /chat/sessions/c1', 200, detail([]));
    final c = await chatContainer(backend);
    controller(c).send('hi');
    await settle();
    expect(stateOf(c).turn!.failure, TurnFailure.protocol);
  });

  test('a duplicate send while streaming is ignored', () async {
    final source = StreamController<Uint8List>();
    backend.on(
      'POST /chat/query/stream',
      (_) => streamBody(200, source.stream),
    );
    final c = await chatContainer(backend);
    final ctrl = controller(c);
    expect(ctrl.send('one'), isTrue);
    expect(ctrl.send('two'), isFalse);
    await settle();
    expect(backend.requestsTo('POST /chat/query/stream'), hasLength(1));
    await source.close();
  });

  test(
    'stop cancels the request at once, ignores late events and reconciles',
    () async {
      final source = StreamController<Uint8List>();
      backend.on(
        'POST /chat/query/stream',
        (_) => streamBody(200, source.stream),
      );
      backend.json(
        'GET /chat/sessions/c1',
        200,
        detail([msg('m1', 'user', 'hi')]),
      );
      final c = await chatContainer(backend);
      final ctrl = controller(c);
      ctrl.send('hi');
      await settle();
      source.add(
        Uint8List.fromList(
          utf8.encode(
            'event: meta\ndata: {"session_id":"c1","user_message_id":"m1","sources":[]}\n\nevent: delta\ndata: {"text":"par"}\n\n',
          ),
        ),
      );
      await settle();

      ctrl.stop();
      expect(stateOf(c).turn!.phase, TurnPhase.stopped);
      source.add(
        Uint8List.fromList(
          utf8.encode('event: delta\ndata: {"text":"LATE"}\n\n'),
        ),
      );
      await settle();

      expect(stateOf(c).turn!.text.value, 'par');
      expect(stateOf(c).turn!.partial, isTrue);
      expect(backend.adapter.cancelledRequests, 1);
      expect(stateOf(c).history.single.id, 'm1');
      await source.close();
    },
  );

  test('leaving the space cancels the stream and drops late events', () async {
    final source = StreamController<Uint8List>();
    backend.on(
      'POST /chat/query/stream',
      (_) => streamBody(200, source.stream),
    );
    final c = await chatContainer(backend);
    final ctrl = controller(c);
    ctrl.send('hi');
    await settle();
    final turn = stateOf(c).turn!;

    c.read(testScope.notifier).set('u1#1/s2');
    c.read(apiClientProvider).cancelSpaceScoped();
    source.add(
      Uint8List.fromList(
        utf8.encode('event: delta\ndata: {"text":"LATE"}\n\n'),
      ),
    );
    await settle();

    expect(turn.text.value, isEmpty);
    expect(ctrl.send('again'), isFalse);
    await source.close();
  });

  test('reactions and branching need a server-confirmed message id', () async {
    backend.json(
      'GET /chat/sessions/c1',
      200,
      detail([msg('m1', 'user', 'hi'), msg('m2', 'assistant', 'ok')]),
    );
    backend.json('POST /chat/messages/m2/reaction', 200, {'success': true});
    backend.json('POST /chat/sessions/c1/branch', 200, {'session_id': 'c2'});
    final c = await chatContainer(backend);
    const existing = (scope: 'u1#1/s1', sessionId: 'c1');
    c.listen(conversationProvider(existing), (_, _) {});
    final ctrl = c.read(conversationProvider(existing).notifier);
    await settle();

    await ctrl.react('local-only', Reaction.up);
    expect(
      backend.requestsTo('POST /chat/messages/local-only/reaction'),
      isEmpty,
    );
    await ctrl.react('m2', Reaction.up);
    expect(c.read(conversationProvider(existing)).reactions['m2'], Reaction.up);
    expect(await ctrl.branch('local-only'), isNull);
    expect(await ctrl.branch('m2'), 'c2');
  });

  test('drafts are cleared when the account changes', () async {
    final c = await chatContainer(backend);
    c.read(draftsProvider.notifier).write('u1#1/s1|new', 'secret draft');
    expect(c.read(draftsProvider.notifier).read('u1#1/s1|new'), 'secret draft');
    c.read(testAuthScope.notifier).set('u2#2');
    expect(c.read(draftsProvider), isEmpty);
  });

  test('X-Space-Id rides along and the request carries no retry', () async {
    backend.on(
      'POST /chat/query/stream',
      (_) => sseBody([
        ('error', {'detail': 'x', 'code': 'internal'}),
      ]),
    );
    final c = await chatContainer(backend);
    controller(c).send('hi', model: 'teia-stub-1');
    await settle();
    final requests = backend.requestsTo('POST /chat/query/stream');
    expect(requests, hasLength(1));
    expect(backend.bodyOf(requests.single), {
      'message': 'hi',
      'model': 'teia-stub-1',
    });
    expect(requests.single.headers.containsKey(ApiClient.spaceHeader), isFalse);
  });
}
