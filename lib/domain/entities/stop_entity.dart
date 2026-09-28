/// A bus expected to arrive at a stop
class BusArrival {
  final String line;
  final String destination;
  final DateTime arrivalTime;
  final String vehicleId;

  /// Stop the bus arrives at. A station spans several platforms, so an
  /// area favorite mixes arrivals from more than one stop.
  final String stopName;

  const BusArrival({
    required this.line,
    required this.destination,
    required this.arrivalTime,
    required this.vehicleId,
    this.stopName = '',
  });

  Map<String, dynamic> toJson() => {
        'line': line,
        'destination': destination,
        'arrivalTime': arrivalTime.millisecondsSinceEpoch,
        'vehicleId': vehicleId,
        'stopName': stopName,
      };

  factory BusArrival.fromJson(Map<String, dynamic> json) => BusArrival(
        line: json['line'] as String,
        destination: json['destination'] as String,
        arrivalTime: DateTime.fromMillisecondsSinceEpoch(
          (json['arrivalTime'] as num).toInt(),
        ),
        vehicleId: json['vehicleId'] as String? ?? '',
        stopName: json['stopName'] as String? ?? '',
      );

  /// Minutes left until arrival, floored at zero
  int minutesUntilArrival([DateTime? now]) {
    final diff = arrivalTime.difference(now ?? DateTime.now()).inSeconds;
    return diff <= 0 ? 0 : (diff / 60).round();
  }
}

/// A stop found near a location, with its upcoming buses
class NearbyStop {
  final String id;
  final String name;
  final double distanceMeters;
  final List<BusArrival> arrivals;

  /// Position worked out from several distance readings. Null when the
  /// stop was not seen from enough vantage points to place it.
  final double? latitude;
  final double? longitude;

  const NearbyStop({
    required this.id,
    required this.name,
    required this.distanceMeters,
    this.arrivals = const [],
    this.latitude,
    this.longitude,
  });

  bool get hasPosition => latitude != null && longitude != null;

  NearbyStop withArrivals(List<BusArrival> arrivals) {
    return NearbyStop(
      id: id,
      name: name,
      distanceMeters: distanceMeters,
      arrivals: arrivals,
      latitude: latitude,
      longitude: longitude,
    );
  }

  NearbyStop withPosition(double latitude, double longitude) {
    return NearbyStop(
      id: id,
      name: name,
      distanceMeters: distanceMeters,
      arrivals: arrivals,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

/// A stop saved by the user.
///
/// The arrivals API only accepts coordinates, so each favorite keeps the
/// position it was found from: querying a small radius around that anchor
/// brings the stop back from anywhere.
class FavoriteStop {
  final String id;

  /// Name the service reports for the stop
  final String name;

  /// Label the user gave it, shown instead of the real name
  final String? customName;
  final double anchorLatitude;
  final double anchorLongitude;
  final int position;

  /// How many times in a row the service answered without mentioning
  /// this stop. A stop that is retired, renumbered or moved out of range
  /// looks exactly like one with no buses coming, so it is counted.
  final int missingCount;

  /// Stop to follow. When null the favorite covers an area and gathers
  /// the arrivals of every stop around the anchor, which is what a
  /// station with several platforms needs.
  final String? stopId;

  /// Whether the home screen lists it; the stops screen always does
  final bool showOnHome;

  /// Lines to show, by short name; empty shows every line. A busy stop
  /// or a station serves many more lines than one person takes.
  final List<String> lines;

  const FavoriteStop({
    required this.id,
    required this.name,
    this.customName,
    required this.anchorLatitude,
    required this.anchorLongitude,
    this.position = 0,
    this.stopId,
    this.missingCount = 0,
    this.showOnHome = true,
    this.lines = const [],
  });

  bool get isArea => stopId == null;

  /// Missed often enough that something has changed on the service side
  bool get looksGone => missingCount >= missingThreshold;

  static const int missingThreshold = 3;

  /// The arrivals worth showing from [arrivals], by [lines]
  List<BusArrival> pick(List<BusArrival> arrivals) => lines.isEmpty
      ? arrivals
      : arrivals.where((b) => lines.contains(b.line)).toList(growable: false);

  /// What to show as the title
  String get displayName => customName?.isNotEmpty == true ? customName! : name;

  /// The real name, only when a custom one is taking its place
  String? get secondaryName =>
      customName?.isNotEmpty == true ? name : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'customName': customName,
        'stopId': stopId,
        'anchorLatitude': anchorLatitude,
        'anchorLongitude': anchorLongitude,
        'position': position,
        'showOnHome': showOnHome,
        'lines': lines,
      };

  factory FavoriteStop.fromJson(Map<String, dynamic> json) {
    return FavoriteStop(
      id: json['id'] as String,
      name: json['name'] as String,
      customName: json['customName'] as String?,
      stopId: json['stopId'] as String?,
      anchorLatitude: (json['anchorLatitude'] as num).toDouble(),
      anchorLongitude: (json['anchorLongitude'] as num).toDouble(),
      position: (json['position'] as num?)?.toInt() ?? 0,
      showOnHome: json['showOnHome'] as bool? ?? true,
      lines: [
        for (final line in json['lines'] as List? ?? const []) line.toString(),
      ],
    );
  }

  FavoriteStop copyWith({
    String? name,
    int? position,
    String? customName,
    String? stopId,
    int? missingCount,
    bool? showOnHome,
    List<String>? lines,
    bool clearCustomName = false,
  }) {
    return FavoriteStop(
      id: id,
      name: name ?? this.name,
      customName: clearCustomName ? null : (customName ?? this.customName),
      anchorLatitude: anchorLatitude,
      anchorLongitude: anchorLongitude,
      position: position ?? this.position,
      stopId: stopId ?? this.stopId,
      missingCount: missingCount ?? this.missingCount,
      showOnHome: showOnHome ?? this.showOnHome,
      lines: lines ?? this.lines,
    );
  }
}

/// A MIO station from the public catalog
class Station {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const Station({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

/// A line serving a stop
class StopLine {
  final String shortName;
  final String name;

  const StopLine({required this.shortName, required this.name});
}
