import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small JSON cache backed by memory and by a file each.
///
/// Used for the parts of the transit data that barely change, so the app
/// does not download them again on every launch.
class JsonCache {
  final Map<String, ({DateTime savedAt, Object? value})> _memory = {};
  Directory? _directory;

  /// Cache that keeps nothing, for tests
  factory JsonCache.noop() = _NoopJsonCache;

  JsonCache();

  /// Cached value for [key], or null when missing or older than [maxAge]
  Future<Object?> read(
    String key, {
    Duration? maxAge,
    bool remember = true,
  }) async {
    final entry = await readEntry(key, remember: remember);
    if (entry == null || _isStale(entry.savedAt, maxAge)) return null;
    return entry.value;
  }

  /// Cached value for [key] however old, with when it was saved; null
  /// when missing. [remember] keeps it in memory for the next read, which
  /// a large value read once a run is better without.
  Future<({DateTime savedAt, Object? value})?> readEntry(
    String key, {
    bool remember = true,
  }) async {
    final cached = _memory[key];
    if (cached != null) return cached;

    try {
      final file = await _fileFor(key);
      if (!await file.exists()) return null;

      final decoded = json.decode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;

      final entry = (
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          (decoded['savedAt'] as num).toInt(),
        ),
        value: decoded['value'],
      );
      if (remember) _memory[key] = entry;
      return entry;
    } catch (_) {
      // A cache miss is always an acceptable answer.
      return null;
    }
  }

  Future<void> write(String key, Object? value, {bool remember = true}) async {
    final savedAt = DateTime.now();
    if (remember) {
      _memory[key] = (savedAt: savedAt, value: value);
    } else {
      _memory.remove(key);
    }

    try {
      final file = await _fileFor(key);
      await file.writeAsString(
        json.encode({
          'savedAt': savedAt.millisecondsSinceEpoch,
          'value': value,
        }),
      );
    } catch (_) {
      // Memory-only is good enough when the disk is not available.
    }
  }

  /// Total bytes the cache occupies on disk
  Future<int> sizeInBytes() async {
    try {
      final directory = await _cacheDirectory();
      var total = 0;
      await for (final entry in directory.list()) {
        if (entry is File) total += await entry.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Throw away everything, on disk and in memory
  Future<void> clear() async {
    _memory.clear();
    try {
      final directory = await _cacheDirectory();
      await for (final entry in directory.list()) {
        if (entry is File) await entry.delete();
      }
    } catch (_) {
      // Nothing to clear is a fine outcome.
    }
  }

  /// Delete entries nobody has asked for in [maxAge].
  ///
  /// One file per stop would otherwise pile up for as long as the app is
  /// installed, since every stop whose lines were looked up leaves one.
  Future<void> prune({required Duration maxAge}) async {
    try {
      final directory = await _cacheDirectory();
      final cutoff = DateTime.now().subtract(maxAge);
      await for (final entry in directory.list()) {
        if (entry is! File) continue;
        final modified = await entry.lastModified();
        if (modified.isBefore(cutoff)) await entry.delete();
      }
    } catch (_) {
      // Pruning is housekeeping: failing to do it changes nothing.
    }
  }

  bool _isStale(DateTime savedAt, Duration? maxAge) {
    if (maxAge == null) return false;
    return DateTime.now().difference(savedAt) > maxAge;
  }

  Future<File> _fileFor(String key) async {
    final directory = _directory ??= await _cacheDirectory();
    return File('${directory.path}/$key.json');
  }

  Future<Directory> _cacheDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}/cache');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }
}

class _NoopJsonCache extends JsonCache {
  @override
  Future<Object?> read(
    String key, {
    Duration? maxAge,
    bool remember = true,
  }) async => null;

  @override
  Future<({DateTime savedAt, Object? value})?> readEntry(
    String key, {
    bool remember = true,
  }) async => null;

  @override
  Future<void> write(String key, Object? value, {bool remember = true}) async {}
}
