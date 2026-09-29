import 'json_cache.dart';

/// How each line's rides run against the estimate from its route, learned
/// from buses followed stop to stop by the arrivals service: a line
/// through the busy centre takes longer than its route suggests.
///
/// Blended over time, so one odd reading moves it only a little and the
/// figure follows the traffic of the last few trips planned.
class RideTimeMemory {
  final JsonCache _cache;

  static const String _key = 'line_ride_factors';

  /// Weight of each new reading against what was known
  static const double _blend = 0.2;

  /// Readings outside these are a bus held at a terminal or a jump in the
  /// service's own estimate, not how the line runs
  static const double _lowest = 0.5;
  static const double _highest = 2.0;

  Map<String, double>? _factors;

  RideTimeMemory(this._cache);

  Future<Map<String, double>> _load() async {
    if (_factors != null) return _factors!;
    final stored = await _cache.read(_key);
    _factors = {
      if (stored is Map)
        for (final MapEntry(key: line, value: factor) in stored.entries)
          if (factor is num) line.toString(): factor.toDouble(),
    };
    return _factors!;
  }

  /// Learn from [readings], each ride's live time over what its route
  /// alone estimates, by line. The same ride read again and again, as an
  /// open trip is, only settles the factor on its reading.
  Future<void> observe(Map<String, double> readings) async {
    final factors = await _load();
    var changed = false;
    for (final MapEntry(key: line, value: reading) in readings.entries) {
      if (reading < _lowest || reading > _highest) continue;
      final known = factors[line] ?? 1.0;
      factors[line] = known * (1 - _blend) + reading * _blend;
      changed = true;
    }
    if (changed) await _cache.write(_key, factors);
  }

  /// The factor of each line followed so far
  Future<Map<String, double>> factors() async => Map.of(await _load());
}
