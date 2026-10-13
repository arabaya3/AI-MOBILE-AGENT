import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = Future<ResponseBody> Function(RequestOptions options);

/// Records requests and answers them with scripted responses; never touches the network.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FakeHandler handler;
  final requests = <RequestOptions>[];

  /// Raw bytes each request sent, in request order (empty when it had no body).
  final bodies = <RequestOptions, List<int>>{};
  int cancelledRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    unawaited(cancelFuture?.then((_) => cancelledRequests++));
    // Reading the body is what drives Dio's upload progress callbacks.
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    bodies[options] = bytes;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

ResponseBody textBody(
  int status,
  String body, {
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
    ...headers,
  },
);

ResponseBody streamBody(int status, Stream<Uint8List> stream) => ResponseBody(
  stream,
  status,
  headers: {
    Headers.contentTypeHeader: ['text/event-stream'],
  },
);

Dio fakeDio(FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
      ..httpClientAdapter = adapter;
