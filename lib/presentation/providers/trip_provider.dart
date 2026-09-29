import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/device_geocoder.dart';
import '../../domain/entities/trip_entity.dart';
import '../../domain/trip_planner.dart';
import 'stops_provider.dart';

/// Android's own geocoder, for addresses and places typed in the planner
final deviceGeocoderProvider = Provider<DeviceGeocoder>(
  (ref) => DeviceGeocoder(),
);

/// The route network as it loads: how many lines are in, then the
/// network itself
typedef NetworkLoad = ({int done, int total, TransitNetwork? network});

/// Every route as one network to plan on. The first load asks for each
/// line; after that the routes come from the cache for a week. Kept for
/// the whole run, since it takes a moment to gather.
final transitNetworkProvider = StreamProvider<NetworkLoad>((ref) async* {
  final progress = StreamController<NetworkLoad>();
  final routes = ref
      .read(stopsRepositoryProvider)
      .getAllLineStops(
        onProgress: (done, total) {
          if (!progress.isClosed) {
            progress.add((done: done, total: total, network: null));
          }
        },
      );
  // Close the progress once loading ends either way; the error itself
  // surfaces from the await below
  unawaited(routes.then((_) {}, onError: (_) {}).whenComplete(progress.close));

  yield* progress.stream;
  final loaded = await routes;
  yield (
    done: loaded.length,
    total: loaded.length,
    network: TransitNetwork.fromRoutes(loaded),
  );
});

/// Plan off the main thread: a plan runs a dozen searches or so, which
/// could hold up the screen for a moment on a modest phone. [headways]
/// and [rideFactors] are what the app has learned of each line.
Future<List<TripOption>> planInBackground({
  required TransitNetwork network,
  required TripPlace from,
  required TripPlace to,
  required Set<String> leaveOut,
  Map<String, Duration> headways = const {},
  Map<String, double> rideFactors = const {},
}) => compute(_plan, (
  network: network,
  from: from,
  to: to,
  leaveOut: leaveOut,
  headways: headways,
  rideFactors: rideFactors,
));

List<TripOption> _plan(
  ({
    TransitNetwork network,
    TripPlace from,
    TripPlace to,
    Set<String> leaveOut,
    Map<String, Duration> headways,
    Map<String, double> rideFactors,
  })
  request,
) => TripPlanner(
  request.network,
  headways: request.headways,
  rideFactors: request.rideFactors,
).plan(request.from, request.to, leaveOut: request.leaveOut);
