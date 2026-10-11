import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/core/network/api_exception.dart';
import 'package:teia_ai/core/network/error_normalizer.dart';
import 'package:teia_ai/core/network/request_kind.dart';

ApiException http(
  int status,
  Object? body, {
  RequestKind kind = RequestKind.authenticated,
  Map<String, List<String>>? headers,
}) => normalizeHttpError(
  statusCode: status,
  body: body,
  headers: Headers.fromMap(headers ?? {}),
  kind: kind,
);

DioException dioError(DioExceptionType type, {Object? error}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
  error: error,
);

void main() {
  test('extracts FastAPI string detail', () {
    final e = http(403, {'detail': 'Space admin required'});
    expect(e, isA<ForbiddenException>());
    expect(e.message, 'Space admin required');
  });

  test('parses FastAPI validation arrays', () {
    final e =
        http(422, {
              'detail': [
                {
                  'loc': ['body', 'email'],
                  'msg': 'value is not a valid email address',
                  'type': 'value_error',
                },
                {
                  'loc': ['body', 'password'],
                  'msg': 'String should have at least 8 characters',
                  'type': 'string_too_short',
                },
              ],
            })
            as ValidationException;
    expect(e.issues.map((i) => i.field), ['email', 'password']);
    expect(e.issues.first.message, 'value is not a valid email address');
    expect(e.message, isNull);
  });

  test('plain-text 429 is HTTP rate limiting with retry hint', () {
    final e = http(
      429,
      'Rate limit exceeded',
      headers: {
        'x-ratelimit-reset': ['42'],
      },
    );
    expect(e, isA<RateLimitedException>());
    expect((e as RateLimitedException).retryAfter, const Duration(seconds: 42));
    expect(e.message, 'Rate limit exceeded');
  });

  test('JSON 429 is a usage quota', () {
    final e = http(429, {'detail': 'Daily token limit reached'});
    expect(e, isA<QuotaExceededException>());
    expect(e.message, 'Daily token limit reached');
  });

  test('401 meaning depends on request kind', () {
    expect(
      http(401, {'detail': 'Invalid authentication credentials'}),
      isA<SessionExpiredException>(),
    );
    expect(
      http(401, {'detail': 'Invalid credentials'}, kind: RequestKind.public),
      isA<InvalidCredentialsException>(),
    );
    expect(
      http(401, {
        'detail': 'Invalid credentials',
      }, kind: RequestKind.credentialCheck),
      isA<InvalidCredentialsException>(),
    );
  });

  test('maps remaining status codes', () {
    expect(http(400, {'detail': 'bad'}), isA<BadRequestException>());
    expect(http(404, {'detail': 'x'}), isA<NotFoundException>());
    expect(http(409, {'detail': 'x'}), isA<ConflictException>());
    expect(http(413, 'too big'), isA<PayloadTooLargeException>());
    expect(
      http(503, '<html>Bad gateway</html>'),
      isA<ServerException>().having((e) => e.message, 'message', isNull),
    );
    expect(http(418, null), isA<UnexpectedResponseException>());
  });

  test('decodes byte bodies from streamed responses', () {
    final e = http(404, '{"detail":"Space not found"}'.codeUnits);
    expect(e.message, 'Space not found');
  });

  test('maps transport failures', () {
    final kind = RequestKind.authenticated;
    expect(
      normalizeDioException(dioError(DioExceptionType.cancel), kind),
      isA<RequestCancelledException>(),
    );
    expect(
      normalizeDioException(dioError(DioExceptionType.receiveTimeout), kind),
      isA<RequestTimeoutException>(),
    );
    expect(
      normalizeDioException(dioError(DioExceptionType.connectionTimeout), kind),
      isA<RequestTimeoutException>(),
    );
    expect(
      normalizeDioException(dioError(DioExceptionType.badCertificate), kind),
      isA<InsecureConnectionException>(),
    );
    expect(
      normalizeDioException(
        dioError(
          DioExceptionType.connectionError,
          error: const SocketException('no route'),
        ),
        kind,
      ),
      isA<NetworkUnavailableException>(),
    );
    expect(
      normalizeDioException(
        dioError(
          DioExceptionType.unknown,
          error: const SocketException('down'),
        ),
        kind,
      ),
      isA<NetworkUnavailableException>(),
    );
  });
}
