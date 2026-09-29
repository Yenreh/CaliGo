import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/datasources/api_exception.dart';
import '../../data/repositories/stops_repository_impl.dart';
import '../../domain/arrival_areas.dart';
import '../../domain/entities/stop_entity.dart';
import '../../domain/entities/trip_entity.dart';
import '../../domain/repositories/stops_repository.dart';
import 'settings_provider.dart';

/// Provider for the stops repository
final stopsRepositoryProvider = Provider<StopsRepository>((ref) {
  return StopsRepositoryImpl();
});

/// State for the favorite stops dashboard
class StopsState {
  final List<FavoriteStop> favorites;
  final Map<String, List<BusArrival>> arrivals;
  final bool isLoading;
  final bool isRefreshing;
  final ApiException? error;
  final DateTime? lastUpdated;

  const StopsState({
    this.favorites = const [],
    this.arrivals = const {},
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.lastUpdated,
  });

  StopsState copyWith({
    List<FavoriteStop>? favorites,
    Map<String, List<BusArrival>>? arrivals,
    bool? isLoading,
    bool? isRefreshing,
    ApiException? error,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return StopsState(
      favorites: favorites ?? this.favorites,
      arrivals: arrivals ?? this.arrivals,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Favorite stops and their upcoming buses
class StopsNotifier extends Notifier<StopsState> {
  /// The arrivals service takes one request per point, so keep a few in
  /// flight at a time instead of firing all of them at once.
  static const int _maxConcurrentRequests = 4;

  /// One request covers every stop within 300 m of the point it asks
  /// about, so favorites saved from nearly the same place share it when
  /// their stops have no known place.
  static const double _clusterRadiusMetres = 30;

  /// Arrivals move slowly enough that answering twice in a few seconds
  /// only wastes data.
  static const Duration _minRefreshGap = Duration(seconds: 15);

  /// Arrivals kept from the last run are shown on launch while fresh
  /// ones load, as long as they are this recent: they hold absolute
  /// times, so their countdowns stay right until buses start to drift.
  static const Duration _keptArrivalsMaxAge = Duration(minutes: 5);

  Timer? _timer;
  DateTime? _lastRefresh;

  /// Screens following the arrivals while on show, each wanting only the
  /// stops the home screen lists or all of them
  final Map<Object, bool> _watchers = {};

  bool get _autoRefreshing => _watchers.isNotEmpty;

  /// Only the home screen is watching: it asks for the stops it lists
  bool get _homeOnly =>
      _watchers.isNotEmpty && _watchers.values.every((homeOnly) => homeOnly);

  StopsRepository get _repository => ref.read(stopsRepositoryProvider);

  @override
  StopsState build() {
    ref.onDispose(() {
      _watchers.clear();
      _timer?.cancel();
    });
    // Reorder in place when the setting flips (or finishes loading): the
    // arrivals do not change with the order.
    ref.listen(
      settingsProvider.select((s) => s.sortStopsByProximity),
      (_, _) => _reorder(),
    );
    Future.microtask(loadFavorites);
    return const StopsState(isLoading: true);
  }

  /// Load saved stops and their arrivals
  Future<void> loadFavorites() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final favorites = await _ordered(await _repository.getFavorites());
      state = state.copyWith(
        favorites: favorites,
        arrivals: state.arrivals.isEmpty
            ? await _keptArrivals(favorites)
            : null,
        isLoading: false,
      );
      if (favorites.isNotEmpty) await refreshArrivals();
    } on ApiException catch (e) {
      state = state.copyWith(error: e, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: ApiException(e.toString()),
        isLoading: false,
      );
    }
  }

  Future<void> _reorder() async {
    if (state.favorites.length < 2) return;
    final ordered = await _ordered(state.favorites);
    state = state.copyWith(favorites: ordered);
  }

  /// Saved order, or closest first when the settings ask for it
  Future<List<FavoriteStop>> _ordered(List<FavoriteStop> stops) async {
    if (ref.read(settingsProvider).sortStopsByProximity) {
      return _sortByDistance(stops);
    }
    return [...stops]..sort((a, b) => a.position.compareTo(b.position));
  }

  /// Arrivals from the last run, without the buses already gone. A list
  /// left empty is dropped: it would claim no bus is coming when the
  /// truth is not known yet.
  Future<Map<String, List<BusArrival>>> _keptArrivals(
    List<FavoriteStop> favorites,
  ) async {
    final kept = await _repository.recentArrivals(_keptArrivalsMaxAge);
    if (kept == null) return const {};

    final now = DateTime.now();
    final ids = {for (final stop in favorites) stop.id};
    return {
      for (final entry in kept.entries)
        if (ids.contains(entry.key))
          if (entry.value.where((b) => !b.arrivalTime.isBefore(now)).toList()
              case final upcoming when upcoming.isNotEmpty)
            entry.key: upcoming,
    };
  }

  /// Put the closest stops first when the location is already known.
  ///
  /// Never asks for the permission here: the dashboard has to work
  /// without it, and only the nearby search is worth a prompt.
  Future<List<FavoriteStop>> _sortByDistance(List<FavoriteStop> stops) async {
    if (stops.length < 2) return stops;

    try {
      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) return stops;

      final position = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 8),
            ),
          );

