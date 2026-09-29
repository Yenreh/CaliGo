import 'entities/line_entity.dart';
import 'entities/stop_entity.dart';
import 'entities/trip_entity.dart';
import 'trip_planner.dart';

/// How long a wait for [line] usually is when no bus is known: half the
/// time between its buses when that has been seen, otherwise a figure
/// by kind of line (trunk lines run most often, feeders least)
Duration typicalWait(String line, [Map<String, Duration> headways = const {}]) {
  final headway = headways[line];
  if (headway != null) return headway ~/ 2;
  return switch (line.isEmpty ? '' : line[0]) {
    'T' || 'E' => const Duration(minutes: 3),
    'P' => const Duration(minutes: 5),
    _ => const Duration(minutes: 7),
  };
}

/// The buses on their way to the stops a trip calls at, as the arrivals
/// service reported them.
///
/// The service lists the next five buses of a stop at most, whatever
/// their line, and leaves out a stop with none: a line missing from a
/// busy stop may well be coming, only after those five.
class LiveArrivals {
  /// When the oldest answer asked for last was fetched
  final DateTime fetchedAt;

  /// Every stop seen, with its buses
  final List<NearbyStop> stops;

  /// Whether some area could not be asked about
  final bool failed;

  const LiveArrivals({
    required this.fetchedAt,
    required this.stops,
    this.failed = false,
  });

  static final LiveArrivals none = LiveArrivals(
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
    stops: const [],
  );

  /// These arrivals, and those of [older] for the stops not asked about
  /// again: an answer for one option leaves the rest of the list as it
  /// was. Buses already gone drop out of the timing by themselves.
  LiveArrivals over(LiveArrivals? older) {
    if (older == null) return this;
    final asked = {for (final stop in stops) stop.id};
    return LiveArrivals(
      fetchedAt: fetchedAt,
      stops: [
        ...stops,
        for (final stop in older.stops)
          if (!asked.contains(stop.id)) stop,
      ],
      failed: failed,
    );
  }

  /// The first bus of [line] leaving [board] at or after [after].
  ///
  /// The routes do not always name a station's platforms as the live
  /// service does, so a bus at another platform of the station also
  /// counts, but only when it is then seen at [alight]: a bus at the
  /// platform across serves the other direction and never gets there.
  BusArrival? nextBus(
    String line,
    LineStop board,
    LineStop alight,
    DateTime after,
  ) {
    BusArrival? best;
    for (final stop in stops) {
      final exact = stop.id == board.stopId;
      if (!exact && !_sameStation(stop, board)) continue;
      for (final bus in stop.arrivals) {
        if (bus.line != line || bus.arrivalTime.isBefore(after)) continue;
        if (!exact &&
            reachedAt(bus.vehicleId, alight, bus.arrivalTime) == null) {
          continue;
        }
        if (best == null || bus.arrivalTime.isBefore(best.arrivalTime)) {
          best = bus;
        }
      }
    }
    return best;
  }

  /// When [vehicleId] reaches [stop], or any platform of its station,
  /// after [after]; null when it is not seen there
  DateTime? reachedAt(String vehicleId, LineStop stop, DateTime after) {
    if (vehicleId.isEmpty) return null;
    DateTime? best;
    for (final seen in stops) {
      if (seen.id != stop.stopId && !_sameStation(seen, stop)) continue;
      for (final bus in seen.arrivals) {
        if (bus.vehicleId != vehicleId || !bus.arrivalTime.isAfter(after)) {
          continue;
        }
        if (best == null || bus.arrivalTime.isBefore(best)) {
          best = bus.arrivalTime;
        }
      }
    }
    return best;
  }

  static bool _sameStation(NearbyStop seen, LineStop stop) {
    final station = stationOf(stop.name);
    return station != null && station == stationOf(seen.name);
  }
}

