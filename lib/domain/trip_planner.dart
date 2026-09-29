import 'dart:math' as math;

import 'entities/line_entity.dart';
import 'entities/trip_entity.dart';
import 'trip_timing.dart';

/// Platform codes end station stop names, a letter up to E and a number:
/// "Aguablanca B4"
final _platform = RegExp(r'^(.+) [A-E]\d+$');

/// A street stop split in berths ends in P and a number, "Cl 70 entre Av 4
/// y 3C P2", but so do the stops numbered along a road out of town, which
/// stand far apart: "Vía La Buitrera P10" to "P25" spans almost 2 km
final _berth = RegExp(r'^(.+) P\d+$');

/// Berths of one stop stand within this of each other
const double _berthMeters = 100;

/// The station a stop belongs to, by name; null for a street stop, which
/// is a place of its own
String? stationOf(String stopName) => _platform.firstMatch(stopName)?.group(1);

/// Whether two stops are one place to wait at: the same stop, two
/// platforms of one station, or two berths of one street stop
bool samePlace(LineStop a, LineStop b) {
  if (a.stopId == b.stopId) return true;
  final station = stationOf(a.name);
  if (station != null) return station == stationOf(b.name);
  final berth = _berth.firstMatch(a.name)?.group(1);
  return berth != null &&
      berth == _berth.firstMatch(b.name)?.group(1) &&
      metersBetween(a.latitude, a.longitude, b.latitude, b.longitude) <=
          _berthMeters;
}

/// Every route of the MIO as one network: its stops, the way each line
/// runs through them, and the short walks between stops close together.
class TransitNetwork {
  /// Each stop once, whatever lines serve it
  final List<LineStop> stops;
  final List<_Pattern> _patterns;

  /// Per stop, the patterns calling at it and where along them
  final List<List<({int pattern, int position})>> _servedBy;

  /// Per stop, the stops a short walk away
  final List<List<({int stop, double meters})>> _walks;

  /// Position of each stop in [stops], by id
  final Map<String, int> _index;

  TransitNetwork._(
    this.stops,
    this._index,
    this._patterns,
    this._servedBy,
    this._walks,
  );

  LineStop? stopById(String id) => switch (_index[id]) {
    final i? => stops[i],
    null => null,
  };

  /// Stops this close can be walked between to change buses; a station's
  /// platforms fall well within it
  static const double transferMeters = 350;

  /// Lines on their own lanes (T trunk, E express) run faster than
  /// those in mixed traffic
  static double _speed(String line) => switch (line.isEmpty ? '' : line[0]) {
    'T' || 'E' => 7.0,
    'P' => 5.5,
    _ => 4.5,
  };

  /// Streets bend: a bus covers more than the straight line between stops
  static const double _routeDetour = 1.15;

  /// Time spent at each stop along the way
  static const double _dwellSeconds = 20;

  bool get isEmpty => _patterns.isEmpty;

  /// Build from each line's stops, by line name
  factory TransitNetwork.fromRoutes(Map<String, List<LineStop>> routes) {
    final index = <String, int>{};
    final stops = <LineStop>[];
    final patterns = <_Pattern>[];

    for (final MapEntry(key: line, value: route) in routes.entries) {
      final directions = {for (final s in route) s.direction};
      for (final direction in directions) {
        final ordered = [
          for (final s in route)
            if (s.direction == direction) s,
        ]..sort((a, b) => a.sequence.compareTo(b.sequence));
        if (ordered.length < 2) continue;

        final positions = <int>[];
        final seconds = <double>[0];
        for (final (i, stop) in ordered.indexed) {
          positions.add(
            index.putIfAbsent(stop.stopId, () {
              stops.add(stop);
              return stops.length - 1;
            }),
          );
          if (i == 0) continue;
          final previous = ordered[i - 1];
          final meters = metersBetween(
            previous.latitude,
            previous.longitude,
            stop.latitude,
            stop.longitude,
          );
          seconds.add(
            seconds.last + meters * _routeDetour / _speed(line) + _dwellSeconds,
          );
        }
        patterns.add(
          _Pattern(
            line: line,
            towards: ordered.last.name,
            stops: positions,
            seconds: seconds,
            route: ordered,
          ),
        );
      }
    }

    final servedBy = List.generate(
      stops.length,
      (_) => <({int pattern, int position})>[],
    );
    for (final (p, pattern) in patterns.indexed) {
      for (final (position, stop) in pattern.stops.indexed) {
        servedBy[stop].add((pattern: p, position: position));
      }
    }

    // Sorted by latitude, each stop only needs to look at a narrow band
    final walks = List.generate(
      stops.length,
      (_) => <({int stop, double meters})>[],
    );
    final byLatitude = List.generate(stops.length, (i) => i)
      ..sort((a, b) => stops[a].latitude.compareTo(stops[b].latitude));
    const band = transferMeters / 111320.0;
    for (var i = 0; i < byLatitude.length; i++) {
      final a = stops[byLatitude[i]];
      for (var j = i + 1; j < byLatitude.length; j++) {
        final b = stops[byLatitude[j]];
        if (b.latitude - a.latitude > band) break;
        final meters = metersBetween(
          a.latitude,
          a.longitude,
          b.latitude,
          b.longitude,
        );
        if (meters > transferMeters) continue;
        walks[byLatitude[i]].add((stop: byLatitude[j], meters: meters));
        walks[byLatitude[j]].add((stop: byLatitude[i], meters: meters));
      }
    }

    return TransitNetwork._(stops, index, patterns, servedBy, walks);
  }

