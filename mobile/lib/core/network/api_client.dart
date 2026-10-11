import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'error_normalizer.dart';
import 'request_kind.dart';
import 'sse/sse_parser.dart';

typedef TokenReader = String? Function();
typedef SpaceIdReader = String? Function();
typedef SessionExpiryHandler = Future<void> Function(String? rejectedToken);

Dio createDio(AppConfig config) => Dio(
  BaseOptions(
    baseUrl: config.apiBaseUrl.toString(),
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
  ),
);

/// Single entry point for backend calls: headers, error normalization and session expiry.
class ApiClient {
  ApiClient({
    required Dio dio,
    required TokenReader readToken,
    required SpaceIdReader readSpaceId,
    required SessionExpiryHandler onSessionExpired,
  }) : _dio = dio,
       _readToken = readToken,
       _readSpaceId = readSpaceId,
       _onSessionExpired = onSessionExpired;

  static const spaceHeader = 'X-Space-Id';

  final Dio _dio;
  final TokenReader _readToken;
  final SpaceIdReader _readSpaceId;
  final SessionExpiryHandler _onSessionExpired;

  Future<Response<T>> request<T>(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? queryParameters,
    RequestKind kind = RequestKind.authenticated,
    bool includeSpace = true,
    CancelToken? cancelToken,
    Duration? receiveTimeout,
  }) async {
    final token = kind == RequestKind.public ? null : _readToken();
    try {
      return await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: _headers(token, includeSpace),
          receiveTimeout: receiveTimeout,
        ),
      );
    } on DioException catch (e) {
      throw await _fail(normalizeDioException(e, kind), kind, token);
    }
  }

  /// POSTs and decodes a `text/event-stream` response. Cancelling the subscription aborts the request.
  Stream<SseEvent> postEventStream(
    String path, {
    Object? data,
    RequestKind kind = RequestKind.authenticated,
    bool includeSpace = true,
  }) async* {
    final token = kind == RequestKind.public ? null : _readToken();
    final cancelToken = CancelToken();
    var finished = false;
    try {
      final Response<ResponseBody> response;
      try {
        response = await _dio.post<ResponseBody>(
          path,
          data: data,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              ..._headers(token, includeSpace),
              'Accept': 'text/event-stream',
            },
            receiveTimeout: const Duration(minutes: 5),
            validateStatus: (_) => true,
          ),
        );
      } on DioException catch (e) {
        throw await _fail(normalizeDioException(e, kind), kind, token);
      }

      final body = response.data!;
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        final bytes = await _readAll(body.stream);
        throw await _fail(
          normalizeHttpError(
            statusCode: status,
            body: bytes,
            headers: response.headers,
            kind: kind,
          ),
          kind,
          token,
        );
      }
      try {
        yield* body.stream.cast<List<int>>().transform(const SseParser());
      } on DioException catch (e) {
        throw normalizeDioException(e, kind);
      }
      finished = true;
    } finally {
      if (!finished && !cancelToken.isCancelled) cancelToken.cancel();
    }
  }

  Map<String, String> _headers(String? token, bool includeSpace) {
    final spaceId = includeSpace ? _readSpaceId() : null;
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (spaceId != null && spaceId.isNotEmpty) spaceHeader: spaceId,
    };
  }

  Future<ApiException> _fail(
    ApiException error,
    RequestKind kind,
    String? token,
  ) async {
    if (error is SessionExpiredException && kind == RequestKind.authenticated) {
      await _onSessionExpired(token);
    }
    return error;
  }

  static Future<List<int>> _readAll(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
      if (bytes.length > 64 * 1024) break;
    }
    return bytes;
  }
}
