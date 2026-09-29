import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../domain/arrival_areas.dart';
import '../../domain/entities/line_entity.dart';
import '../../domain/entities/stop_entity.dart';
import '../../domain/entities/trip_entity.dart';
import '../../domain/trip_timing.dart';
import 'api_exception.dart';
import 'headway_memory.dart';
import 'json_cache.dart';
import 'ride_time_memory.dart';
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

  /// A bus keeps the direction of its trip until it turns around at the
  /// trip's last stop, and the service takes one bus per request: far
  /// from that stop the direction is asked again only now and then, near
  /// it every couple of minutes. Without the route to tell, every ten.
  static const Duration _directionFarMaxAge = Duration(minutes: 45);
  static const Duration _directionNearMaxAge = Duration(minutes: 2);
  static const Duration _busDirectionMaxAge = Duration(minutes: 10);
  static const double _nearTripEndMeters = 400;

  /// Routes change a few times a year, and the hours with them
  static const Duration _routesMaxAge = Duration(days: 7);
  static const Duration _hoursMaxAge = Duration(days: 1);

  /// A line the catalog leaves out is taken as running when the arrivals
  /// showed it this recently
  static const Duration _seenLately = Duration(days: 14);

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

  /// The routes place a bit over two thousand stops, so this holds every
  /// one the user could plausibly meet while never growing without end.
  static const int _maxStoredPositions = 4000;

  /// Files nobody has read in this long are swept once per run
  static const Duration _cacheLifetime = Duration(days: 45);

  /// Old catalog copies fetched again in the background at once: a
  /// week-old route still plans fine, and the service is shared
  static const int _refreshAtOnce = 2;

  static bool _pruned = false;

  final http.Client _client;
  final Duration _backoff;
  final JsonCache _cache;
  final HeadwayMemory _headways;
  final RideTimeMemory _rides;
  final DateTime Function() _now;

  /// Recent answers of the arrivals service, by the point asked around,
  /// so a stop inside one asked about a moment ago needs no new request
  final List<_Area> _recentAreas = [];
  static const int _maxRecentAreas = 24;

  /// The arrivals and the catalog come from different servers, each left
  /// alone on its own when it pushes back
  final ServiceGuard _arrivalsGuard;
  final ServiceGuard _catalogGuard;

  /// Direction of each bus's current trip, by bus number
  final Map<String, ({int? direction, String line, DateTime at})>
      _busDirections = {};

  /// Last stop of each direction of a line, where its trips end, by line
  final Map<String, Map<int, GeoPoint>> _tripEnds = {};

  /// Requests on their way, so asking for the same point twice at once
  /// shares one answer instead of sending two
  final Map<String, Future<dynamic>> _inFlight = {};

  /// Old catalog copies waiting to be fetched again, and those on their
  /// way, by cache key
  final Map<String, ({String url, bool remember})> _toRefresh = {};
  final Set<String> _refreshing = {};

  /// Stop positions, from the routes or worked out earlier: a stop never
  /// moves, so they are kept for good and spare the extra lookups.
  Future<Map<String, List<double>>>? _positions;
  bool _positionsSavePending = false;

  StopsRemoteDatasource({
    http.Client? client,
    Duration backoff = const Duration(milliseconds: 600),
    JsonCache? cache,
    ServiceGuard? arrivalsGuard,
    ServiceGuard? catalogGuard,
    HeadwayMemory? headways,
    RideTimeMemory? rides,
    DateTime Function()? now,
  })  : _client = client ?? http.Client(),
        _backoff = backoff,
        _cache = cache ?? JsonCache(),
        _headways = headways ?? HeadwayMemory(cache ?? JsonCache()),
        _rides = rides ?? RideTimeMemory(cache ?? JsonCache()),
        _now = now ?? DateTime.now,
        _arrivalsGuard = arrivalsGuard ?? ServiceGuard(),
        _catalogGuard = catalogGuard ?? ServiceGuard() {
    if (!_pruned) {
      _pruned = true;
      unawaited(_cache.prune(maxAge: _cacheLifetime));
    }
  }

  /// Stops within [radiusMeters] of a position, each with its next buses,
  /// and placed on the map when its place is known.
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

    final known = await _knownPositions();
    final stops = [
      for (final json in decoded.whereType<Map<String, dynamic>>())
        _placed(_parseStop(json), known),
    ];

    // Whoever asked, the answer also serves trips planned nearby and
    // teaches how often each line comes
    final now = DateTime.now();
    if (radius == maxRadiusMeters) {
      _recentAreas.add(
        (latitude: latitude, longitude: longitude, at: now, stops: stops),
      );
      if (_recentAreas.length > _maxRecentAreas) _recentAreas.removeAt(0);
    }
    unawaited(_headways.observe(stops, now));
    return stops;
  }

  static NearbyStop _placed(
    NearbyStop stop,
    Map<String, List<double>> known,
  ) => switch (known[stop.id]) {
    final position? => stop.withPosition(position[0], position[1]),
    null => stop,
  };

  /// Buses on their way to [stops], asking as little as possible: an area
  /// asked about within [maxAge] is reused, and the rest are grouped so
  /// one request answers for every stop within its reach.
  Future<LiveArrivals> arrivalsFor(
    List<LineStop> stops, {
    Duration maxAge = const Duration(minutes: 1),
  }) async {
    bool covers(double lat, double lon, LineStop stop) =>
        metersBetween(lat, lon, stop.latitude, stop.longitude) <=
        arrivalsReachMeters;

    final now = DateTime.now();
    final areas = <_Area>{};
    final missing = <LineStop>[];
    for (final stop in stops) {
      final known = _recentAreas.reversed
          .where((a) => now.difference(a.at) <= maxAge)
          .where((a) => covers(a.latitude, a.longitude, stop))
          .firstOrNull;
      if (known != null) {
        areas.add(known);
      } else {
        missing.add(stop);
      }
    }

    final centres = areasCovering([
      for (final stop in missing)
        (latitude: stop.latitude, longitude: stop.longitude),
    ], arrivalsReachMeters);

    var failed = false;
    final answers = await Future.wait(
      centres.map((centre) async {
        try {
          final found = await getNearbyStops(
            latitude: centre.latitude,
            longitude: centre.longitude,
          );
          return (
            latitude: centre.latitude,
            longitude: centre.longitude,
            at: DateTime.now(),
            stops: found,
          );
        } on ApiException {
          failed = true;
          return null;
        }
      }),
    );
    areas.addAll(answers.nonNulls);

    final seen = <String, NearbyStop>{};
    for (final area in areas) {
      for (final stop in area.stops) {
        seen[stop.id] = stop;
      }
    }
    return LiveArrivals(
      fetchedAt: areas.isEmpty
          ? now
          : areas.map((a) => a.at).reduce((a, b) => a.isBefore(b) ? a : b),
      stops: seen.values.toList(growable: false),
      failed: failed,
    );
  }

  /// How often each line comes around the hour of [at], as learned
  Future<Map<String, Duration>> lineHeadways(DateTime at) =>
      _headways.at(at);

  /// Learn how each line's rides run against the route's estimate, from
  /// rides timed by following their bus
  Future<void> observeRides(Map<String, double> readings) =>
      _rides.observe(readings);

  /// How each line's rides run against the route's estimate, as learned
  Future<Map<String, double>> rideFactors() => _rides.factors();

  /// Where each of [stopIds] stands, for those whose place is known
  Future<Map<String, GeoPoint>> stopPositions(Iterable<String> stopIds) async {
    final known = await _knownPositions();
    return {
      for (final id in stopIds)
        if (known[id] case final position?)
          id: (latitude: position[0], longitude: position[1]),
    };
  }

  /// The full MIO station catalog, used to add favorites without GPS.
  Future<List<Station>> getStations() async {
    final decoded = await _cachedJson(
      'stations',
      _stationsUrl,
      _stationsMaxAge,
    );

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
  /// The service reports how far a stop is but never where it is. The
  /// routes place every stop they call at, and earlier looks some more;
  /// for a stop still unplaced the same area is queried from two extra
  /// vantage points and the stop is trilaterated from the three
  /// distances. Stops that fall out of range of the extra points simply
  /// come back without a position.
  Stream<List<NearbyStop>> locatedStops({
    required double latitude,
    required double longitude,
  }) async* {
    const offset = 120.0;
    final lonScale = _metresPerDegree * cos(latitude * pi / 180);

    final placed = await getNearbyStops(
      latitude: latitude,
      longitude: longitude,
    );
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

  Future<Map<String, List<double>>> _knownPositions() =>
      _positions ??= _loadPositions();

  Future<Map<String, List<double>>> _loadPositions() async {
    final cached = await _cache.read(_positionsKey);
    return {
      if (cached is Map)
        for (final MapEntry(key: id, value: position) in cached.entries)
          if (position case [final num latitude, final num longitude])
            id.toString(): [latitude.toDouble(), longitude.toDouble()],
    };
  }

  /// Keep the stops placed by trilateration that were not known
  Future<void> _rememberPositions(List<NearbyStop> stops) async {
    final positions = await _knownPositions();
    var added = false;

    for (final stop in stops) {
      if (!stop.hasPosition || positions.containsKey(stop.id)) continue;
      positions[stop.id] = [stop.latitude!, stop.longitude!];
      added = true;
    }

    if (added) _savePositionsSoon();
  }

  /// A route places its stops exactly: kept over any trilateration
  Future<void> _placeFromRoute(List<LineStop> stops) async {
    final positions = await _knownPositions();
    var changed = false;

    for (final stop in stops) {
      if (stop.stopId.isEmpty) continue;
      final known = positions[stop.stopId];
      if (known != null &&
          known[0] == stop.latitude &&
          known[1] == stop.longitude) {
        continue;
      }
      positions[stop.stopId] = [stop.latitude, stop.longitude];
      changed = true;
    }

    if (changed) _savePositionsSoon();
  }

  /// Save the positions a moment after they change: a whole network of
  /// routes comes in within a second or two, and a write or two does for
  /// all of it
  void _savePositionsSoon() {
    if (_positionsSavePending) return;
    _positionsSavePending = true;
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), () async {
        _positionsSavePending = false;
        final positions = await _knownPositions();
        while (positions.length > _maxStoredPositions) {
          positions.remove(positions.keys.first);
        }
        await _cache.write(_positionsKey, positions);
      }),
    );
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
    final decoded = await _cachedJson(
      'lines_$stopId',
      '$_linesByStopUrl/$stopId',
      _linesMaxAge,
    );

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

  /// Every MIO line, sorted by name: the catalog's, and any line with
  /// hours that the arrivals have shown running lately. The catalog can
  /// leave out a line that runs, while the hours list some that do not.
  /// With [staleOk], a catalog past its age answers at once, as
  /// [getLineStops] does.
  Future<List<TransitLine>> getLines({bool staleOk = false}) async {
    final decoded = await _cachedJson(
      'lines',
      _linesUrl,
      _routesMaxAge,
      staleOk: staleOk,
    );
    final lines = [
      for (final l in decoded.whereType<Map<String, dynamic>>())
        if (l['lineId'] is num && l['name'] is String)
          TransitLine(
            id: (l['lineId'] as num).toInt(),
            name: l['name'] as String,
          ),
    ];

    final listed = {for (final l in lines) l.name};
    final seen = await _headways.seenSince(
      DateTime.now().subtract(_seenLately),
    );
    if (!seen.every(listed.contains)) {
      try {
        final hours = await getLineHours();
        lines.addAll([
          for (final name in hours.keys)
            if (!listed.contains(name) && seen.contains(name))
              TransitLine(id: 0, name: name),
        ]);
      } on ApiException {
        // Without the hours, the catalog alone
      }
    }
    return lines..sort((a, b) => a.name.compareTo(b.name));
  }

  /// The stops of [line] in route order, both directions. With [staleOk],
  /// a route past its age answers at once and is fetched again in the
  /// background, for next time: routes change a few times a year, and a
  /// whole network of them expires at once.
  Future<List<LineStop>> getLineStops(
    String line, {
    bool staleOk = false,
  }) async {
    final decoded = await _cachedJson(
      'linestops_$line',
      '$_lineStopsUrl/${Uri.encodeComponent(line)}',
      _routesMaxAge,
      staleOk: staleOk,
      // Read once a run to build the network: not worth holding twice
      remember: false,
    );
    final stops = decoded
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
    await _placeFromRoute(stops);
    return stops;
  }

  /// Buses running on [line] right now, each with the direction of its
  /// trip. The positions are never cached; the directions are, until the
  /// bus nears the end of its trip.
  Future<List<LineBus>> getLineBuses(String line) async {
    final buses = await _lineBusPositions(line);
    final ends = await _endsOf(line);
    final now = _now();

    Duration maxAge(LineBus bus, int? direction) {
      final end = ends[direction];
      if (end == null) return _busDirectionMaxAge;
      final toEnd = metersBetween(
        bus.latitude,
        bus.longitude,
        end.latitude,
        end.longitude,
      );
      return toEnd <= _nearTripEndMeters
          ? _directionNearMaxAge
          : _directionFarMaxAge;
    }

    final stale = [
      for (final bus in buses)
        if (_busDirections[bus.busNumber] case final known
            when known == null ||
                known.line != line ||
                now.difference(known.at) > maxAge(bus, known.direction))
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

  /// Last stop of each direction of [line], where its trips end; empty
  /// when the route cannot be had
  Future<Map<int, GeoPoint>> _endsOf(String line) async {
    final known = _tripEnds[line];
    if (known != null) return known;

    Map<int, GeoPoint> ends;
    try {
      ends = {
        // In route order, so the last stop of each direction stays
        for (final stop in await getLineStops(line))
          stop.direction: (latitude: stop.latitude, longitude: stop.longitude),
      };
    } on ApiException {
      // Every bus is then asked about as often as before
      ends = const {};
    }
    return _tripEnds[line] = ends;
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
        at: _now(),
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

  /// A list from the catalog server, from the cache while it is fresh.
  /// Past its age it is asked for again, and the old copy still answers
  /// when that fails: routes and hours change a few times a year, and a
  /// day offline should not lose them. With [staleOk] the old copy
  /// answers at once and a new one is fetched in the background, for next
  /// time. [remember] is the cache's, for large lists read once a run.
  Future<List> _cachedJson(
    String key,
    String url,
    Duration maxAge, {
    bool staleOk = false,
    bool remember = true,
  }) async {
    final entry = await _cache.readEntry(key, remember: remember);
    final kept = entry?.value is List ? entry!.value as List : null;
    if (kept != null) {
      if (DateTime.now().difference(entry!.savedAt) <= maxAge) return kept;
      if (staleOk) {
        _refreshLater(key, url, remember: remember);
        return kept;
      }
    }

    try {
      return await _fetchList(key, url, remember: remember);
    } on ApiException {
      if (kept != null) return kept;
      rethrow;
    }
  }

  Future<List> _fetchList(
    String key,
    String url, {
    required bool remember,
  }) async {
    final decoded = await _getJson(Uri.parse(url), _catalogGuard);
    if (decoded is! List) {
      throw const ServerApiException('Unexpected catalog response');
    }
    await _cache.write(key, decoded, remember: remember);
    return decoded;
  }

  /// Fetch [key] again in the background, behind the others waiting
  void _refreshLater(String key, String url, {required bool remember}) {
    if (_refreshing.contains(key)) return;
    _toRefresh[key] = (url: url, remember: remember);
    _refreshNext();
  }

  void _refreshNext() {
    while (_refreshing.length < _refreshAtOnce && _toRefresh.isNotEmpty) {
      final key = _toRefresh.keys.first;
      final job = _toRefresh.remove(key)!;
      _refreshing.add(key);
      unawaited(
        _fetchList(key, job.url, remember: job.remember)
            .then<void>(
              (_) {},
              // The old copy stays, and is tried again next time it is read
              onError: (_) {},
            )
            .whenComplete(() {
              _refreshing.remove(key);
              _refreshNext();
            }),
      );
    }
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

/// An answer of the arrivals service and the point it was asked around
typedef _Area = ({
  double latitude,
  double longitude,
  DateTime at,
  List<NearbyStop> stops,
});
