import 'package:caligo/domain/entities/line_entity.dart';
import 'package:caligo/domain/entities/stop_entity.dart';
import 'package:caligo/domain/entities/trip_entity.dart';
import 'package:caligo/domain/trip_timing.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime(2026, 9, 29, 10, 0);

LineStop _stop(String id, String name, double east) => LineStop(
  stopId: id,
  name: name,
  latitude: 3.45,
  longitude: -76.53 + east,
  direction: 0,
  sequence: 1,
);

/// From a point 120 m west of [board] to one next to [alight]
TripOption _trip(List<RideLeg> rides) => TripOption.through(
  fromLatitude: 3.45,
  fromLongitude: rides.first.board.longitude - 0.0011,
  rides: rides,
  toLatitude: 3.45,
  toLongitude: rides.last.alight.longitude,
);

RideLeg _ride(String line, LineStop board, LineStop alight) => RideLeg(
  line: line,
  towards: 'End',
  stops: [board, alight],
  wait: typicalWait(line),
  duration: const Duration(minutes: 15),
);

BusArrival _bus(String line, String vehicle, int minutes) => BusArrival(
  line: line,
  destination: 'End',
  arrivalTime: _start.add(Duration(minutes: minutes)),
  vehicleId: vehicle,
);

LiveArrivals _live(Map<LineStop, List<BusArrival>> byStop) => LiveArrivals(
  fetchedAt: _start,
  stops: [
    for (final MapEntry(key: stop, value: buses) in byStop.entries)
      NearbyStop(
        id: stop.stopId,
        name: stop.name,
        distanceMeters: 0,
        arrivals: buses,
      ),
  ],
);

void main() {
  final board = _stop('b', 'Cl 5 entre Kr 1 y 2', 0);
  final alight = _stop('a', 'Cl 5 entre Kr 30 y 31', 0.05);

  test('waits for the live bus and rides until that bus gets there', () {
    final timed = timeTrip(
      _trip([_ride('T1', board, alight)]),
      start: _start,
      live: _live({
        board: [_bus('T1', 'v1', 8)],
        alight: [_bus('T1', 'v1', 20)],
      }),
    );
    final ride = timed.firstRide!;

    expect(ride.departsAt, _start.add(const Duration(minutes: 8)));
    expect(ride.duration, const Duration(minutes: 12));
    expect(ride.liveWait, isTrue);
    expect(ride.liveRide, isTrue);
    expect(timed.isLive, isTrue);
  });

  test('takes the next bus when the first leaves before one gets there', () {
    final timed = timeTrip(
      _trip([_ride('T1', board, alight)]),
      start: _start,
      live: _live({
        // The walk to the stop takes about two minutes
        board: [_bus('T1', 'v1', 1), _bus('T1', 'v2', 9)],
      }),
    );

    expect(timed.firstRide!.departsAt, _start.add(const Duration(minutes: 9)));
    // Not seen where it is left: the ride is the estimate
    expect(timed.firstRide!.liveRide, isFalse);
    expect(timed.firstRide!.duration, const Duration(minutes: 15));
  });

  test('falls back to the usual wait when no bus is on its way', () {
    final timed = timeTrip(_trip([_ride('A9', board, alight)]), start: _start);

    expect(timed.firstRide!.wait, const Duration(minutes: 7));
    expect(timed.firstRide!.liveWait, isFalse);
    expect(timed.isLive, isFalse);
  });

  test('uses half the learned time between buses as the usual wait', () {
    final timed = timeTrip(
      _trip([_ride('A9', board, alight)]),
      start: _start,
      headways: {'A9': const Duration(minutes: 12)},
    );

    expect(timed.firstRide!.wait, const Duration(minutes: 6));
  });

  group('lines sharing a ride', () {
    final shared = _ride(
      'T1',
      board,
      alight,
    ).withVariant(_ride('T2', board, alight));
    final live = _live({
      board: [_bus('T1', 'v1', 12), _bus('T2', 'v2', 4)],
    });

    test('takes the one that comes first', () {
      final timed = timeTrip(_trip([shared]), start: _start, live: live);

      expect(timed.firstRide!.line, 'T2');
      expect(timed.firstRide!.lines, ['T1', 'T2']);
    });

    test('keeps the one chosen by hand', () {
      final timed = timeTrip(
        _trip([shared]),
        start: _start,
        live: live,
        pinned: {0: 'T1'},
      );

      expect(timed.firstRide!.line, 'T1');
      expect(
        timed.firstRide!.departsAt,
        _start.add(const Duration(minutes: 12)),
      );
    });
  });

  test('counts a bus at another platform only if it gets where needed', () {
    final platform = _stop('b1', 'Centro B1', 0);
    final across = _stop('b2', 'Centro B2', 0.0002);
    final end = _stop('e', 'Norte A1', 0.05);
    final timed = timeTrip(
      _trip([_ride('T1', platform, end)]),
      start: _start,
      live: _live({
        // The platform across: one bus heads the other way, one does
        // reach the end
        across: [_bus('T1', 'away', 3), _bus('T1', 'v9', 6)],
        end: [_bus('T1', 'v9', 25)],
      }),
    );

    expect(timed.firstRide!.departsAt, _start.add(const Duration(minutes: 6)));
    expect(timed.firstRide!.liveRide, isTrue);
  });


  test('an answer for one option keeps what the others had', () {
    final other = _stop('o', 'Cl 9 entre Kr 5 y 4', 0.01);
    final older = _live({
      board: [_bus('T1', 'v1', 8)],
      other: [_bus('A9', 'v7', 5)],
    });
    final newer = _live({
      board: [_bus('T1', 'v1', 6)],
    });

    final merged = newer.over(older);

    expect(
      {for (final s in merged.stops) s.id: s.arrivals.single.vehicleId},
      {'b': 'v1', 'o': 'v7'},
    );
    expect(
      merged.stops.firstWhere((s) => s.id == 'b').arrivals.single.arrivalTime,
      _start.add(const Duration(minutes: 6)),
    );
  });

  test('reads how a followed ride ran against its estimate', () {
    final planned = _trip([_ride('T1', board, alight)]);
    final timed = timeTrip(
      planned,
      start: _start,
      live: _live({
        board: [_bus('T1', 'v1', 8)],
        alight: [_bus('T1', 'v1', 26)],
      }),
    );

    // 18 minutes against the 15 of the estimate
    expect(rideReadings(planned, timed), {'T1': closeTo(1.2, 1e-9)});
    // Timed by the usual figures, a ride says nothing
    expect(rideReadings(planned, timeTrip(planned, start: _start)), isEmpty);
    // Planned already a fifth slower, the route alone read 18 against 12.5
    expect(
      rideReadings(planned, timed, rideFactors: {'T1': 1.2}),
      {'T1': closeTo(1.44, 1e-9)},
    );
  });
}
