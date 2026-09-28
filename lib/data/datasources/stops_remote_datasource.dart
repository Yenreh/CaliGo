import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../domain/entities/line_entity.dart';
import '../../domain/entities/stop_entity.dart';
import 'api_exception.dart';
import 'json_cache.dart';
import 'service_guard.dart';

/// Remote data source for stops, arrivals and the station catalog.
class StopsRemoteDatasource {
  static const String _arrivalsUrl =
      'https://servicios.siur.com.co/buscarutas/api/paradas_con_buses_proximos_a_llegar.php';
  static const String _stationsUrl =
      'https://wsmio.siur.com.co:8083/apiMIO/jaxrs/stations';
  static const String _linesByStopUrl =
      'https://wsmio.siur.com.co:8083/apiMIO/jaxrs/linesByStop';
  static const String _linesUrl =
      'https://wsmio.siur.com.co:8083/apiMIO/jaxrs/lines';
  static const String _lineStopsUrl =
      'https://wsmio.siur.com.co:8083/apiMIO/jaxrs/linestops';
  static const String _lineBusesUrl =
      'https://wsmio.siur.com.co:8083/apiMIO/jaxrs/operations';
  static const String _lineHoursUrl =
      'https://wsmio.siur.com.co:8083/apiMIO/jaxrs/linesOperation';
  static const String _busInfoUrl =
      'https://wsmio.siur.com.co:8083/apiMIO/jaxrs/busInfo';

  /// A trip keeps its direction for longer than this, so a bus is asked
  /// about again only after it, one bus per request being all the
  /// service takes
  static const Duration _busDirectionMaxAge = Duration(minutes: 10);

  /// Routes change a few times a year, and the hours with them
  static const Duration _routesMaxAge = Duration(days: 7);
  static const Duration _hoursMaxAge = Duration(days: 1);

  /// The service sends bus positions as degrees times ten million
  static const double _gpsScale = 1e7;

  /// The arrivals service rejects anything above this radius.
  static const int maxRadiusMeters = 300;

  static const Duration _requestTimeout = Duration(seconds: 10);
  static const int _maxAttempts = 2;

  /// The catalog changes a few times a year at most
  static const Duration _stationsMaxAge = Duration(days: 7);

  /// Which lines serve a stop is stable too
  static const Duration _linesMaxAge = Duration(days: 30);

  static const String _positionsKey = 'stop_positions';

  /// Cali has a bit over a thousand stops, so this holds every one the
  /// user could plausibly meet while never growing without end.
  static const int _maxStoredPositions = 1500;

  /// Files nobody has read in this long are swept once per run
  static const Duration _cacheLifetime = Duration(days: 45);

  static bool _pruned = false;

  final http.Client _client;
  final Duration _backoff;
  final JsonCache _cache;

  /// The arrivals and the catalog come from different servers, each left
  /// alone on its own when it pushes back
  final ServiceGuard _arrivalsGuard;
  final ServiceGuard _catalogGuard;

  /// Direction of each bus's current trip, by bus number
  final Map<String, ({int? direction, String line, DateTime at})>
      _busDirections = {};

  /// Requests on their way, so asking for the same point twice at once
  /// shares one answer instead of sending two
  final Map<String, Future<dynamic>> _inFlight = {};

  /// Stop positions worked out earlier: a stop never moves, so they are
  /// kept for good and spare the extra lookups.
  Map<String, List<double>>? _positions;

  StopsRemoteDatasource({
    http.Client? client,
    Duration backoff = const Duration(milliseconds: 600),
    JsonCache? cache,
    ServiceGuard? arrivalsGuard,
    ServiceGuard? catalogGuard,
  })  : _client = client ?? http.Client(),
        _backoff = backoff,
        _cache = cache ?? JsonCache(),
        _arrivalsGuard = arrivalsGuard ?? ServiceGuard(),
        _catalogGuard = catalogGuard ?? ServiceGuard() {
    if (!_pruned) {
      _pruned = true;
      unawaited(_cache.prune(maxAge: _cacheLifetime));
    }
  }

  /// Stops within [radiusMeters] of a position, each with its next buses.
  Future<List<NearbyStop>> getNearbyStops({
    required double latitude,
    required double longitude,
    int radiusMeters = maxRadiusMeters,
  }) async {
    final radius =
        radiusMeters > maxRadiusMeters ? maxRadiusMeters : radiusMeters;
    final uri = Uri.parse(
      '$_arrivalsUrl?latitud=$latitude&longitud=$longitude&radio=$radius',
    );

    final decoded = await _getJson(uri, _arrivalsGuard);

    if (decoded is Map && decoded['error'] != null) {
      throw ServerApiException('Arrivals service: ${decoded['error']}');
    }
    if (decoded is! List) {
      throw const ServerApiException('Unexpected arrivals response');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_parseStop)
        .toList(growable: false);
  }

