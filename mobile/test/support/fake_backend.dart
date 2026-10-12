import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:teia_ai/core/storage/token_store.dart';

import 'fake_adapter.dart';

typedef Reply = FutureOr<ResponseBody> Function(RequestOptions request);

/// Scriptable in-memory backend keyed by "METHOD /path". Unrouted calls fail loudly.
class FakeBackend {
  FakeBackend() {
    adapter = FakeAdapter((options) async {
      final key =
          '${options.method} ${options.uri.path.replaceFirst('/api/v1', '')}';
      final reply = _routes[key];
      if (reply == null) return jsonBody(599, {'detail': 'Unrouted $key'});
      return reply(options);
    });
  }

  late final FakeAdapter adapter;
  final _routes = <String, Reply>{};

  Dio get dio => fakeDio(adapter);

  void on(String route, Reply reply) => _routes[route] = reply;

  void json(String route, int status, Object body) =>
      on(route, (_) => jsonBody(status, body));

  /// Holds the response until [release] is called, for deterministic race tests.
  HeldReply hold(String route) {
    final held = HeldReply();
    on(route, (_) => held._completer.future);
    return held;
  }

  List<RequestOptions> requestsTo(String route) => adapter.requests
      .where(
        (r) => '${r.method} ${r.uri.path.replaceFirst('/api/v1', '')}' == route,
      )
      .toList();

  Map<String, dynamic> bodyOf(RequestOptions request) => request.data is String
      ? jsonDecode(request.data as String) as Map<String, dynamic>
      : Map<String, dynamic>.from(request.data as Map);
}

/// SSE frames for `event`/JSON `data` pairs, optionally split into byte chunks.
ResponseBody sseBody(List<(String, Object)> events, {int? chunkSize}) {
  final text = events
      .map((e) => 'event: ${e.$1}\ndata: ${jsonEncode(e.$2)}\n\n')
      .join();
  final bytes = utf8.encode(text);
  final size = chunkSize ?? bytes.length;
  return streamBody(
    200,
    Stream.fromIterable([
      for (var i = 0; i < bytes.length; i += size)
        Uint8List.fromList(
          bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size),
        ),
    ]),
  );
}

class HeldReply {
  final _completer = Completer<ResponseBody>();

  void release(int status, Object body) =>
      _completer.complete(jsonBody(status, body));
}

Map<String, dynamic> userJson(
  String id, {
  String role = 'viewer',
  String? firstName,
}) => {
  'id': id,
  'email': '$id@example.com',
  'role': role,
  'is_active': true,
  'email_verified': false,
  'first_name': firstName,
  'created_at': '2026-10-12T00:00:00',
};

Map<String, dynamic> spaceJson(String id, {bool active = true}) => {
  'id': id,
  'name': 'Space $id',
  's3_bucket': 'b',
  'is_active': active,
  'policy': {'allowed_models': <String>[]},
  'created_at': '2026-10-12T00:00:00',
};

Map<String, dynamic> membershipJson(
  String spaceId, {
  String role = 'member',
  String status = 'active',
}) => {
  'space_id': spaceId,
  'user_id': 'u',
  'role': role,
  'status': status,
  'can_upload_documents': false,
  'overrides': <String, dynamic>{},
};

/// Token store whose operations complete only when the test allows it.
class ControlledTokenStore implements TokenStore {
  ControlledTokenStore([this.value]);

  String? value;
  final log = <String>[];
  final _pending = <Completer<void>>[];
  bool failReads = false;
  bool failWrites = false;
  bool failDeletes = false;

  int get pendingCount => _pending.length;

  /// Waits for the next storage operation to start, then lets it finish.
  Future<void> completeNext() async {
    for (var i = 0; i < 50 && _pending.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    _pending.removeAt(0).complete();
  }

  Future<void> _gate(String op) {
    log.add(op);
    final c = Completer<void>();
    _pending.add(c);
    return c.future;
  }

  @override
  Future<String?> read() async {
    await _gate('read');
    if (failReads) throw StateError('keystore unavailable');
    return value;
  }

  @override
  Future<void> write(String token) async {
    await _gate('write:$token');
    if (failWrites) throw StateError('keystore unavailable');
    value = token;
  }

  @override
  Future<void> delete() async {
    await _gate('delete');
    if (failDeletes) throw StateError('keystore unavailable');
    value = null;
  }
}
