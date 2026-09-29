import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/app_info.dart';
import '../../data/datasources/json_cache.dart';
import '../../data/datasources/api_exception.dart';
import '../../data/datasources/map_tile_cache.dart';
import '../../data/datasources/update_checker.dart';
import '../../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/cards_provider.dart';
import '../widgets/github_mark.dart';
import '../widgets/lab.dart';

/// Settings screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _farePriceController = TextEditingController();
  String _appVersion = '';

  final _updates = UpdateChecker();
  bool _checkingUpdates = false;

  /// What the last check found; null until the user asks
  ({String text, Color? color, AppRelease? release})? _updateResult;
  final _cache = JsonCache();
  int _cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _farePriceController.text = settings.farePrice.toString();
    _loadAppVersion();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    // Map tiles are cached apart from the rest, but count as cached data
    final sizes = await Future.wait([
      _cache.sizeInBytes(),
      MapTileCache.sizeInBytes(),
    ]);
    final bytes = sizes[0] + sizes[1];
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  Future<void> _clearCache(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final snackBar = labSnackBar(context, l10n.cacheCleared, tone: LabTone.ok);
    await Future.wait([_cache.clear(), MapTileCache.clear()]);
    await _loadCacheSize();
    messenger.showSnackBar(snackBar);
  }

  /// Only on request: nothing is asked of GitHub in the background
  Future<void> _checkForUpdates(AppLocalizations l10n, LabPalette p) async {
    setState(() => _checkingUpdates = true);
    ({String text, Color? color, AppRelease? release}) result;
    try {
      final release = await _updates.latest();
      if (release == null) {
        result = (text: l10n.noReleasesYet, color: null, release: null);
      } else if (UpdateChecker.isNewer(release.version, _appVersion)) {
        result = (
          text: l10n.updateAvailable(release.version),
          color: p.ok,
          release: release,
        );
      } else {
        result = (text: l10n.upToDate(_appVersion), color: null, release: null);
      }
    } on ApiException {
      result = (text: l10n.updateCheckFailed, color: p.crit, release: null);
    }
    if (!mounted) return;
    setState(() {
      _checkingUpdates = false;
      _updateResult = result;
    });
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  @override
  void dispose() {
    _farePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = LabPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final cardsNotifier = ref.read(cardsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // Theme Section
          _SectionHeader(title: l10n.appearance),
          _SettingsCard(
            child: Column(
              children: [
                _ThemeOption(
                  title: l10n.themeSystem,
                  subtitle: l10n.themeSystemDesc,
                  icon: Icons.brightness_auto_outlined,
                  isSelected: settings.themeMode == AppThemeMode.system,
                  onTap:
                      () => settingsNotifier.setThemeMode(AppThemeMode.system),
                ),
                const Divider(),
                _ThemeOption(
                  title: l10n.themeLight,
                  subtitle: l10n.themeLightDesc,
                  icon: Icons.light_mode_outlined,
                  isSelected: settings.themeMode == AppThemeMode.light,
                  onTap:
                      () => settingsNotifier.setThemeMode(AppThemeMode.light),
                ),
                const Divider(),
                _ThemeOption(
                  title: l10n.themeDark,
                  subtitle: l10n.themeDarkDesc,
                  icon: Icons.dark_mode_outlined,
                  isSelected: settings.themeMode == AppThemeMode.dark,
                  onTap: () => settingsNotifier.setThemeMode(AppThemeMode.dark),
                ),
              ],
            ),
          ),

          // Home screen section
          _SectionHeader(title: l10n.homeScreen),
          _SettingsCard(
            child: Column(
              children: [
                _ThemeOption(
                  title: l10n.homeCardsOnly,
                  subtitle: l10n.homeScreenDesc,
                  icon: Icons.credit_card_outlined,
                  isSelected: settings.homeContent == HomeContent.cards,
                  onTap:
                      () => settingsNotifier.setHomeContent(HomeContent.cards),
                ),
                const Divider(),
                _ThemeOption(
                  title: l10n.homeStopsOnly,
                  subtitle: l10n.homeScreenDesc,
                  icon: Icons.signpost_outlined,
                  isSelected: settings.homeContent == HomeContent.stops,
                  onTap:
                      () => settingsNotifier.setHomeContent(HomeContent.stops),
                ),
                const Divider(),
                _ThemeOption(
                  title: l10n.homeBoth,
                  subtitle: l10n.homeScreenDesc,
                  icon: Icons.dashboard_outlined,
                  isSelected: settings.homeContent == HomeContent.both,
                  onTap:
                      () => settingsNotifier.setHomeContent(HomeContent.both),
                ),
              ],
            ),
          ),

          // Stops section
          _SectionHeader(title: l10n.favoriteStops),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.near_me_outlined),
              title: Text(l10n.sortByProximity),
              subtitle: Text(l10n.sortByProximityDesc),
              trailing: LabSwitch(
                value: settings.sortStopsByProximity,
                onChanged: settingsNotifier.setSortStopsByProximity,
              ),
              onTap:
                  () => settingsNotifier.setSortStopsByProximity(
                    !settings.sortStopsByProximity,
                  ),
            ),
          ),

          // Map section
          _SectionHeader(title: l10n.mapTab),
          _SettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(l10n.darkMap),
                  subtitle: Text(l10n.darkMapDesc),
                  trailing: LabSwitch(
                    value: settings.darkMap,
                    onChanged: settingsNotifier.setDarkMap,
                  ),
                  onTap: () => settingsNotifier.setDarkMap(!settings.darkMap),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.hd_outlined),
                  title: Text(l10n.sharpMap),
                  subtitle: Text(l10n.sharpMapDesc),
                  trailing: LabSwitch(
                    value: settings.sharpMap,
                    onChanged: settingsNotifier.setSharpMap,
                  ),
                  onTap:
                      () => settingsNotifier.setSharpMap(!settings.sharpMap),
                ),
              ],
            ),
          ),

          // Cards section
          _SectionHeader(title: l10n.myCards),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: Text(l10n.refreshBalancesOnOpen),
              subtitle: Text(l10n.refreshBalancesOnOpenDesc),
              trailing: LabSwitch(
                value: settings.refreshBalancesOnOpen,
                onChanged: settingsNotifier.setRefreshBalancesOnOpen,
              ),
              onTap: () => settingsNotifier.setRefreshBalancesOnOpen(
                !settings.refreshBalancesOnOpen,
              ),
            ),
          ),

          // Fare Section
          _SectionHeader(title: l10n.fare),
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.farePrice, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(l10n.farePriceDesc, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _farePriceController,
                          keyboardType: TextInputType.number,
                          style: LabText.mono(p, size: 16),
                          decoration: InputDecoration(
                            hintText: '${SettingsState.defaultFarePrice}',
                            prefixText: '\$ ',
                            prefixStyle: LabText.mono(
                              p,
                              size: 16,
                              color: p.muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: () {
                            final price = int.tryParse(
                              _farePriceController.text,
                            );
                            if (price != null && price > 0) {
                              settingsNotifier.setFarePrice(price);
                              ScaffoldMessenger.of(context).showSnackBar(
                                labSnackBar(
                                  context,
                                  l10n.farePriceUpdated,
                                  tone: LabTone.ok,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: Text(l10n.save),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Data Section
          _SectionHeader(title: l10n.data),
          _SettingsCard(
            child: Column(
              children: [
                _ActionTile(
                  title: l10n.exportData,
                  subtitle: l10n.exportDataDesc,
                  icon: Icons.upload_outlined,
                  onTap: () => _handleExport(context, cardsNotifier, l10n),
                ),
                const Divider(),
                _ActionTile(
                  title: l10n.importData,
                  subtitle: l10n.importDataDesc,
                  icon: Icons.download_outlined,
                  onTap: () => _handleImport(context, cardsNotifier, l10n),
                ),
                const Divider(),
                _ActionTile(
                  title: l10n.cache,
                  subtitle: l10n.cacheDesc,
                  icon: Icons.cleaning_services_outlined,
                  trailing: LabChip(_formatBytes(_cacheBytes)),
                  onTap: () => _clearCache(l10n),
                ),
              ],
            ),
          ),

          // About Section
          _SectionHeader(title: l10n.about),
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.directions_bus_outlined,
                        color: p.accent,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppInfo.name,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      if (_appVersion.isNotEmpty) LabChip('v$_appVersion'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _UpdateCheck(
                    checking: _checkingUpdates,
                    result: _updateResult,
                    onCheck: () => _checkForUpdates(l10n, p),
                  ),
                  const SizedBox(height: 12),
                  // Not the operator's app, and the data is the operator's:
                  // both said plainly, with the link Metro Cali asks for
                  Text(l10n.unofficialNotice, style: LabText.statusLine(p)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap:
                        () => launchUrl(
                          Uri.parse(AppInfo.dataSourceUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        l10n.dataFrom(AppInfo.dataSource),
                        style: LabText.mono(p, size: 12, color: p.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed:
                            () => showLicensePage(
                              context: context,
                              applicationName: AppInfo.name,
                              applicationVersion: _appVersion,
                              applicationLegalese: l10n.madeBy,
                            ),
                        child: Text(l10n.licenses),
                      ),
                      const Spacer(),
                      _RepoLink(label: l10n.madeBy),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    CardsNotifier cardsNotifier,
    AppLocalizations l10n,
  ) async {
    final success = await cardsNotifier.exportData();
    if (context.mounted && !success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(labSnackBar(context, l10n.nothingToExport));
    }
  }

  Future<void> _handleImport(
    BuildContext context,
    CardsNotifier cardsNotifier,
    AppLocalizations l10n,
  ) async {
    final count = await cardsNotifier.importData();
    if (context.mounted) {
      String message;
      if (count < 0) {
        message = l10n.importError;
      } else if (count == 0) {
        message = l10n.noNewItemsImported;
      } else {
        message = l10n.importedItems(count);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        labSnackBar(
          context,
          message,
          tone:
              count < 0
                  ? LabTone.crit
                  : count == 0
                  ? LabTone.neutral
                  : LabTone.ok,
        ),
      );
    }
  }
}

/// Button that asks for the latest release, what it found, and the way to
/// download a newer one: the browser fetches the APK, and Android installs
/// it over this one from the download, so the app needs no permission
class _UpdateCheck extends StatelessWidget {
  final bool checking;
  final ({String text, Color? color, AppRelease? release})? result;
  final VoidCallback onCheck;

  const _UpdateCheck({
    required this.checking,
    required this.result,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final found = result;
    final release = found?.release;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: checking ? null : onCheck,
          icon:
              checking
                  ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.accent,
                    ),
                  )
                  : const Icon(Icons.system_update_alt_rounded, size: 18),
          label: Text(l10n.checkUpdates),
        ),
        if (found != null) ...[
          const SizedBox(height: 8),
          Text(
            found.text,
            style: LabText.statusLine(p).copyWith(color: found.color),
          ),
        ],
        if (release != null) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed:
                () => launchUrl(
                  release.apk ?? release.page,
                  mode: LaunchMode.externalApplication,
                ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(l10n.downloadUpdate(release.version)),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.updateInstallHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// The footer link of the browser extensions: GitHub's mark and the
/// author, opening the app's repository
class _RepoLink extends StatelessWidget {
  final String label;

  const _RepoLink({required this.label});

  static final Uri _repository = Uri.parse(AppInfo.repository);

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);

    return Tooltip(
      message: 'github.com/Yenreh',
      child: InkWell(
        onTap:
            () => launchUrl(_repository, mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GitHubMark(color: p.muted),
              const SizedBox(width: 6),
              Text(label, style: LabText.mono(p, size: 12, color: p.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  const mb = 1024 * 1024;
  return bytes < mb
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / mb).toStringAsFixed(1)} MB';
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
      child: LabSectionLabel(title),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: LabPanel(padding: EdgeInsets.zero, child: child),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);

    return ListTile(
      leading: Icon(icon, color: isSelected ? p.accent : p.muted),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: _SquareRadio(selected: isSelected),
      selected: isSelected,
      selectedColor: p.ink,
      onTap: onTap,
    );
  }
}

/// Square radio mark: an empty box, filled with accent when chosen
class _SquareRadio extends StatelessWidget {
  final bool selected;

  const _SquareRadio({required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);

    return Container(
      width: 18,
      height: 18,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: selected ? p.accent : p.rule),
      ),
      child: selected ? Container(color: p.accent) : null,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
