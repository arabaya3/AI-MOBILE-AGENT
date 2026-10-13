import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/providers.dart';
import 'package:teia_ai/features/documents/application/documents_controller.dart';
import 'package:teia_ai/features/documents/data/documents_api.dart';
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

Map<String, dynamic> docJson(
  String id, {
  String state = 'ready',
  String? error,
  String name = 'notes.txt',
}) => {
  'id': id,
  'filename': name,
  'file_type': 'txt',
  'file_size': 1200,
  'state': state,
  'error_code': error,
  'chunks_count': state == 'ready' ? 2 : 0,
  'uploaded_at': '2026-10-13T08:00:00',
  'state_updated_at': '2026-10-13T08:00:00',
  'can_retry': false,
  'is_hidden': false,
};

Future<ProviderContainer> docsContainer(
  FakeBackend backend, {
  Map<String, Object> prefs = const {},
  bool start = true,
}) async {
  final c = await makeContainer(
    backend,
    prefs: prefs,
    overrides: [spaceScopeProvider.overrideWith((ref) => ref.watch(testScope))],
  );
  addTearDown(c.dispose);
  // Polling tests start the controller inside fakeAsync so its timers use fake time.
  if (start) c.listen(documentsControllerProvider, (_, _) {});
  return c;
}

DocumentsState stateOf(ProviderContainer c) =>
    c.read(documentsControllerProvider);

UploadSource source(String name, List<int> bytes) => UploadSource(
  name: name,
  length: bytes.length,
  open: () => Stream.fromIterable([
    for (var i = 0; i < bytes.length; i += 4)
      bytes.sublist(i, i + 4 > bytes.length ? bytes.length : i + 4),
  ]),
);

