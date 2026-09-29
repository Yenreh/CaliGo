import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../domain/entities/stop_entity.dart';
import '../providers/settings_provider.dart';
import '../providers/stops_provider.dart';
import '../widgets/edit_favorite_sheet.dart';
import '../widgets/favorite_stop_card.dart';
import '../widgets/lab.dart';
import '../widgets/live_clock.dart';
import '../widgets/shown_on_screen.dart';

/// Dashboard of favorite stops with their upcoming buses
class StopsScreen extends ConsumerStatefulWidget {
  const StopsScreen({super.key});

  @override
  ConsumerState<StopsScreen> createState() => _StopsScreenState();
}

class _StopsScreenState extends ConsumerState<StopsScreen> with ShownOnScreen {
  /// Held so dispose does not have to reach for ref, which is unsafe
  /// once the widget is being unmounted.
  late final StopsNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(stopsProvider.notifier);
  }

  @override
  void dispose() {
    _notifier.stopAutoRefresh(this);
    super.dispose();
  }

  /// No polling the arrivals service in the background, or under another
  /// screen. In view, the stops the home screen leaves out are asked for
  /// at once, and anything that changed while away.
  @override
  void shownChanged(bool shown) {
    if (shown) {
      _notifier.startAutoRefresh(this);
      _notifier.refreshArrivals();
    } else {
      _notifier.stopAutoRefresh(this);
    }
  }

  /// Its own name and the lines it shows
  Future<void> _edit(FavoriteStop stop) async {
    final seen = ref.read(stopsProvider).arrivals[stop.id] ?? const [];
    final edit = await showEditFavoriteSheet(
      context,
      stop: stop,
      seenLines: seen.map((b) => b.line),
    );
    if (edit == null) return;

    await _notifier.editFavorite(
      stop.id,
      customName: edit.name,
      lines: edit.lines,
    );
  }

  /// Let the user pick the stop that replaced a missing favorite
  Future<void> _relink(FavoriteStop stop) async {
    final l10n = AppLocalizations.of(context)!;
    final point = (
      latitude: stop.anchorLatitude,
      longitude: stop.anchorLongitude,
    );

    final chosen = await showModalBottomSheet<NearbyStop>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (sheetContext) => Consumer(
            builder: (context, ref, _) {
              final nearby = ref.watch(nearbyAtPointProvider(point));

              return SafeArea(
                child: nearby.when(
                  loading:
                      () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  error:
                      (_, _) => Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(l10n.couldNotLoadArrivals),
                      ),
                  data:
                      (stops) =>
                          stops.isEmpty
                              ? Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(l10n.noStopsNearby),
                              )
                              : ListView(
                                shrinkWrap: true,
                                children: [
                                  for (final candidate in stops) ...[
                                    const Divider(),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.signpost_outlined,
                                      ),
                                      title: Text(candidate.name),
                                      subtitle: Text(
                                        l10n.metersAway(
                                          candidate.distanceMeters.round(),
                                        ),
                                      ),
                                      onTap:
                                          () => Navigator.of(
                                            sheetContext,
                                          ).pop(candidate),
                                    ),
                                  ],
                                ],
                              ),
                ),
              );
            },
          ),
    );

    if (chosen == null) return;
    await _notifier.relinkFavorite(stop.id, chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(stopsProvider);
    final sortedByProximity = ref.watch(
      settingsProvider.select((s) => s.sortStopsByProximity),
    );
    final notifier = ref.read(stopsProvider.notifier);

    ref.listen<StopsState>(stopsProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          labSnackBar(
            context,
            l10n.couldNotLoadArrivals,
            tone: LabTone.crit,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: l10n.retry,
              onPressed: () => notifier.refreshArrivals(force: true),
            ),
          ),
        );
      }
    });

    return LiveClock(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.favoriteStops),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          actions: [
            if (state.isRefreshing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: l10n.retry,
                onPressed: () => notifier.refreshArrivals(force: true),
              ),
          ],
        ),
        body:
            state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.favorites.isEmpty
                ? LabEmptyState(
                  icon: Icons.signpost_outlined,
                  title: l10n.noFavoriteStops,
                  message: l10n.noFavoriteStopsMessage,
                )
                : RefreshIndicator(
                  onRefresh: () => notifier.refreshArrivals(force: true),
                  // In the saved order a stop can be held and dragged;
                  // sorted by proximity, the distance decides instead
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      96 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: state.favorites.length,
                    buildDefaultDragHandles: !sortedByProximity,
                    onReorder: notifier.reorderFavorites,
                    proxyDecorator: labDragProxy,
                    itemBuilder: (context, index) {
                      final stop = state.favorites[index];
                      return Padding(
                        key: ValueKey(stop.id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FavoriteStopCard(
                          stop: stop,
                          arrivals: state.arrivals[stop.id],
                          isLoading: state.isRefreshing,
                          l10n: l10n,
                          onRemove: () => notifier.removeFavorite(stop.id),
                          onRename: () => _edit(stop),
                          onToggleHome:
                              () => notifier.setShowOnHome(
                                stop.id,
                                !stop.showOnHome,
                              ),
                          onRelink: stop.looksGone ? () => _relink(stop) : null,
                        ),
                      );
                    },
                  ),
                ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/stops/add'),
          tooltip: l10n.addStop,
          child: const Icon(Icons.add_location_alt_outlined),
        ),
      ),
    );
  }
}
