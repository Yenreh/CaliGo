/// Base exception for API errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Whether retrying the request may succeed.
  final bool isRetryable;

  const ApiException(
    this.message, {
    this.statusCode,
    this.isRetryable = false,
  });

  @override
  String toString() => 'ApiException: $message';
}

/// Network failure or timeout. Transient, retryable.
class NetworkApiException extends ApiException {
  const NetworkApiException(super.message) : super(isRetryable: true);
}

/// Server-side failure (5xx, 429, malformed payloads). Transient by default.
class ServerApiException extends ApiException {
  const ServerApiException(
    super.message, {
    super.statusCode,
    super.isRetryable = true,
  });
}

/// The card number is invalid (not 13 digits). Not retryable.
class InvalidCardApiException extends ApiException {
  const InvalidCardApiException(super.message);
}

/// The card exists but has no movements/balance info. Not retryable.
class CardNotFoundApiException extends ApiException {
  const CardNotFoundApiException(super.message);
}

/// The service rate-limited this origin. Not retryable: immediate retries
/// only extend the penalty window.
class RateLimitApiException extends ApiException {
  const RateLimitApiException(super.message);
}