      final sorted = [...stops]..sort((a, b) {
          final da = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            a.anchorLatitude,
            a.anchorLongitude,
          );
          final db = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            b.anchorLatitude,
            b.anchorLongitude,
          );
          return da.compareTo(db);
        });
      return sorted;
    } catch (_) {
      // Location is optional here: keep the order the user saved.
      return stops;
    }
  }

  /// Refresh the arrivals of every saved stop.
  ///
  /// Favorites one request can answer share it, as [_groupFavorites]
  /// makes them; a stop the shared answer does not mention is asked for
  /// on its own when that could tell more.
  List<FavoriteStop> get _targets => _homeOnly
      ? state.favorites.where((s) => s.showOnHome).toList(growable: false)
      : state.favorites;

  Future<void> refreshArrivals({bool force = false}) async {
    final targets = _targets;
    if (state.isRefreshing || targets.isEmpty) return;

    final last = _lastRefresh;
    // Too soon after the last one, unless some stop has nothing to show
    // yet, such as those the home screen leaves out
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _minRefreshGap &&
        targets.every((s) => state.arrivals.containsKey(s.id))) {
      return;
    }

    state = state.copyWith(isRefreshing: true, clearError: true);

    final results = Map<String, List<BusArrival>>.from(state.arrivals);
    final groups = await _groupFavorites(targets);
    ApiException? failure;

    final healed = <String, FavoriteStop>{};

    for (var i = 0; i < groups.length; i += _maxConcurrentRequests) {
      final batch = groups.skip(i).take(_maxConcurrentRequests);
      await Future.wait(
        batch.map((group) async {
          try {
            var nearby = await _repository.getNearbyStops(
              group.latitude,
              group.longitude,
            );

            for (final favorite in group.stops) {
              var arrivals = _arrivalsFor(favorite, nearby);
              var seen = nearby;

              // A placed stop within reach that the answer leaves out has
              // no bus coming. One asked about around an anchor is worth
              // asking again only when anchored somewhere else: the same
              // point gives the same answer.
              final elsewhere =
                  !group.placed &&
                  Geolocator.distanceBetween(
                        group.latitude,
                        group.longitude,
                        favorite.anchorLatitude,
                        favorite.anchorLongitude,
                      ) >
                      1;

              if (arrivals == null && elsewhere) {
                seen = await _repository.getNearbyStops(
                  favorite.anchorLatitude,
                  favorite.anchorLongitude,
                );
                arrivals = _arrivalsFor(favorite, seen);
              }

              results[favorite.id] = arrivals ?? const [];

              final update = _reconcile(favorite, seen, found: arrivals != null);
              if (update != null) healed[favorite.id] = update;
            }
          } on ApiException catch (e) {
            // A failed request says nothing about the stops themselves.
            failure ??= e;
          }
        }),
      );
    }

    for (final stop in healed.values) {
      await _repository.updateFavorite(stop);
    }

    _lastRefresh = DateTime.now();
    state = state.copyWith(
      favorites: healed.isEmpty
          ? state.favorites
          : [
              for (final stop in state.favorites) healed[stop.id] ?? stop,
            ],
      arrivals: results,
      isRefreshing: false,
      error: failure,
      lastUpdated: DateTime.now(),
      clearError: failure == null,
    );
    if (failure == null) unawaited(_repository.keepArrivals(results));
    // A refresh from anywhere resets the clock, and sets its new pace
    if (_autoRefreshing) _scheduleNext();
  }

  /// How long to wait before asking again, from how soon the next bus
  /// comes: a countdown near zero is worth following closely, one twenty
  /// minutes out barely moves between two looks.
  static Duration nextRefreshDelay(
    Iterable<List<BusArrival>> arrivals, [
    DateTime? now,
  ]) {
    final at = now ?? DateTime.now();
    int? soonest;
    for (final list in arrivals) {
      for (final bus in list) {
        if (bus.arrivalTime.isBefore(at)) continue;
        final minutes = bus.minutesUntilArrival(at);
        if (soonest == null || minutes < soonest) soonest = minutes;
      }
    }

    if (soonest != null && soonest <= 5) return const Duration(seconds: 30);
    if (soonest != null && soonest <= 15) return const Duration(seconds: 60);
    return const Duration(seconds: 120);
  }

  void _scheduleNext() {
    _timer?.cancel();
    // Paced by the buses the user follows, not the whole stop
    final delay = nextRefreshDelay([
      for (final stop in _targets) stop.pick(state.arrivals[stop.id] ?? const []),
    ]);
    _timer = Timer(delay, () async {
      await refreshArrivals();
      // Skipped refreshes (too soon, already running) still keep the pace
      if (_autoRefreshing) _scheduleNext();
    });
  }

  /// Keep a favorite in step with what the service reports.
  ///
  /// Names drift when Metrocali relabels a stop, and a stop that stops
  /// being reported has probably been retired, renumbered or moved out
  /// of reach: counting the misses tells that apart from a quiet stop
  /// with no bus on the way.
  FavoriteStop? _reconcile(
    FavoriteStop favorite,
    List<NearbyStop> nearby, {
    required bool found,
  }) {
    if (!found) {
      // An area is only gone when nothing at all answers around it.
      if (favorite.isArea && nearby.isNotEmpty) return null;
      return favorite.missingCount >= FavoriteStop.missingThreshold
          ? null
          : favorite.copyWith(missingCount: favorite.missingCount + 1);
    }

    final reportedName = favorite.isArea
        ? favorite.name
        : nearby.firstWhere((s) => s.id == favorite.stopId).name;

    final nameChanged =
        reportedName.isNotEmpty && reportedName != favorite.name;
    if (!nameChanged && favorite.missingCount == 0) return null;

    return favorite.copyWith(
      name: nameChanged ? reportedName : favorite.name,
      missingCount: 0,
    );
  }

  /// Point a favorite at another stop, keeping its label and place
  Future<void> relinkFavorite(String id, NearbyStop stop) async {
    final favorite = state.favorites.where((s) => s.id == id).firstOrNull;
    if (favorite == null) return;

    await _repository.updateFavorite(
      favorite.copyWith(
        stopId: stop.id,
        name: stop.name,
        missingCount: 0,
      ),
    );
    await loadFavorites();
  }

  /// Group favorites that a single request can answer together.
  ///
  /// A stop whose place is known can be asked about from anywhere within
  /// reach of it, so those share requests the way the stops of a trip do.
  /// An area, or a stop never placed, is asked about around its anchor,
  /// with the others saved from nearly the same spot.
  Future<List<_Group>> _groupFavorites(List<FavoriteStop> stops) async {
    final positions = await _repository.stopPositions([
      for (final stop in stops)
        if (stop.stopId case final id?) id,
    ]);
    final placed = [
      for (final stop in stops)
        if (positions[stop.stopId] case final at?) (stop: stop, at: at),
    ];

    final groups = <_Group>[];
    final grouped = <String>{};
    final centres = areasCovering([
      for (final p in placed) p.at,
    ], arrivalsReachMeters);
    for (final centre in centres) {
      final within = [
        for (final p in placed)
          if (!grouped.contains(p.stop.id) &&
              metersBetween(
                    centre.latitude,
                    centre.longitude,
                    p.at.latitude,
                    p.at.longitude,
                  ) <=
                  arrivalsReachMeters)
            p.stop,
      ];
      grouped.addAll(within.map((s) => s.id));
      groups.add((
        latitude: centre.latitude,
        longitude: centre.longitude,
        stops: within,
        placed: true,
      ));
    }

    final rest = [
      for (final stop in stops)
        if (!grouped.contains(stop.id)) stop,
    ];
    for (final cluster in _clusterByAnchor(rest)) {
      groups.add((
        latitude: cluster.first.anchorLatitude,
        longitude: cluster.first.anchorLongitude,
        stops: cluster,
        placed: false,
      ));
    }
    return groups;
  }

  /// Group favorites saved from nearly the same spot
  List<List<FavoriteStop>> _clusterByAnchor(List<FavoriteStop> stops) {
    final clusters = <List<FavoriteStop>>[];

    for (final stop in stops) {
      final match = clusters.where((cluster) {
        final head = cluster.first;
        return Geolocator.distanceBetween(
              head.anchorLatitude,
              head.anchorLongitude,
              stop.anchorLatitude,
              stop.anchorLongitude,
            ) <=
            _clusterRadiusMetres;
      }).firstOrNull;

      if (match != null) {
        match.add(stop);
      } else {
        clusters.add([stop]);
      }
    }

    return clusters;
  }

  /// Arrivals for [favorite] inside a shared answer, or null when that
  /// answer does not cover it
  List<BusArrival>? _arrivalsFor(
    FavoriteStop favorite,
    List<NearbyStop> nearby,
  ) {
    if (favorite.isArea) {
      return nearby.expand((s) => s.arrivals).toList()
        ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
    }

    for (final stop in nearby) {
      if (stop.id == favorite.stopId) return stop.arrivals;
    }
    return null;
  }

  /// Save a stop, or an area when [stopId] is null
  Future<void> addFavorite({
    required String id,
    required String name,
    required double anchorLatitude,
    required double anchorLongitude,
    String? stopId,
    String? customName,
  }) async {
    final position = await _repository.nextPosition();
    await _repository.addFavorite(
      FavoriteStop(
        id: id,
        name: name,
        anchorLatitude: anchorLatitude,
        anchorLongitude: anchorLongitude,
        position: position,
        stopId: stopId,
        customName: (customName?.trim().isEmpty ?? true)
            ? null
            : customName!.trim(),
      ),
    );
    await loadFavorites();
  }

  /// Restore stops from a backup, skipping the ones already saved
  Future<int> importFavorites(List<FavoriteStop> stops) async {
    var imported = 0;
    final existing = {for (final s in state.favorites) s.id};

    for (final stop in stops) {
      if (existing.contains(stop.id)) continue;
      await _repository.addFavorite(stop);
      imported++;
    }

    if (imported > 0) await loadFavorites();
    return imported;
  }

  /// Change what the user chose for a stop: its own label, dropped when
  /// [customName] is empty, and the lines it shows, all when empty
  Future<void> editFavorite(
    String id, {
    required String? customName,
    required List<String> lines,
  }) async {
    final stop = state.favorites.where((s) => s.id == id).firstOrNull;
    if (stop == null) return;

    final trimmed = customName?.trim();
    final updated = stop.copyWith(
      customName: trimmed,
      clearCustomName: trimmed == null || trimmed.isEmpty,
      lines: lines,
    );
    await _repository.updateFavorite(updated);
    // Nothing to fetch: the arrivals kept already hold every line
    state = state.copyWith(
      favorites: [for (final s in state.favorites) s.id == id ? updated : s],
    );
  }

  /// Move a favorite as a drag leaves it, with the indexes a reorderable
  /// list reports. Only meaningful in the saved order: sorted by
  /// proximity, the next load would undo it.
  Future<void> reorderFavorites(int oldIndex, int newIndex) async {
    final stops = [...state.favorites];
    final moved = stops.removeAt(oldIndex);
    stops.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);

    final numbered = [
      for (final (i, stop) in stops.indexed) stop.copyWith(position: i),
    ];
    state = state.copyWith(favorites: numbered);

    for (final (i, stop) in numbered.indexed) {
      if (stops[i].position != i) await _repository.updateFavorite(stop);
    }
  }

  /// List a stop on the home screen, or keep it to the stops screen
  Future<void> setShowOnHome(String id, bool show) async {
    final stop = state.favorites.where((s) => s.id == id).firstOrNull;
    if (stop == null || stop.showOnHome == show) return;

    final updated = stop.copyWith(showOnHome: show);
    await _repository.updateFavorite(updated);
    state = state.copyWith(
      favorites: [
        for (final s in state.favorites) s.id == id ? updated : s,
      ],
    );
  }

  /// Remove a saved stop
  Future<void> removeFavorite(String stopId) async {
    await _repository.removeFavorite(stopId);
    final arrivals = Map<String, List<BusArrival>>.from(state.arrivals)
      ..remove(stopId);
    state = state.copyWith(
      favorites: state.favorites.where((s) => s.id != stopId).toList(),
      arrivals: arrivals,
    );
  }

  /// Refresh arrivals while [watcher], a screen listing them, is on show,
  /// at the pace [nextRefreshDelay] sets.
  ///
  /// [homeOnly] is the home screen, which lists only some stops; as long
  /// as another screen watches too, every stop is asked for.
  void startAutoRefresh(Object watcher, {bool homeOnly = false}) {
    _watchers[watcher] = homeOnly;
    _scheduleNext();
  }

  /// [watcher] went out of sight; the refresh stops with the last one
  void stopAutoRefresh(Object watcher) {
    _watchers.remove(watcher);
    if (_watchers.isNotEmpty) return;
    _timer?.cancel();
    _timer = null;
  }

  void clearError() => state = state.copyWith(clearError: true);
}

