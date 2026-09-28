import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/stop_entity.dart';
import '../../l10n/app_localizations.dart';
import 'lab.dart';
import 'live_clock.dart';

/// One favorite stop with its next buses
class FavoriteStopCard extends StatelessWidget {
  final FavoriteStop stop;
  final List<BusArrival>? arrivals;
  final AppLocalizations l10n;

  /// Removing lives in the stops screen; null hides the action
  final VoidCallback? onRemove;

  /// Renaming lives in the stops screen too; null hides the action
  final VoidCallback? onRename;

  /// Offered when the stop went missing; null hides the action
  final VoidCallback? onRelink;

  /// Flips whether the home screen lists the stop; null hides the action
  final VoidCallback? onToggleHome;

  /// Whether a refresh is on its way, which tells an empty card apart
  /// from one still waiting for its first answer
  final bool isLoading;

  const FavoriteStopCard({
    super.key,
    required this.stop,
    required this.arrivals,
    required this.l10n,
    this.onRemove,
    this.onRename,
    this.onRelink,
    this.onToggleHome,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = LabPalette.of(context);
    final all = arrivals;
    final list = all == null ? null : stop.pick(all);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: p.muted);

    return LabPanel(
      accentTop: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              onRename != null || onRemove != null || onToggleHome != null
                  ? 12
                  : 16,
              12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (stop.secondaryName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          stop.secondaryName!,
                          style: LabText.statusLine(p).copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (stop.lines.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        LabChip(stop.lines.join(' · ')),
                      ],
                      if (onToggleHome != null && !stop.showOnHome) ...[
                        const SizedBox(height: 6),
                        LabChip(l10n.hiddenFromHome.toUpperCase()),
                      ],
                    ],
                  ),
                ),
                if (onToggleHome != null) ...[
                  const SizedBox(width: 8),
                  LabIconButton(
                    icon:
                        stop.showOnHome
                            ? Icons.home_rounded
                            : Icons.home_outlined,
                    active: stop.showOnHome,
                    tooltip:
                        stop.showOnHome ? l10n.hideFromHome : l10n.showOnHome,
                    onPressed: onToggleHome,
                  ),
                ],
                if (onRename != null) ...[
                  const SizedBox(width: 6),
                  LabIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: l10n.editStop,
                    onPressed: onRename,
                  ),
                ],
                if (onRemove != null) ...[
                  const SizedBox(width: 6),
                  LabIconButton(
                    icon: Icons.star_rounded,
                    tooltip: l10n.removeStop,
                    onPressed: onRemove,
                  ),
                ],
              ],
            ),
          ),
          if (stop.looksGone) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Container(width: 8, height: 8, color: p.crit),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.stopNotReported,
                      style: LabText.statusLine(
                        p,
                      ).copyWith(color: p.crit, fontSize: 13),
                    ),
                  ),
                  if (onRelink != null)
                    TextButton(
                      onPressed: onRelink,
                      child: Text(l10n.relinkStop),
                    ),
                ],
              ),
            ),
          ],
          const Divider(),
          if (list == null)
            isLoading
                ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: LinearProgressIndicator(),
                )
                : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.arrivalsUnknown, style: muted),
                )
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                // Buses may be coming, just none of the lines followed
                all!.isNotEmpty ? l10n.noBusesOfLines : l10n.noBusesComing,
                style: muted,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final (i, arrival) in list.take(5).indexed) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    ArrivalRow(
                      arrival: arrival,
                      l10n: l10n,
                      showStopName: stop.isArea,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A single line/destination/countdown row
class ArrivalRow extends StatelessWidget {
  final BusArrival arrival;
  final AppLocalizations l10n;
  final bool showStopName;
  final EdgeInsetsGeometry padding;

  const ArrivalRow({
    super.key,
    required this.arrival,
    required this.l10n,
    this.showStopName = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          LabLineChip(arrival.line),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  arrival.destination,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showStopName && arrival.stopName.isNotEmpty)
                  Text(
                    arrival.stopName,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Countdown(arrival: arrival, l10n: l10n),
        ],
      ),
    );
  }
}

/// Minutes left, the only part of an arrival that changes on its own:
/// it alone follows the [LiveClock] above
class _Countdown extends StatelessWidget {
  final BusArrival arrival;
  final AppLocalizations l10n;

  const _Countdown({required this.arrival, required this.l10n});

  @override
  Widget build(BuildContext context) {
    LiveClock.watch(context);
    final p = LabPalette.of(context);
    final minutes = arrival.minutesUntilArrival();

    return Text(
      minutes == 0 ? l10n.arrivingNow : l10n.minutesShort(minutes),
      style: LabText.mono(p, size: 16, color: minutes <= 2 ? p.ok : p.ink),
    );
  }
}
