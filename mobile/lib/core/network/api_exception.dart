sealed class ApiException implements Exception {
  const ApiException({this.statusCode, this.message, this.code});

  final int? statusCode;

  /// Server-provided detail, when one was safe to extract.
  final String? message;

  /// Stable machine-readable reason, when the server sent `{"detail": {"code": ...}}`.
  final String? code;

  @override
  String toString() => '$runtimeType(${statusCode ?? '-'}): ${message ?? ''}';
}

class NetworkUnavailableException extends ApiException {
  const NetworkUnavailableException();
}

class RequestTimeoutException extends ApiException {
  const RequestTimeoutException();
}

class RequestCancelledException extends ApiException {
  const RequestCancelledException();
}

class InsecureConnectionException extends ApiException {
  const InsecureConnectionException();
}

/// The bearer token used for an authenticated request was rejected.
class SessionExpiredException extends ApiException {
  const SessionExpiredException({super.message}) : super(statusCode: 401);
}

/// A login or current-password check failed; the session itself is unaffected.
class InvalidCredentialsException extends ApiException {
  const InvalidCredentialsException({super.message}) : super(statusCode: 401);
}

class BadRequestException extends ApiException {
  const BadRequestException({super.message, super.code})
    : super(statusCode: 400);
}

class ForbiddenException extends ApiException {
  const ForbiddenException({super.message, super.code})
    : super(statusCode: 403);
}

class NotFoundException extends ApiException {
  const NotFoundException({super.message, super.code}) : super(statusCode: 404);
}

class ConflictException extends ApiException {
  const ConflictException({super.message, super.code}) : super(statusCode: 409);
}

/// The server refused the content type (for example a file whose bytes do not match its extension).
class UnsupportedMediaException extends ApiException {
  const UnsupportedMediaException({super.message, super.code})
    : super(statusCode: 415);
}

class PayloadTooLargeException extends ApiException {
  const PayloadTooLargeException({super.message, super.code})
    : super(statusCode: 413);
}

class ValidationIssue {
  const ValidationIssue({
    required this.location,
    required this.message,
    this.type,
  });

  final List<String> location;
  final String message;
  final String? type;

  /// Field name without the FastAPI `body`/`query` prefix.
  String? get field => location
      .where((p) => p != 'body' && p != 'query' && p != 'path')
      .lastOrNull;
}

class ValidationException extends ApiException {
  const ValidationException({required this.issues, super.message, super.code})
    : super(statusCode: 422);

  final List<ValidationIssue> issues;
}

/// Generic HTTP rate limiting (plain-text 429 from the API gateway middleware).
class RateLimitedException extends ApiException {
  const RateLimitedException({this.retryAfter, super.message})
    : super(statusCode: 429);

  final Duration? retryAfter;
}

/// Usage policy limit (JSON 429 such as "Daily token limit reached").
class QuotaExceededException extends ApiException {
  const QuotaExceededException({super.message}) : super(statusCode: 429);
}

class ServerException extends ApiException {
  const ServerException({required int super.statusCode, super.message});
}

class UnexpectedResponseException extends ApiException {
  const UnexpectedResponseException({
    super.statusCode,
    super.message,
    super.code,
  });
}
