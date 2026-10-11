import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/network/sse/sse_parser.dart';
import 'package:teia_ai/features/chat/data/chat_stream_event.dart';

Future<List<SseEvent>> parseChunks(List<List<int>> chunks) =>
    Stream.fromIterable(chunks).transform(const SseParser()).toList();

/// Splits [bytes] into every possible pair of chunks and checks each yields [expected].
Future<void> expectAllSplits(List<int> bytes, List<SseEvent> expected) async {
  for (var cut = 0; cut <= bytes.length; cut++) {
    final events = await parseChunks([
      bytes.sublist(0, cut),
      bytes.sublist(cut),
    ]);
    expect(events, expected, reason: 'split at byte $cut');
  }
}

void main() {
  group('SseParser', () {
    test('parses the backend wire format', () async {
      final events = await parseChunks([
        utf8.encode(
          'event: meta\ndata: {"session_id":"s1","sources":[]}\n\n'
          'event: delta\ndata: {"text":"Hello"}\n\n'
          'event: done\ndata: {}\n\n',
        ),
      ]);
      expect(events.map((e) => e.event), ['meta', 'delta', 'done']);
      expect(events[1].data, '{"text":"Hello"}');
    });

    test(
      'handles every byte boundary, including inside multi-byte Arabic characters',
      () async {
        final bytes = utf8.encode(
          'event: delta\ndata: {"text":"مرحبًا 👋 world"}\n\n',
        );
        await expectAllSplits(bytes, [
          const SseEvent(event: 'delta', data: '{"text":"مرحبًا 👋 world"}'),
        ]);
      },
    );

    test('feeds one byte at a time', () async {
      final bytes = utf8.encode('event: delta\r\ndata: {"text":"نص"}\r\n\r\n');
      final events = await parseChunks([
        for (final b in bytes) [b],
      ]);
      expect(events, [const SseEvent(event: 'delta', data: '{"text":"نص"}')]);
    });

    test(
      'supports CRLF, LF and lone CR line endings, including CRLF split across chunks',
      () async {
        await expectAllSplits(utf8.encode('event: a\r\ndata: 1\r\n\r\n'), [
          const SseEvent(event: 'a', data: '1'),
        ]);
        expect(await parseChunks([utf8.encode('event: b\rdata: 2\r\r')]), [
          const SseEvent(event: 'b', data: '2'),
        ]);
        expect(
          await parseChunks([utf8.encode('data: x\r'), utf8.encode('\n\r\n')]),
          [const SseEvent(event: 'message', data: 'x')],
        );
      },
    );

    test(
      'joins multi-line data with newlines and keeps inner spacing',
      () async {
        final events = await parseChunks([
          utf8.encode('data: line one\ndata:line two\ndata:   indented\n\n'),
        ]);
        expect(events.single.data, 'line one\nline two\n  indented');
      },
    );

    test('ignores comments, keepalives and unknown fields', () async {
      final events = await parseChunks([
        utf8.encode(
          ': keepalive\n\nretry: 10\nfoo: bar\nevent: x\ndata: y\n\n: trailing\n',
        ),
      ]);
      expect(events, [const SseEvent(event: 'x', data: 'y')]);
    });

    test(
      'does not dispatch events without data and resets the event name',
      () async {
        final events = await parseChunks([
          utf8.encode('event: lost\n\ndata: kept\n\n'),
        ]);
        expect(events, [const SseEvent(event: 'message', data: 'kept')]);
      },
    );

    test('discards an unterminated final event', () async {
      final events = await parseChunks([
        utf8.encode(
          'event: delta\ndata: {"text":"a"}\n\nevent: delta\ndata: {"text":"partial"}',
        ),
      ]);
      expect(events, hasLength(1));
    });

    test('strips a leading byte order mark and tracks ids', () async {
      final events = await parseChunks([
        [0xEF, 0xBB, 0xBF],
        utf8.encode('id: 7\ndata: a\n\ndata: b\n\n'),
      ]);
      expect(events.map((e) => e.id), ['7', '7']);
    });

    test('reports invalid UTF-8 as a stream error', () async {
      await expectLater(
        parseChunks([
          [0x64, 0x61, 0x74, 0x61, 0x3A, 0xC3, 0x28, 0x0A, 0x0A],
        ]),
        throwsA(isA<FormatException>()),
      );
    });

    test('cancelling the output cancels the source subscription', () async {
      var sourceCancelled = false;
      final source = StreamController<List<int>>(
        onCancel: () => sourceCancelled = true,
      );
      final sub = source.stream.transform(const SseParser()).listen((_) {});
      source.add(utf8.encode('data: a\n\n'));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(sourceCancelled, isTrue);
      await source.close();
    });
  });

  group('ChatStreamDecoder', () {
    ChatStreamEvent? decode(String event, String data) =>
        ChatStreamDecoder.decode(SseEvent(event: event, data: data));

    test('maps meta with citations', () {
      final meta =
          decode(
                'meta',
                jsonEncode({
                  'session_id': 's1',
                  'sources': [
                    {
                      'chunk_id': 'd:1:0',
                      'score': 0.82,
                      'document_id': 'd',
                      'filename': 'عقد.pdf',
                      'file_type': 'pdf',
                      'chunk_index': 1,
                      'text': 'نص',
                      'metadata': {},
                    },
                  ],
                }),
              )
              as ChatStreamMeta;
      expect(meta.sessionId, 's1');
      expect(meta.sources.single.filename, 'عقد.pdf');
      expect(meta.sources.single.chunkIndex, 1);
    });

    test('maps delta, provider failures, done and quota errors', () {
      expect(
        (decode('delta', '{"text":"Hi"}') as ChatStreamDelta).isProviderError,
        isFalse,
      );
      expect(
        (decode(
                  'delta',
                  jsonEncode({'text': '\n\n[stream_error] 401 invalid key'}),
                )
                as ChatStreamDelta)
            .isProviderError,
        isTrue,
      );
      expect(decode('done', '{}'), isA<ChatStreamDone>());
      final error =
          decode('error', '{"detail":"429: Daily token limit reached"}')
              as ChatStreamError;
      expect(error.isQuotaExceeded, isTrue);
      expect(
        (decode('error', '{"detail":"Model not allowed in this space"}')
                as ChatStreamError)
            .isQuotaExceeded,
        isFalse,
      );
    });

    test('ignores unknown events and rejects malformed known events', () {
      expect(decode('progress', '{}'), isNull);
      expect(
        () => decode('delta', 'not json'),
        throwsA(isA<ChatStreamProtocolException>()),
      );
      expect(
        () => decode('delta', '{"value":"x"}'),
        throwsA(isA<ChatStreamProtocolException>()),
      );
      expect(
        () => decode('meta', '{"sources":[]}'),
        throwsA(isA<ChatStreamProtocolException>()),
      );
      expect(
        () => decode('error', '[1,2]'),
        throwsA(isA<ChatStreamProtocolException>()),
      );
    });
  });
}
