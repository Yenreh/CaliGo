import 'entities/trip_entity.dart';

/// A point on the map
typedef GeoPoint = ({double latitude, double longitude});

/// A stop this close to where the arrivals service is asked around is
/// surely in its answer: the service's radius, 300 m, less a margin for
/// rounding on their side
const double arrivalsReachMeters = 280;

/// Points to ask the arrivals service around so that each of [points] is
/// within [reach] metres of one of them, as few as a greedy pick finds:
/// each next centre is the one answering for most of those left. Besides
/// the points themselves, the midpoint of two a single request can span
/// is tried, since it answers for both; on a tie a point wins, as the
/// centre closest to what is asked about.
List<GeoPoint> areasCovering(List<GeoPoint> points, double reach) {
  double meters(GeoPoint a, GeoPoint b) =>
      metersBetween(a.latitude, a.longitude, b.latitude, b.longitude);

  final candidates = <GeoPoint>[
    ...points,
    for (var i = 0; i < points.length; i++)
      for (var j = i + 1; j < points.length; j++)
        if (meters(points[i], points[j]) <= 2 * reach)
          (
            latitude: (points[i].latitude + points[j].latitude) / 2,
            longitude: (points[i].longitude + points[j].longitude) / 2,
          ),
  ];
  // Which points each candidate answers for, worked out once
  final answers = [
    for (final candidate in candidates)
      {
        for (final (i, point) in points.indexed)
          if (meters(candidate, point) <= reach) i,
      },
  ];

  final left = {for (var i = 0; i < points.length; i++) i};
  final centres = <GeoPoint>[];
  while (left.isNotEmpty) {
    var best = -1;
    var bestCount = 0;
    for (final (c, answered) in answers.indexed) {
      final count = answered.where(left.contains).length;
      if (count > bestCount) {
        best = c;
        bestCount = count;
      }
    }
    centres.add(candidates[best]);
    left.removeAll(answers[best]);
  }
  return centres;
}