/// [option] timed from [start]: each wait against the first live bus
/// that can still be caught, each ride by following that bus to where it
/// is left, and the usual figures wherever no bus is known. Of the lines
/// making a ride, the one arriving first is taken, unless [pinned] names
/// one for that ride, by its position among the rides.
TripOption timeTrip(
  TripOption option, {
  required DateTime start,
  LiveArrivals? live,
  Map<String, Duration> headways = const {},
  Map<int, String> pinned = const {},
}) {
  final rides = option.rides.toList();
  if (rides.isEmpty) return TripOption(option.legs, startsAt: start);

  final origin = option.legs.first as WalkLeg;
  final destination = option.legs.last as WalkLeg;
  var at = start;
  var fromLatitude = origin.fromLatitude;
  var fromLongitude = origin.fromLongitude;
  final timed = <RideLeg>[];

  for (final (i, ride) in rides.indexed) {
    final lines = switch (pinned[i]) {
      final line? when ride.lines.contains(line) => [line],
      _ => ride.lines,
    };

    RideLeg? best;
    DateTime? bestArrival;
    for (final line in lines) {
      final variant = ride.variants.isEmpty ? ride : ride.choose(line);
      final walk = WalkLeg.between(
        fromLatitude,
        fromLongitude,
        variant.board.latitude,
        variant.board.longitude,
      );
      final atStop = at.add(walk.duration);

      final bus = live?.nextBus(line, variant.board, variant.alight, atStop);
      final DateTime departs;
      final DateTime arrives;
      final bool liveRide;
      if (bus != null) {
        departs = bus.arrivalTime;
        final reached = live!.reachedAt(bus.vehicleId, variant.alight, departs);
        liveRide = reached != null;
        arrives = reached ?? departs.add(variant.duration);
      } else {
        departs = atStop.add(typicalWait(line, headways));
        liveRide = false;
        arrives = departs.add(variant.duration);
      }

      if (bestArrival == null || arrives.isBefore(bestArrival)) {
        bestArrival = arrives;
        best = variant.timed(
          wait: departs.difference(atStop),
          duration: arrives.difference(departs),
          departsAt: departs,
          liveWait: bus != null,
          liveRide: liveRide,
        );
      }
    }

    timed.add(best!);
    at = bestArrival!;
    fromLatitude = best.alight.latitude;
    fromLongitude = best.alight.longitude;
  }

  return TripOption.through(
    fromLatitude: origin.fromLatitude,
    fromLongitude: origin.fromLongitude,
    rides: timed,
    toLatitude: destination.toLatitude,
    toLongitude: destination.toLongitude,
    startsAt: start,
  );
}

/// Rides shorter than this say little of how a line runs: a minute either
/// way would swing them
const Duration _readableRide = Duration(minutes: 5);

/// How long each ride of [timed] took by following its bus, against what
/// its route alone estimates: the live time over the estimate it had in
/// [planned], the same option before timing, with the [rideFactors] it
/// was planned with taken back out. By line.
Map<String, double> rideReadings(
  TripOption planned,
  TripOption timed, {
  Map<String, double> rideFactors = const {},
}) {
  final estimates = planned.rides.toList();
  final readings = <String, double>{};
  for (final (i, ride) in timed.rides.indexed) {
    if (!ride.liveRide || i >= estimates.length) continue;
    final estimate = estimates[i].variants.isEmpty
        ? estimates[i]
        : estimates[i].choose(ride.line);
    if (estimate.duration < _readableRide) continue;
    readings[ride.line] =
        ride.duration.inSeconds *
        (rideFactors[ride.line] ?? 1.0) /
        estimate.duration.inSeconds;
  }
  return readings;
}

/// The stops a set of options calls at while buses could already be on
/// their way to them: the service lists buses up to about this far ahead
List<LineStop> stopsWorthAsking(
  Iterable<TripOption> options, {
  required DateTime start,
  Duration horizon = const Duration(minutes: 50),
  Map<String, Duration> headways = const {},
}) {
  final byId = <String, LineStop>{};
  final until = start.add(horizon);
  for (final option in options) {
    final rough = timeTrip(option, start: start, headways: headways);
    for (final (i, ride) in option.rides.indexed) {
      final departs = rough.rides.elementAt(i).departsAt;
      if (departs != null && departs.isAfter(until)) continue;
      for (final variant in ride.variants.isEmpty ? [ride] : ride.variants) {
        byId[variant.board.stopId] = variant.board;
        byId[variant.alight.stopId] = variant.alight;
      }
    }
  }
  return byId.values.toList(growable: false);
}
