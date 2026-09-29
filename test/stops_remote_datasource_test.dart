import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:caligo/data/datasources/api_exception.dart';
import 'package:caligo/data/datasources/headway_memory.dart';
import 'package:caligo/data/datasources/json_cache.dart';
import 'package:caligo/data/datasources/ride_time_memory.dart';
import 'package:caligo/data/datasources/service_guard.dart';
import 'package:caligo/data/datasources/stops_remote_datasource.dart';
import 'package:caligo/domain/entities/line_entity.dart';
import 'package:caligo/domain/entities/stop_entity.dart';

const _arrivalsBody = '''
[{"idParada":"500800","nombreParada":"Plaza de Cayzedo A1",
  "distanciaMetros":119.52,
  "buses":[{"nombreLinea":"E21","nombreDestino":"Est. Universidades",
            "tiempoEstimadoDeSalida":1787429222000,"vehiculoId":"637001"},
           {"nombreLinea":"P27D","nombreDestino":"Av. Roosevelt-Capri",
            "tiempoEstimadoDeSalida":1787429500000,"vehiculoId":"1144001"}]},
 {"idParada":"500751","nombreParada":"La Ermita A2",
  "distanciaMetros":187.46,"buses":[]}]''';

const _stationsBody = '''
[{"id":1,"name":"Estación Alamos","address":"Av 3N - Cl 52N",
  "neighborhood":"Ciudad Los Alamos","commune":2,
  "longitude":-76.5133880103,"latitude":3.4842460459}]''';

StopsRemoteDatasource _datasource(http.Client client, {JsonCache? cache}) =>
    StopsRemoteDatasource(
      client: client,
      backoff: Duration.zero,
      cache: cache ?? JsonCache.noop(),
    );

