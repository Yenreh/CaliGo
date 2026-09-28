import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miocard/domain/entities/line_entity.dart';
import 'package:miocard/domain/entities/stop_entity.dart';
import 'package:miocard/domain/repositories/stops_repository.dart';
import 'package:miocard/presentation/providers/stops_provider.dart';

/// Repository that records how the arrivals were asked for
class _FakeStopsRepository implements StopsRepository {
  final List<FavoriteStop> favorites;
  final List<NearbyStop> nearby;

  int nearbyCalls = 0;
  final List<FavoriteStop> saved = [];

  _FakeStopsRepository({required this.favorites, required this.nearby});

  @override
  Future<List<FavoriteStop>> getFavorites() async => favorites;

  @override
  Future<List<NearbyStop>> getNearbyStops(double lat, double lon) async {
    nearbyCalls++;
    return nearby;
  }

  @override
  Future<void> addFavorite(FavoriteStop stop) async {}

  @override
  Future<void> removeFavorite(String stopId) async {}

  @override
  Future<void> updateFavorite(FavoriteStop stop) async => saved.add(stop);

  @override
  Future<int> nextPosition() async => 0;

  @override
  Future<List<Station>> getStations() async => const [];

  @override
  Future<List<StopLine>> getLinesByStop(String stopId) async => const [];

  @override
  Stream<List<NearbyStop>> locatedStops(double lat, double lon) =>
      Stream.value(nearby);

  Map<String, List<BusArrival>>? kept;

  @override
  Future<List<TransitLine>> getLines() async => const [];

  @override
  Future<List<LineStop>> getLineStops(String line) async => const [];

  @override
  Future<List<LineBus>> getLineBuses(String line) async => const [];

  @override
  Future<Map<String, LineHours>> getLineHours() async => const {};

  @override
  Future<Map<String, List<BusArrival>>?> recentArrivals(
    Duration maxAge,
  ) async => kept;

  @override
  Future<void> keepArrivals(Map<String, List<BusArrival>> arrivals) async =>
      kept = arrivals;
}

FavoriteStop _favorite(String id, double lat, double lon) => FavoriteStop(
  id: id,
  stopId: id,
  name: 'Stop $id',
  anchorLatitude: lat,
  anchorLongitude: lon,
);

/// Let the load the notifier starts on its own finish, then reset the
/// state from the repository so a test counts only what it does itself.
Future<StopsNotifier> _readyNotifier(ProviderContainer container) async {
  final notifier = container.read(stopsProvider.notifier);
  await Future<void>.delayed(Duration.zero);
  await notifier.loadFavorites();
  return notifier;
}

NearbyStop _stop(String id, {List<BusArrival> arrivals = const []}) =>
    NearbyStop(
      id: id,
      name: 'Stop $id',
      distanceMeters: 10,
      arrivals: arrivals,
    );

