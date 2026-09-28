import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Disk cache for the map tiles, kept by flutter_map.
///
/// Its default ceiling is a gigabyte, far more than a city map needs, and
/// it lives apart from the other cached data, so it is sized and cleared
/// from here.
class MapTileCache {
  /// Enough for the city at every zoom the map allows, many times over
  static const int maxBytes = 100 * 1024 * 1024;

  /// The configuration only applies when the instance is created, so every
  /// user goes through here
  static BuiltInMapCachingProvider get provider =>
      BuiltInMapCachingProvider.getOrCreateInstance(
        maxCacheSize: maxBytes,
        tileKeyGenerator: _keyWithoutApiKey,
      );

  /// The API key says nothing about the image, and keeping it in the key
  /// would throw the whole cache away whenever the key changes
  static String _keyWithoutApiKey(String url) =>
      BuiltInMapCachingProvider.uuidTileKeyGenerator(
        url.replaceFirst(RegExp(r'[?&]key=[^&]*'), ''),
      );

  /// Where flutter_map keeps the tiles when no directory is given
  static Future<Directory> get _directory async => Directory(
        p.join((await getApplicationCacheDirectory()).path, 'fm_cache'),
      );

  static Future<int> sizeInBytes() async {
    final directory = await _directory;
    if (!await directory.exists()) return 0;

    var total = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  static Future<void> clear() => provider.destroy(deleteCache: true);
}
