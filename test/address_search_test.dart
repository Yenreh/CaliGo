import 'package:caligo/domain/address_search.dart';
import 'package:caligo/domain/entities/line_entity.dart';
import 'package:flutter_test/flutter_test.dart';

LineStop _stop(String name, double lat, double lon) => LineStop(
  stopId: name,
  name: name,
  latitude: lat,
  longitude: lon,
  direction: 0,
  sequence: 1,
);

/// A few stops named after their crossings, as the MIO names them
final _stops = [
  _stop('Plaza de Cayzedo A1', 3.4513, -76.5331),
  _stop('Cl 1 entre Kr 44 y 42', 3.42334, -76.55276),
  _stop('Kr 23 entre Cl 118 y 119', 3.42859, -76.46362),
  _stop('Av 3N entre Cl 31 y 30', 3.47066, -76.52201),
  _stop('Cl 36 entre Kr 148 y 146', 3.31356, -76.52238),
  _stop('Kr 100 con Cl 16', 3.37500, -76.53900),
];

/// How Google answered each query in the test of 2026-09-29
const _answers = {
  'Cl. 4 #75-71, Cali': [
    GeocodedPlace(
      line: 'Cl. 4 #75-71, Cali, Valle del Cauca, Colombia',
      latitude: 3.3899242,
      longitude: -76.5461137,
    ),
  ],
  'Carrera 23 # 118-40, Cali': [
    GeocodedPlace(
      line: 'Cra. 23 # 33B-118, Comuna 8, Cali, Valle del Cauca, Colombia',
      latitude: 3.4368657,
      longitude: -76.510473,
    ),
  ],
  'Carrera 23 & Calle 118, Cali': [
    GeocodedPlace(
      line: 'Cl. 118 & Cra. 23, Puerta Del Sol, Cali, Valle del Cauca, Colombia',
      latitude: 3.42875,
      longitude: -76.46355,
    ),
  ],
  'Calle 1 Oeste # 42-40, Cali': [
    GeocodedPlace(
      line: 'Cl. 1 Oe. # 79A-42, Prados Del Sur, Cali, Valle del Cauca, Colombia',
      latitude: 3.385545,
      longitude: -76.5561649,
    ),
  ],
  'Calle 1 Oeste & Carrera 42, Cali': [
    GeocodedPlace(
      line: 'Cl. 1 Oe., Cali, Valle del Cauca, Colombia',
      latitude: 3.44,
      longitude: -76.60,
    ),
  ],
  'Unicentro, Cali': [
    GeocodedPlace(
      line: 'Cra. 100 #5 - 169, Las Vegas, Cali, Valle del Cauca, Colombia',
      latitude: 3.3740819,
      longitude: -76.5395399,
    ),
  ],
};

AddressSearch _search(List<String> asked) => AddressSearch(
  geocode: (query) async {
    asked.add(query);
    return _answers[query] ?? const [];
  },
  stops: _stops,
);

