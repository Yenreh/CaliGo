import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/stop_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/lines_provider.dart';
import '../providers/stops_provider.dart';
import '../widgets/lab.dart';
import '../widgets/stop_details_sheet.dart';
import 'line_screen.dart';
import 'map_stops_screen.dart';
import 'station_stops_screen.dart';

/// Look stops up on the map, around the device, in the station catalog
/// or along a line, and save the ones worth following
class AddStopScreen extends ConsumerStatefulWidget {
  /// Opened from home to look something up rather than to add a
  /// favorite; only the title changes, saving stays one tap away
  final bool explore;

  const AddStopScreen({super.key, this.explore = false});

  @override
  ConsumerState<AddStopScreen> createState() => _AddStopScreenState();
}

class _AddStopScreenState extends ConsumerState<AddStopScreen>
    with SingleTickerProviderStateMixin {
  /// Owned here rather than taken from a DefaultTabController: that one
  /// tells its tabs whenever this screen is covered or shown again, and
  /// the tab view then jumps pages in the middle of a build, which
  /// Flutter rejects when it happens mid-swipe.
  late final _tabs = TabController(length: 4, vsync: this);
  final _searchController = TextEditingController();
  String _query = '';
  final _lineController = TextEditingController();
  String _lineQuery = '';

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    _lineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.explore ? l10n.findStops : l10n.addStop),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabs,
          // Four labels only fit with the icons stacked above them
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          tabs: [
            _IconTab(icon: Icons.map_outlined, label: l10n.mapTab),
            _IconTab(
              icon: Icons.directions_bus_outlined,
              label: l10n.stationCatalog,
            ),
            _IconTab(icon: Icons.route_outlined, label: l10n.linesTab),
            _IconTab(icon: Icons.near_me_outlined, label: l10n.nearbyStops),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const MapStopsScreen(),
          _StationsTab(
            l10n: l10n,
            controller: _searchController,
            query: _query,
            onQueryChanged: (value) => setState(() => _query = value),
          ),
          _LinesTab(
            l10n: l10n,
            controller: _lineController,
            query: _lineQuery,
            onQueryChanged: (value) => setState(() => _lineQuery = value),
          ),
          _NearbyTab(l10n: l10n),
        ],
      ),
    );
  }
}

/// Tab with its icon above the label
class _IconTab extends StatelessWidget {
  final IconData icon;
  final String label;

  const _IconTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tab(
      icon: Icon(icon, size: 20),
      iconMargin: const EdgeInsets.only(bottom: 4),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Every MIO line, each opening its route with the buses on it
class _LinesTab extends ConsumerWidget {
  final AppLocalizations l10n;
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQueryChanged;

  const _LinesTab({
    required this.l10n,
    required this.controller,
    required this.query,
    required this.onQueryChanged,
  });

  static String _hhmm(Duration d) =>
      '${d.inHours.remainder(24).toString().padLeft(2, '0')}:'
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = LabPalette.of(context);
    final lines = ref.watch(linesProvider);
    final hours = ref.watch(lineHoursProvider).asData?.value ?? const {};
    final now = DateTime.now();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: l10n.searchLine,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: lines.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (_, _) => _Message(
                  icon: Icons.cloud_off_outlined,
                  text: l10n.couldNotLoadArrivals,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(linesProvider),
                ),
            data: (all) {
              final needle = query.trim().toUpperCase();
              final shown =
                  needle.isEmpty
                      ? all
                      : all
                          .where((l) => l.name.toUpperCase().contains(needle))
                          .toList(growable: false);

              return ListView.separated(
                itemCount: shown.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final line = shown[index];
                  final lineHours = hours[line.name];
                  final running = lineHours?.runsAt(now);

                  return ListTile(
                    leading: LabLineChip(line.name),
                    title: Text(
                      lineHours == null
                          ? line.name
                          : '${_hhmm(lineHours.start)} – '
                              '${_hhmm(lineHours.end)}',
                      style: LabText.mono(p, size: 15),
                    ),
                    subtitle:
                        running == null
                            ? null
                            : Text(
                              running
                                  ? l10n.lineRunningNow
                                  : l10n.lineNotRunning,
                              style: TextStyle(color: running ? p.ok : p.muted),
                            ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LineScreen(line: line),
                          ),
                        ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Stops around the device, with the buses coming to each
class _NearbyTab extends ConsumerWidget {
  final AppLocalizations l10n;

  const _NearbyTab({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(nearbyStopsProvider);

    return nearby.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => _Message(
            icon: Icons.location_off_outlined,
            text:
                error is LocationUnavailableException
                    ? (error.permanentlyDenied
                        ? l10n.locationDeniedForever
                        : l10n.locationUnavailable)
                    : l10n.couldNotLoadArrivals,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(nearbyStopsProvider),
          ),
      data: (result) {
        if (result.stops.isEmpty) {
          return _Message(
            icon: Icons.signpost_outlined,
            text: l10n.noStopsNearby,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(nearbyStopsProvider),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(nearbyStopsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: result.stops.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final stop = result.stops[index];
              return ListTile(
                leading: const Icon(Icons.signpost_outlined),
                title: Text(stop.name),
                subtitle: Text(
                  '${l10n.metersAway(stop.distanceMeters.round())}'
                  '${stop.arrivals.isEmpty ? '' : ' · ${stop.arrivals.map((a) => a.line).toSet().take(4).join(', ')}'}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap:
                    () => StopDetailsSheet.show(
                      context,
                      stop: stop,
                      anchorLatitude: result.lat,
                      anchorLongitude: result.lon,
                    ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Searchable MIO station catalog, no location permission needed
class _StationsTab extends ConsumerWidget {
  final AppLocalizations l10n;
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQueryChanged;

  const _StationsTab({
    required this.l10n,
    required this.controller,
    required this.query,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: l10n.searchStation,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: stations.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => _Message(
                  icon: Icons.cloud_off_outlined,
                  text: l10n.couldNotLoadArrivals,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(stationsProvider),
                ),
            data: (all) {
              final needle = query.trim().toLowerCase();
              final filtered =
                  needle.isEmpty
                      ? all
                      : all
                          .where(
                            (s) =>
                                s.name.toLowerCase().contains(needle) ||
                                s.address.toLowerCase().contains(needle),
                          )
                          .toList(growable: false);

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final Station station = filtered[index];
                  return ListTile(
                    leading: const Icon(Icons.directions_bus_outlined),
                    title: Text(station.name),
                    subtitle: Text(station.address),
                    trailing: const Icon(Icons.star_outline_rounded),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) => StationStopsScreen(station: station),
                          ),
                        ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _Message({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LabEmptyState(
      icon: icon,
      message: text,
      actionLabel: actionLabel,
      onAction: onAction,
      secondaryAction: true,
    );
  }
}
