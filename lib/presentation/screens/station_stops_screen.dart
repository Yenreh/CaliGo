import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/stop_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/stops_provider.dart';
import '../widgets/stop_details_sheet.dart';
import '../widgets/stop_name_dialog.dart';

/// Stops belonging to a station.
///
/// A station spans several platforms, and following all of them at once
/// is usually noise, so each one can be saved on its own.
class StationStopsScreen extends ConsumerWidget {
  final Station station;

  const StationStopsScreen({super.key, required this.station});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final point = (latitude: station.latitude, longitude: station.longitude);
    final stops = ref.watch(stopsAtPointProvider(point));

    return Scaffold(
      appBar: AppBar(
        title: Text(station.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_outline_rounded),
            tooltip: l10n.saveThisArea,
            onPressed: () async {
              final customName = await showStopNameDialog(
                context,
                title: l10n.saveThisArea,
                realName: station.name,
              );
              if (customName == null) return;

              await ref.read(stopsProvider.notifier).addFavorite(
                    id: 'station-${station.id}',
                    name: station.name,
                    anchorLatitude: station.latitude,
                    anchorLongitude: station.longitude,
                    customName: customName,
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: stops.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.couldNotLoadArrivals)),
        data: (found) => found.isEmpty
            ? Center(child: Text(l10n.noStopsNearby))
            : ListView.separated(
                itemCount: found.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final stop = found[index];
                  final lines =
                      stop.arrivals.map((a) => a.line).toSet().take(4).join(', ');
                  return ListTile(
                    leading: const Icon(Icons.signpost_outlined),
                    title: Text(stop.name),
                    subtitle: Text(
                      '${l10n.metersAway(stop.distanceMeters.round())}'
                      '${lines.isEmpty ? '' : ' · $lines'}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => StopDetailsSheet.show(
                      context,
                      stop: stop,
                      anchorLatitude: station.latitude,
                      anchorLongitude: station.longitude,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
