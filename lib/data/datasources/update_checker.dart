import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;

import 'package:http/http.dart' as http;

import '../../core/app_info.dart';
import 'api_exception.dart';

/// A version published on the repository's releases
class AppRelease {
  final String version;

  /// The release page, with its notes and every APK
  final Uri page;

  /// The APK built for this device, when the release has one
  final Uri? apk;

  const AppRelease({required this.version, required this.page, this.apk});
}

/// Asks the repository for its latest release, and only when told to:
/// updates come from GitHub releases, downloaded through the browser, so
/// the app needs no permission to install anything.
class UpdateChecker {
  static final Uri _latest = Uri.parse(
    'https://api.github.com/repos/${AppInfo.githubRepo}/releases/latest',
  );
  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client;
  final String _abi;

  UpdateChecker({http.Client? client, String? abi})
      : _client = client ?? http.Client(),
        _abi = abi ?? _deviceAbi();

  /// The release workflow builds one APK per ABI; old 32-bit phones take
  /// the armeabi-v7a one, everything else arm64-v8a
  static String _deviceAbi() =>
      Abi.current() == Abi.androidArm ? 'armeabi-v7a' : 'arm64-v8a';

  /// The latest release, or null when none is published yet
  Future<AppRelease?> latest() async {
    final http.Response response;
    try {
      response = await _client.get(
        _latest,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': AppInfo.name,
        },
      ).timeout(_timeout);
    } on TimeoutException {
      throw const NetworkApiException('Request timed out');
    } on http.ClientException catch (e) {
      throw NetworkApiException('Connection error: ${e.message}');
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ServerApiException(
        'Unexpected status: ${response.statusCode}',
        statusCode: response.statusCode,
        isRetryable: false,
      );
    }

    final Object? decoded;
    try {
      decoded = json.decode(response.body);
    } on FormatException {
      throw const ServerApiException('Unexpected response format');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['tag_name'] is! String ||
        decoded['html_url'] is! String) {
      throw const ServerApiException('Unexpected release response');
    }

    final apk = (decoded['assets'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((a) => a['browser_download_url'])
        .whereType<String>()
        .where((url) => url.endsWith('-$_abi.apk'))
        .firstOrNull;

    return AppRelease(
      version: (decoded['tag_name'] as String).replaceFirst(RegExp('^v'), ''),
      page: Uri.parse(decoded['html_url'] as String),
      apk: apk == null ? null : Uri.parse(apk),
    );
  }

  /// Whether [candidate] is a later version than [current], comparing
  /// the numbers of "major.minor.patch" one by one
  static bool isNewer(String candidate, String current) {
    List<int> parts(String v) => [
          for (final part in v.split('+').first.split('.'))
            int.tryParse(part) ?? 0,
        ];
    final a = parts(candidate);
    final b = parts(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
