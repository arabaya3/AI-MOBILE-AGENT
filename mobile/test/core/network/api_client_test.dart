import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/network/api_client.dart';
import 'package:teia_ai/core/network/api_exception.dart';
import 'package:teia_ai/core/network/request_kind.dart';
import 'package:teia_ai/core/network/sse/sse_parser.dart';
import 'package:teia_ai/core/session/session_manager.dart';
import 'package:teia_ai/core/storage/token_store.dart';

import '../../support/fake_adapter.dart';

void main() {
  late InMemoryTokenStore store;
  late SessionManager session;
  String? spaceId;

  ApiClient clientFor(FakeAdapter adapter) => ApiClient(
    dio: fakeDio(adapter),
    readToken: () => session.token,
    readSpaceId: () => spaceId,
    onSessionExpired: session.expire,
  );

  setUp(() async {
    store = InMemoryTokenStore('token-1');
    session = SessionManager(store);
    await session.restore();
    spaceId = 'space-42';
  });

  group('headers', () {
    test('authenticated requests send bearer token and active space', () async {
      final adapter = FakeAdapter((_) async => jsonBody(200, {'ok': true}));
      await clientFor(adapter).request<Map<String, dynamic>>('/spaces');
      final headers = adapter.requests.single.headers;
      expect(headers['Authorization'], 'Bearer token-1');
      expect(headers[ApiClient.spaceHeader], 'space-42');
    });

    test('public requests never send the bearer token', () async {
      final adapter = FakeAdapter((_) async => jsonBody(200, {}));
      await clientFor(adapter).request<Object>(
        '/auth/login',
        method: 'POST',
        kind: RequestKind.public,
      );
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test(
      'space header is omitted when no space is active or when excluded',
      () async {
        final adapter = FakeAdapter((_) async => jsonBody(200, {}));
        final client = clientFor(adapter);
        spaceId = null;
        await client.request<Object>('/spaces');
        spaceId = 'space-42';
        await client.request<Object>('/spaces', includeSpace: false);
        expect(
          adapter.requests.every(
            (r) => !r.headers.containsKey(ApiClient.spaceHeader),
          ),
          isTrue,
        );
      },
    );
  });

  group('session expiry', () {
    test(
      'concurrent 401s end the session exactly once and are never retried',
      () async {
        final adapter = FakeAdapter(
          (_) async =>
              jsonBody(401, {'detail': 'Invalid authentication credentials'}),
        );
        final client = clientFor(adapter);
        final events = <SessionStatus>[];
        final sub = session.changes.listen(events.add);

        final results = await Future.wait(
          List.generate(
            6,
            (i) => client
                .request<Object>('/chat/sessions')
                .then<Object?>((_) => null, onError: (Object e) => e),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(results, everyElement(isA<SessionExpiredException>()));
        expect(adapter.requests, hasLength(6));
        expect(events.where((s) => s == SessionStatus.expired), hasLength(1));
        expect(store.deleteCount, 1);
        expect(session.token, isNull);
        await sub.cancel();
      },
    );

    test('a 401 for an old token does not end a newer session', () async {
      final gate = Completer<void>();
      final adapter = FakeAdapter((_) async {
        await gate.future;
        return jsonBody(401, {'detail': 'expired'});
      });
      final pending = clientFor(adapter).request<Object>('/chat/sessions');
      await session.start('token-2');
      gate.complete();

      await expectLater(pending, throwsA(isA<SessionExpiredException>()));
      expect(session.token, 'token-2');
      expect(session.status, SessionStatus.signedIn);
    });

    test(
      'wrong current password is a credential failure, not an expiry',
      () async {
        final adapter = FakeAdapter(
          (_) async => jsonBody(401, {'detail': 'Invalid credentials'}),
        );
        await expectLater(
          clientFor(adapter).request<Object>(
            '/auth/change-password',
            method: 'POST',
            kind: RequestKind.credentialCheck,
          ),
          throwsA(isA<InvalidCredentialsException>()),
        );
        expect(
          adapter.requests.single.headers['Authorization'],
          'Bearer token-1',
        );
        expect(session.token, 'token-1');
        expect(store.deleteCount, 0);
      },
    );

    test('failed login does not touch the session', () async {
      final adapter = FakeAdapter(
        (_) async => jsonBody(401, {'detail': 'Invalid credentials'}),
      );
      await expectLater(
        clientFor(adapter).request<Object>(
          '/auth/login',
          method: 'POST',
          kind: RequestKind.public,
        ),
        throwsA(isA<InvalidCredentialsException>()),
      );
      expect(session.token, 'token-1');
    });
  });

  group('event stream', () {
    test('decodes events and sends stream headers', () async {
      final adapter = FakeAdapter(
        (_) async => streamBody(
          200,
          Stream.fromIterable([
            Uint8List.fromList(
              utf8.encode(
                'event: meta\ndata: {"session_id":"s1","sources":[]}\n\nevent: delta\ndata: {"text":"مر',
              ),
            ),
            Uint8List.fromList(
              utf8.encode('حبا"}\n\nevent: done\ndata: {}\n\n'),
            ),
          ]),
        ),
      );
      final events = await clientFor(
        adapter,
      ).postEventStream('/chat/query/stream', data: {'message': 'hi'}).toList();
      expect(events.map((e) => e.event), ['meta', 'delta', 'done']);
      expect(events[1].data, '{"text":"مرحبا"}');
      expect(adapter.requests.single.headers['Accept'], 'text/event-stream');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer token-1',
      );
    });

    test('non-2xx responses are normalized and trigger expiry once', () async {
      final adapter = FakeAdapter(
        (_) async => streamBody(
          401,
          Stream.value(Uint8List.fromList(utf8.encode('{"detail":"expired"}'))),
        ),
      );
      await expectLater(
        clientFor(adapter).postEventStream('/chat/query/stream').toList(),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(session.token, isNull);
    });

    test('cancelling the subscription aborts the underlying request', () async {
      final source = StreamController<Uint8List>();
      final adapter = FakeAdapter((_) async => streamBody(200, source.stream));
      final received = <SseEvent>[];
      final sub = clientFor(
        adapter,
      ).postEventStream('/chat/query/stream').listen(received.add);

      await pumpUntil(() => source.hasListener);
      source.add(
        Uint8List.fromList(utf8.encode('event: delta\ndata: {"text":"a"}\n\n')),
      );
      await pumpUntil(() => received.isNotEmpty);

      await sub.cancel();
      await pumpUntil(() => adapter.cancelledRequests == 1);
      expect(adapter.requests.single.cancelToken?.isCancelled, isTrue);
      await source.close();
    });
  });
}

Future<void> pumpUntil(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}
