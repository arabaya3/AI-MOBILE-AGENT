import 'dart:convert';
import 'dart:io' show HandshakeException, SocketException;

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'request_kind.dart';

ApiException normalizeDioException(DioException error, RequestKind kind) {
  switch (error.type) {
    case DioExceptionType.cancel:
      return const RequestCancelledException();
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const RequestTimeoutException();
    case DioExceptionType.badCertificate:
      return const InsecureConnectionException();
    case DioExceptionType.connectionError:
      return error.error is HandshakeException
          ? const InsecureConnectionException()
          : const NetworkUnavailableException();
    case DioExceptionType.badResponse:
      final response = error.response!;
      return normalizeHttpError(
        statusCode: response.statusCode ?? 0,
        body: response.data,
        headers: response.headers,
        kind: kind,
      );
    case DioExceptionType.unknown:
      if (error.error is SocketException) {
        return const NetworkUnavailableException();
      }
      return UnexpectedResponseException(message: error.message);
  }
}

ApiException normalizeHttpError({
  required int statusCode,
  required Object? body,
  required Headers headers,
  required RequestKind kind,
}) {
  final parsed = _decodeBody(body);
  final detail = parsed.detail;
  final structured = detail is Map ? detail : null;
  final code = structured?['code'] is String
      ? structured!['code'] as String
      : null;
  final message = detail is String
      ? detail
      : structured?['message'] is String
      ? structured!['message'] as String
      : (parsed.isJson ? null : parsed.text);

  switch (statusCode) {
    case 400:
      return BadRequestException(message: message, code: code);
    case 401:
      return kind == RequestKind.authenticated
          ? SessionExpiredException(message: message)
          : InvalidCredentialsException(message: message);
    case 403:
      return ForbiddenException(message: message, code: code);
    case 404:
      return NotFoundException(message: message, code: code);
    case 409:
      return ConflictException(message: message, code: code);
    case 413:
      return PayloadTooLargeException(message: message, code: code);
    case 415:
      return UnsupportedMediaException(message: message, code: code);
    case 422:
      return ValidationException(
        issues: _validationIssues(detail),
        message: message,
        code: code,
      );
    case 429:
      return parsed.isJson
          ? QuotaExceededException(message: message)
          : RateLimitedException(
              retryAfter: _retryAfter(headers),
              message: message,
            );
  }
  if (statusCode >= 500) {
    return ServerException(statusCode: statusCode, message: message);
  }
  return UnexpectedResponseException(
    statusCode: statusCode,
    message: message,
    code: code,
  );
}

class _DecodedBody {
  const _DecodedBody({required this.isJson, this.detail, this.text});

  final bool isJson;
  final Object? detail;
  final String? text;
}

_DecodedBody _decodeBody(Object? body) {
  Object? value = body;
  if (value is List<int>) value = utf8.decode(value, allowMalformed: true);
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        value = jsonDecode(trimmed);
      } on FormatException {
        return _DecodedBody(isJson: false, text: _safeText(trimmed));
      }
    } else {
      return _DecodedBody(isJson: false, text: _safeText(trimmed));
    }
  }
  if (value is Map) return _DecodedBody(isJson: true, detail: value['detail']);
  return _DecodedBody(isJson: value != null);
}

String? _safeText(String text) {
  if (text.isEmpty || text.startsWith('<')) return null;
  return text.length > 300 ? text.substring(0, 300) : text;
}

List<ValidationIssue> _validationIssues(Object? detail) {
  if (detail is! List) return const [];
  return [
    for (final item in detail)
      if (item is Map)
        ValidationIssue(
          location: [
            for (final part in (item['loc'] as List? ?? const [])) '$part',
          ],
          message: '${item['msg'] ?? ''}',
          type: item['type'] as String?,
        ),
  ];
}

Duration? _retryAfter(Headers headers) {
  final raw =
      headers.value('retry-after') ?? headers.value('x-ratelimit-reset');
  final seconds = int.tryParse(raw?.trim() ?? '');
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}
