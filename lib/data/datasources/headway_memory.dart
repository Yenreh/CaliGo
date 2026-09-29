import 'dart:async';

import '../../domain/entities/stop_entity.dart';
import 'json_cache.dart';

/// How often each line comes, learned from the arrivals the app already
/// asks for: the gaps between a line's next buses at a stop.
///
/// Kept per hour of the day, since a line runs more often at rush hour,
/// and blended over time so one odd reading moves it only a little. The
/// day each line was last seen coming is kept too: the line catalog can
/// leave out a line that runs.
class HeadwayMemory {
  final JsonCache _cache;

  static const String _key = 'line_headways';
  static const String _seenKey = 'lines_seen';

  /// Weight of each new reading against what was known
  static const double _blend = 0.3;

  /// Gaps outside these are two buses bunched together or a line that
  /// is closing for the night, not how often it runs
  static const double _shortestMinutes = 1.5;
  static const double _longestMinutes = 60;

  /// Saved at most this often; readings in between wait in memory
  static const Duration _saveEvery = Duration(minutes: 5);

  /// Minutes between buses, by line and then by hour of the day
  Map<String, Map<String, double>>? _minutes;

  /// Day each line was last seen coming, counted from the epoch
  Map<String, int>? _seen;
  DateTime? _savedAt;
  bool _dirty = false;

  HeadwayMemory(this._cache);

  static int _day(DateTime at) =>
      at.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  Future<Map<String, Map<String, double>>> _load() async {
    if (_minutes != null) return _minutes!;
    final stored = await _cache.read(_key);
    _minutes = {
      if (stored is Map)
        for (final MapEntry(key: line, value: hours) in stored.entries)
          if (hours is Map)
            line.toString(): {
              for (final MapEntry(key: hour, value: minutes) in hours.entries)
                if (minutes is num) hour.toString(): minutes.toDouble(),
            },
    };
    return _minutes!;
  }

  Future<Map<String, int>> _loadSeen() async {
    if (_seen != null) return _seen!;
    final stored = await _cache.read(_seenKey);
    _seen = {
      if (stored is Map)
        for (final MapEntry(key: line, value: day) in stored.entries)
          if (day is num) line.toString(): day.toInt(),
    };
    return _seen!;
  }

  /// Learn from the buses on their way to [stops], seen at [at]
  Future<void> observe(List<NearbyStop> stops, DateTime at) async {
    final memory = await _load();
    final seen = await _loadSeen();
    final hour = '${at.hour}';
    final today = _day(at);

    for (final stop in stops) {
      final byLine = <String, List<DateTime>>{};
      for (final bus in stop.arrivals) {
        (byLine[bus.line] ??= []).add(bus.arrivalTime);
        if (seen[bus.line] != today) {
          seen[bus.line] = today;
          _dirty = true;
        }
      }
      for (final MapEntry(key: line, value: times) in byLine.entries) {
        if (times.length < 2) continue;
        times.sort();
        final gaps = [
          for (var i = 1; i < times.length; i++)
            times[i].difference(times[i - 1]).inSeconds / 60,
        ].where((g) => g >= _shortestMinutes && g <= _longestMinutes).toList()
          ..sort();
        if (gaps.isEmpty) continue;

        final reading = gaps[gaps.length ~/ 2];
        final hours = memory[line] ??= {};
        final known = hours[hour];
        hours[hour] =
            known == null ? reading : known * (1 - _blend) + reading * _blend;
        _dirty = true;
      }
    }

    final savedAt = _savedAt;
    if (_dirty &&
        (savedAt == null || DateTime.now().difference(savedAt) > _saveEvery)) {
      _dirty = false;
      _savedAt = DateTime.now();
      await Future.wait([
        _cache.write(_key, memory),
        _cache.write(_seenKey, seen),
      ]);
    }
  }

  /// Time between buses of each line known for the hour of [at]: that
  /// hour's when seen, otherwise the nearest hour seen within two
  Future<Map<String, Duration>> at(DateTime at) async {
    final memory = await _load();
    final result = <String, Duration>{};
    for (final MapEntry(key: line, value: hours) in memory.entries) {
      for (final offset in const [0, -1, 1, -2, 2]) {
        final minutes = hours['${(at.hour + offset) % 24}'];
        if (minutes == null) continue;
        result[line] = Duration(seconds: (minutes * 60).round());
        break;
      }
    }
    return result;
  }

  /// Lines seen coming to some stop on the day of [since] or later
  Future<Set<String>> seenSince(DateTime since) async {
    final seen = await _loadSeen();
    final from = _day(since);
    return {
      for (final MapEntry(key: line, value: day) in seen.entries)
        if (day >= from) line,
    };
  }
}
