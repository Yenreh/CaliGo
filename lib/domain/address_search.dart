import 'entities/line_entity.dart';

/// The area searched: Cali, from Pance to Menga and the hills to the river
const caliBounds = (south: 3.30, west: -76.62, north: 3.52, east: -76.44);

/// A place a geocoder found, and how it writes it
class GeocodedPlace {
  final String line;
  final double latitude;
  final double longitude;

  const GeocodedPlace({
    required this.line,
    required this.latitude,
    required this.longitude,
  });
}

/// How close a match is to what was typed
enum AddressPrecision {
  /// The address itself, with the numbers typed
  exact,

  /// A place by its name, as the geocoder knows it
  place,

  /// The crossing of the address's two streets: within a block of it
  crossing,

  /// The MIO stop named after that crossing: within a block or so too
  stop,
}

/// A place found for what was typed
class AddressMatch {
  /// What to call it: the address, or the name typed for a place
  final String name;

  /// More about it, such as a place's address; null when the name says it
  final String? detail;
  final double latitude;
  final double longitude;
  final AddressPrecision precision;

  const AddressMatch({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.precision,
    this.detail,
  });
}

enum StreetKind { calle, carrera, avenida, transversal, diagonal }

/// The grids of Cali: the plain one, and the Norte and Oeste of the north
/// and of the western hills
enum StreetSide { plain, north, west, south }

/// One street of an address: "Calle 26P", "Carrera 28D Bis",
/// "Avenida 3 Norte"
class StreetRef {
  final StreetKind kind;
  final int number;

  /// The letter after the number, lowercase; empty for none
  final String letter;
  final bool bis;
  final StreetSide side;

  const StreetRef({
    required this.kind,
    required this.number,
    this.letter = '',
    this.bis = false,
    this.side = StreetSide.plain,
  });

  /// Letter and "bis" together, to tell 26 from 26P or 28D from 28D Bis
  String get mark => '$letter${bis ? 'bis' : ''}';

  /// As a geocoder is asked for it
  String get spoken {
    final name = switch (kind) {
      StreetKind.calle => 'Calle',
      StreetKind.carrera => 'Carrera',
      StreetKind.avenida => 'Avenida',
      StreetKind.transversal => 'Transversal',
      StreetKind.diagonal => 'Diagonal',
    };
    final grid = switch (side) {
      StreetSide.plain => '',
      StreetSide.north => ' Norte',
      StreetSide.west => ' Oeste',
      StreetSide.south => ' Sur',
    };
    return '$name $number${letter.toUpperCase()}${bis ? ' Bis' : ''}$grid';
  }
}

/// A Cali address: "Calle 4 # 75-71" stands on Calle 4, 71 m past its
/// crossing with Carrera 75. Typed as a crossing, "Calle 5 con Carrera
/// 38", it has no metres.
class ParsedAddress {
  final StreetRef street;
  final StreetRef cross;
  final int? meters;

  const ParsedAddress({required this.street, required this.cross, this.meters});

  /// The crossing of both streets, as a geocoder is asked for it
  String get crossingQuery => '${street.spoken} & ${cross.spoken}, Cali';

  /// Whether a geocoder's [line] is this address, with its numbers. Where
  /// Google has no address ranges for a block it answers with another
  /// address that shares a number, even as an exact match, so only these
  /// numbers are taken: "Calle 1 # 42-40" once came back "Cl. 1 Oe. #
  /// 79A-42".
  bool isAt(String line) {
    final found = _numbersIn(line);
    return found != null &&
        found.street == street.number &&
        found.cross.number == cross.number &&
        found.cross.mark == cross.mark &&
        found.meters == meters;
  }

  /// Whether a geocoder's [line] is the crossing of both streets, "Cl. 118
  /// & Cra. 23", rather than one of them alone
  bool crossesIn(String line) {
    final first = line.split(',').first;
    if (!first.contains('&')) return false;
    final numbers = {
      for (final m in RegExp(r'\d+').allMatches(first)) int.parse(m[0]!),
    };
    return numbers.contains(street.number) && numbers.contains(cross.number);
  }
}

/// Street kinds as written, longest first so "cra" is not read as "cr"
const _kinds = {
  'transversal': StreetKind.transversal,
  'diagonal': StreetKind.diagonal,
  'carrera': StreetKind.carrera,
  'avenida': StreetKind.avenida,
  'calle': StreetKind.calle,
  'trans': StreetKind.transversal,
  'avda': StreetKind.avenida,
  'diag': StreetKind.diagonal,
  'cll': StreetKind.calle,
  'cra': StreetKind.carrera,
  'crr': StreetKind.carrera,
  'kra': StreetKind.carrera,
  'av': StreetKind.avenida,
  'ac': StreetKind.calle,
  'ak': StreetKind.carrera,
  'cl': StreetKind.calle,
  'cr': StreetKind.carrera,
  'kr': StreetKind.carrera,
  'tv': StreetKind.transversal,
  'tr': StreetKind.transversal,
  'dg': StreetKind.diagonal,
  'k': StreetKind.carrera,
};

