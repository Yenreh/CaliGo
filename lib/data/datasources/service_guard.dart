import 'dart:math';

import 'api_exception.dart';

/// Leaves a public service alone for a while after it pushes back.
///
/// Rate limits and server errors that outlast a retry are the service
/// asking for less, and polling on schedule regardless is how an origin
/// gets blocked. Each push back in a row doubles the wait, from
/// [firstWait] up to [longestWait]; the first normal answer clears it.
class ServiceGuard {
  static const Duration firstWait = Duration(minutes: 1);
  static const Duration longestWait = Duration(minutes: 16);

  /// One instance, so a refresh that keeps failing reports the same error
  /// instead of looking like a new one each time
  static const RateLimitApiException resting =
      RateLimitApiException('Leaving the service alone for a while');

  final DateTime Function() _now;
  int _strikes = 0;
  DateTime? _until;

  ServiceGuard({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Throws [resting] while the service is being left alone
  void check() {
    final until = _until;
    if (until != null && _now().isBefore(until)) throw resting;
  }

  void pushedBack() {
    _strikes++;
    final wait = firstWait * (1 << min(_strikes - 1, 30));
    _until = _now().add(wait > longestWait ? longestWait : wait);
  }

  void answered() {
    _strikes = 0;
    _until = null;
  }

  /// Whether [error] is the service pushing back, rather than the device
  /// being offline or the request itself being wrong
  static bool isPushBack(ApiException error) =>
      error is RateLimitApiException ||
      error.statusCode == 429 ||
      (error.statusCode ?? 0) >= 500;
}
