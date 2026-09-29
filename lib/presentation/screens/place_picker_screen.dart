import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/trip_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/stops_provider.dart';
import '../providers/trip_provider.dart';
import '../widgets/lab.dart';
import '../widgets/map_parts.dart';

/// Choose where a trip starts or ends: the device, a point on the map,
/// a favorite, a station or any stop along the routes
class PlacePickerScreen extends ConsumerStatefulWidget {
  final String title;

  /// Where the map opens when picking a point
  final TripPlace? near;

  const PlacePickerScreen({super.key, required this.title, this.near});

  static Future<TripPlace?> pick(
    BuildContext context, {
    required String title,
    TripPlace? near,
  }) => Navigator.of(context).push<TripPlace>(
    MaterialPageRoute(
      builder: (_) => PlacePickerScreen(title: title, near: near),
    ),
  );

  @override
  ConsumerState<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends ConsumerState<PlacePickerScreen> {
  final _controller = TextEditingController();
  String _query = '';
  bool _locating = false;

  /// Stops matching a query, at most: the list is for picking, not
  /// browsing every platform in the city
  static const int _maxStops = 25;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useDevice() async {
    final l10n = AppLocalizations.of(context)!;
    // Where the device was last seen answers at once; the planner then
    // refines it with a fresh fix
    final known = await lastKnownDevicePosition();
    if (!mounted) return;
    setState(() => _locating = true);
    try {
      final position = known ?? await currentDevicePosition();
      if (!mounted) return;
      Navigator.of(context).pop(
        TripPlace(
          latitude: position.latitude,
          longitude: position.longitude,
          name: l10n.myLocation,
          isDevice: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          labSnackBar(context, l10n.couldNotLocate, tone: LabTone.warn),
        );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickOnMap() async {
    final l10n = AppLocalizations.of(context)!;
    final point = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => _MapPointPicker(near: widget.near)),
    );
    if (point == null || !mounted) return;

    // A stop close by names the point better than its coordinates
    final network = ref.read(transitNetworkProvider).asData?.value.network;
    final stop = network?.nearestStop(
      point.latitude,
      point.longitude,
      radius: 250,
    );
    Navigator.of(context).pop(
      TripPlace(
        latitude: point.latitude,
        longitude: point.longitude,
        name: stop == null ? l10n.pointOnMap : l10n.nearStop(stop.name),
      ),
    );
  }

  void _choose(String name, double latitude, double longitude) {
    Navigator.of(
      context,
    ).pop(TripPlace(latitude: latitude, longitude: longitude, name: name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final needle = _fold(_query.trim());
    bool matches(String text) => needle.isEmpty || _fold(text).contains(needle);

    final network = ref.watch(transitNetworkProvider).asData?.value.network;
    final favorites = ref.watch(stopsProvider.select((s) => s.favorites));
    final stations = ref.watch(stationsProvider).asData?.value ?? const [];

    final shownStations = [
      for (final s in stations)
        if (matches(s.name) || matches(s.address)) s,
    ];
    final seenNames = <String>{};
    final shownStops =
        [
          if (needle.length >= 2 && network != null)
            for (final stop in network.stops)
              if (matches(stop.name) && seenNames.add(stop.name)) stop,
        ].take(_maxStops).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: l10n.searchPlace,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.my_location_rounded),
                  title: Text(l10n.myLocation),
                  trailing:
                      _locating
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : null,
                  onTap: _locating ? null : _useDevice,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(l10n.pickOnMap),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _pickOnMap,
                ),
                ..._section(l10n.favoritesShort, [
                  for (final favorite in favorites)
                    if (matches(favorite.displayName) || matches(favorite.name))
                      _tile(
                        icon: Icons.signpost_outlined,
                        title: favorite.displayName,
                        subtitle: favorite.secondaryName,
                        onTap: () {
                          // The stop itself when the routes know it; its
                          // anchor, a few metres off, otherwise
                          final stop =
                              favorite.stopId == null
                                  ? null
                                  : network?.stopById(favorite.stopId!);
                          _choose(
                            favorite.displayName,
                            stop?.latitude ?? favorite.anchorLatitude,
                            stop?.longitude ?? favorite.anchorLongitude,
                          );
                        },
                      ),
                ]),
                ..._section(l10n.stationCatalog, [
                  for (final station in shownStations)
                    _tile(
                      icon: Icons.directions_bus_outlined,
                      title: station.name,
                      subtitle: station.address,
                      onTap:
                          () => _choose(
                            station.name,
                            station.latitude,
                            station.longitude,
                          ),
                    ),
                ]),
                ..._section(l10n.stopsSection, [
                  for (final stop in shownStops)
                    _tile(
                      icon: Icons.place_outlined,
                      title: stop.name,
                      onTap:
                          () =>
                              _choose(stop.name, stop.latitude, stop.longitude),
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null || subtitle.isEmpty ? null : Text(subtitle),
    onTap: onTap,
  );

  List<Widget> _section(String title, List<Widget> tiles) => [
    if (tiles.isNotEmpty) ...[
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        child: LabSectionLabel(title),
      ),
      for (final (i, tile) in tiles.indexed) ...[
        if (i > 0) const Divider(),
        tile,
      ],
    ],
  ];
}

/// Lowercase and without accents, so "universidades" finds "Universidades"
/// and "estacion" finds "Estación"
String _fold(String text) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final i = from.indexOf(char);
    buffer.write(i < 0 ? char : to[i]);
  }
  return buffer.toString();
}

/// A map with a crosshair: the point under it is the one chosen
class _MapPointPicker extends ConsumerStatefulWidget {
  final TripPlace? near;

  const _MapPointPicker({this.near});

  @override
  ConsumerState<_MapPointPicker> createState() => _MapPointPickerState();
}

class _MapPointPickerState extends ConsumerState<_MapPointPicker> {
  final _mapController = MapController();
  bool _creditsOpen = false;

  static const LatLng _caliCenter = LatLng(3.4516, -76.5320);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = LabPalette.of(context);
    final dark = ref.watch(settingsProvider.select((s) => s.darkMap));
    final sharp = ref.watch(settingsProvider.select((s) => s.sharpMap));
    final tiles = tilesPalette(dark: dark);
    final near = widget.near;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pickOnMap)),
      body: Stack(
        alignment: Alignment.center,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  near == null
                      ? _caliCenter
                      : LatLng(near.latitude, near.longitude),
              initialZoom: near == null ? 13 : 16,
              minZoom: 11,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && _creditsOpen) {
                  setState(() => _creditsOpen = false);
                }
              },
            ),
            children: [mapTileLayer(context, dark: dark, sharp: sharp)],
          ),
          IgnorePointer(
            child: Icon(Icons.add_rounded, size: 36, color: p.crit),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: MapCredits(
              open: _creditsOpen,
              onToggle: () => setState(() => _creditsOpen = !_creditsOpen),
              tiles: tiles,
            ),
          ),
          Positioned(
            left: 72,
            right: 72,
            bottom: 16,
            child: FilledButton.icon(
              onPressed:
                  () => Navigator.of(context).pop(_mapController.camera.center),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(l10n.usePoint),
            ),
          ),
        ],
      ),
    );
  }
}
