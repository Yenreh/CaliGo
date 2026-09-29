import '../arrival_areas.dart';
import '../entities/line_entity.dart';
import '../entities/stop_entity.dart';
import '../trip_timing.dart';

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

  /// Every MIO line: the catalog's, and any line with hours the arrivals
  /// have shown running lately, which the catalog can leave out
  Future<List<TransitLine>> getLines();

  /// The stops of a line in route order, both directions
  Future<List<LineStop>> getLineStops(String line);

  /// Every line's stops, by line name, for planning trips. Lines that
  /// fail to load are left out; [onProgress] hears of each one done.
  /// Routes past their age still answer, and are fetched again in the
  /// background for next time.
  Future<Map<String, List<LineStop>>> getAllLineStops({
    void Function(int done, int total)? onProgress,
  });

  /// Buses on their way to the given stops, reusing recent answers and
  /// grouping the rest into as few requests as possible
  Future<LiveArrivals> arrivalsFor(
    List<LineStop> stops, {
    Duration maxAge = const Duration(minutes: 1),
  });

  /// How often each line comes around the hour of [at], learned from the
  /// arrivals seen so far; lines never seen are missing
  Future<Map<String, Duration>> lineHeadways(DateTime at);

  /// Learn from rides timed by following their bus: the live time over
  /// what the route alone estimates, by line, as [rideReadings] gives it
  Future<void> observeRides(Map<String, double> readings);

  /// How each line's rides run against the estimate from its route;
  /// lines never followed are missing
  Future<Map<String, double>> rideFactors();

  /// Where each of [stopIds] stands, for those whose place is known: from
  /// the routes, or worked out from the arrivals service
  Future<Map<String, GeoPoint>> stopPositions(Iterable<String> stopIds);

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
