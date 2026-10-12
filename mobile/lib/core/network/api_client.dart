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
typedef SpaceRejectedHandler = void Function(String spaceId);

Dio createDio(AppConfig config) => Dio(
  BaseOptions(
    baseUrl: config.apiBaseUrl.toString(),
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
  ),
);

class _InFlight {
  _InFlight(this.cancelToken, this.spaceId);

  final CancelToken cancelToken;
  final String? spaceId;
}

/// Single entry point for backend calls: headers, error normalization,
/// session expiry and scoped cancellation.
class ApiClient {
  ApiClient({
    required Dio dio,
    required TokenReader readToken,
    required SpaceIdReader readSpaceId,
    required SessionExpiryHandler onSessionExpired,
    SpaceRejectedHandler? onSpaceRejected,
  }) : _dio = dio,
       _readToken = readToken,
       _readSpaceId = readSpaceId,
       _onSessionExpired = onSessionExpired,
       _onSpaceRejected = onSpaceRejected;

  static const spaceHeader = 'X-Space-Id';

  final Dio _dio;
  final TokenReader _readToken;
  final SpaceIdReader _readSpaceId;
  final SessionExpiryHandler _onSessionExpired;
  final SpaceRejectedHandler? _onSpaceRejected;
  final _inFlight = <_InFlight>{};

  /// Aborts every in-flight request (sign-out, expiry, account change).
  void cancelAll() => _cancelWhere((_) => true);

  /// Aborts requests that carried an `X-Space-Id` (space switch).
  void cancelSpaceScoped() => _cancelWhere((r) => r.spaceId != null);

  Future<Response<T>> request<T>(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? queryParameters,
    RequestKind kind = RequestKind.authenticated,
    bool includeSpace = true,
    CancelToken? cancelToken,
    Duration? receiveTimeout,
    ResponseType? responseType,
  }) async {
    final token = kind == RequestKind.public ? null : _readToken();
    final spaceId = includeSpace ? _readSpaceId() : null;
    final inFlight = _track(spaceId, cancelToken);
    try {
      return await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: inFlight.cancelToken,
        options: Options(
          method: method,
          headers: _headers(token, spaceId),
          receiveTimeout: receiveTimeout,
          responseType: responseType,
        ),
      );
    } on DioException catch (e) {
      throw await _fail(normalizeDioException(e, kind), kind, token, spaceId);
    } finally {
      _inFlight.remove(inFlight);
    }
  }

  /// POSTs and decodes a `text/event-stream` response. Cancelling the subscription aborts the request.
  Stream<SseEvent> postEventStream(
    String path, {
    Object? data,
    RequestKind kind = RequestKind.authenticated,
    bool includeSpace = true,
    CancelToken? cancelToken,
  }) async* {
    final token = kind == RequestKind.public ? null : _readToken();
    final spaceId = includeSpace ? _readSpaceId() : null;
    final inFlight = _track(spaceId, cancelToken);
    final requestToken = inFlight.cancelToken;
    var finished = false;
    try {
      final Response<ResponseBody> response;
      try {
        response = await _dio.post<ResponseBody>(
          path,
          data: data,
          cancelToken: requestToken,
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              ..._headers(token, spaceId),
              'Accept': 'text/event-stream',
            },
            receiveTimeout: const Duration(minutes: 5),
            validateStatus: (_) => true,
          ),
        );
      } on DioException catch (e) {
        throw await _fail(normalizeDioException(e, kind), kind, token, spaceId);
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
          spaceId,
        );
      }
      try {
        yield* body.stream.cast<List<int>>().transform(const SseParser());
      } on DioException catch (e) {
        throw normalizeDioException(e, kind);
      }
      finished = true;
    } finally {
      _inFlight.remove(inFlight);
      if (!finished && !requestToken.isCancelled) requestToken.cancel();
    }
  }

  _InFlight _track(String? spaceId, CancelToken? callerToken) {
    final inFlight = _InFlight(CancelToken(), spaceId);
    callerToken?.whenCancel.then((_) => inFlight.cancelToken.cancel());
    _inFlight.add(inFlight);
    return inFlight;
  }

  void _cancelWhere(bool Function(_InFlight) test) {
    for (final request in _inFlight.where(test).toList()) {
      request.cancelToken.cancel();
      _inFlight.remove(request);
    }
  }

  Map<String, String> _headers(String? token, String? spaceId) => {
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    if (spaceId != null && spaceId.isNotEmpty) spaceHeader: spaceId,
  };

  Future<ApiException> _fail(
    ApiException error,
    RequestKind kind,
    String? token,
    String? spaceId,
  ) async {
    if (error is SessionExpiredException && kind == RequestKind.authenticated) {
      await _onSessionExpired(token);
    } else if (spaceId != null &&
        _isSpaceRejection(error) &&
        spaceId == _readSpaceId()) {
      _onSpaceRejected?.call(spaceId);
    }
    return error;
  }

  /// Responses from `get_current_space_id` when the selected space is no longer usable.
  static bool _isSpaceRejection(ApiException error) =>
      (error is ForbiddenException && error.message == 'Space access denied') ||
      (error is NotFoundException && error.message == 'Space not found');

  static Future<List<int>> _readAll(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
      if (bytes.length > 64 * 1024) break;
    }
    return bytes;
  }
}
