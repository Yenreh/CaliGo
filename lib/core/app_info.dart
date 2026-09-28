/// What the app is called and where it lives, kept in one place so a
/// rename touches only this file and the Android label in
/// android/app/src/main/res/values/strings.xml
class AppInfo {
  static const String name = 'CaliGo';

  /// Android application ID, also how the map introduces itself to the
  /// tile servers
  static const String packageId = 'com.yenreh.caligo';

  static const String repository = 'https://github.com/Yenreh/CaliGo';

  /// Where the transit data comes from. Metro Cali allows its reuse for
  /// non-commercial, informative ends, citing it with a link to its site.
  static const String dataSource = 'Metro Cali S.A.';
  static const String dataSourceUrl = 'https://www.metrocali.gov.co';
}
