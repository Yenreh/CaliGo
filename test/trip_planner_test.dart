import 'package:caligo/domain/entities/line_entity.dart';
import 'package:caligo/domain/entities/trip_entity.dart';
import 'package:caligo/domain/trip_planner.dart';
import 'package:flutter_test/flutter_test.dart';

const _lat = 3.45;
const _lon = -76.53;

/// About 440 m between stops
const _step = 0.004;

/// A line running one way through stops at the given offsets, in steps
/// east (x) and north (y) of the origin
List<LineStop> _line(String prefix, List<(num, num)> points) => [
  for (final (i, (x, y)) in points.indexed)
    LineStop(
      stopId: '$prefix$i',
      name: '$prefix $i',
      latitude: _lat + y * _step,
      longitude: _lon + x * _step,
      direction: 0,
      sequence: i + 1,
    ),
];

TripPlace _at(num x, num y) => TripPlace(
  latitude: _lat + y * _step,
  longitude: _lon + x * _step,
  name: '($x, $y)',
);

List<(num, num)> _east(int from, int to, {num y = 0}) => [
  for (var x = from; x <= to; x++) (x, y),
];

List<(num, num)> _north(int from, int to, {num x = 0}) => [
  for (var y = from; y <= to; y++) (x, y),
];

void main() {
  test('rides one line when it goes all the way', () {
    final planner = TripPlanner(
      TransitNetwork.fromRoutes({'T1': _line('a', _east(0, 12))}),
    );

    final best = planner.plan(_at(0, 0.5), _at(12, 0.5)).first;

    expect(best.rides.map((r) => r.line), ['T1']);
    expect(best.firstRide!.board.stopId, 'a0');
    expect(best.firstRide!.alight.stopId, 'a12');
    expect(best.legs.first, isA<WalkLeg>());
    expect(best.legs.last, isA<WalkLeg>());
    expect(best.transfers, 0);
  });

  test('changes buses where two lines meet', () {
    final planner = TripPlanner(
      TransitNetwork.fromRoutes({
        'T1': _line('a', _east(0, 10)),
        // Crosses T1 at (10, 0) and heads north
        'P2': _line('b', _north(0, 10, x: 10)),
      }),
    );

    final best = planner.plan(_at(0, 0), _at(10, 10)).first;

    expect(best.rides.map((r) => r.line), ['T1', 'P2']);
    expect(best.transfers, 1);
  });

  test('walks between nearby stops to change buses', () {
    final planner = TripPlanner(
      TransitNetwork.fromRoutes({
        'T1': _line('a', _east(0, 10)),
        // Starts 180 m north of T1's last stop
        'P2': _line('b', [
          for (final (x, y) in _north(0, 10, x: 10)) (x, y + 0.4),
        ]),
      }),
    );

    final best = planner.plan(_at(0, 0), _at(10, 10.4)).first;
    final walks = best.legs.whereType<WalkLeg>().toList();

    expect(best.rides.map((r) => r.line), ['T1', 'P2']);
    expect(walks.where((w) => w.toStop?.stopId == 'b0'), hasLength(1));
  });

  test('offers lines sharing the same stops as one option', () {
    final route = _east(0, 10);
    final network = TransitNetwork.fromRoutes({
      'T1': _line('a', route),
      'T2': [
        for (final s in _line('a', route))
          LineStop(
            stopId: s.stopId,
            name: s.name,
            latitude: s.latitude,
            longitude: s.longitude,
            direction: 1,
            sequence: s.sequence,
          ),
      ],
    });

    final options = TripPlanner(network).plan(_at(0, 0), _at(10, 0));

    expect(options.first.firstRide!.lines, unorderedEquals(['T1', 'T2']));
    expect(options.where((o) => o.rides.isNotEmpty).length, 1);
  });

  test('shows a slower feeder that reaches the same transfer later', () {
    List<LineStop> named(String prefix, List<(num, num)> points, String last) {
      final stops = _line(prefix, points);
      return [
        for (final (i, s) in stops.indexed)
          LineStop(
            stopId: s.stopId,
            name: i == stops.length - 1 ? last : s.name,
            latitude: s.latitude,
            longitude: s.longitude,
            direction: 0,
            sequence: s.sequence,
          ),
      ];
    }

    final planner = TripPlanner(
      TransitNetwork.fromRoutes({
        // Two ways to the hub at (8, 0): a trunk line and a feeder just
        // north of it, each to its own platform
        'T1': named('a', _east(0, 8), 'Hub B1'),
        'A2': named('c', _east(0, 8, y: 0.3), 'Hub B2'),
        'T3': _line('d', _north(0, 10, x: 8.2)),
      }),
    );

    final options = planner.plan(_at(0, 0.15), _at(8.2, 10), limit: 10);
    final firstLines = options.expand((o) => o.firstRide?.lines ?? []);

    expect(firstLines, containsAll(['T1', 'A2']));
  });

  test('merges lines leaving from platforms of one station', () {
    LineStop stop(String id, String name, num x, num y, int sequence) =>
        LineStop(
          stopId: id,
          name: name,
          latitude: _lat + y * _step,
          longitude: _lon + x * _step,
          direction: 0,
          sequence: sequence,
        );

    final network = TransitNetwork.fromRoutes({
      'T1': [
        stop('s1', 'Centro B1', 0, 0, 1),
        for (var x = 1; x < 10; x++) stop('m$x', 'Road $x', x, 0, x + 1),
        stop('e1', 'Norte A1', 10, 0, 11),
      ],
      'T2': [
        stop('s2', 'Centro B2', 0, 0.2, 1),
        for (var x = 1; x < 10; x++) stop('n$x', 'Lane $x', x, 0.2, x + 1),
        stop('e2', 'Norte A2', 10, 0.2, 11),
      ],
    });

    final options = TripPlanner(network).plan(_at(0, 0.1), _at(10, 0.1));
    final rides = options.where((o) => o.rides.isNotEmpty).toList();

    expect(rides, hasLength(1));
    expect(rides.single.firstRide!.lines, unorderedEquals(['T1', 'T2']));
  });

  test('choosing another line of a ride follows its own platforms', () {
    LineStop stop(String id, String name, num x, num y, int sequence) =>
        LineStop(
          stopId: id,
          name: name,
          latitude: _lat + y * _step,
          longitude: _lon + x * _step,
          direction: 0,
          sequence: sequence,
        );

    final network = TransitNetwork.fromRoutes({
      'T1': [
        stop('s1', 'Centro B1', 0, 0, 1),
        for (var x = 1; x < 10; x++) stop('m$x', 'Road $x', x, 0, x + 1),
        stop('e1', 'Norte A1', 10, 0, 11),
      ],
      'T2': [
        stop('s2', 'Centro B2', 0, 0.2, 1),
        for (var x = 1; x < 10; x++) stop('n$x', 'Lane $x', x, 0.2, x + 1),
        stop('e2', 'Norte A2', 10, 0.2, 11),
      ],
    });
    final option = TripPlanner(
      network,
    ).plan(_at(0, 0.1), _at(10, 0.1)).firstWhere((o) => o.rides.isNotEmpty);
    final other = option.firstRide!.lines.firstWhere(
      (l) => l != option.firstRide!.line,
    );

    final chosen = option.choose(0, other);
    final ride = chosen.firstRide!;
    final firstWalk = chosen.legs.first as WalkLeg;

    expect(ride.line, other);
    expect(ride.board.stopId, other == 'T2' ? 's2' : 's1');
    expect(firstWalk.toStop!.stopId, ride.board.stopId);
    // The other lines stay on offer, in the same order
    expect(ride.lines, option.firstRide!.lines);
  });

  test('keeps street stops apart even when close', () {
    const a = LineStop(
      stopId: '1',
      name: 'Cl 121 entre Kr 26R y 26R1',
      latitude: 0,
      longitude: 0,
      direction: 0,
      sequence: 1,
    );
    const b = LineStop(
      stopId: '2',
      name: 'Kr 27 entre Cl 123 y 122',
      latitude: 0,
      longitude: 0,
      direction: 0,
      sequence: 1,
    );
    const platform = LineStop(
      stopId: '3',
      name: 'Aguablanca B4',
      latitude: 0,
      longitude: 0,
      direction: 0,
      sequence: 1,
    );

    expect(samePlace(a, b), isFalse);
    expect(samePlace(a, a), isTrue);
    expect(stationOf(platform.name), 'Aguablanca');
    expect(stationOf(a.name), isNull);
  });

  test('leaves out the lines it is told to', () {
    final planner = TripPlanner(
      TransitNetwork.fromRoutes({
        'T1': _line('a', _east(0, 12)),
        'A9': _line('c', _east(0, 12, y: 0.5)),
      }),
    );

    final options = planner.plan(_at(0, 0), _at(12, 0), leaveOut: {'T1'});

    expect(
      options.expand((o) => o.rides).map((r) => r.line),
      everyElement('A9'),
    );
  });

  test('never rides against a line direction', () {
    final planner = TripPlanner(
      TransitNetwork.fromRoutes({'T1': _line('a', _east(0, 12))}),
    );

    final options = planner.plan(_at(12, 0), _at(0, 0));

    expect(options.expand((o) => o.rides), isEmpty);
  });

  test('only walks between places a few steps apart', () {
    final planner = TripPlanner(
      TransitNetwork.fromRoutes({'T1': _line('a', _east(0, 12))}),
    );

    final options = planner.plan(_at(0, 0), _at(0.5, 0));

    expect(options, hasLength(1));
    expect(options.single.rides, isEmpty);
  });

  test('finds the stop nearest a point', () {
    final network = TransitNetwork.fromRoutes({'T1': _line('a', _east(0, 5))});

    expect(network.nearestStop(_lat, _lon + 3.1 * _step)?.stopId, 'a3');
    expect(network.nearestStop(_lat + 1, _lon), isNull);
    expect(network.stopById('a2')?.name, 'a 2');
  });


  test('tells berths of one stop from stops numbered along a road', () {
    LineStop at(String id, String name, double north) => LineStop(
      stopId: id,
      name: name,
      latitude: _lat + north,
      longitude: _lon,
      direction: 0,
      sequence: 1,
    );
    // Two berths 45 m apart; two road stops 330 m apart
    final berth = at('1', 'Cl 70 entre Av 4 y 3C P1', 0);
    final otherBerth = at('2', 'Cl 70 entre Av 4 y 3C P2', 0.0004);
    final road = at('3', 'Vía La Buitrera P10', 0);
    final furtherOn = at('4', 'Vía La Buitrera P11', 0.003);

    expect(samePlace(berth, otherBerth), isTrue);
    expect(samePlace(road, furtherOn), isFalse);
    expect(stationOf(road.name), isNull);
    expect(stationOf('Universidades D3'), 'Universidades');
  });

  group('what is learned of each line', () {
    // Two lines along parallel roads 220 m apart, the origin on the first
    final network = TransitNetwork.fromRoutes({
      'A1': _line('a', _east(0, 12)),
      'A2': _line('b', _east(0, 12, y: 0.5)),
    });
    final from = _at(0, 0);
    final to = _at(12, 0.25);

    test('a line seen to come seldom loses to one a short walk away', () {
      expect(
        TripPlanner(network).plan(from, to).first.firstRide!.line,
        'A1',
      );
      expect(
        TripPlanner(
          network,
          headways: {'A1': const Duration(minutes: 30)},
        ).plan(from, to).first.firstRide!.line,
        'A2',
      );
    });

    test('a line seen to run slow loses to one a short walk away', () {
      final slow = TripPlanner(network, rideFactors: {'A1': 1.5});
      final best = slow.plan(from, to).first;

      Duration rideOnA1(TripPlanner planner) => planner
          .plan(from, to)
          .firstWhere((o) => o.firstRide?.line == 'A1')
          .firstRide!
          .duration;

      expect(best.firstRide!.line, 'A2');
      expect(
        rideOnA1(slow).inSeconds,
        closeTo(rideOnA1(TripPlanner(network)).inSeconds * 1.5, 1),
      );
    });
  });

  group('a hop onto a ride another option walks to', () {
    // A trunk line east, and a feeder hopping one stop from the origin,
    // 330 m north of the trunk's first stop, to its second
    final network = TransitNetwork.fromRoutes({
      'T1': _line('a', _east(0, 12)),
      'A5': _line('c', [(0, 0.75), (1, 0)]),
    });
    final from = _at(0, 0.75);
    final to = _at(12, 0);

    test('is left out when walking to the ride ranks better', () {
      // The hop saves under a minute and costs a change of bus
      final options = TripPlanner(
        network,
        headways: {'A5': const Duration(seconds: 690)},
      ).plan(from, to);

      expect(options.map((o) => o.rides.map((r) => r.line).join('>')), [
        'T1',
      ]);
    });

    test('stays when it ranks better than walking', () {
      final options = TripPlanner(
        network,
        headways: {'A5': const Duration(minutes: 4)},
      ).plan(from, to);

      expect(options.map((o) => o.rides.map((r) => r.line).join('>')), [
        'A5>T1',
        'T1',
      ]);
    });
  });

  test('ranks time on foot above time on a bus', () {
    final walk = TripOption([WalkLeg.between(_lat, _lon, _lat, _lon + 0.01)]);

    expect(
      TripPlanner.cost(walk),
      walk.duration.inSeconds * (1 + TripPlanner.walkReluctance),
    );
  });
}