/// Favorites one request answers, and the point it asks around; a group
/// of [placed] stops asks around a point within reach of each of them
typedef _Group = ({
  double latitude,
  double longitude,
  List<FavoriteStop> stops,
  bool placed,
});

/// Provider for the favorite stops dashboard
final stopsProvider = NotifierProvider<StopsNotifier, StopsState>(() {
  return StopsNotifier();
});

/// Raised when the device location cannot be read
class LocationUnavailableException implements Exception {
  final bool permanentlyDenied;

  const LocationUnavailableException({this.permanentlyDenied = false});
}

/// Current position.
///
/// Only asks for the permission when [requestPermission] is set, so a
/// screen can quietly use the location it already has without putting a
/// system prompt in front of someone who just opened it.
Future<Position> currentDevicePosition({bool requestPermission = true}) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationUnavailableException();
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied && requestPermission) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationUnavailableException(permanentlyDenied: true);
  }
  if (permission == LocationPermission.denied) {
    throw const LocationUnavailableException();
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
}

/// Where the device was last placed, instantly and without GPS; null
/// when unknown or without the permission already given
Future<Position?> lastKnownDevicePosition() async {
  try {
    return await Geolocator.getLastKnownPosition();
  } catch (_) {
    return null;
  }
}

/// Stops around the user, with the position they were found from
typedef NearbyResult = ({List<NearbyStop> stops, double lat, double lon});