void main() {
  test(
    'polls with bounded backoff while processing and stops once ready',
    () async {
      final backend = FakeBackend();
      var calls = 0;
      backend.on('GET /documents/accessible', (_) {
        calls++;
        return jsonBody(200, [
          docJson('d1', state: calls < 4 ? 'processing' : 'ready'),
        ]);
      });
      final c = await docsContainer(backend, start: false);
      fakeAsync((async) {
        c.listen(documentsControllerProvider, (_, _) {});
        async.elapse(const Duration(milliseconds: 1));
        expect(calls, 1);
        async.elapse(const Duration(seconds: 2));
        expect(calls, 2);
        async.elapse(const Duration(seconds: 2));
        expect(calls, 2, reason: 'second delay is 3s');
        async.elapse(const Duration(seconds: 1));
        expect(calls, 3);
        async.elapse(const Duration(seconds: 5));
        expect(calls, 4);
        expect(stateOf(c).items!.single.isReady, isTrue);
        async.elapse(const Duration(minutes: 5));
        expect(calls, 4, reason: 'nothing left to poll');
      });
    },
  );

  test(
    'polling pauses in the background and stops on a space change',
    () async {
      final backend = FakeBackend()
        ..json('GET /documents/accessible', 200, [
          docJson('d1', state: 'processing'),
        ]);
      final c = await docsContainer(backend, start: false);
      fakeAsync((async) {
        c.listen(documentsControllerProvider, (_, _) {});
        async.elapse(const Duration(milliseconds: 1));
        c.read(appForegroundProvider.notifier).set(false);
        async.elapse(const Duration(minutes: 2));
        expect(backend.requestsTo('GET /documents/accessible'), hasLength(1));

        c.read(appForegroundProvider.notifier).set(true);
        async.elapse(const Duration(milliseconds: 1));
        expect(backend.requestsTo('GET /documents/accessible'), hasLength(2));

        c.read(testScope.notifier).set(null);
        async.elapse(const Duration(milliseconds: 1));
        final before = backend.requestsTo('GET /documents/accessible').length;
        async.elapse(const Duration(minutes: 2));
        expect(
          backend.requestsTo('GET /documents/accessible'),
          hasLength(before),
        );
        expect(stateOf(c).items, isEmpty);
      });
    },
  );

  test(
    'upload reports real byte progress, then processing, and sends the raw body once',
    () async {
      final backend = FakeBackend()
        ..json('GET /documents/accessible', 200, <Object>[]);
      final phases = <UploadPhase>[];
      final held = Completer<ResponseBody>();
      String? uploadPath;
      final c = await docsContainer(backend);
      await settle();
      final controller = c.read(documentsControllerProvider.notifier);
      c.listen(
        documentsControllerProvider.select((s) => s.uploads.firstOrNull?.phase),
        (_, p) {
          if (p != null && (phases.isEmpty || phases.last != p)) phases.add(p);
        },
      );
      backend.onAny((options) {
        if (options.method == 'PUT') {
          uploadPath = options.uri.path;
          return held.future;
        }
        return null;
      });

      final bytes = utf8.encode('Heron census notes for the marsh.');
      final pending = controller.upload(source('census.txt', bytes));
      await settle();
      expect(phases, [UploadPhase.sending, UploadPhase.processing]);
      final request = backend.adapter.requests.firstWhere(
        (r) => r.method == 'PUT',
      );
      expect(request.queryParameters['filename'], 'census.txt');
      expect(request.headers[Headers.contentLengthHeader], bytes.length);
      expect(backend.adapter.bodies[request], bytes);
      final uploadId = uploadPath!.split('/').last;
      expect(
        c.read(sharedPreferencesProvider).getString('pending_uploads.u1#1/s1'),
        contains(uploadId),
      );

      held.complete(jsonBody(201, docJson('d9', name: 'census.txt')));
      await pending;
      await settle();
      expect(phases.last, UploadPhase.done);
      expect(stateOf(c).uploads.single.document!.id, 'd9');
      expect(
        c.read(sharedPreferencesProvider).getString('pending_uploads.u1#1/s1'),
        isNull,
      );
    },
  );

  test(
    'oversized and unsupported files are refused before any request',
    () async {
      final backend = FakeBackend()
        ..json('GET /documents/accessible', 200, <Object>[]);
      final c = await docsContainer(backend);
      await settle();
      final controller = c.read(documentsControllerProvider.notifier);
      final big = UploadSource(
        name: 'big.pdf',
        length: maxUploadBytes + 1,
        open: () => const Stream.empty(),
      );
      expect(await controller.upload(big), LocalRejection.tooLarge);
      expect(
        await controller.upload(source('tool.exe', [1, 2])),
        LocalRejection.unsupportedType,
      );
      final exact = UploadSource(
        name: 'exact.pdf',
        length: maxUploadBytes,
        open: () => const Stream.empty(),
      );
      expect(checkLocally(exact), isNull);
      expect(backend.adapter.requests.where((r) => r.method == 'PUT'), isEmpty);
    },
  );

  test('a server rejection is final and never retried', () async {
    final backend = FakeBackend()
      ..json('GET /documents/accessible', 200, <Object>[]);
    backend.onAny(
      (o) => o.method == 'PUT'
          ? jsonBody(413, {
              'detail': {
                'code': 'too_large',
                'message': 'Files must be 25 MiB or smaller.',
              },
            })
          : null,
    );
    final c = await docsContainer(backend);
    await settle();
    await c
        .read(documentsControllerProvider.notifier)
        .upload(source('a.txt', [65, 66]));
    expect(stateOf(c).uploads.single.phase, UploadPhase.failed);
    expect(stateOf(c).uploads.single.error!.code, 'too_large');
    expect(
      backend.adapter.requests.where((r) => r.method == 'PUT'),
      hasLength(1),
    );
    expect(
      backend.adapter.requests.where(
        (r) => r.uri.path.contains('/documents/uploads/') && r.method == 'GET',
      ),
      isEmpty,
    );
  });

  test(
    'a duplicate the user may not read is final and reveals nothing',
    () async {
      final backend = FakeBackend()
        ..json('GET /documents/accessible', 200, <Object>[]);
      backend.onAny(
        (o) => o.method == 'PUT'
            ? jsonBody(409, {
                'detail': {
                  'code': 'duplicate_conflict',
                  'message': "This file can't be added to this space.",
                },
              })
            : null,
      );
      final c = await docsContainer(backend);
      await settle();
      await c
          .read(documentsControllerProvider.notifier)
          .upload(source('a.txt', [65, 66]));
      await settle();
      final task = stateOf(c).uploads.single;
      expect(task.phase, UploadPhase.failed);
      expect(task.error!.code, 'duplicate_conflict');
      expect(task.document, isNull);
      expect(
        backend.adapter.requests.where((r) => r.method == 'PUT'),
        hasLength(1),
      );
      expect(
        backend.adapter.requests.where(
          (r) =>
              r.method == 'GET' && r.uri.path.contains('/documents/uploads/'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'an uncertain failure is reconciled by upload ID instead of being resent',
    () async {
      final backend = FakeBackend()
        ..json('GET /documents/accessible', 200, <Object>[]);
      String? uploadId;
      backend.onAny((o) {
        if (o.method == 'PUT') {
          uploadId = o.uri.pathSegments.last;
          throw DioException.connectionError(
            requestOptions: o,
            reason: 'reset',
          );
        }
        if (o.method == 'GET' &&
            o.uri.path.endsWith('/documents/uploads/$uploadId')) {
          return jsonBody(200, docJson('d7', state: 'processing'));
        }
        return null;
      });
      final c = await docsContainer(backend);
      await settle();
      await c
          .read(documentsControllerProvider.notifier)
          .upload(source('a.txt', [65, 66, 67]));
      await settle();
      final task = stateOf(c).uploads.single;
      expect(task.phase, UploadPhase.done);
      expect(task.document!.id, 'd7');
      expect(
        backend.adapter.requests.where((r) => r.method == 'PUT'),
        hasLength(1),
      );
    },
  );

  test('an upload the server never received is reported, not resent', () async {
    final backend = FakeBackend()
      ..json('GET /documents/accessible', 200, <Object>[]);
    backend.onAny((o) {
      if (o.method == 'PUT') {
        throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        );
      }
      if (o.method == 'GET' && o.uri.path.contains('/documents/uploads/')) {
        return jsonBody(404, {'detail': 'Upload not found'});
      }
      return null;
    });
    final c = await docsContainer(backend);
    await settle();
    await c
        .read(documentsControllerProvider.notifier)
        .upload(source('a.txt', [65]));
    await settle();
    expect(stateOf(c).uploads.single.phase, UploadPhase.notReceived);
    expect(
      backend.adapter.requests.where((r) => r.method == 'PUT'),
      hasLength(1),
    );
  });

  test('pending uploads are checked again after a restart', () async {
    final backend = FakeBackend()
      ..json('GET /documents/accessible', 200, [
        docJson('d3', state: 'indexing'),
      ])
      ..json(
        'GET /documents/uploads/up-1111-arrived',
        200,
        docJson('d3', state: 'indexing'),
      )
      ..json('GET /documents/uploads/up-2222-missing', 404, {
        'detail': 'Upload not found',
      });
    final c = await docsContainer(
      backend,
      prefs: {
        'pending_uploads.u1#1/s1': jsonEncode([
          {'id': 'up-1111-arrived', 'name': 'a.pdf', 'size': 10},
          {'id': 'up-2222-missing', 'name': 'b.pdf', 'size': 10},
        ]),
      },
    );
    await settle();
    final uploads = {for (final u in stateOf(c).uploads) u.uploadId: u};
    expect(uploads['up-1111-arrived']!.phase, UploadPhase.done);
    expect(uploads['up-2222-missing']!.phase, UploadPhase.notReceived);
    expect(
      c.read(sharedPreferencesProvider).getString('pending_uploads.u1#1/s1'),
      isNull,
    );
  });

  test(
    'cancelling stops this device only and then checks what the server received',
    () async {
      final backend = FakeBackend()
        ..json('GET /documents/accessible', 200, <Object>[]);
      final held = Completer<ResponseBody>();
      backend.onAny((o) {
        if (o.method == 'PUT') return held.future;
        if (o.method == 'GET' && o.uri.path.contains('/documents/uploads/')) {
          return jsonBody(404, {'detail': 'Upload not found'});
        }
        return null;
      });
      final c = await docsContainer(backend);
      await settle();
      final controller = c.read(documentsControllerProvider.notifier);
      final pending = controller.upload(source('a.txt', [65, 66]));
      await settle();
      controller.cancelUpload(stateOf(c).uploads.single.uploadId);
      await pending;
      await settle();
      expect(stateOf(c).uploads.single.phase, UploadPhase.cancelled);
      expect(backend.adapter.cancelledRequests, greaterThanOrEqualTo(1));
    },
  );

  test('a late upload result after a space switch is dropped', () async {
    final backend = FakeBackend()
      ..json('GET /documents/accessible', 200, <Object>[]);
    final held = Completer<ResponseBody>();
    backend.onAny((o) => o.method == 'PUT' ? held.future : null);
    final c = await docsContainer(backend);
    await settle();
    final pending = c
        .read(documentsControllerProvider.notifier)
        .upload(source('a.txt', [65]));
    await settle();
    c.read(testScope.notifier).set('u1#1/s2');
    await settle();
    held.complete(jsonBody(201, docJson('late')));
    await pending.catchError((_) => null);
    await settle();
    expect(stateOf(c).uploads, isEmpty);
    expect(
      (stateOf(c).items ?? const []).map((d) => d.id),
      isNot(contains('late')),
    );
  });
}