  /// Stops within [radius] metres of a point, with their distance
  List<({int stop, double meters})> _near(
    double latitude,
    double longitude,
    double radius,
  ) => [
    for (final (i, stop) in stops.indexed)
      if (metersBetween(latitude, longitude, stop.latitude, stop.longitude)
          case final meters when meters <= radius)
        (stop: i, meters: meters),
  ];

  /// The stop closest to a point, when one is within [radius] metres
  LineStop? nearestStop(
    double latitude,
    double longitude, {
    double radius = 500,
  }) {
    LineStop? best;
    var bestMeters = radius;
    for (final stop in stops) {
      final meters = metersBetween(
        latitude,
        longitude,
        stop.latitude,
        stop.longitude,
      );
      if (meters <= bestMeters) {
        best = stop;
        bestMeters = meters;
      }
    }
    return best;
  }
}

/// A line in one direction: the stops it calls at, in order, and the
/// estimated seconds from its first stop to each
class _Pattern {
  final String line;
  final String towards;
  final List<int> stops;
  final List<double> seconds;
  final List<LineStop> route;

  const _Pattern({
    required this.line,
    required this.towards,
    required this.stops,
    required this.seconds,
    required this.route,
  });
}

/// How a stop was reached in a round, by bus
class _Ride {
  final int pattern;
  final int boardPosition;
  final int alightPosition;

  const _Ride(this.pattern, this.boardPosition, this.alightPosition);
}

/// Finds ways between two places over a [TransitNetwork].
///
/// Works in rounds, one more bus each (RAPTOR without timetables): the
/// MIO publishes none, so every ride and wait is an estimate and the
/// answer is a set of sensible options rather than a schedule.
class TripPlanner {
  final TransitNetwork network;

  /// Time between buses of each line, as learned: half of it is the wait
  /// for a line that has one, the usual figure for the rest
  final Map<String, Duration> headways;

  /// How each line's rides run against the estimate from its route, as
  /// learned from buses followed stop to stop; 1 for a line not seen
  final Map<String, double> rideFactors;

  const TripPlanner(
    this.network, {
    this.headways = const {},
    this.rideFactors = const {},
  });

  /// How far anyone walks to a first stop or from a last one; widened
  /// once when nothing is that close
  static const double accessMeters = 900;
  static const double widerAccessMeters = 1800;

  /// What a change of bus costs beyond the time, when ranking options
  static const Duration transferPenalty = Duration(minutes: 4);

  /// Share of the time on foot counted again when ranking options: most
  /// would rather ride a little longer than walk as long
  static const double walkReluctance = 0.5;

  /// Two changes at most
  static const int maxRides = 3;

  /// Searches for one plan: each takes a few milliseconds
  static const int maxSearches = 16;

  /// Places closer than this are only walked
  static const double walkOnlyMeters = 400;

  /// Walking beats the bus up to this far, so it is offered alongside
  static const double walkOptionMeters = 1500;

  static double _walkSeconds(double meters) =>
      meters * WalkLeg.detour / WalkLeg.speed;

  /// Options from [from] to [to], best first. Lines in [leaveOut] are not
  /// used, such as those not running at the time.
  List<TripOption> plan(
    TripPlace from,
    TripPlace to, {
    Set<String> leaveOut = const {},
    int limit = 5,
  }) {
    final straight = metersBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    final walk = _walkOnly(from, to);
    if (straight <= walkOnlyMeters) return [walk];

    // One search only finds the fastest way with each number of buses.
    // Leaving out the lines of every trip found, one more at a time,
    // brings up the others, such as a slower feeder that reaches the
    // same transfer a little later.
    final found = <TripOption>[];
    final tried = <String>{};
    final queue = [leaveOut];
    var searches = 0;
    while (queue.isNotEmpty && searches < maxSearches) {
      final out = queue.removeAt(0);
      if (!tried.add((out.toList()..sort()).join(','))) continue;
      searches++;
      for (final option in _search(from, to, out)) {
        found.add(option);
        for (final ride in option.rides) {
          queue.add({...out, ride.line});
        }
      }
    }
    if (straight <= walkOptionMeters) found.add(walk);

    final ranked = _ranked(found);
    if (ranked.isEmpty) return const [];

    // Options far worse than the best only fill the list
    final cutoff = cost(ranked.first) * 1.6 + 600;
    final kept = <TripOption>[];
    final seen = <String>{};
    for (final option in ranked) {
      if (cost(option) > cutoff || !seen.add(option.signature)) continue;
      final twin = kept.indexWhere((k) => _sameRide(k, option));
      if (twin >= 0) {
        kept[twin] = _merged(kept[twin], option);
      } else if (!kept.any((k) => _hopsOnto(option, k))) {
        kept.add(option);
      }
    }
    return kept.take(limit).toList(growable: false);
  }

