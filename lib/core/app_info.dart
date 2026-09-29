/// What the app is called and where it lives, kept in one place so a
/// rename touches only this file and the Android label in
/// android/app/src/main/res/values/strings.xml
class AppInfo {
  static const String name = 'CaliGo';

  /// Android application ID, also how the map introduces itself to the
  /// tile servers
  static const String packageId = 'com.yenreh.caligo';

  /// SHA-1 of the certificate every release is signed with. Public, like
  /// any certificate; the map key is limited to this app and this
  /// certificate, which the tile requests announce.
  static const String signingSha1 =
      '9B:AD:EB:EF:73:AF:2E:F5:95:AF:94:F9:00:B0:34:45:B3:E5:44:C2';

  /// GitHub owner/name: its page, and the releases updates come from
  static const String githubRepo = 'Yenreh/CaliGo';
  static const String repository = 'https://github.com/$githubRepo';

  /// Where the transit data comes from. Metro Cali allows its reuse for
  /// non-commercial, informative ends, citing it with a link to its site.
  static const String dataSource = 'Metro Cali S.A.';
  static const String dataSourceUrl = 'https://www.metrocali.gov.co';
}
