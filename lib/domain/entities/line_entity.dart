/// A MIO line, known to the service by its short name
class TransitLine {
  final int id;
  final String name;

  const TransitLine({required this.id, required this.name});
}

/// A stop along a line's route
class LineStop {
  final String stopId;
  final String name;
  final double latitude;
  final double longitude;

  /// Which way the route runs: each line goes out and comes back, and
  /// the service numbers the two directions 0 and 1
  final int direction;

  /// Place along the route in its direction, from 1
  final int sequence;

  const LineStop({
    required this.stopId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.direction,
    required this.sequence,
  });
}

/// A bus running on a line, where its GPS last put it
class LineBus {
  final String busNumber;
  final double latitude;
  final double longitude;

  /// Which of the line's two directions its trip runs; null when the
  /// service could not say
  final int? direction;

  const LineBus({
    required this.busNumber,
    required this.latitude,
    required this.longitude,
    this.direction,
  });

  LineBus withDirection(int? direction) => LineBus(
        busNumber: busNumber,
        latitude: latitude,
        longitude: longitude,
        direction: direction,
      );
}

/// Hours a line runs, as local times of day
class LineHours {
  final Duration start;
  final Duration end;

  const LineHours({required this.start, required this.end});

  /// Whether the line runs at [now]. Late lines end past midnight, so
  /// an end earlier than the start wraps to the next day.
  bool runsAt(DateTime now) {
    final time = Duration(hours: now.hour, minutes: now.minute);
    if (end >= start) return time >= start && time <= end;
    return time >= start || time <= end;
  }

  /// "05:00:00" into a time of day; null when it does not read as one
  static Duration? parseTime(Object? value) {
    final parts = value?.toString().split(':');
    if (parts == null || parts.length < 2) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null) return null;
    return Duration(hours: hours, minutes: minutes);
  }
}