/// Stops near the device, refreshed on demand
final nearbyStopsProvider = FutureProvider.autoDispose<NearbyResult>((ref) async {
  final position = await currentDevicePosition();
  final stops = await ref
      .read(stopsRepositoryProvider)
      .getNearbyStops(position.latitude, position.longitude);
  return (
    stops: stops,
    lat: position.latitude,
    lon: position.longitude,
  );
});

/// MIO station catalog, used to add favorites without GPS
final stationsProvider = FutureProvider<List<Station>>((ref) async {
  return ref.read(stopsRepositoryProvider).getStations();
});

/// A point to look up stops around
typedef MapPoint = ({double latitude, double longitude});

/// Stops around an arbitrary point, so any place can be inspected
/// without saving it first. The list comes as soon as the service
/// answers, and again once the stops are placed on the map.
final stopsAtPointProvider =
    StreamProvider.autoDispose.family<List<NearbyStop>, MapPoint>(
  (ref, point) {
    return ref
        .read(stopsRepositoryProvider)
        .locatedStops(point.latitude, point.longitude);
  },
);

/// Stops around a point from a single request, placed where their place
/// is already known: for lists, which need no map to put them on
final nearbyAtPointProvider =
    FutureProvider.autoDispose.family<List<NearbyStop>, MapPoint>((ref, point) {
  return ref
      .read(stopsRepositoryProvider)
      .getNearbyStops(point.latitude, point.longitude);
});

/// Fresh arrivals for a stop being looked at, from a single request.
///
/// Asks around the stop itself when its position is known, and around
/// the point it was found from otherwise. The service leaves out stops
/// with no bus on the way, so a stop missing from the answer has none.
Future<NearbyStop> refreshStopArrivals(
  StopsRepository repository,
  NearbyStop stop, {
  required double anchorLatitude,
  required double anchorLongitude,
}) async {
  final nearby = await repository.getNearbyStops(
    stop.latitude ?? anchorLatitude,
    stop.longitude ?? anchorLongitude,
  );
  final match = nearby.where((s) => s.id == stop.id).firstOrNull;
  return stop.withArrivals(match?.arrivals ?? const []);
}

/// Lines serving a stop
final linesByStopProvider =
    FutureProvider.autoDispose.family<List<StopLine>, String>((ref, stopId) {
  return ref.read(stopsRepositoryProvider).getLinesByStop(stopId);
});
