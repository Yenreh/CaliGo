import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/stop_entity.dart';
import '../../domain/entities/trip_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/stops_provider.dart';
import '../screens/plan_trip_screen.dart';
import 'favorite_stop_card.dart';
import 'lab.dart';
import 'live_clock.dart';
import 'stop_name_dialog.dart';

/// Details of a stop: the buses on their way and the lines serving it.
///
/// Opens from any stop list so a place can be checked without saving it,
/// and refreshes on demand since a look is often all it gets.
class StopDetailsSheet extends ConsumerStatefulWidget {
  final NearbyStop stop;
  final double anchorLatitude;
  final double anchorLongitude;

  /// Opened from somewhere that knows the stop but not its buses, such
  /// as a line's route: ask for them at once, with no distance to show
  final bool fetchOnOpen;

  const StopDetailsSheet({
    super.key,
    required this.stop,
    required this.anchorLatitude,
    required this.anchorLongitude,
    this.fetchOnOpen = false,
  });

  static Future<void> show(
    BuildContext context, {
    required NearbyStop stop,
    required double anchorLatitude,
    required double anchorLongitude,
    bool fetchOnOpen = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => StopDetailsSheet(
            stop: stop,
            anchorLatitude: anchorLatitude,
            anchorLongitude: anchorLongitude,
            fetchOnOpen: fetchOnOpen,
          ),
    );
  }

  @override
  ConsumerState<StopDetailsSheet> createState() => _StopDetailsSheetState();
}

class _StopDetailsSheetState extends ConsumerState<StopDetailsSheet> {
  late NearbyStop _stop = widget.stop;

  /// When the arrivals on screen were fetched; null until a refresh,
  /// since the list the sheet came from does not say
  DateTime? _updatedAt;
  bool _refreshing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.fetchOnOpen) {
      _refreshing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final fresh = await refreshStopArrivals(
        ref.read(stopsRepositoryProvider),
        _stop,
        anchorLatitude: widget.anchorLatitude,
        anchorLongitude: widget.anchorLongitude,
      );
      if (!mounted) return;
      setState(() {
        _stop = fresh;
        _updatedAt = DateTime.now();
        _failed = false;
      });
    } catch (_) {
      // Keep the arrivals already on screen and say they are not fresh
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = LabPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final stop = _stop;
    final updatedAt = _updatedAt;
    final lines = ref.watch(linesByStopProvider(stop.id));
    final isSaved = ref
        .watch(stopsProvider)
        .favorites
        .any((f) => f.stopId == stop.id);

    return LiveClock(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stop.name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (!widget.fetchOnOpen)
                              l10n.metersAway(stop.distanceMeters.round()),
                            if (updatedAt != null)
                              l10n.updatedAt(DateFormat.Hm().format(updatedAt)),
                          ].join(' · '),
                          style: LabText.statusLine(p),
                        ),
                        if (_failed)
                          Text(
                            l10n.couldNotLoadArrivals,
                            style: LabText.statusLine(
                              p,
                            ).copyWith(color: p.crit),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  LabIconButton(
                    icon: Icons.refresh_rounded,
                    isLoading: _refreshing,
                    onPressed: _refresh,
                    tooltip: l10n.updateArrivals,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.rule)),
                ),
              ),
              // Nothing known yet: the first answer is on its way
              if (widget.fetchOnOpen && updatedAt == null && !_failed)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(),
                )
              else if (stop.arrivals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.noBusesComing,
                    style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                  ),
                )
              else
                for (final (i, arrival) in stop.arrivals.take(6).indexed) ...[
                  if (i > 0) const Divider(),
                  ArrivalRow(
                    arrival: arrival,
                    l10n: l10n,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ],
              const Divider(),
              const SizedBox(height: 16),
              LabSectionLabel(l10n.linesServing),
              const SizedBox(height: 10),
              lines.when(
                loading:
                    () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                error:
                    (_, _) => Text(
                      l10n.noLinesForStop,
                      style: theme.textTheme.bodySmall,
                    ),
                data:
                    (data) =>
                        data.isEmpty
                            ? Text(
                              l10n.noLinesForStop,
                              style: theme.textTheme.bodySmall,
                            )
                            : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final line in data)
                                  Tooltip(
                                    message: line.name,
                                    child: LabLineChip(line.shortName),
                                  ),
                              ],
                            ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // The stop itself when placed; where it was found
                    // from, a few metres off, otherwise
                    final destination = TripPlace(
                      latitude: stop.latitude ?? widget.anchorLatitude,
                      longitude: stop.longitude ?? widget.anchorLongitude,
                      name: stop.name,
                    );
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => PlanTripScreen(destination: destination),
                      ),
                    );
                  },
                  icon: const Icon(Icons.directions_outlined),
                  label: Text(l10n.goHere),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      isSaved
                          ? null
                          : () async {
                            final customName = await showStopNameDialog(
                              context,
                              title: l10n.saveAsFavorite,
                              realName: stop.name,
                            );
                            if (customName == null) return;

                            await ref
                                .read(stopsProvider.notifier)
                                .addFavorite(
                                  id: stop.id,
                                  stopId: stop.id,
                                  name: stop.name,
                                  anchorLatitude: widget.anchorLatitude,
                                  anchorLongitude: widget.anchorLongitude,
                                  customName: customName,
                                );
                            if (context.mounted) Navigator.of(context).pop();
                          },
                  icon: Icon(
                    isSaved ? Icons.star_rounded : Icons.star_outline_rounded,
                  ),
                  label: Text(
                    isSaved ? l10n.stopAlreadySaved : l10n.saveAsFavorite,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