final String _kind = '(${_kinds.keys.join('|')})\\.?';

/// A street number and what follows it: "26", "26P", "28D Bis", "3N",
/// "44 Norte", "1 Oe."; four groups: number, letters, bis, grid
const String _number =
    r'(\d+)'
    r'(?:\s*(?!(?:oe|oeste|nte|norte|sur|bis|no|con|y|x|entre)(?![a-z]))'
    r'([a-z]{1,2})(?![a-z]))?'
    r'(\s*bis(?![a-z]))?'
    r'(?:\s*(norte|nte|oeste|oe|sur)(?![a-z])\.?)?';

final _address = RegExp(
  '^$_kind\\s*$_number'
  r'\s*(?:#|no\.?|n°\.?|nº\.?|numero|num\.?)?\s*'
  '$_number'
  r'\s*-\s*(\d+)',
);

final _crossing = RegExp(
  '^$_kind\\s*$_number'
  r'(?:\s*&\s*|\s+(?:con|y|x|entre)\s+)'
  '(?:$_kind\\s*)?'
  '$_number',
);

/// A stop named after a crossing: "Cl 16 entre Kr 100 y 98", "Kr 100 con
/// Cl 16", "Av 3N entre Cl 31 y 30"
final _stopName = RegExp(
  '^$_kind\\s*$_number'
  r'\s+(?:entre|con)\s+'
  '(?:$_kind\\s*)?'
  '$_number'
  r'(?:\s+y\s+'
  '(?:$_kind\\s*)?'
  '$_number)?',
);

/// The street, crossing and metres of an address as a geocoder writes it,
/// anywhere in its line: "Cl. 4 #75-71", "Cra. 100 #5 - 169"
final _written = RegExp(
  '\\b$_kind\\s*$_number'
  r'[^#,]*#\s*(?:no\.?\s*)?'
  '$_number'
  r'\s*-\s*(\d+)',
);

/// Lowercase, without accents and with one space between words, as the
/// patterns read it: "Cl. 4  #75-71" is "cl. 4 #75-71"
String _plain(String text) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    final i = from.indexOf(char);
    buffer.write(i < 0 ? char : to[i]);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

StreetRef _streetAt(Match m, int group, StreetKind kind) {
  var letter = m[group + 1] ?? '';
  var side = switch (m[group + 3]) {
    'norte' || 'nte' => StreetSide.north,
    'oeste' || 'oe' => StreetSide.west,
    'sur' => StreetSide.south,
    _ => StreetSide.plain,
  };
  // An N after the number is the Norte grid: "3N", "2AN"
  if (side == StreetSide.plain && letter.endsWith('n')) {
    side = StreetSide.north;
    letter = letter.substring(0, letter.length - 1);
  }
  return StreetRef(
    kind: kind,
    number: int.parse(m[group]!),
    letter: letter,
    bis: m[group + 2] != null,
    side: side,
  );
}

/// The street crossing one of [kind]: calles cross carreras, and the
/// avenidas of the north run like carreras
StreetKind _crossKind(StreetKind kind) => switch (kind) {
  StreetKind.calle || StreetKind.diagonal => StreetKind.carrera,
  StreetKind.carrera ||
  StreetKind.transversal ||
  StreetKind.avenida => StreetKind.calle,
};

/// The crossing street of [street], [cross] as typed: in the Norte grid
/// the crossing streets are Norte too
StreetRef _crossOf(StreetRef street, StreetRef cross) => StreetRef(
  kind: cross.kind,
  number: cross.number,
  letter: cross.letter,
  bis: cross.bis,
  side:
      cross.side == StreetSide.plain && street.side == StreetSide.north
          ? StreetSide.north
          : cross.side,
);

/// A Cali address or crossing read from what was typed; null for anything
/// else, such as the name of a place
ParsedAddress? parseAddress(String text) {
  final plain = _plain(text);
  if (_address.firstMatch(plain) case final m?) {
    final street = _streetAt(m, 2, _kinds[m[1]]!);
    final cross = _streetAt(m, 6, _crossKind(street.kind));
    return ParsedAddress(
      street: street,
      cross: _crossOf(street, cross),
      meters: int.parse(m[10]!),
    );
  }
  if (_crossing.firstMatch(plain) case final m?) {
    final street = _streetAt(m, 2, _kinds[m[1]]!);
    final cross = _streetAt(m, 7, _kinds[m[6]] ?? _crossKind(street.kind));
    return ParsedAddress(street: street, cross: _crossOf(street, cross));
  }
  return null;
}

