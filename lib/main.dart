import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/app_info.dart';
import 'presentation/routes/app_router.dart';
import 'presentation/providers/settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerLicenses();
  runApp(const ProviderScope(child: CaliGoApp()));
}

/// The app's own GPL and the fonts' OFL, both of which ask for the
/// licence to travel with the program: list them on the licenses page.
void _registerLicenses() {
  const licenses = {
    AppInfo.name: 'LICENSE',
    'Fraunces': 'assets/fonts/OFL-Fraunces.txt',
    'IBM Plex Sans': 'assets/fonts/OFL-IBMPlexSans.txt',
    'IBM Plex Mono': 'assets/fonts/OFL-IBMPlexMono.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final entry in licenses.entries) {
      var text = await rootBundle.loadString(entry.value);
      // The GPL text names no one: say whose program it covers
      if (entry.key == AppInfo.name) {
        text = '${AppInfo.name}\nCopyright (C) 2026 Yenreh\n\n'
            'Free software under the GNU General Public License, version 3 '
            'or any later version.\n\n$text';
      }
      yield LicenseEntryWithLineBreaks([entry.key], text);
    }
  });
}

class CaliGoApp extends ConsumerWidget {
  const CaliGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,

      // Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.flutterThemeMode,

      // Screens without an app bar still get status bar icons that
      // contrast with the paper
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).appBarTheme.systemOverlayStyle!,
        child: child!,
      ),

      // Navigation
      routerConfig: appRouter,
    );
  }
}
