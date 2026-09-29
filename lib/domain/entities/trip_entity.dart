import 'dart:math' as math;

import 'line_entity.dart';

/// Distance in metres, flat-earth: exact enough across one city
double metersBetween(double lat1, double lon1, double lat2, double lon2) {
  const metresPerDegree = 111320.0;
  final dy = (lat2 - lat1) * metresPerDegree;
  final dx =
      (lon2 - lon1) *
      metresPerDegree *
      math.cos((lat1 + lat2) / 2 * math.pi / 180);
  return math.sqrt(dx * dx + dy * dy);
}

/// Where a trip starts or ends
class TripPlace {
  final double latitude;
  final double longitude;
  final String name;

  /// The device's own position, named by the screen showing it
  final bool isDevice;

  const TripPlace({
    required this.latitude,
    required this.longitude,
    required this.name,
    this.isDevice = false,
  });
}

/// One stretch of a trip, on foot or on a bus
sealed class TripLeg {
  const TripLeg();

  /// Time spent on the leg, waiting included
  Duration get total;
}

/// A walk, to a stop or from one
class WalkLeg extends TripLeg {
  final double fromLatitude;
  final double fromLongitude;
  final double toLatitude;
  final double toLongitude;

  /// Estimated walking distance, longer than the straight line
  final double meters;
  final Duration duration;

  /// Stop walked to; null for the last walk, to the destination
  final LineStop? toStop;

  const WalkLeg({
    required this.fromLatitude,
    required this.fromLongitude,
    required this.toLatitude,
    required this.toLongitude,
    required this.meters,
    required this.duration,
    this.toStop,
  });

  /// Walking pace, in metres a second: an unhurried 3.6 km/h, with
  /// crossings, bags and the heat of Cali
  static const double speed = 1.0;

  /// Sidewalks bend: a walk is longer than the straight line
  static const double detour = 1.3;

  static Duration timeFor(double straightMeters) =>
      Duration(seconds: (straightMeters * detour / speed).round());

  /// A walk between two points, estimated from the straight line
  factory WalkLeg.between(
    double fromLatitude,
    double fromLongitude,
    double toLatitude,
    double toLongitude, {
    LineStop? toStop,
  }) {
    final straight = metersBetween(
      fromLatitude,
      fromLongitude,
      toLatitude,
      toLongitude,
    );
    return WalkLeg(
      fromLatitude: fromLatitude,
      fromLongitude: fromLongitude,
      toLatitude: toLatitude,
      toLongitude: toLongitude,
      meters: straight * detour,
      duration: timeFor(straight),
      toStop: toStop,
    );
  }

  @override
  Duration get total => duration;
}

/// A ride on one line, from the stop boarded at to the one left at
class RideLeg extends TripLeg {
  final String line;

  /// Last stop of the line this way, as the bus announces it
  final String towards;

  /// Every stop from boarding to getting off, both included
  final List<LineStop> stops;

  /// Wait for the bus: a live bus's when timed against one, otherwise
  /// what the line usually takes
  final Duration wait;
  final Duration duration;

  /// When the bus leaves the stop; null until the trip is timed
  final DateTime? departsAt;

  /// Whether [wait] comes from a bus on its way, rather than the usual
  final bool liveWait;

  /// Whether [duration] comes from following that bus to the stop got
  /// off at, rather than the estimate from the route
  final bool liveRide;

  /// Every line that makes this ride, this one among them, each with its
  /// own platforms and stops; empty when only one line does. Kept in the
  /// order found, so choosing one does not shuffle the others.
  final List<RideLeg> variants;

  const RideLeg({
    required this.line,
    required this.towards,
    required this.stops,
    required this.wait,
    required this.duration,
    this.variants = const [],
    this.departsAt,
    this.liveWait = false,
    this.liveRide = false,
  });

  /// The same ride timed: against a live bus, or by the usual figures
  RideLeg timed({
    required Duration wait,
    required Duration duration,
    required DateTime departsAt,
    required bool liveWait,
    required bool liveRide,
  }) => RideLeg(
    line: line,
    towards: towards,
    stops: stops,
    wait: wait,
    duration: duration,
    variants: variants,
    departsAt: departsAt,
    liveWait: liveWait,
    liveRide: liveRide,
  );

