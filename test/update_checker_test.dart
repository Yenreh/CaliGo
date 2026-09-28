import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miocard/data/datasources/update_checker.dart';

const _release = '''
{"tag_name":"v4.1.0",
 "html_url":"https://github.com/Yenreh/CaliGo/releases/tag/v4.1.0",
 "assets":[
  {"browser_download_url":"https://github.com/Yenreh/CaliGo/releases/download/v4.1.0/CaliGo-v4.1.0-armeabi-v7a.apk"},
  {"browser_download_url":"https://github.com/Yenreh/CaliGo/releases/download/v4.1.0/CaliGo-v4.1.0-arm64-v8a.apk"}]}''';

UpdateChecker _checker(http.Response response, {String abi = 'arm64-v8a'}) =>
    UpdateChecker(client: MockClient((_) async => response), abi: abi);

void main() {
  group('UpdateChecker.latest', () {
    test('reads the version and the APK built for this device', () async {
      final release = await _checker(http.Response(_release, 200)).latest();

      expect(release!.version, '4.1.0');
      expect(release.apk.toString(), endsWith('CaliGo-v4.1.0-arm64-v8a.apk'));
      expect(release.page.path, '/Yenreh/CaliGo/releases/tag/v4.1.0');
    });

    test('gives old 32-bit phones their own APK', () async {
      final release = await _checker(
        http.Response(_release, 200),
        abi: 'armeabi-v7a',
      ).latest();

      expect(release!.apk.toString(), endsWith('-armeabi-v7a.apk'));
    });

    test('a repository without releases has nothing to offer', () async {
      expect(await _checker(http.Response('{}', 404)).latest(), isNull);
    });
  });

  group('UpdateChecker.isNewer', () {
    test('compares each number, not the text', () {
      expect(UpdateChecker.isNewer('4.10.0', '4.9.3'), isTrue);
      expect(UpdateChecker.isNewer('4.0.1', '4.0.0'), isTrue);
      expect(UpdateChecker.isNewer('5.0.0', '4.99.99'), isTrue);
    });

    test('the same or an older version is no update', () {
      expect(UpdateChecker.isNewer('4.0.0', '4.0.0'), isFalse);
      expect(UpdateChecker.isNewer('3.9.9', '4.0.0'), isFalse);
      expect(UpdateChecker.isNewer('4.0.0', '4.0.0+12'), isFalse);
    });
  });
}
