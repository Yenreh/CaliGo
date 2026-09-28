import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miocard/data/datasources/card_remote_datasource.dart';

/// Random without jitter so retries are instant in tests.
class _NoJitterRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

const _card = '1906051868981';

/// Metrocali proxy success payload.
const _successBody = '{"cardNumber":1906051868981,"cd_id":6,'
    '"crd_snr":5186898,"tsn":525,"balance":15300.0,'
    '"balanceDate":1785631011000}';

const _proxyErrorBody = '{"error":"Error al consultar la API externa"}';

/// Serves [respond] for each call to the proxy and counts them
class _Proxy {
  final Future<http.Response> Function(int call) respond;
  int calls = 0;

  _Proxy(this.respond);

  http.Client get client => MockClient((request) async {
        calls++;
        expect(request.url.host, 'metrocali.gov.co');
        expect(request.url.queryParameters['numero'], _card);
        return respond(calls);
      });
}

CardRemoteDatasource _datasource(http.Client client) {
  return CardRemoteDatasource(
    client: client,
    random: _NoJitterRandom(),
    backoffBase: Duration.zero,
  );
}

void main() {
  group('CardRemoteDatasource', () {
    test('parses the balance and its epoch date', () async {
      final proxy = _Proxy((_) async => http.Response(_successBody, 200));

      final result = await _datasource(proxy.client).getCardBalance(_card);

      expect(proxy.calls, 1);
      expect(result.balance, 15300.0);
      expect(result.cardNumber, '1906051868981');
      expect(
        result.balanceDate,
        DateTime.fromMillisecondsSinceEpoch(1785631011000),
      );
    });

    test('rejects a malformed card number without asking', () async {
      final proxy = _Proxy((_) async => http.Response(_successBody, 200));

      await expectLater(
        _datasource(proxy.client).getCardBalance('19060518'),
        throwsA(isA<InvalidCardApiException>()),
      );
      expect(proxy.calls, 0);
    });

    test('reports a card without movements', () async {
      final proxy = _Proxy(
        (_) async => http.Response(
          '{"cardNumber": 0, "balance": 0, "balanceDate": null}',
          200,
        ),
      );

      await expectLater(
        _datasource(proxy.client).getCardBalance(_card),
        throwsA(isA<CardNotFoundApiException>()),
      );
    });

    test('does not retry the generic proxy error', () async {
      final proxy = _Proxy((_) async => http.Response(_proxyErrorBody, 200));

      await expectLater(
        _datasource(proxy.client).getCardBalance(_card),
        throwsA(isA<ServerApiException>()),
      );
      expect(proxy.calls, 1);
    });

    test('retries a 5xx once before succeeding', () async {
      final proxy = _Proxy(
        (call) async => call < 2
            ? http.Response('Internal Server Error', 500)
            : http.Response(_successBody, 200),
      );

      final result = await _datasource(proxy.client).getCardBalance(_card);

      expect(proxy.calls, 2);
      expect(result.balance, 15300.0);
    });

    test('retries a dropped connection once before giving up', () async {
      final proxy = _Proxy(
        (_) async => throw http.ClientException('Connection refused'),
      );

      await expectLater(
        _datasource(proxy.client).getCardBalance(_card),
        throwsA(isA<NetworkApiException>()),
      );
      expect(proxy.calls, 2);
    });

    test('treats non-JSON bodies as retryable server errors', () async {
      final proxy = _Proxy(
        (_) async => http.Response('<html>Service Unavailable</html>', 200),
      );

      await expectLater(
        _datasource(proxy.client).getCardBalance(_card),
        throwsA(isA<ServerApiException>()),
      );
      expect(proxy.calls, 2);
    });

    test('does not retry non-5xx client errors', () async {
      final proxy = _Proxy((_) async => http.Response('Not Found', 404));

      await expectLater(
        _datasource(proxy.client).getCardBalance(_card),
        throwsA(isA<ServerApiException>()),
      );
      expect(proxy.calls, 1);
    });
  });

  group('CardRemoteDatasource when the proxy pushes back', () {
    test('does not retry a rate limit, and rests before asking again',
        () async {
      final proxy = _Proxy((_) async => http.Response('Too Many', 429));
      final datasource = _datasource(proxy.client);

      await expectLater(
        datasource.getCardBalance(_card),
        throwsA(isA<ServerApiException>()),
      );
      await expectLater(
        datasource.getCardBalance(_card),
        throwsA(isA<RateLimitApiException>()),
      );
      expect(proxy.calls, 1);
    });
  });
}