  /// A ride this short only saves a few steps
  static const int _hopStops = 2;

  /// Whether [option] takes a hop of a stop or two to board the main ride
  /// of [other], which gets there with fewer buses: the same trip with a
  /// bus more, not another way to go
  static bool _hopsOnto(TripOption option, TripOption other) {
    if (other.rides.isEmpty || option.rides.length <= other.rides.length) {
      return false;
    }
    final main = _mainRide(option);
    final hops = option.rides.any(
      (r) => !identical(r, main) && r.stopCount <= _hopStops,
    );
    if (!hops) return false;
    final theirs = _mainRide(other);
    return main.lines.any(theirs.lines.contains) &&
        samePlace(main.alight, theirs.alight);
  }

  /// The longest ride, which the others lead to or from
  static RideLeg _mainRide(TripOption option) =>
      option.rides.reduce((a, b) => b.duration > a.duration ? b : a);

  /// Lines sharing a stretch of road board and leave at the same stop,
  /// or at platforms of one station: one option with either line reads
  /// better than two nearly equal rows
  static bool _sameRide(TripOption a, TripOption b) {
    final ridesA = a.rides.toList();
    final ridesB = b.rides.toList();
    if (ridesA.isEmpty || ridesA.length != ridesB.length) return false;
    if ((a.duration - b.duration).abs() > _twinSlack) return false;

    for (var i = 0; i < ridesA.length; i++) {
      if (!samePlace(ridesA[i].board, ridesB[i].board) ||
          !samePlace(ridesA[i].alight, ridesB[i].alight)) {
        return false;
      }
    }
    return true;
  }

  static const Duration _twinSlack = Duration(minutes: 3);

  static TripOption _merged(TripOption kept, TripOption twin) {
    final others = twin.rides.toList();
    var i = 0;
    return TripOption([
      for (final leg in kept.legs)
        if (leg is RideLeg) leg.withVariant(others[i++]) else leg,
    ]);
  }

  /// How an option ranks, lower first: its time, a few minutes for each
  /// change of bus, and half again the time on foot
  static double cost(TripOption option) =>
      option.duration.inSeconds +
      option.transfers * transferPenalty.inSeconds +
      option.legs.whereType<WalkLeg>().fold(
            0,
            (sum, walk) => sum + walk.duration.inSeconds,
          ) *
          walkReluctance;

  static List<TripOption> _ranked(List<TripOption> options) =>
      [...options]..sort((a, b) => cost(a).compareTo(cost(b)));

  TripOption _walkOnly(TripPlace from, TripPlace to) => TripOption([
    WalkLeg.between(from.latitude, from.longitude, to.latitude, to.longitude),
  ]);