  /// Every line that makes the ride
  List<String> get lines =>
      variants.isEmpty ? [line] : [for (final v in variants) v.line];

  RideLeg get _alone => RideLeg(
    line: line,
    towards: towards,
    stops: stops,
    wait: wait,
    duration: duration,
  );

  /// The same ride, also made by [other] and whatever lines make it
  RideLeg withVariant(RideLeg other) {
    final known = variants.isEmpty ? [_alone] : variants;
    final lines = {for (final v in known) v.line};
    return RideLeg(
      line: line,
      towards: towards,
      stops: stops,
      wait: wait,
      duration: duration,
      variants: [
        ...known,
        for (final v
            in other.variants.isEmpty ? [other._alone] : other.variants)
          if (lines.add(v.line)) v,
      ],
    );
  }

  /// The same ride made by [line], one of [lines]
  RideLeg choose(String line) {
    final chosen = variants.firstWhere((v) => v.line == line);
    return RideLeg(
      line: chosen.line,
      towards: chosen.towards,
      stops: chosen.stops,
      wait: chosen.wait,
      duration: chosen.duration,
      variants: variants,
    );
  }

  LineStop get board => stops.first;
  LineStop get alight => stops.last;

  /// Stops ridden past, the one got off at included
  int get stopCount => stops.length - 1;

  @override
  Duration get total => wait + duration;
}

/// A way to get from one place to another
class TripOption {
  final List<TripLeg> legs;

  /// When the trip was timed from; null until it is
  final DateTime? startsAt;

  const TripOption(this.legs, {this.startsAt});

  /// When the trip ends, once timed
  DateTime? get arrivesAt => startsAt?.add(duration);

  /// On foot from the origin to the first bus, between buses where they
  /// stop apart, and from the last one to the destination
  factory TripOption.through({
    required double fromLatitude,
    required double fromLongitude,
    required List<RideLeg> rides,
    required double toLatitude,
    required double toLongitude,
    DateTime? startsAt,
  }) {
    final legs = <TripLeg>[
      WalkLeg.between(
        fromLatitude,
        fromLongitude,
        rides.first.board.latitude,
        rides.first.board.longitude,
        toStop: rides.first.board,
      ),
    ];
    for (final (i, ride) in rides.indexed) {
      legs.add(ride);
      if (i == rides.length - 1) break;
      final next = rides[i + 1].board;
      if (next.stopId != ride.alight.stopId) {
        legs.add(
          WalkLeg.between(
            ride.alight.latitude,
            ride.alight.longitude,
            next.latitude,
            next.longitude,
            toStop: next,
          ),
        );
      }
    }
    legs.add(
      WalkLeg.between(
        rides.last.alight.latitude,
        rides.last.alight.longitude,
        toLatitude,
        toLongitude,
      ),
    );
    return TripOption(legs, startsAt: startsAt);
  }

  /// The same trip with ride [rideIndex] made by [line]: the walks around
  /// it follow, since its platforms may differ
  TripOption choose(int rideIndex, String line) {
    final rides = this.rides.toList();
    rides[rideIndex] = rides[rideIndex].choose(line);
    final first = legs.first as WalkLeg;
    final last = legs.last as WalkLeg;
    return TripOption.through(
      fromLatitude: first.fromLatitude,
      fromLongitude: first.fromLongitude,
      rides: rides,
      toLatitude: last.toLatitude,
      toLongitude: last.toLongitude,
    );
  }

  Duration get duration =>
      legs.fold(Duration.zero, (sum, leg) => sum + leg.total);

  Iterable<RideLeg> get rides => legs.whereType<RideLeg>();

  /// Every wait and ride timed against a bus on its way
  bool get isLive => rides.every((r) => r.liveWait && r.liveRide);

  RideLeg? get firstRide => rides.firstOrNull;

  int get transfers => rides.isEmpty ? 0 : rides.length - 1;

  double get walkMeters =>
      legs.whereType<WalkLeg>().fold(0.0, (sum, leg) => sum + leg.meters);

  /// The lines taken, in order: two options on the same lines differ
  /// only in where they are boarded, which is not worth a second row
  String get signature => rides.map((r) => r.line).join('>');
}