void main() {
  group('reads a Cali address', () {
    ({String street, String cross, int? meters})? read(String text) {
      final address = parseAddress(text);
      if (address == null) return null;
      return (
        street: address.street.spoken,
        cross: address.cross.spoken,
        meters: address.meters,
      );
    }

    test('in its usual spellings', () {
      const expected = (
        street: 'Calle 4',
        cross: 'Carrera 75',
        meters: 71,
      );
      expect(read('Cl. 4 #75-71'), expected);
      expect(read('Calle 4 # 75-71, Cali'), expected);
      expect(read('calle 4 no. 75-71'), expected);
      expect(read('Cll 4 N° 75 - 71'), expected);
      expect(read('Calle 4 75-71'), expected);
      expect(read('Kr 23 # 118 - 40'), (
        street: 'Carrera 23',
        cross: 'Calle 118',
        meters: 40,
      ));
      expect(read('Cra. 50 #50-40')?.street, 'Carrera 50');
    });

    test('with letters, bis and the Norte and Oeste grids', () {
      expect(read('Calle 26P # 72U-35'), (
        street: 'Calle 26P',
        cross: 'Carrera 72U',
        meters: 35,
      ));
      expect(read('Carrera 28D Bis # 72W-15'), (
        street: 'Carrera 28D Bis',
        cross: 'Calle 72W',
        meters: 15,
      ));
      expect(read('Calle 1 Oeste # 42-40')?.street, 'Calle 1 Oeste');
      expect(read('Cl. 1 Oe. #42-40')?.street, 'Calle 1 Oeste');
      // In the Norte grid the crossing streets are Norte too
      const north = (
        street: 'Avenida 3 Norte',
        cross: 'Calle 30 Norte',
        meters: 40,
      );
      expect(read('Av. 3 Nte. #30-40'), north);
      expect(read('Avenida 3 Norte # 30N-40'), north);
      expect(read('Av 3N #30N-40'), north);
      expect(read('Calle 30 Norte # 2AN-29')?.cross, 'Carrera 2A Norte');
    });

    test('typed as a crossing', () {
      const crossing = (street: 'Calle 5', cross: 'Carrera 38', meters: null);
      expect(read('Calle 5 con Carrera 38'), crossing);
      expect(read('cl 5 y kr 38'), crossing);
      expect(read('Calle 5 & Carrera 38'), crossing);
    });

    test('and leaves a place by its name alone', () {
      expect(read('Unicentro'), isNull);
      expect(read('Universidad del Valle'), isNull);
      expect(read('Calle del Arte'), isNull);
      expect(read('Clínica Imbanaco'), isNull);
    });
  });

  group('takes an answer', () {
    test('only with the numbers asked for', () {
      bool at(String typed, String line) => parseAddress(typed)!.isAt(line);

      expect(at('Cl. 4 #75-71', 'Cl. 4 #75-71, Cali, Valle del Cauca'), isTrue);
      expect(at('Carrera 100 # 5-169', 'Cra. 100 #5 - 169, Las Vegas'), isTrue);
      expect(
        at('Carrera 23 # 118-07', 'frente al Cali 21, Cra. 23 #118-07, Cali'),
        isTrue,
      );
      expect(
        at('Calle 30 Norte # 2AN-29', 'Cl. 30 Nte. #2AN-29 Piso 2 of 312'),
        isTrue,
      );
      // What Google answered when it did not know the number
      expect(at('Calle 1 # 42-40', 'Cl. 1 Oe. # 79A-42, Prados Del Sur'), isFalse);
      expect(at('Carrera 23 # 118-40', 'Cra. 23 # 33B-118, Comuna 8'), isFalse);
      expect(
        at('Avenida 3 Norte # 30-40', 'Av. 3 Nte. #30-140, Prados Norte'),
        isFalse,
      );
      expect(at('Calle 36 # 146-40', 'Cl. 36 #146, Esmeralda'), isFalse);
    });

    test('as a crossing only when it names both streets', () {
      final address = parseAddress('Carrera 23 # 118-40')!;

      expect(address.crossingQuery, 'Carrera 23 & Calle 118, Cali');
      expect(address.crossesIn('Cl. 118 & Cra. 23, Puerta Del Sol'), isTrue);
      expect(
        parseAddress('Calle 1 Oeste # 42-40')!.crossesIn('Cl. 1 Oe., Cali'),
        isFalse,
      );
    });
  });

  test('finds the stop named after a crossing', () {
    String? at(String typed) =>
        stopAtCrossing(parseAddress(typed)!, _stops)?.name;

    expect(at('Calle 1 # 42-40'), 'Cl 1 entre Kr 44 y 42');
    expect(at('Calle 1 Oeste # 42-40'), 'Cl 1 entre Kr 44 y 42');
    expect(at('Carrera 23 # 118-40'), 'Kr 23 entre Cl 118 y 119');
    expect(at('Avenida 3 Norte # 30-40'), 'Av 3N entre Cl 31 y 30');
    expect(at('Calle 36 # 146-40'), 'Cl 36 entre Kr 148 y 146');
    // Named the other way round: on the crossing street
    expect(at('Calle 16 # 100-20'), 'Kr 100 con Cl 16');
    expect(at('Calle 99 # 1-10'), isNull);
  });

  test('shortens a line to what comes before the city', () {
    expect(shortLine('Cl. 4 #75-71, Cali, Valle del Cauca, Colombia'), 'Cl. 4 #75-71');
    expect(
      shortLine('Cl. 5 #38-20, San Fernando, Cali, Valle del Cauca, Colombia'),
      'Cl. 5 #38-20, San Fernando',
    );
  });

  group('searches', () {
    test('an address the geocoder knows, as it is', () async {
      final asked = <String>[];
      final found = await _search(asked).find('Cl. 4 #75-71');

      expect(asked, ['Cl. 4 #75-71, Cali']);
      expect(found.single.precision, AddressPrecision.exact);
      expect(found.single.name, 'Cl. 4 #75-71');
    });

    test('the crossing when the geocoder gets the number wrong', () async {
      final asked = <String>[];
      final found = await _search(asked).find('Carrera 23 # 118-40');

      expect(asked, [
        'Carrera 23 # 118-40, Cali',
        'Carrera 23 & Calle 118, Cali',
      ]);
      expect(found.single.precision, AddressPrecision.crossing);
      expect(found.single.name, 'Cl. 118 & Cra. 23, Puerta Del Sol');
    });

    test('the stop at the crossing when the geocoder has neither', () async {
      final found = await _search([]).find('Calle 1 Oeste # 42-40');

      expect(found.single.precision, AddressPrecision.stop);
      expect(found.single.name, 'Cl 1 entre Kr 44 y 42');
    });

    test('a place by its name, in Cali', () async {
      final asked = <String>[];
      final found = await _search(asked).find('Unicentro');

      expect(asked, ['Unicentro, Cali']);
      expect(found.single.precision, AddressPrecision.place);
      expect(found.single.name, 'Unicentro');
      expect(found.single.detail, 'Cra. 100 #5 - 169, Las Vegas');
    });

    test('nothing rather than a wrong place', () async {
      expect(await _search([]).find('Calle 99 # 1-10'), isEmpty);
    });
  });
}