  /// The fastest trip with each number of buses, as long as it beats
  /// every trip with fewer
  List<TripOption> _search(TripPlace from, TripPlace to, Set<String> leaveOut) {
    var access = network._near(from.latitude, from.longitude, accessMeters);
    var egress = network._near(to.latitude, to.longitude, accessMeters);
    if (access.isEmpty) {
      access = network._near(from.latitude, from.longitude, widerAccessMeters);
    }
    if (egress.isEmpty) {
      egress = network._near(to.latitude, to.longitude, widerAccessMeters);
    }
    if (access.isEmpty || egress.isEmpty) return const [];

    final count = network.stops.length;
    final best = List.filled(count, double.infinity);

    // Per round: arrival by bus and on foot, and how each was reached
    final byRide = <List<double>>[List.filled(count, double.infinity)];
    final byWalk = <List<double>>[List.filled(count, double.infinity)];
    final rides = <List<_Ride?>>[List.filled(count, null)];
    final walksFrom = <List<int>>[List.filled(count, -1)];

    var marked = <int>{};
    for (final a in access) {
      final seconds = _walkSeconds(a.meters);
      byWalk[0][a.stop] = seconds;
      best[a.stop] = seconds;
      marked.add(a.stop);
    }

    final options = <TripOption>[];
    var bestArrival = double.infinity;

    for (var round = 1; round <= maxRides && marked.isNotEmpty; round++) {
      final previousRide = byRide[round - 1];
      final previousWalk = byWalk[round - 1];
      final ride = List.filled(count, double.infinity);
      final walk = List.filled(count, double.infinity);
      final rideFrom = List<_Ride?>.filled(count, null);
      final walkFrom = List.filled(count, -1);
      byRide.add(ride);
      byWalk.add(walk);
      rides.add(rideFrom);
      walksFrom.add(walkFrom);

      // Each pattern from the earliest stop along it reached last round
      final queue = <int, int>{};
      for (final stop in marked) {
        for (final served in network._servedBy[stop]) {
          if (leaveOut.contains(network._patterns[served.pattern].line)) {
            continue;
          }
          final known = queue[served.pattern];
          if (known == null || served.position < known) {
            queue[served.pattern] = served.position;
          }
        }
      }

      final reached = <int>{};
      for (final MapEntry(key: p, value: start) in queue.entries) {
        final pattern = network._patterns[p];
        final wait = typicalWait(pattern.line, headways).inSeconds.toDouble();
        final pace = rideFactors[pattern.line] ?? 1.0;
        var boardPosition = -1;
        var boardedAt = 0.0;

        for (
          var position = start;
          position < pattern.stops.length;
          position++
        ) {
          final stop = pattern.stops[position];

          if (boardPosition >= 0) {
            final arrival =
                boardedAt +
                (pattern.seconds[position] - pattern.seconds[boardPosition]) *
                    pace;
            if (arrival < best[stop]) {
              best[stop] = arrival;
              ride[stop] = arrival;
              rideFrom[stop] = _Ride(p, boardPosition, position);
              reached.add(stop);
            }
          }

          // Boarding here instead, if that gets further sooner
          final here = math.min(previousRide[stop], previousWalk[stop]);
          if (here.isFinite) {
            final board = here + wait;
            if (boardPosition < 0 ||
                board - pattern.seconds[position] * pace <
                    boardedAt - pattern.seconds[boardPosition] * pace) {
              boardPosition = position;
              boardedAt = board;
            }
          }
        }
      }

      // A short walk to change buses, only right after a ride
      final walked = <int>{};
      for (final stop in reached) {
        for (final near in network._walks[stop]) {
          final arrival = ride[stop] + _walkSeconds(near.meters);
          if (arrival < best[near.stop]) {
            best[near.stop] = arrival;
            walk[near.stop] = arrival;
            walkFrom[near.stop] = stop;
            walked.add(near.stop);
          }
        }
      }
      marked = {...reached, ...walked};

      // Off the bus and on foot to the destination
      var arrival = double.infinity;
      var last = -1;
      for (final e in egress) {
        final total = ride[e.stop] + _walkSeconds(e.meters);
        if (total < arrival) {
          arrival = total;
          last = e.stop;
        }
      }
      if (last >= 0 && arrival < bestArrival) {
        bestArrival = arrival;
        options.add(
          _trace(from, to, round, last, byRide, byWalk, rides, walksFrom),
        );
      }
    }

    return options;
  }

  /// Walk the labels back from the last stop to the origin, gathering
  /// the rides; the walks between them follow from where they stop
  TripOption _trace(
    TripPlace from,
    TripPlace to,
    int round,
    int last,
    List<List<double>> byRide,
    List<List<double>> byWalk,
    List<List<_Ride?>> rides,
    List<List<int>> walksFrom,
  ) {
    final found = <RideLeg>[];
    var stop = last;
    var onBus = true;
    while (round > 0) {
      if (!onBus) {
        stop = walksFrom[round][stop];
        onBus = true;
        continue;
      }

      final ride = rides[round][stop]!;
      final pattern = network._patterns[ride.pattern];
      found.add(
        RideLeg(
          line: pattern.line,
          towards: pattern.towards,
          stops: pattern.route.sublist(
            ride.boardPosition,
            ride.alightPosition + 1,
          ),
          wait: typicalWait(pattern.line, headways),
          duration: Duration(
            seconds:
                ((pattern.seconds[ride.alightPosition] -
                            pattern.seconds[ride.boardPosition]) *
                        (rideFactors[pattern.line] ?? 1.0))
                    .round(),
          ),
        ),
      );
      stop = pattern.stops[ride.boardPosition];
      round--;
      onBus = byRide[round][stop] <= byWalk[round][stop];
    }

    return TripOption.through(
      fromLatitude: from.latitude,
      fromLongitude: from.longitude,
      rides: found.reversed.toList(),
      toLatitude: to.latitude,
      toLongitude: to.longitude,
    );
  }
}
