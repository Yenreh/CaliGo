import '../entities/line_entity.dart';
import '../entities/stop_entity.dart';

/// Repository interface for stops and arrivals
abstract class StopsRepository {
  /// Stops saved by the user
  Future<List<FavoriteStop>> getFavorites();

  /// Save a stop, appending it to the end of the list
  Future<void> addFavorite(FavoriteStop stop);

  /// Remove a saved stop
  Future<void> removeFavorite(String stopId);

  /// Save changes to a stop the user already keeps
  Future<void> updateFavorite(FavoriteStop stop);

  /// Position to assign to the next saved stop
  Future<int> nextPosition();

  /// Stops around a position, with their upcoming buses
  Future<List<NearbyStop>> getNearbyStops(double latitude, double longitude);

  /// MIO station catalog
  Future<List<Station>> getStations();

  /// Lines serving a stop
  Future<List<StopLine>> getLinesByStop(String stopId);

  /// Stops around a point: first as found, then again placed on the map
  /// where possible
  Stream<List<NearbyStop>> locatedStops(double latitude, double longitude);

  /// Every MIO line
  Future<List<TransitLine>> getLines();

  /// The stops of a line in route order, both directions
  Future<List<LineStop>> getLineStops(String line);

  /// Buses running on a line right now
  Future<List<LineBus>> getLineBuses(String line);

  /// Hours each line runs, by line name
  Future<Map<String, LineHours>> getLineHours();

  /// Arrivals of the favorites as last fetched, when that was within
  /// [maxAge]; null otherwise
  Future<Map<String, List<BusArrival>>?> recentArrivals(Duration maxAge);

  /// Keep the arrivals just fetched, to show at once on the next launch
  Future<void> keepArrivals(Map<String, List<BusArrival>> arrivals);
}
