import 'package:flutter/services.dart';

import '../../domain/address_search.dart';

/// Android's own geocoder, through the app's bridge to it: Google's, by
/// way of Play services, with no key or quota to manage. Elsewhere, or on
/// a phone without Play services, it finds nothing and the search falls
/// back on the MIO stop names.
class DeviceGeocoder {
  static const _channel = MethodChannel('caligo/geocoder');

  /// Places Android finds for [query], within Cali, best first
  Future<List<GeocodedPlace>> search(String query) async {
    try {
      final found = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'search',
        {
          'query': query,
          'south': caliBounds.south,
          'west': caliBounds.west,
          'north': caliBounds.north,
          'east': caliBounds.east,
        },
      );
      return [
        for (final place in found ?? const <Map<Object?, Object?>>[])
          if ((place['latitude'], place['longitude'])
              case (final num latitude, final num longitude))
            GeocodedPlace(
              line: place['line']?.toString() ?? '',
              latitude: latitude.toDouble(),
              longitude: longitude.toDouble(),
            ),
      ];
    } on MissingPluginException {
      // Not Android: there is no geocoder to ask
      return const [];
    } on PlatformException {
      // The service did not answer this time
      return const [];
    }
  }
}
