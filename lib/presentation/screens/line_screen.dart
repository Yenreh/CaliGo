import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/line_entity.dart';
import '../../domain/entities/stop_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/lines_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/lab.dart';
import '../widgets/map_parts.dart';
import '../widgets/shown_on_screen.dart';
import '../widgets/stop_details_sheet.dart';

/// A line's route on the map, one direction at a time, with its buses
/// where they are now and its stops in order below.
class LineScreen extends ConsumerStatefulWidget {
  final TransitLine line;

  const LineScreen({super.key, required this.line});

  @override
  ConsumerState<LineScreen> createState() => _LineScreenState();
}

class _LineScreenState extends ConsumerState<LineScreen> with ShownOnScreen {
  final _mapController = MapController();
  bool _mapReady = false;
  bool _creditsOpen = false;
  int? _direction;
  String? _selectedStopId;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Out of view the buses are let go, which stops asking for them; back
  /// in view they are asked for at once
  @override
  void shownChanged(bool shown) => setState(() {});

  AsyncValue<List<LineBus>> _buses(String line) =>
      shown ? ref.watch(lineBusesProvider(line)) : const AsyncValue.loading();

  /// Frame [stops] on the map
  void _fit(List<LineStop> stops) {
    if (!_mapReady || stops.length < 2) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [for (final s in stops) LatLng(s.latitude, s.longitude)],
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  void _chooseDirection(int direction, List<LineStop> all) {
    setState(() {
      _direction = direction;
      _selectedStopId = null;
    });
    _fit(all.where((s) => s.direction == direction).toList());
  }

  /// Bring the map to a stop and show its buses, fetched as it opens:
  /// the route says where the stop is, not what is coming
  void _open(LineStop stop) {
    setState(() => _selectedStopId = stop.stopId);
    if (_mapReady) {
      _mapController.move(
        LatLng(stop.latitude, stop.longitude),
        _mapController.camera.zoom < 16 ? 16 : _mapController.camera.zoom,
      );
    }
    StopDetailsSheet.show(
      context,
      stop: NearbyStop(
        id: stop.stopId,
        name: stop.name,
        distanceMeters: 0,
        latitude: stop.latitude,
        longitude: stop.longitude,
      ),
      anchorLatitude: stop.latitude,
      anchorLongitude: stop.longitude,
      fetchOnOpen: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.line.name;
    final stops = ref.watch(lineStopsProvider(name));
    final updatingBuses = _buses(name).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          if (updatingBuses)
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
              tooltip: l10n.updateBusPositions,
              // Starts the round over: positions now, the next in 30 s
              onPressed: () => ref.invalidate(lineBusesProvider(name)),
            ),
        ],
      ),
      body: stops.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LabEmptyState(
          icon: Icons.cloud_off_outlined,
          message: l10n.couldNotLoadArrivals,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(lineStopsProvider(name)),
          secondaryAction: true,
        ),
        data: (all) => all.isEmpty
            ? LabEmptyState(
                icon: Icons.route_outlined,
                message: l10n.noLineRoute,
              )
            : _route(context, all),
      ),
    );
  }

  Widget _route(BuildContext context, List<LineStop> all) {
    final p = LabPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final name = widget.line.name;
    final dark = ref.watch(settingsProvider.select((s) => s.darkMap));
    final sharp = ref.watch(settingsProvider.select((s) => s.sharpMap));
    final tiles = tilesPalette(dark: dark);
    final buses = _buses(name);
    final hours = ref.watch(lineHoursProvider).asData?.value[name];

    final directions = {for (final s in all) s.direction}.toList()..sort();
    final direction = directions.contains(_direction)
        ? _direction!
        : directions.first;
    final route = [
      for (final s in all)
        if (s.direction == direction) s,
    ];
    final points = [for (final s in route) LatLng(s.latitude, s.longitude)];

    String hhmm(Duration d) =>
        '${d.inHours.remainder(24).toString().padLeft(2, '0')}:'
        '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}';
    final status = [
      if (hours != null)
        hours.runsAt(DateTime.now())
            ? l10n.lineRuns(hhmm(hours.start), hhmm(hours.end))
            : '${l10n.lineNotRunning} · '
                '${hhmm(hours.start)}–${hhmm(hours.end)}',
      if (buses.asData?.value case final running?)
        l10n.busesThisWay(
          running.where((b) => b.direction == direction).length,
        ),
    ].join(' · ');
    // Buses going the other way would read as coming; those the service
    // could not place show faded rather than not at all
    final shownBuses = [
      for (final bus in buses.asData?.value ?? const <LineBus>[])
        if (bus.direction == null || bus.direction == direction) bus,
    ];

    return Column(
      children: [
        if (directions.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _DirectionToggle(
              labels: [
                for (final d in directions)
                  l10n.towards(all.lastWhere((s) => s.direction == d).name),
              ],
              selected: directions.indexOf(direction),
              onSelected: (i) => _chooseDirection(directions[i], all),
            ),
          ),
        if (status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(status, style: LabText.statusLine(p)),
            ),
          ),
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCameraFit: CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(40),
                  ),
                  minZoom: 11,
                  maxZoom: 18,
                  // A route reads north up; no compass to bring it back
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () => _mapReady = true,
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture && _creditsOpen) {
                      setState(() => _creditsOpen = false);
                    }
                  },
                ),
                children: [
                  mapTileLayer(context, dark: dark, sharp: sharp),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: tiles.accent,
                        strokeWidth: 4,
                        borderColor: tiles.paper,
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      for (final stop in route)
                        Marker(
                          point: LatLng(stop.latitude, stop.longitude),
                          width: 28,
                          height: 28,
                          child: GestureDetector(
                            onTap: () => _open(stop),
                            child: _RouteStopDot(
                              selected: stop.stopId == _selectedStopId,
                              tiles: tiles,
                            ),
                          ),
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      for (final bus in shownBuses)
                        Marker(
                          point: LatLng(bus.latitude, bus.longitude),
                          width: 28,
                          height: 28,
                          child: Tooltip(
                            message: bus.busNumber,
                            child: Opacity(
                              opacity: bus.direction == null ? 0.45 : 1,
                              child: _BusMarker(tiles: tiles),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
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
            ],
          ),
        ),
        Container(height: 2, color: p.ink),
        Expanded(
          flex: 2,
          child: ListView.separated(
            itemCount: route.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final stop = route[index];
              return ListTile(
                selected: stop.stopId == _selectedStopId,
                selectedTileColor: p.paper2,
                leading: SizedBox(
                  width: 28,
                  child: Text(
                    '${stop.sequence}',
                    textAlign: TextAlign.right,
                    style: LabText.mono(p, size: 13, color: p.muted),
                  ),
                ),
                title: Text(stop.name),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _open(stop),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Two-way switch between a line's directions, named by where each ends
class _DirectionToggle extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  const _DirectionToggle({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(border: Border.all(color: p.rule)),
      child: Row(
        children: [
          for (final (i, label) in labels.indexed)
            Expanded(
              child: Material(
                color: i == selected ? p.fill : p.paper,
                child: InkWell(
                  onTap: i == selected ? null : () => onSelected(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: i == selected ? p.onFill : p.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small square for a stop along the route; larger and filled once picked
class _RouteStopDot extends StatelessWidget {
  final bool selected;
  final LabPalette tiles;

  const _RouteStopDot({required this.selected, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final size = selected ? 18.0 : 12.0;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: selected ? tiles.accent : tiles.paper,
          border: Border.all(color: tiles.ink, width: 2),
        ),
      ),
    );
  }
}

/// A bus on the line: filled square with a bus in it, apart from the
/// hollow stops
class _BusMarker extends StatelessWidget {
  final LabPalette tiles;

  const _BusMarker({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: tiles.fill,
          border: Border.all(color: tiles.paper, width: 1.5),
        ),
        child: Icon(Icons.directions_bus_rounded, size: 16, color: tiles.onFill),
      ),
    );
  }
}