  /// The full MIO station catalog, used to add favorites without GPS.
  Future<List<Station>> getStations() async {
    var decoded = await _cache.read('stations', maxAge: _stationsMaxAge);
    if (decoded == null) {
      decoded = await _getJson(Uri.parse(_stationsUrl), _catalogGuard);
      if (decoded is List) await _cache.write('stations', decoded);
    }

    if (decoded is! List) {
      throw const ServerApiException('Unexpected stations response');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .where((s) => s['latitude'] is num && s['longitude'] is num)
        .map(
          (s) => Station(
            id: (s['id'] as num).toInt(),
            name: s['name']?.toString() ?? '',
            address: s['address']?.toString() ?? '',
            latitude: (s['latitude'] as num).toDouble(),
            longitude: (s['longitude'] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  /// Stops around a point, each placed on the map when possible: first as
  /// soon as the service answers, then again once they are placed.
  ///
  /// The service reports how far a stop is but never where it is, so the
  /// same area is queried from two extra vantage points and each stop is
  /// trilaterated from the three distances. Stops that fall out of range
  /// of the extra points simply come back without a position.
  Stream<List<NearbyStop>> locatedStops({
    required double latitude,
    required double longitude,
  }) async* {
    const offset = 120.0;
    final lonScale = _metresPerDegree * cos(latitude * pi / 180);

    final origin = await getNearbyStops(
      latitude: latitude,
      longitude: longitude,
    );

    final known = await _knownPositions();
    final placed = [
      for (final stop in origin)
        if (known[stop.id] case final position?)
          stop.withPosition(position[0], position[1])
        else
          stop,
    ];
    // The list is useful before the stops are placed: hand it over now
    yield placed;
    // Every stop here has been placed before: no extra requests needed.
    if (placed.every((s) => s.hasPosition)) return;

    final List<List<NearbyStop>> extras;
    try {
      extras = await Future.wait([
        getNearbyStops(
          latitude: latitude + offset / _metresPerDegree,
          longitude: longitude,
        ),
        getNearbyStops(
          latitude: latitude,
          longitude: longitude + offset / lonScale,
        ),
      ]);
    } on ApiException {
      // Placing the stops is a bonus: the list already went out.
      return;
    }

    final north = {for (final s in extras[0]) s.id: s.distanceMeters};
    final east = {for (final s in extras[1]) s.id: s.distanceMeters};

    final located = placed.map((stop) {
      if (stop.hasPosition) return stop;

      final dNorth = north[stop.id];
      final dEast = east[stop.id];
      if (dNorth == null || dEast == null) return stop;

      final point = _trilaterate(
        [
          (x: 0.0, y: 0.0, d: stop.distanceMeters),
          (x: 0.0, y: offset, d: dNorth),
          (x: offset, y: 0.0, d: dEast),
        ],
      );
      if (point == null) return stop;

      return stop.withPosition(
        latitude + point.y / _metresPerDegree,
        longitude + point.x / lonScale,
      );
    }).toList(growable: false);

    await _rememberPositions(located);
    yield located;
  }

  /// [locatedStops] once every stop that can be placed is
  Future<List<NearbyStop>> getLocatedStops({
    required double latitude,
    required double longitude,
  }) =>
      locatedStops(latitude: latitude, longitude: longitude).last;

  Future<Map<String, List<double>>> _knownPositions() async {
    if (_positions != null) return _positions!;

    final cached = await _cache.read(_positionsKey);
    _positions = {
      if (cached is Map)
        for (final entry in cached.entries)
          if (entry.value is List && (entry.value as List).length == 2)
            entry.key.toString(): [
              (entry.value as List)[0] as double,
              (entry.value as List)[1] as double,
            ],
    };
    return _positions!;
  }

  Future<void> _rememberPositions(List<NearbyStop> stops) async {
    final positions = await _knownPositions();
    var added = false;

    for (final stop in stops) {
      if (!stop.hasPosition || positions.containsKey(stop.id)) continue;
      positions[stop.id] = [stop.latitude!, stop.longitude!];
      added = true;
    }

    if (!added) return;

    while (positions.length > _maxStoredPositions) {
      positions.remove(positions.keys.first);
    }
    await _cache.write(_positionsKey, positions);
  }

  /// Metres per degree of latitude, close enough over a few hundred metres
  static const double _metresPerDegree = 111320.0;

  /// Intersect three distance circles in a local metric frame
  ({double x, double y})? _trilaterate(
    List<({double x, double y, double d})> readings,
  ) {
    final (p1, p2, p3) = (readings[0], readings[1], readings[2]);

    final a = 2 * (p2.x - p1.x);
    final b = 2 * (p2.y - p1.y);
    final c = p1.d * p1.d -
        p2.d * p2.d -
        p1.x * p1.x +
        p2.x * p2.x -
        p1.y * p1.y +
        p2.y * p2.y;
    final d = 2 * (p3.x - p2.x);
    final e = 2 * (p3.y - p2.y);
    final f = p2.d * p2.d -
        p3.d * p3.d -
        p2.x * p2.x +
        p3.x * p3.x -
        p2.y * p2.y +
        p3.y * p3.y;

    final denominator = a * e - d * b;
    if (denominator.abs() < 1e-9) return null;

    return (
      x: (c * e - f * b) / denominator,
      y: (a * f - d * c) / denominator,
    );
  }

  /// Lines serving a stop, useful when no bus is on its way
  Future<List<StopLine>> getLinesByStop(String stopId) async {
    final key = 'lines_$stopId';
    var decoded = await _cache.read(key, maxAge: _linesMaxAge);
    if (decoded == null) {
      decoded = await _getJson(
        Uri.parse('$_linesByStopUrl/$stopId'),
        _catalogGuard,
      );
      if (decoded is List) await _cache.write(key, decoded);
    }

    if (decoded is! List) {
      throw const ServerApiException('Unexpected lines response');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(
          (l) => StopLine(
            shortName: l['shortName']?.toString() ?? '',
            name: l['name']?.toString() ?? '',
          ),
        )
        .where((l) => l.shortName.isNotEmpty)
        .toList(growable: false);
  }

  /// Every MIO line, sorted by name
  Future<List<TransitLine>> getLines() async {
    final decoded = await _cachedJson('lines', _linesUrl, _routesMaxAge);
    return decoded
        .whereType<Map<String, dynamic>>()
        .where((l) => l['lineId'] is num && l['name'] is String)
        .map(
          (l) => TransitLine(
            id: (l['lineId'] as num).toInt(),
            name: l['name'] as String,
          ),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// The stops of [line] in route order, both directions
  Future<List<LineStop>> getLineStops(String line) async {
    final decoded = await _cachedJson(
      'linestops_$line',
      '$_lineStopsUrl/${Uri.encodeComponent(line)}',
      _routesMaxAge,
    );
    return decoded
        .whereType<Map<String, dynamic>>()
        .where((s) => s['latitude'] is num && s['longitude'] is num)
        .map(
          (s) => LineStop(
            stopId: s['stopId']?.toString() ?? '',
            // The service does spell it "stopNam"
            name: (s['stopNam'] ?? s['stopName'])?.toString() ?? '',
            latitude: (s['latitude'] as num).toDouble(),
            longitude: (s['longitude'] as num).toDouble(),
            direction: int.tryParse(s['orientation']?.toString() ?? '') ?? 0,
            sequence: (s['stopSequence'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => a.direction != b.direction
          ? a.direction.compareTo(b.direction)
          : a.sequence.compareTo(b.sequence));
  }

  /// Buses running on [line] right now, each with the direction of its
  /// trip. The positions are never cached; the directions are, briefly.
  Future<List<LineBus>> getLineBuses(String line) async {
    final buses = await _lineBusPositions(line);
    final now = DateTime.now();

    final stale = [
      for (final bus in buses)
        if (_busDirections[bus.busNumber] case final known
            when known == null ||
                known.line != line ||
                now.difference(known.at) > _busDirectionMaxAge)
          bus.busNumber,
    ];
    for (var i = 0; i < stale.length; i += 4) {
      await Future.wait(stale.skip(i).take(4).map(_learnBusDirection));
    }

    return [
      for (final bus in buses)
        bus.withDirection(
          _busDirections[bus.busNumber]?.line == line
              ? _busDirections[bus.busNumber]!.direction
              : null,
        ),
    ];
  }

  /// Ask the service which way a bus's trip runs. A failure leaves the
  /// direction unknown rather than failing the whole line.
  Future<void> _learnBusDirection(String busNumber) async {
    try {
      final decoded = await _getJson(
        Uri.parse('$_busInfoUrl/${Uri.encodeComponent(busNumber)}'),
        _catalogGuard,
      );
      final info = decoded is List && decoded.isNotEmpty ? decoded.first : null;
      if (info is! Map) return;
      _busDirections[busNumber] = (
        direction: int.tryParse(info['orientation']?.toString() ?? ''),
        line: info['line']?.toString() ?? '',
        at: DateTime.now(),
      );
    } on ApiException {
      // Shown without a direction; asked again on the next round
    }
  }

  Future<List<LineBus>> _lineBusPositions(String line) async {
    final decoded = await _getJson(
      Uri.parse('$_lineBusesUrl/${Uri.encodeComponent(line)}'),
      _catalogGuard,
    );
    if (decoded is! List) {
      throw const ServerApiException('Unexpected buses response');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .where((b) => b['gpsx'] is num && b['gpsy'] is num)
        .map(
          (b) => LineBus(
            busNumber: b['busNumber']?.toString() ?? '',
            latitude: (b['gpsy'] as num) / _gpsScale,
            longitude: (b['gpsx'] as num) / _gpsScale,
          ),
        )
        .toList(growable: false);
  }

  /// Hours each line runs, by line name
  Future<Map<String, LineHours>> getLineHours() async {
    final decoded = await _cachedJson('lines_hours', _lineHoursUrl, _hoursMaxAge);
    return {
      for (final l in decoded.whereType<Map<String, dynamic>>())
        if (l['line'] is String)
          if ((
            LineHours.parseTime(l['startTime']),
            LineHours.parseTime(l['endTime']),
          )
              case (final start?, final end?))
            l['line'] as String: LineHours(start: start, end: end),
    };
  }

  /// A list from the catalog server, from the cache while it is fresh
  Future<List> _cachedJson(String key, String url, Duration maxAge) async {
    var decoded = await _cache.read(key, maxAge: maxAge);
    if (decoded == null) {
      decoded = await _getJson(Uri.parse(url), _catalogGuard);
      if (decoded is List) await _cache.write(key, decoded);
    }
    if (decoded is! List) {
      throw const ServerApiException('Unexpected catalog response');
    }
    return decoded;
  }

  NearbyStop _parseStop(Map<String, dynamic> json) {
    final buses = json['buses'];
    final stopName = json['nombreParada']?.toString() ?? '';
    return NearbyStop(
      id: json['idParada']?.toString() ?? '',
      name: stopName,
      distanceMeters: (json['distanciaMetros'] as num?)?.toDouble() ?? 0,
      arrivals: buses is List
          ? buses
              .whereType<Map<String, dynamic>>()
              .where((b) => b['tiempoEstimadoDeSalida'] is num)
              .map(
                (b) => BusArrival(
                  line: b['nombreLinea']?.toString() ?? '',
                  destination: b['nombreDestino']?.toString() ?? '',
                  arrivalTime: DateTime.fromMillisecondsSinceEpoch(
                    (b['tiempoEstimadoDeSalida'] as num).toInt(),
                  ),
                  vehicleId: b['vehiculoId']?.toString() ?? '',
                  stopName: stopName,
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }

  /// GET [uri] and decode its JSON body, unless [guard] says the server
  /// asked to be left alone; a server that pushes back arms it.
  Future<dynamic> _getJson(Uri uri, ServiceGuard guard) {
    final key = uri.toString();
    // The callback must not return the removed future: whenComplete would
    // wait on it, and so on itself
    return _inFlight[key] ??= _getJsonGuarded(uri, guard).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<dynamic> _getJsonGuarded(Uri uri, ServiceGuard guard) async {
    guard.check();
    try {
      final decoded = await _getJsonWithRetry(uri);
      guard.answered();
      return decoded;
    } on ApiException catch (e) {
      if (ServiceGuard.isPushBack(e)) guard.pushedBack();
      rethrow;
    }
  }

  /// GET [uri] and decode its JSON body, retrying transient failures once.
  /// A rate limit is not retried: asking again at once only prolongs it.
  Future<dynamic> _getJsonWithRetry(Uri uri) async {
    ApiException? lastError;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_backoff);
      try {
        final http.Response response;
        try {
          response = await _client.get(uri).timeout(_requestTimeout);
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

        try {
          return json.decode(response.body);
        } on FormatException {
          throw const ServerApiException('Unexpected response format');
        }
      } on ApiException catch (e) {
        if (!e.isRetryable) rethrow;
        lastError = e;
      }
    }

    throw lastError!;
  }
}
