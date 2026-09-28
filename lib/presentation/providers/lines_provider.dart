import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/api_exception.dart';
import '../../domain/entities/line_entity.dart';
import 'stops_provider.dart';

/// Every MIO line
final linesProvider = FutureProvider<List<TransitLine>>((ref) {
  return ref.read(stopsRepositoryProvider).getLines();
});

/// Hours each line runs, by name. Missing hours only hide the status,
/// so a failure here leaves an empty map rather than an error.
final lineHoursProvider = FutureProvider<Map<String, LineHours>>((ref) async {
  try {
    return await ref.read(stopsRepositoryProvider).getLineHours();
  } on ApiException {
    return const {};
  }
});

/// A line's route, both directions
final lineStopsProvider =
    FutureProvider.autoDispose.family<List<LineStop>, String>((ref, line) {
  return ref.read(stopsRepositoryProvider).getLineStops(line);
});

/// Buses on a line, asked again every [lineBusesInterval] for as long as
/// a screen watches them, and no longer
final lineBusesProvider =
    StreamProvider.autoDispose.family<List<LineBus>, String>((ref, line) {
  final repository = ref.read(stopsRepositoryProvider);
  final controller = StreamController<List<LineBus>>();
  var closed = false;

  Future<void> fetch() async {
    try {
      final buses = await repository.getLineBuses(line);
      if (!closed) controller.add(buses);
    } on ApiException catch (e, stack) {
      if (!closed) controller.addError(e, stack);
    }
  }

  fetch();
  final timer = Timer.periodic(lineBusesInterval, (_) => fetch());
  ref.onDispose(() {
    closed = true;
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Buses move a block or two in this time: often enough to follow them,
/// seldom enough for a public service
const Duration lineBusesInterval = Duration(seconds: 30);
