import '../../domain/entities/line_entity.dart';
import '../../domain/entities/stop_entity.dart';
import '../../domain/repositories/stops_repository.dart';
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
