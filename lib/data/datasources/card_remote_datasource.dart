import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/card_balance_response.dart';
import 'api_exception.dart';
import 'service_guard.dart';

export 'api_exception.dart';

/// Remote data source for fetching card balance.
///
/// Asks Metrocali's balance service. It queries the fare system
/// server-side, so its quota is not tied to the user's IP.
class CardRemoteDatasource {
  static const String _ctsUrl = 'https://metrocali.gov.co/cts/api/cts.php';

  static const Map<String, String> _ctsHeaders = {
    'Accept': 'application/json',
  };

  /// A transit card number, prefix and suffix included
  static final RegExp _cardNumber = RegExp(r'^\d{13}$');

  /// A second attempt covers a dropped connection; more only press a
  /// service that is struggling
  static const int _maxAttempts = 2;
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _baseBackoff = Duration(seconds: 1);
  static const int _maxJitterMs = 500;

  final http.Client _client;
  final Random _random;
  final Duration _backoffBase;

  /// Left alone for a while after it pushes back
  final ServiceGuard _guard;

  CardRemoteDatasource({
    http.Client? client,
    Random? random,
    Duration backoffBase = _baseBackoff,
    ServiceGuard? guard,
  })  : _client = client ?? http.Client(),
        _random = random ?? Random(),
        _backoffBase = backoffBase,
        _guard = guard ?? ServiceGuard();

  /// Fetch the balance of [cardId], the full 13-digit card number
  Future<CardBalanceResponse> getCardBalance(String cardId) async {
    // The proxy answers a malformed number with the same generic error as
    // any failure, so catch it here, without a request
    if (!_cardNumber.hasMatch(cardId)) {
      throw const InvalidCardApiException(
        'Card number must have exactly 13 digits',
      );
    }

    _guard.check();
    try {
      final response = await _withRetries(() => _fetch(cardId));
      _guard.answered();
      return response;
    } on ApiException catch (e) {
      if (ServiceGuard.isPushBack(e)) _guard.pushedBack();
      rethrow;
    }
  }

  /// Run [request], retrying transient failures with exponential backoff
  Future<CardBalanceResponse> _withRetries(
    Future<CardBalanceResponse> Function() request,
  ) async {
    ApiException? lastError;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_backoffFor(attempt));
      }
      try {
        return await request();
      } on ApiException catch (e) {
        if (!e.isRetryable) rethrow;
        lastError = e;
      }
    }
    throw lastError!;
  }

  Duration _backoffFor(int attempt) {
    final multiplier = 1 << (attempt - 1);
    final jitter = _random.nextInt(_maxJitterMs);
    return Duration(
      milliseconds: _backoffBase.inMilliseconds * multiplier + jitter,
    );
  }

  Future<http.Response> _get(Uri uri) async {
    final http.Response response;
    try {
      response =
          await _client.get(uri, headers: _ctsHeaders).timeout(_requestTimeout);
    } on TimeoutException {
      throw const NetworkApiException('Request timed out');
    } on http.ClientException catch (e) {
      throw NetworkApiException('Connection error: ${e.message}');
    }

    if (response.statusCode == 429) {
      throw const ServerApiException(
        'Rate limited',
        statusCode: 429,
        isRetryable: false,
      );
    }
    if (response.statusCode >= 500) {
      throw ServerApiException(
        'Server error: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode != 200) {
      throw ServerApiException(
        'Unexpected status: ${response.statusCode}',
        statusCode: response.statusCode,
        isRetryable: false,
      );
    }

    return response;
  }

  /// Success: {"cardNumber": 1906051868981, "balance": 15300.0,
  ///           "balanceDate": 1785631011000, ...}
  /// Failure: {"error": "..."} with HTTP 200.
  Future<CardBalanceResponse> _fetch(String cardId) async {
    final response = await _get(Uri.parse('$_ctsUrl?numero=$cardId'));
    final payload = _decodeJsonObject(response.body);

    if (payload['error'] != null) {
      // The proxy collapses every upstream problem into one generic
      // message; asking again at once would only get the same one
      throw ServerApiException(
        'Proxy error: ${payload['error']}',
        isRetryable: false,
      );
    }

    return _toResponse(payload);
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Not a JSON object');
      }
      return decoded;
    } on FormatException {
      // HTML error page, empty body or any non-JSON payload: the service
      // is misbehaving, retrying may help.
      throw const ServerApiException('Unexpected response format');
    }
  }

  /// A card the fare system has no movements for comes back with a zero
  /// card number
  CardBalanceResponse _toResponse(Map<String, dynamic> payload) {
    final cardNumber = payload['cardNumber'];
    if (payload['balance'] is! num || cardNumber is! num || cardNumber <= 0) {
      throw const CardNotFoundApiException('Card not found');
    }
    return CardBalanceResponse.fromJson(payload);
  }
}