void main() {
  group('StopsNotifier.refreshArrivals', () {
    test('answers stops saved from the same place with one request', () async {
      final repository = _FakeStopsRepository(
        favorites: [
          // Two platforms saved from the same spot, one street away.
          _favorite('a', 3.4516, -76.5320),
          _favorite('b', 3.4516, -76.5320),
          _favorite('c', 3.4700, -76.5320),
        ],
        nearby: [_stop('a'), _stop('b'), _stop('c')],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stopsProvider.notifier);
      await notifier.loadFavorites();
      repository.nearbyCalls = 0;
      await notifier.refreshArrivals(force: true);

      expect(repository.nearbyCalls, 2);
    });

    test('the home screen only asks for the stops it lists', () async {
      final repository = _FakeStopsRepository(
        favorites: [
          _favorite('shown', 3.4516, -76.5320),
          _favorite('hidden', 3.4700, -76.5320).copyWith(showOnHome: false),
        ],
        nearby: [_stop('shown'), _stop('hidden')],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = await _readyNotifier(container);
      notifier.startAutoRefresh(homeOnly: true);
      addTearDown(notifier.stopAutoRefresh);
      repository.nearbyCalls = 0;
      await notifier.refreshArrivals(force: true);

      // The two stops are too far apart to share a request.
      expect(repository.nearbyCalls, 1);
    });

    test('asks again only when the stop is anchored somewhere else', () async {
      final repository = _FakeStopsRepository(
        favorites: [
          _favorite('a', 3.4516, -76.5320),
          _favorite('missing', 3.4516, -76.5320),
        ],
        nearby: [_stop('a')],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stopsProvider.notifier);
      await notifier.loadFavorites();
      repository.nearbyCalls = 0;
      await notifier.refreshArrivals(force: true);

      // The same anchor gives the same answer: asking twice is waste.
      expect(repository.nearbyCalls, 1);
    });

    test('skips a refresh that follows another too closely', () async {
      final repository = _FakeStopsRepository(
        favorites: [_favorite('a', 3.4516, -76.5320)],
        nearby: [_stop('a')],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stopsProvider.notifier);
      await notifier.loadFavorites();
      repository.nearbyCalls = 0;
      await notifier.refreshArrivals(force: true);
      await notifier.refreshArrivals();

      expect(repository.nearbyCalls, 1);
    });
  });

  group('StopsNotifier arrivals', () {
    test('hands each favorite the arrivals of its own stop', () async {
      final arrival = BusArrival(
        line: 'T31',
        destination: 'Universidades',
        arrivalTime: DateTime(2026, 1, 1, 12),
        vehicleId: '1',
        stopName: 'Stop a',
      );
      final repository = _FakeStopsRepository(
        favorites: [_favorite('a', 3.4516, -76.5320)],
        nearby: [
          _stop('a', arrivals: [arrival]),
          _stop('b'),
        ],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stopsProvider.notifier);
      await notifier.loadFavorites();
      await notifier.refreshArrivals(force: true);

      expect(container.read(stopsProvider).arrivals['a'], [arrival]);
    });

    test('an area favorite gathers every stop around its anchor', () async {
      final later = BusArrival(
        line: 'A1',
        destination: 'X',
        arrivalTime: DateTime(2026, 1, 1, 12, 5),
        vehicleId: '1',
      );
      final sooner = BusArrival(
        line: 'A2',
        destination: 'Y',
        arrivalTime: DateTime(2026, 1, 1, 12),
        vehicleId: '2',
      );
      final repository = _FakeStopsRepository(
        favorites: [
          const FavoriteStop(
            id: 'station-1',
            name: 'Station',
            anchorLatitude: 3.4516,
            anchorLongitude: -76.5320,
          ),
        ],
        nearby: [
          _stop('a', arrivals: [later]),
          _stop('b', arrivals: [sooner]),
        ],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(stopsProvider.notifier);
      await notifier.loadFavorites();
      await notifier.refreshArrivals(force: true);

      // Both platforms, soonest first.
      expect(container.read(stopsProvider).arrivals['station-1'], [
        sooner,
        later,
      ]);
    });
  });

  group('StopsNotifier reconciliation', () {
    test('counts a stop the service stops reporting', () async {
      final repository = _FakeStopsRepository(
        favorites: [_favorite('gone', 3.4516, -76.5320)],
        nearby: [_stop('other')],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = await _readyNotifier(container);
      repository.saved.clear();

      await notifier.refreshArrivals(force: true);
      expect(repository.saved.single.missingCount, 1);
      expect(container.read(stopsProvider).favorites.single.looksGone, isFalse);

      await notifier.refreshArrivals(force: true);
      await notifier.refreshArrivals(force: true);

      final favorite = container.read(stopsProvider).favorites.single;
      expect(favorite.missingCount, FavoriteStop.missingThreshold);
      expect(favorite.looksGone, isTrue);
    });

    test('picks up a stop that was renamed', () async {
      final repository = _FakeStopsRepository(
        favorites: [_favorite('a', 3.4516, -76.5320)],
        nearby: const [
          NearbyStop(id: 'a', name: 'Kr 27 con Cl 122', distanceMeters: 5),
        ],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = await _readyNotifier(container);
      repository.saved.clear();
      await notifier.refreshArrivals(force: true);

      expect(repository.saved.single.name, 'Kr 27 con Cl 122');
      expect(
        container.read(stopsProvider).favorites.single.name,
        'Kr 27 con Cl 122',
      );
    });

    test('leaves a favorite alone while nothing changes', () async {
      final repository = _FakeStopsRepository(
        favorites: [_favorite('a', 3.4516, -76.5320)],
        nearby: [_stop('a')],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = await _readyNotifier(container);
      repository.saved.clear();
      await notifier.refreshArrivals(force: true);

      expect(repository.saved, isEmpty);
    });
  });

  group('refreshStopArrivals', () {
    final bus = BusArrival(
      line: 'A47',
      destination: 'Valle Grande',
      arrivalTime: DateTime(2026, 9, 28, 10, 30),
      vehicleId: '1',
    );

    test('takes the new arrivals of the stop being looked at', () async {
      final repository = _FakeStopsRepository(
        favorites: const [],
        nearby: [
          _stop('other'),
          _stop('a', arrivals: [bus]),
        ],
      );

      final fresh = await refreshStopArrivals(
        repository,
        _stop('a'),
        anchorLatitude: 3.45,
        anchorLongitude: -76.53,
      );

      expect(repository.nearbyCalls, 1);
      expect(fresh.arrivals, [bus]);
    });

    test('a stop missing from the answer has no bus coming', () async {
      final repository = _FakeStopsRepository(
        favorites: const [],
        nearby: [_stop('other')],
      );

      final fresh = await refreshStopArrivals(
        repository,
        _stop('a', arrivals: [bus]),
        anchorLatitude: 3.45,
        anchorLongitude: -76.53,
      );

      expect(fresh.arrivals, isEmpty);
    });
  });

  group('StopsNotifier.nextRefreshDelay', () {
    final now = DateTime(2026, 9, 28, 12);
    BusArrival inMinutes(int minutes) => BusArrival(
      line: 'A47',
      destination: 'Valle Grande',
      arrivalTime: now.add(Duration(minutes: minutes)),
      vehicleId: '1',
    );

    test('follows a bus closely when it is about to come', () {
      expect(
        StopsNotifier.nextRefreshDelay([
          [inMinutes(20), inMinutes(4)],
        ], now),
        const Duration(seconds: 30),
      );
    });

    test('eases off as the next bus gets further away', () {
      expect(
        StopsNotifier.nextRefreshDelay([
          [inMinutes(12)],
        ], now),
        const Duration(seconds: 60),
      );
      expect(
        StopsNotifier.nextRefreshDelay([
          [inMinutes(25)],
        ], now),
        const Duration(seconds: 120),
      );
    });

    test('waits longest with no bus coming, ignoring buses already gone', () {
      expect(
        StopsNotifier.nextRefreshDelay([
          const [],
          [inMinutes(-3)],
        ], now),
        const Duration(seconds: 120),
      );
    });
  });

  group('StopsNotifier kept arrivals', () {
    test(
      'shows the last arrivals at once, without the buses already gone',
      () async {
        final now = DateTime.now();
        BusArrival bus(String line, Duration fromNow) => BusArrival(
          line: line,
          destination: 'Valle Grande',
          arrivalTime: now.add(fromNow),
          vehicleId: line,
        );
        final repository = _FakeStopsRepository(
            favorites: [
              _favorite('a', 3.4516, -76.5320),
              _favorite('b', 3.4700, -76.5320),
            ],
            // Nothing answers, so only the kept arrivals can show
            nearby: const [],
          )
          ..kept = {
            'a': [
              bus('gone', const Duration(minutes: -2)),
              bus('next', const Duration(minutes: 6)),
            ],
            'b': [bus('gone', const Duration(minutes: -1))],
            'removed': [bus('next', const Duration(minutes: 3))],
          };
        final container = ProviderContainer(
          overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        // The first arrivals to show are the kept ones, before the refresh
        // that follows replaces them
        final shown = <String, List<BusArrival>>{};
        container.listen(stopsProvider, (_, next) {
          if (shown.isEmpty && next.arrivals.isNotEmpty) {
            shown.addAll(next.arrivals);
          }
        }, fireImmediately: true);
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(shown.keys, ['a']);
        expect(shown['a']!.map((b) => b.line), ['next']);
      },
    );
  });

  group('StopsNotifier.reorderFavorites', () {
    test('moves a stop down as the list reports it, and saves the order',
        () async {
      final repository = _FakeStopsRepository(
        favorites: [
          for (final (i, id) in ['a', 'b', 'c'].indexed)
            _favorite(id, 3.45, -76.53).copyWith(position: i),
        ],
        nearby: const [],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final notifier = await _readyNotifier(container);
      repository.saved.clear();

      // Dragging 'a' below 'b': a reorderable list reports index 2
      await notifier.reorderFavorites(0, 2);

      final order = container.read(stopsProvider).favorites;
      expect(order.map((s) => s.id), ['b', 'a', 'c']);
      expect(order.map((s) => s.position), [0, 1, 2]);
      // 'c' kept its place, so only the two that moved are written
      expect(repository.saved.map((s) => s.id), ['b', 'a']);
    });
  });

  group('Lines per favorite', () {
    BusArrival bus(String line) => BusArrival(
          line: line,
          destination: 'Terminal',
          arrivalTime: DateTime(2026, 9, 28, 12, 30),
          vehicleId: line,
        );

    test('a favorite with lines shows only those buses', () {
      final stop = _favorite('a', 3.45, -76.53).copyWith(lines: ['A47']);

      expect(
        stop.pick([bus('A47'), bus('T52'), bus('A47')]).map((b) => b.line),
        ['A47', 'A47'],
      );
      expect(_favorite('b', 3.45, -76.53).pick([bus('T52')]), hasLength(1));
    });

    test('the lines travel with the backup', () {
      final stop = _favorite('a', 3.45, -76.53).copyWith(lines: ['A47', 'T52']);

      expect(FavoriteStop.fromJson(stop.toJson()).lines, ['A47', 'T52']);
      // Backups made before the lines existed show every line
      expect(
        FavoriteStop.fromJson(stop.toJson()..remove('lines')).lines,
        isEmpty,
      );
    });

    test('editing saves the name and the lines together', () async {
      final repository = _FakeStopsRepository(
        favorites: [_favorite('a', 3.45, -76.53)],
        nearby: const [],
      );
      final container = ProviderContainer(
        overrides: [stopsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final notifier = await _readyNotifier(container);
      repository.saved.clear();

      await notifier.editFavorite('a', customName: ' Casa ', lines: ['A47']);

      final saved = repository.saved.single;
      expect(saved.customName, 'Casa');
      expect(saved.lines, ['A47']);
      expect(container.read(stopsProvider).favorites.single.lines, ['A47']);
    });
  });
}