({int street, StreetRef cross, int meters})? _numbersIn(String line) {
  final m = _written.firstMatch(_plain(line));
  if (m == null) return null;
  return (
    street: int.parse(m[2]!),
    cross: _streetAt(m, 6, StreetKind.calle),
    meters: int.parse(m[10]!),
  );
}

/// The MIO stop named after the crossing of [address]'s two streets, the
/// one closest along them when several are
LineStop? stopAtCrossing(ParsedAddress address, Iterable<LineStop> stops) {
  LineStop? best;
  var bestScore = double.infinity;
  for (final stop in stops) {
    final m = _stopName.firstMatch(_plain(stop.name));
    if (m == null) continue;
    final on = _streetAt(m, 2, _kinds[m[1]]!);
    final crossKind = _kinds[m[6]] ?? _crossKind(on.kind);
    final crossings = [
      _streetAt(m, 7, crossKind).number,
      if (m[12] != null) _streetAt(m, 12, crossKind).number,
    ];

    // On the address's street, or on its crossing street, between the
    // crossings around the other one
    for (final (street, other) in [
      (address.street, address.cross),
      (address.cross, address.street),
    ]) {
      if (on.kind != street.kind ||
          on.number != street.number ||
          crossKind != other.kind) {
        continue;
      }
      final low = crossings.reduce((a, b) => a < b ? a : b);
      final high = crossings.reduce((a, b) => a > b ? a : b);
      if (other.number < low || other.number > high) continue;
      // A letter apart is another street: kept only for want of better
      final score =
          (on.mark == street.mark ? 0 : 1000) +
          crossings
              .map((c) => (c - other.number).abs())
              .reduce((a, b) => a < b ? a : b)
              .toDouble();
      if (score < bestScore) {
        best = stop;
        bestScore = score;
      }
    }
  }
  return best;
}

/// A geocoder's line without the city and what follows: "Cl. 4 #75-71,
/// Cali, Valle del Cauca, Colombia" is "Cl. 4 #75-71"
String shortLine(String line) {
  final parts = [for (final part in line.split(',')) part.trim()];
  final city = parts.indexWhere((p) => _plain(p) == 'cali');
  return (city > 0 ? parts.take(city) : parts.take(2)).join(', ');
}

/// Finds what was typed: an address, a crossing of two streets, or a
/// place by its name.
///
/// An address is only taken with the numbers typed; failing that, the
/// crossing of its two streets is asked for, and failing that, the MIO
/// stop named after that crossing. Anything else is a wrong place, which
/// is worse than none.
class AddressSearch {
  /// Places a geocoder finds for a query, within Cali, best first
  final Future<List<GeocodedPlace>> Function(String query) geocode;

  /// Stops to fall back on, named after the crossings they stand at
  final Iterable<LineStop> stops;

  const AddressSearch({required this.geocode, this.stops = const []});

  Future<List<AddressMatch>> find(String text) async {
    final typed = text.trim();
    if (typed.isEmpty) return const [];
    // Unbounded by a city, "Cl. 9 #17-40" once landed in Mexico
    final inCali =
        RegExp(r'\bcali\b').hasMatch(_plain(typed)) ? typed : '$typed, Cali';

    final address = parseAddress(typed);
    if (address == null) {
      return [
        for (final place in _unique(await geocode(inCali)))
          AddressMatch(
            name: typed,
            detail: shortLine(place.line),
            latitude: place.latitude,
            longitude: place.longitude,
            precision: AddressPrecision.place,
          ),
      ];
    }

    if (address.meters != null) {
      final exact = [
        for (final place in _unique(await geocode(inCali)))
          if (address.isAt(place.line))
            AddressMatch(
              name: shortLine(place.line),
              latitude: place.latitude,
              longitude: place.longitude,
              precision: AddressPrecision.exact,
            ),
      ];
      if (exact.isNotEmpty) return exact;
    }

    for (final place in await geocode(address.crossingQuery)) {
      if (!address.crossesIn(place.line)) continue;
      return [
        AddressMatch(
          name: shortLine(place.line),
          latitude: place.latitude,
          longitude: place.longitude,
          precision: AddressPrecision.crossing,
        ),
      ];
    }

    final stop = stopAtCrossing(address, stops);
    return [
      if (stop != null)
        AddressMatch(
          name: stop.name,
          latitude: stop.latitude,
          longitude: stop.longitude,
          precision: AddressPrecision.stop,
        ),
    ];
  }

  static Iterable<GeocodedPlace> _unique(List<GeocodedPlace> places) {
    final seen = <String>{};
    return places.where((p) => seen.add(p.line));
  }
}