void main() {
  group('StopsRemoteDatasource', () {
    test('parses nearby stops with their arrivals', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['latitud'], '3.4516');
        expect(request.url.queryParameters['radio'], '300');
        return http.Response(_arrivalsBody, 200);
      });

      final stops = await _datasource(client)
          .getNearbyStops(latitude: 3.4516, longitude: -76.532);

      expect(stops, hasLength(2));
      expect(stops.first.name, 'Plaza de Cayzedo A1');
      expect(stops.first.distanceMeters, closeTo(119.52, 0.01));
      expect(stops.first.arrivals, hasLength(2));
      expect(stops.first.arrivals.first.line, 'E21');
      expect(
        stops.first.arrivals.first.arrivalTime,
        DateTime.fromMillisecondsSinceEpoch(1787429222000),
      );
      expect(stops.last.arrivals, isEmpty);
    });

    test('caps the radius at what the service accepts', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response('[]', 200);
      });

      await _datasource(client).getNearbyStops(
        latitude: 3.4516,
        longitude: -76.532,
        radiusMeters: 5000,
      );

      expect(requested.queryParameters['radio'], '300');
    });

    test('reports service-level errors returned with HTTP 200', () async {
      final client = MockClient(
        (_) async => http.Response('{"error":"El radio no puede estar vacía."}', 200),
      );

      await expectLater(
        _datasource(client).getNearbyStops(latitude: 1, longitude: 1),
        throwsA(isA<ServerApiException>()),
      );
    });

    test('parses the lines serving a stop', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/linesByStop/512081'));
        return http.Response(
          '[{"lineId":282,"shortName":"P82","name":"TERMINAL CALIPSO"}]',
          200,
        );
      });

      final lines = await _datasource(client).getLinesByStop('512081');

      expect(lines, hasLength(1));
      expect(lines.first.shortName, 'P82');
    });

    test('retries transient failures once', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('Server Error', 500);
        return http.Response(_arrivalsBody, 200);
      });

      final stops = await _datasource(client)
          .getNearbyStops(latitude: 3.4516, longitude: -76.532);

      expect(calls, 2);
      expect(stops, hasLength(2));
    });

    test('places stops by trilaterating three distance readings', () async {
      // A stop 50 m north and 30 m east of the origin, seen from the
      // origin and from two vantage points 120 m away.
      const originLat = 3.4842;
      const originLon = -76.5134;
      const metresPerDegree = 111320.0;
      final lonScale = metresPerDegree * math.cos(originLat * math.pi / 180);

      String body(double distance) =>
          '[{"idParada":"1","nombreParada":"Target","distanciaMetros":'
          '$distance,"buses":[]}]';

      final client = MockClient((request) async {
        final lat = double.parse(request.url.queryParameters['latitud']!);
        final lon = double.parse(request.url.queryParameters['longitud']!);
        final vantageY = (lat - originLat) * metresPerDegree;
        final vantageX = (lon - originLon) * lonScale;
        final distance = math.sqrt(
          math.pow(30 - vantageX, 2) + math.pow(50 - vantageY, 2),
        );
        return http.Response(body(distance), 200);
      });

      final stops = await _datasource(client)
          .getLocatedStops(latitude: originLat, longitude: originLon);

      expect(stops, hasLength(1));
      final stop = stops.single;
      expect(stop.hasPosition, isTrue);
      expect(
        (stop.latitude! - originLat) * metresPerDegree,
        closeTo(50, 1),
      );
      expect((stop.longitude! - originLon) * lonScale, closeTo(30, 1));
    });

    test('keeps stops that only the first reading saw', () async {
      var call = 0;
      final client = MockClient((_) async {
        call++;
        // Only the origin sees the stop; the vantage points are empty.
        return http.Response(call == 1 ? _arrivalsBody : '[]', 200);
      });

      final stops = await _datasource(client)
          .getLocatedStops(latitude: 3.4516, longitude: -76.532);

      expect(stops, hasLength(2));
      expect(stops.every((s) => s.hasPosition), isFalse);
    });

    test('serves the station catalog from cache on the second call',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(_stationsBody, 200);
      });
      final cache = JsonCache();
      final datasource = _datasource(client, cache: cache);

      await datasource.getStations();
      final second = await datasource.getStations();

      expect(calls, 1);
      expect(second.single.name, 'Estación Alamos');
    });

    test('reuses a stop position instead of asking again', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        final lat = double.parse(request.url.queryParameters['latitud']!);
        final lon = double.parse(request.url.queryParameters['longitud']!);
        const originLat = 3.4842;
        const originLon = -76.5134;
        const metresPerDegree = 111320.0;
        final lonScale = metresPerDegree * math.cos(originLat * math.pi / 180);
        final vantageY = (lat - originLat) * metresPerDegree;
        final vantageX = (lon - originLon) * lonScale;
        final distance = math.sqrt(
          math.pow(30 - vantageX, 2) + math.pow(50 - vantageY, 2),
        );
        return http.Response(
          '[{"idParada":"1","nombreParada":"Target","distanciaMetros":'
          '$distance,"buses":[]}]',
          200,
        );
      });
      final cache = JsonCache();
      final datasource = _datasource(client, cache: cache);

      final first = await datasource.getLocatedStops(
        latitude: 3.4842,
        longitude: -76.5134,
      );
      expect(calls, 3);
      expect(first.single.hasPosition, isTrue);

      // The position is known now, so the vantage points are skipped.
      final second = await datasource.getLocatedStops(
        latitude: 3.4842,
        longitude: -76.5134,
      );
      expect(calls, 4);
      expect(second.single.hasPosition, isTrue);
    });

    test('parses the station catalog', () async {
      final client = MockClient((_) async => http.Response(_stationsBody, 200));

      final stations = await _datasource(client).getStations();

      expect(stations, hasLength(1));
      expect(stations.first.name, 'Estación Alamos');
      expect(stations.first.latitude, closeTo(3.484246, 0.000001));
    });

    test('counts minutes until arrival', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      final arrival = BusArrival(
        line: 'T31',
        destination: 'Universidades',
        arrivalTime: now.add(const Duration(seconds: 150)),
        vehicleId: '1001',
      );

      expect(arrival.minutesUntilArrival(now), 3);
      expect(
        BusArrival(
          line: 'T31',
          destination: 'Universidades',
          arrivalTime: now.subtract(const Duration(seconds: 30)),
          vehicleId: '1001',
        ).minutesUntilArrival(now),
        0,
      );
    });
  });
  group('FavoriteStop naming', () {
    const stop = FavoriteStop(
      id: '500800',
      stopId: '500800',
      name: 'Plaza de Cayzedo A1',
      anchorLatitude: 3.4516,
      anchorLongitude: -76.532,
    );

    test('shows the real name when there is no custom one', () {
      expect(stop.displayName, 'Plaza de Cayzedo A1');
      expect(stop.secondaryName, isNull);
    });

    test('shows the custom name with the real one behind it', () {
      final renamed = stop.copyWith(customName: 'Trabajo');

      expect(renamed.displayName, 'Trabajo');
      expect(renamed.secondaryName, 'Plaza de Cayzedo A1');
    });

    test('falls back to the real name when the custom one is cleared', () {
      final cleared =
          stop.copyWith(customName: 'Trabajo').copyWith(clearCustomName: true);

      expect(cleared.displayName, 'Plaza de Cayzedo A1');
      expect(cleared.secondaryName, isNull);
    });
  });

  group('StopsRemoteDatasource when the service pushes back', () {
    test('does not retry a rate limit, and rests before asking again',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('Too Many Requests', 429);
      });
      final datasource = _datasource(client);

      await expectLater(
        datasource.getNearbyStops(latitude: 3.45, longitude: -76.53),
        throwsA(isA<ServerApiException>()),
      );
      expect(calls, 1);

      await expectLater(
        datasource.getNearbyStops(latitude: 3.45, longitude: -76.53),
        throwsA(same(ServiceGuard.resting)),
      );
      expect(calls, 1);
    });

    test('an offline device is not taken for a push back', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        throw http.ClientException('Network is unreachable');
      });
      final datasource = _datasource(client);

      for (var i = 0; i < 2; i++) {
        await expectLater(
          datasource.getNearbyStops(latitude: 3.45, longitude: -76.53),
          throwsA(isA<NetworkApiException>()),
        );
      }
      // Two attempts per call, and the second call still went out
      expect(calls, 4);
    });
  });

  group('ServiceGuard', () {
    test('doubles the wait with each push back in a row, up to a cap', () {
      var now = DateTime(2026, 9, 28, 12);
      final guard = ServiceGuard(now: () => now);

      Duration waitAfterPushBack() {
        guard.pushedBack();
        var wait = Duration.zero;
        while (true) {
          try {
            guard.check();
            return wait;
          } on RateLimitApiException {
            now = now.add(const Duration(minutes: 1));
            wait += const Duration(minutes: 1);
          }
        }
      }

      expect(
        [for (var i = 0; i < 6; i++) waitAfterPushBack().inMinutes],
        [1, 2, 4, 8, 16, 16],
      );
    });

    test('an answer clears the wait at once', () {
      final guard = ServiceGuard()..pushedBack();
      expect(guard.check, throwsA(isA<RateLimitApiException>()));

      guard.answered();
      expect(guard.check, returnsNormally);
    });
  });

  test('asking for the same point twice at once sends one request',
      () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return http.Response(_arrivalsBody, 200);
    });
    final datasource = _datasource(client);

    final answers = await Future.wait([
      datasource.getNearbyStops(latitude: 3.45, longitude: -76.53),
      datasource.getNearbyStops(latitude: 3.45, longitude: -76.53),
    ]);

    expect(calls, 1);
    expect(answers[1].map((s) => s.id), answers[0].map((s) => s.id));
  });

  test('hands over the stop list before placing the stops', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(_arrivalsBody, 200);
    });

    final first = await _datasource(client)
        .locatedStops(latitude: 3.4516, longitude: -76.532)
        .first;

    // Only the request around the point itself was needed for the list
    expect(calls, 1);
    expect(first.map((s) => s.id), ['500800', '500751']);
  });

  group('Line lookup', () {
    MockClient serving(Map<String, String> bodies) => MockClient((request) async {
          for (final entry in bodies.entries) {
            if (request.url.path.endsWith(entry.key)) {
              return http.Response(entry.value, 200);
            }
          }
          return http.Response('Not Found', 404);
        });

    test('reads the lines sorted by name', () async {
      final lines = await _datasource(serving({
        '/lines': '[{"lineId":347,"name":"A47"},{"lineId":152,"name":"T52"},'
            '{"lineId":302,"name":"A02"}]',
      })).getLines();

      expect(lines.map((l) => l.name), ['A02', 'A47', 'T52']);
      expect(lines.first.id, 302);
    });

    test('reads a route in order, each direction apart', () async {
      final stops = await _datasource(serving({
        '/linestops/A47': '['
            '{"orientation":"1","stopSequence":1,"stopId":"9","stopNam":"Back",'
            '"longitude":-76.47,"latitude":3.41},'
            '{"orientation":"0","stopSequence":2,"stopId":"514484",'
            '"stopNam":"Tv 103 con Kr 28F","longitude":-76.4798,'
            '"latitude":3.4109},'
            '{"orientation":"0","stopSequence":1,"stopId":"504107",'
            '"stopNam":"Aguablanca B3","longitude":-76.4812,"latitude":3.4141}]',
      })).getLineStops('A47');

      expect(stops.map((s) => (s.direction, s.sequence, s.stopId)), [
        (0, 1, '504107'),
        (0, 2, '514484'),
        (1, 1, '9'),
      ]);
      expect(stops.first.name, 'Aguablanca B3');
    });

    test('places the buses from their scaled GPS readings', () async {
      final buses = await _datasource(serving({
        '/operations/A47':
            '[{"busNumber":32051,"gpsx":-7.6473702E8,"gpsy":3.4096152E7}]',
      })).getLineBuses('A47');

      expect(buses.single.busNumber, '32051');
      expect(buses.single.latitude, closeTo(3.4096152, 1e-9));
      expect(buses.single.longitude, closeTo(-76.473702, 1e-9));
    });

    test('gives each bus the direction of its trip, asking once per bus',
        () async {
      var infoCalls = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/operations/A47')) {
          return http.Response(
            '[{"busNumber":32051,"gpsx":-7.648E8,"gpsy":3.441E7},'
            '{"busNumber":12081,"gpsx":-7.646E8,"gpsy":3.425E7}]',
            200,
          );
        }
        if (path.contains('/busInfo/')) {
          infoCalls++;
          final bus = path.split('/').last;
          final orientation = bus == '32051' ? '1' : '0';
          return http.Response(
            '[{"busNumber":$bus,"line":"A47","orientation":"$orientation"}]',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      final datasource = _datasource(client);

      final buses = await datasource.getLineBuses('A47');
      await datasource.getLineBuses('A47');

      expect(
        {for (final b in buses) b.busNumber: b.direction},
        {'32051': 1, '12081': 0},
      );
      // The second round found both directions still fresh
      expect(infoCalls, 2);
    });

    test('reads the hours of each line', () async {
      final hours = await _datasource(serving({
        '/linesOperation': '[{"line":"A12A","startTime":"04:23:00",'
            '"endTime":"00:19:00"}]',
      })).getLineHours();

      expect(hours['A12A']!.start, const Duration(hours: 4, minutes: 23));
      expect(hours['A12A']!.end, const Duration(minutes: 19));
    });

    test('a line running past midnight still runs just before its end', () {
      const late = LineHours(
        start: Duration(hours: 4, minutes: 23),
        end: Duration(minutes: 19),
      );

      expect(late.runsAt(DateTime(2026, 9, 28, 0, 10)), isTrue);
      expect(late.runsAt(DateTime(2026, 9, 28, 23, 50)), isTrue);
      expect(late.runsAt(DateTime(2026, 9, 28, 2, 0)), isFalse);
    });
  });

  group('Arrivals for a trip', () {
    LineStop stop(String id, double lat, double lon) => LineStop(
      stopId: id,
      name: id,
      latitude: lat,
      longitude: lon,
      direction: 0,
      sequence: 1,
    );

    test('asks once for stops close together, then reuses it', () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return http.Response(_arrivalsBody, 200);
      });
      final datasource = _datasource(client);
      // About 100 m apart, and a third one 2 km away
      final stops = [
        stop('500800', 3.4516, -76.5320),
        stop('500751', 3.4525, -76.5320),
        stop('far', 3.4700, -76.5320),
      ];

      final first = await datasource.arrivalsFor(stops);
      expect(requests, 2);
      expect(first.stops.map((s) => s.id), contains('500800'));

      await datasource.arrivalsFor(stops.take(2).toList());
      expect(requests, 2);

      await datasource.arrivalsFor(
        stops.take(2).toList(),
        maxAge: Duration.zero,
      );
      expect(requests, 3);
    });

    test('says so when an area cannot be asked about', () async {
      final client = MockClient((request) async => http.Response('', 500));
      final live = await _datasource(
        client,
      ).arrivalsFor([stop('500800', 3.4516, -76.5320)]);

      expect(live.stops, isEmpty);
      expect(live.failed, isTrue);
    });

    test('asks once between two stops too far apart to answer for each other',
        () async {
      final asked = <(double, double)>[];
      final client = MockClient((request) async {
        asked.add((
          double.parse(request.url.queryParameters['latitud']!),
          double.parse(request.url.queryParameters['longitud']!),
        ));
        return http.Response('[]', 200);
      });

      // About 450 m apart: each is out of the other's reach, not the middle's
      await _datasource(client).arrivalsFor([
        stop('a', 3.4500, -76.5320),
        stop('b', 3.4540, -76.5320),
      ]);

      expect(asked, hasLength(1));
      expect(asked.single.$1, closeTo(3.4520, 1e-9));
    });

    test('learns how often each line comes from the arrivals seen', () async {
      final memory = HeadwayMemory(JsonCache.noop());
      final now = DateTime(2026, 9, 29, 8, 15);
      BusArrival bus(int minutes) => BusArrival(
        line: 'T50',
        destination: 'Andres Sanin',
        arrivalTime: now.add(Duration(minutes: minutes)),
        vehicleId: 'v$minutes',
      );

      await memory.observe([
        NearbyStop(
          id: 's',
          name: 'Aguablanca B4',
          distanceMeters: 0,
          arrivals: [bus(1), bus(10), bus(19), bus(28)],
        ),
      ], now);

      expect((await memory.at(now))['T50'], const Duration(minutes: 9));
      // An hour later still counts; a quiet night hour does not
      expect((await memory.at(now.add(const Duration(hours: 1))))['T50'],
          const Duration(minutes: 9));
      expect((await memory.at(now.add(const Duration(hours: 12))))['T50'],
          isNull);
    });
  });

  group('Catalog kept offline', () {
    test('an old copy answers when the catalog cannot be reached', () async {
      final cache = _OldCache({
        'lines_hours': [
          {'line': 'A12A', 'startTime': '04:23:00', 'endTime': '00:19:00'},
        ],
      });
      final client = MockClient(
        (_) async => throw http.ClientException('Network is unreachable'),
      );

      final hours = await _datasource(client, cache: cache).getLineHours();

      expect(hours.keys, ['A12A']);
    });

    test('an old route answers at once, and a new one comes behind it',
        () async {
      String route(String name) =>
          '[{"orientation":"0","stopSequence":1,"stopId":"1",'
          '"stopNam":"$name","longitude":-76.53,"latitude":3.45}]';
      final cache = _OldCache({'linestops_A47': jsonDecode(route('Old'))});
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response(route('New'), 200);
      });
      final datasource = _datasource(client, cache: cache);

      final stops = await datasource.getLineStops('A47', staleOk: true);
      expect(stops.single.name, 'Old');

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(requests, 1);
      expect((await datasource.getLineStops('A47')).single.name, 'New');
      expect(requests, 1);
    });
  });

  test('places the stops from the routes, asking around no further',
      () async {
    var arrivalsRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/linestops/E21')) {
        return http.Response(
          '[{"orientation":"0","stopSequence":1,"stopId":"500800",'
          '"stopNam":"Plaza de Cayzedo A1","longitude":-76.5331,'
          '"latitude":3.4513},'
          '{"orientation":"0","stopSequence":2,"stopId":"500751",'
          '"stopNam":"La Ermita A2","longitude":-76.5310,"latitude":3.4531}]',
          200,
        );
      }
      arrivalsRequests++;
      return http.Response(_arrivalsBody, 200);
    });
    final datasource = _datasource(client);
    await datasource.getLineStops('E21');

    final stops = await datasource.getLocatedStops(
      latitude: 3.4516,
      longitude: -76.532,
    );

    expect(arrivalsRequests, 1);
    expect(stops.first.latitude, 3.4513);
    expect(stops.last.longitude, -76.5310);
  });

  test('adds a line the catalog leaves out once it is seen running',
      () async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/lines')) {
        return http.Response('[{"lineId":131,"name":"T31"}]', 200);
      }
      if (path.endsWith('/linesOperation')) {
        return http.Response(
          '[{"line":"T31","startTime":"04:30:00","endTime":"23:00:00"},'
          '{"line":"A52","startTime":"05:00:00","endTime":"20:09:00"},'
          '{"line":"E51","startTime":"05:00:00","endTime":"20:55:00"}]',
          200,
        );
      }
      return http.Response(
        '[{"idParada":"1","nombreParada":"Stop","distanciaMetros":10,'
        '"buses":[{"nombreLinea":"A52","nombreDestino":"Terminal",'
        '"tiempoEstimadoDeSalida":1787429222000,"vehiculoId":"9"}]}]',
        200,
      );
    });
    final datasource = _datasource(client);

    expect((await datasource.getLines()).map((l) => l.name), ['T31']);

    await datasource.getNearbyStops(latitude: 3.45, longitude: -76.53);
    // The arrivals teach what they show in the background
    await Future<void>.delayed(Duration.zero);

    // E51 has hours too, but nothing shows it running
    expect(
      (await datasource.getLines()).map((l) => l.name),
      ['A52', 'T31'],
    );
  });

  test('asks a bus its direction again only as it nears its trip end',
      () async {
    var clock = DateTime(2026, 9, 29, 12);
    final asked = <String>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/linestops/A47')) {
        // One direction, north from 3.40 to its last stop at 3.44
        return http.Response(
          '[{"orientation":"0","stopSequence":1,"stopId":"s",'
          '"stopNam":"Start","longitude":-76.53,"latitude":3.40},'
          '{"orientation":"0","stopSequence":2,"stopId":"e",'
          '"stopNam":"End","longitude":-76.53,"latitude":3.44}]',
          200,
        );
      }
      if (path.endsWith('/operations/A47')) {
        // Bus 1 is 200 m from the last stop, bus 2 four kilometres
        return http.Response(
          '[{"busNumber":1,"gpsx":-7.653E8,"gpsy":3.4382E7},'
          '{"busNumber":2,"gpsx":-7.653E8,"gpsy":3.40E7}]',
          200,
        );
      }
      if (path.contains('/busInfo/')) {
        final bus = path.split('/').last;
        asked.add(bus);
        return http.Response(
          '[{"busNumber":$bus,"line":"A47","orientation":"0"}]',
          200,
        );
      }
      return http.Response('Not Found', 404);
    });
    final datasource = StopsRemoteDatasource(
      client: client,
      backoff: Duration.zero,
      cache: JsonCache.noop(),
      now: () => clock,
    );

    await datasource.getLineBuses('A47');
    expect(asked, unorderedEquals(['1', '2']));

    clock = clock.add(const Duration(minutes: 3));
    asked.clear();
    await datasource.getLineBuses('A47');
    expect(asked, ['1']);

    clock = clock.add(const Duration(minutes: 43));
    asked.clear();
    await datasource.getLineBuses('A47');
    expect(asked, unorderedEquals(['1', '2']));
  });

  group('Learned per line', () {
    test('a line seen coming is known for a while', () async {
      final memory = HeadwayMemory(JsonCache.noop());
      final now = DateTime(2026, 9, 29, 8);

      await memory.observe([
        NearbyStop(
          id: 's',
          name: 'Stop',
          distanceMeters: 0,
          arrivals: [
            BusArrival(
              line: 'A52',
              destination: 'Terminal',
              arrivalTime: now,
              vehicleId: '1',
            ),
          ],
        ),
      ], now);

      expect(
        await memory.seenSince(now.subtract(const Duration(days: 14))),
        {'A52'},
      );
      expect(await memory.seenSince(now.add(const Duration(days: 1))), isEmpty);
    });

    test('a ride factor moves a share of the way to each reading', () async {
      final memory = RideTimeMemory(JsonCache.noop());

      await memory.observe({'T31': 1.5, 'A12A': 3.0});
      final factors = await memory.factors();

      expect(factors['T31'], closeTo(1.1, 1e-9));
      // Three times the estimate is a bus held at a terminal, not the line
      expect(factors.containsKey('A12A'), isFalse);
    });

    test('the same ride read again settles on its reading', () async {
      final memory = RideTimeMemory(JsonCache.noop());

      for (var i = 0; i < 30; i++) {
        await memory.observe({'T31': 1.5});
      }

      expect((await memory.factors())['T31'], closeTo(1.5, 0.01));
      expect((await memory.factors())['T31'], lessThanOrEqualTo(1.5));
    });
  });
}

/// Cache holding copies saved long ago, as a week offline leaves them
class _OldCache extends JsonCache {
  final Map<String, Object?> old;
  final Map<String, Object?> written = {};

  _OldCache(this.old);

  @override
  Future<({DateTime savedAt, Object? value})?> readEntry(
    String key, {
    bool remember = true,
  }) async {
    if (written.containsKey(key)) {
      return (savedAt: DateTime.now(), value: written[key]);
    }
    if (old.containsKey(key)) {
      return (savedAt: DateTime(2020), value: old[key]);
    }
    return null;
  }

  @override
  Future<void> write(String key, Object? value, {bool remember = true}) async =>
      written[key] = value;
}
