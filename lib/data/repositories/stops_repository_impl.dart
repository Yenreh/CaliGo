import '../../domain/arrival_areas.dart';
import '../../domain/entities/line_entity.dart';
import '../../domain/entities/stop_entity.dart';
import '../../domain/repositories/stops_repository.dart';
import '../../domain/trip_timing.dart';
import '../datasources/api_exception.dart';
import '../datasources/json_cache.dart';
import '../datasources/stops_local_datasource.dart';
import '../datasources/stops_remote_datasource.dart';

/// Implementation of StopsRepository
class StopsRepositoryImpl implements StopsRepository {
  final StopsLocalDatasource _localDatasource;
  final StopsRemoteDatasource _remoteDatasource;
  final JsonCache _cache;

  static const String _arrivalsKey = 'favorite_arrivals';

  StopsRepositoryImpl({
    StopsLocalDatasource? localDatasource,
    StopsRemoteDatasource? remoteDatasource,
    JsonCache? cache,
  })  : _localDatasource = localDatasource ?? StopsLocalDatasource(),
        _remoteDatasource = remoteDatasource ?? StopsRemoteDatasource(),
        _cache = cache ?? JsonCache();

  @override
  Future<List<FavoriteStop>> getFavorites() => _localDatasource.getFavorites();

  @override
  Future<void> addFavorite(FavoriteStop stop) =>
      _localDatasource.insert(stop);

  @override
  Future<void> removeFavorite(String stopId) =>
      _localDatasource.delete(stopId);

  @override
  Future<void> updateFavorite(FavoriteStop stop) =>
      _localDatasource.update(stop);

  @override
  Future<int> nextPosition() => _localDatasource.nextPosition();

  @override
  Future<List<NearbyStop>> getNearbyStops(double latitude, double longitude) {
    return _remoteDatasource.getNearbyStops(
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<List<Station>> getStations() => _remoteDatasource.getStations();

  @override
  Future<List<StopLine>> getLinesByStop(String stopId) =>
      _remoteDatasource.getLinesByStop(stopId);

  @override
  Stream<List<NearbyStop>> locatedStops(double latitude, double longitude) {
    return _remoteDatasource.locatedStops(
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<List<TransitLine>> getLines() => _remoteDatasource.getLines();

  @override
  Future<List<LineStop>> getLineStops(String line) =>
      _remoteDatasource.getLineStops(line);

  /// Requests at once while loading every route: few enough to be kind
  /// to the service, enough to finish in seconds the first time
  static const int _routesAtOnce = 4;

  @override
  Future<Map<String, List<LineStop>>> getAllLineStops({
    void Function(int done, int total)? onProgress,
  }) async {
    // A network a week old plans as well as a new one: it answers at once
    // and the new one comes in the background, for next time
    final lines = await _remoteDatasource.getLines(staleOk: true);
    final routes = <String, List<LineStop>>{};
    var done = 0;
    var failed = 0;
    ApiException? lastError;

    final pending = lines.map((l) => l.name).toList();
    Future<void> worker() async {
      while (pending.isNotEmpty) {
        final line = pending.removeLast();
        try {
          routes[line] = await _remoteDatasource.getLineStops(
            line,
            staleOk: true,
          );
        } on ApiException catch (e) {
          failed++;
          lastError = e;
        }
        onProgress?.call(++done, lines.length);
      }
    }

    await Future.wait(List.generate(_routesAtOnce, (_) => worker()));

    // A few missing lines still leave a network worth planning on
    if (lines.isNotEmpty && failed * 2 > lines.length) throw lastError!;
    return routes;
  }

  @override
  Future<LiveArrivals> arrivalsFor(
    List<LineStop> stops, {
    Duration maxAge = const Duration(minutes: 1),
  }) => _remoteDatasource.arrivalsFor(stops, maxAge: maxAge);

  @override
  Future<Map<String, Duration>> lineHeadways(DateTime at) =>
      _remoteDatasource.lineHeadways(at);

  @override
  Future<void> observeRides(Map<String, double> readings) =>
      _remoteDatasource.observeRides(readings);

  @override
  Future<Map<String, double>> rideFactors() => _remoteDatasource.rideFactors();

  @override
  Future<Map<String, GeoPoint>> stopPositions(Iterable<String> stopIds) =>
      _remoteDatasource.stopPositions(stopIds);

  @override
  Future<List<LineBus>> getLineBuses(String line) =>
      _remoteDatasource.getLineBuses(line);

  @override
  Future<Map<String, LineHours>> getLineHours() =>
      _remoteDatasource.getLineHours();

  @override
  Future<Map<String, List<BusArrival>>?> recentArrivals(
    Duration maxAge,
  ) async {
    final kept = await _cache.read(_arrivalsKey, maxAge: maxAge);
    if (kept is! Map) return null;

    try {
      return {
        for (final entry in kept.entries)
          if (entry.value is List)
            entry.key.toString(): [
              for (final bus in entry.value as List)
                if (bus is Map<String, dynamic>) BusArrival.fromJson(bus),
            ],
      };
    } catch (_) {
      // A kept snapshot is only a head start: without it, wait as before
      return null;
    }
  }

  @override
  Future<void> keepArrivals(Map<String, List<BusArrival>> arrivals) {
    return _cache.write(_arrivalsKey, {
      for (final entry in arrivals.entries)
        entry.key: [for (final bus in entry.value) bus.toJson()],
    });
  }
}
