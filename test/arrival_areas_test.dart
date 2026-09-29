import 'package:caligo/domain/arrival_areas.dart';
import 'package:flutter_test/flutter_test.dart';

/// About 111 m of latitude
const _step = 0.001;

GeoPoint _north(double steps) =>
    (latitude: 3.45 + steps * _step, longitude: -76.53);

void main() {
  test('one point answers for stops within reach of it', () {
    // 250 m apart: only the middle stop reaches the other two
    final centres = areasCovering([
      _north(0),
      _north(2.25),
      _north(4.5),
    ], arrivalsReachMeters);

    expect(centres, [_north(2.25)]);
  });

  test('the middle of two stops answers for both when neither can', () {
    // 445 m apart: past each other's reach, within the middle's
    final centres = areasCovering([_north(0), _north(4)], arrivalsReachMeters);

    expect(centres, hasLength(1));
    expect(centres.single.latitude, closeTo(_north(2).latitude, 1e-12));
  });

  test('stops far apart each get their own', () {
    final centres = areasCovering([
      _north(0),
      _north(20),
      _north(40),
    ], arrivalsReachMeters);

    expect(centres, hasLength(3));
  });

  test('nothing to ask about asks nothing', () {
    expect(areasCovering(const [], arrivalsReachMeters), isEmpty);
  });
}
