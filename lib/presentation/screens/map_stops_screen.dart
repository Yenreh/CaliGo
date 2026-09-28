import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../data/datasources/json_cache.dart';
import '../../domain/entities/stop_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/stops_provider.dart';
import '../widgets/map_parts.dart';
import '../widgets/stop_details_sheet.dart';

/// Pick any place on the map and inspect the stops around it
class MapStopsScreen extends ConsumerStatefulWidget {
  const MapStopsScreen({super.key});

  /// Cali city centre, used when nothing better is known
  static const LatLng _caliCenter = LatLng(3.4516, -76.5320);

  /// Zoom the map opens at on a known position
  static const double _placeZoom = 16;

  /// A fresh fix closer than this to where the map opened leaves it be:
  /// moving would only fetch the same area again
  static const double _recentreMetres = 150;

  static const String _cameraKey = 'map_camera';

  @override
  ConsumerState<MapStopsScreen> createState() => _MapStopsScreenState();
}

class _MapStopsScreenState extends ConsumerState<MapStopsScreen> {
  final _mapController = MapController();
  MapPoint? _searched;
  String? _selectedStopId;
  bool _mapReady = false;
  bool _locating = false;
  bool _creditsOpen = false;

  /// Rotation in degrees. Only the compass follows it, so it is kept out
  /// of the screen state: a turn reports dozens of steps a second.
  final _rotation = ValueNotifier<double>(0);

  StreamSubscription<MapEvent>? _events;

  final _cache = JsonCache();

  /// Where the map opens; null until worked out, which takes a moment
  ({LatLng center, double zoom})? _start;

  /// Last view reported by the map, saved on leaving: by then the map
  /// itself may already be gone
  MapCamera? _lastCamera;

  @override
  void initState() {
    super.initState();
    _openWhereUseful();
    // Rotation is only reported through the event stream, so the needle
    // follows the map as it turns instead of jumping at the end.
    _events = _mapController.mapEventStream.listen((event) {
      _lastCamera = event.camera;
      // Moving the map puts the credits away, as tapping elsewhere would
      if (_creditsOpen && event is MapEventMove && mounted) {
        setState(() => _creditsOpen = false);
      }
      final rotation = event.camera.rotation;
      if ((rotation - _rotation.value).abs() > 0.1) {
        _rotation.value = rotation;
      }
    });
  }

  /// Open on the last known device position, then on where the map was
  /// left, and only then on the city centre. Opening on the centre and
  /// jumping to the user once located fetched two areas every time.
  Future<void> _openWhereUseful() async {
    ({LatLng center, double zoom})? start;

    try {
      // Instant and GPS-free, but only with the permission already given
      final known = await Geolocator.getLastKnownPosition();
      if (known != null) {
        start = (
          center: LatLng(known.latitude, known.longitude),
          zoom: MapStopsScreen._placeZoom,
        );
      }
    } catch (_) {
      // No permission or no fix yet: fall through
    }

    if (start == null) {
      final saved = await _cache.read(MapStopsScreen._cameraKey);
      if (saved is List && saved.length == 3) {
        start = (
          center: LatLng(
            (saved[0] as num).toDouble(),
            (saved[1] as num).toDouble(),
          ),
          zoom: (saved[2] as num).toDouble(),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _start = start ?? (center: MapStopsScreen._caliCenter, zoom: 15);
    });
    _centreOnDevice(askForPermission: false);
  }

  @override
  void dispose() {
    final camera = _lastCamera;
    if (camera != null) {
      unawaited(
        _cache.write(MapStopsScreen._cameraKey, [
          camera.center.latitude,
          camera.center.longitude,
          camera.zoom,
        ]),
      );
    }
    _events?.cancel();
    _rotation.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Move to where the user is, staying put when that is not known.
  ///
  /// The quiet call on opening leaves the map alone when the fix lands
  /// near where it already is; the button always moves.
  Future<void> _centreOnDevice({bool askForPermission = true}) async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      final position = await currentDevicePosition(
        requestPermission: askForPermission,
      );
      if (!mounted || !_mapReady) return;
      final here = LatLng(position.latitude, position.longitude);
      final away = const Distance().as(
        LengthUnit.Meter,
        _mapController.camera.center,
        here,
      );
      if (!askForPermission && away < MapStopsScreen._recentreMetres) return;
      _mapController.move(here, MapStopsScreen._placeZoom);
    } catch (_) {
      // No location: the map stays where it opened.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _searchHere() {
    final center = _mapController.camera.center;
    setState(() {
      _searched = (latitude: center.latitude, longitude: center.longitude);
      _selectedStopId = null;
    });
  }

  /// Highlight a stop and bring the map to it
  void _focus(NearbyStop stop) {
    setState(() => _selectedStopId = stop.id);
    if (!stop.hasPosition || !_mapReady) return;

    _mapController.move(
      LatLng(stop.latitude!, stop.longitude!),
      _mapController.camera.zoom < 16 ? 17 : _mapController.camera.zoom,
    );
  }

  void _openDetails(NearbyStop stop, MapPoint point) {
    _focus(stop);
    StopDetailsSheet.show(
      context,
      stop: stop,
      anchorLatitude: point.latitude,
      anchorLongitude: point.longitude,
    );
  }

  /// One marker per placed stop, the selected one standing out
  List<Marker> _markers(
    BuildContext context,
    AsyncValue<List<NearbyStop>>? results,
  ) {
    final stops = results?.asData?.value;
    if (stops == null) return const [];

    final p = LabPalette.of(context);

    return [
      for (final stop in stops.where((s) => s.hasPosition))
        Marker(
          point: LatLng(stop.latitude!, stop.longitude!),
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _openDetails(stop, _searched!),
            child: MapStopMarker(
              selected: stop.id == _selectedStopId,
              palette: p,
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    final isDark = ref.watch(settingsProvider.select((s) => s.darkMap));
    final tiles = tilesPalette(dark: isDark);
    final l10n = AppLocalizations.of(context)!;
    final point = _searched;
    final results =
        point == null ? null : ref.watch(stopsAtPointProvider(point));
    final start = _start;

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Plain paper for the moment it takes to pick where to open,
              // so no tiles are fetched for a place the map leaves at once
              if (start == null)
                Positioned.fill(child: ColoredBox(color: tiles.paper))
              else
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: start.center,
                    initialZoom: start.zoom,
                    minZoom: 11,
                    maxZoom: 18,
                    onMapReady: () => _mapReady = true,
                  ),
                  children: [
                    mapTileLayer(context, dark: isDark),
                    MarkerLayer(markers: _markers(context, results)),
                  ],
                ),
              // Crosshair marking the point that will be searched
              IgnorePointer(
                child: Icon(Icons.add_rounded, size: 36, color: p.crit),
              ),
              // The data is OpenStreetMap's (ODbL) and the tiles are drawn
              // by CARTO or the OSM Foundation: all ask to be credited on
              // the map. Kept behind a button aligned with the others.
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
                top: 12,
                right: 12,
                child: ValueListenableBuilder<double>(
                  valueListenable: _rotation,
                  builder:
                      (context, rotation, _) =>
                          rotation.abs() > 0.5
                              ? MapButton(
                                onPressed: () => _mapController.rotate(0),
                                tooltip: l10n.resetNorth,
                                child: CompassNeedle(
                                  rotationDegrees: rotation,
                                  tiles: tiles,
                                ),
                              )
                              : const SizedBox.shrink(),
                ),
              ),
              // Icon only and centred, so it hides as little map as
              // possible
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Center(
                  child: MapButton(
                    onPressed: _searchHere,
                    tooltip: l10n.searchHere,
                    child: _SearchGlyph(tiles: tiles),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: MapButton(
                  onPressed: _locating ? null : () => _centreOnDevice(),
                  tooltip: l10n.myLocation,
                  child:
                      _locating
                          ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: tiles.ink,
                            ),
                          )
                          : Icon(
                            Icons.my_location_rounded,
                            color: tiles.ink,
                            size: 24,
                            shadows: mapHalo(tiles.paper),
                          ),
                ),
              ),
            ],
          ),
        ),
        Container(height: 2, color: p.ink),
        Expanded(
          flex: 2,
          child:
              results == null
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.mapHint,
                        textAlign: TextAlign.center,
                        style: LabText.statusLine(p),
                      ),
                    ),
                  )
                  : results.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error:
                        (_, _) =>
                            Center(child: Text(l10n.couldNotLoadArrivals)),
                    data:
                        (stops) =>
                            stops.isEmpty
                                ? Center(child: Text(l10n.noStopsNearby))
                                : ListView.separated(
                                  itemCount: stops.length,
                                  separatorBuilder: (_, _) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final stop = stops[index];
                                    final lines = stop.arrivals
                                        .map((a) => a.line)
                                        .toSet()
                                        .take(4)
                                        .join(', ');
                                    return ListTile(
                                      // The row of the stop picked on the map
                                      selected: stop.id == _selectedStopId,
                                      selectedTileColor: p.paper2,
                                      leading: const Icon(
                                        Icons.signpost_outlined,
                                      ),
                                      title: Text(stop.name),
                                      subtitle: Text(
                                        '${l10n.metersAway(stop.distanceMeters.round())}'
                                        '${lines.isEmpty ? '' : ' · $lines'}',
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                      ),
                                      // Same as tapping its marker: bring the map
                                      // to it before showing the details
                                      onTap: () => _openDetails(stop, point!),
                                    );
                                  },
                                ),
                  ),
        ),
      ],
    );
  }
}

/// Magnifier drawn to match the compass: an ink lens with a red reticle
/// inside, since the search looks around the point under the crosshair
class _SearchGlyph extends StatelessWidget {
  final LabPalette tiles;

  const _SearchGlyph({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(30),
      painter: _SearchPainter(
        lens: tiles.ink,
        cross: tiles.crit,
        halo: tiles.paper,
      ),
    );
  }
}

class _SearchPainter extends CustomPainter {
  final Color lens;
  final Color cross;
  final Color halo;

  const _SearchPainter({
    required this.lens,
    required this.cross,
    required this.halo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide * 0.32;
    // Lens up and left, leaving room for the handle
    final centre = Offset(radius + 2, radius + 2);
    final rim = centre + Offset(radius, radius) * (1 / math.sqrt2);
    final tick = radius * 0.4;

    // Halo pass first, then the glyph over it
    for (final haloPass in [true, false]) {
      final extra = haloPass ? mapHaloWidth : 0.0;
      Color tone(Color c) => haloPass ? halo : c;

      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + extra
          ..color = tone(lens),
      );

      // Handle, at 45 degrees from the rim to the corner
      canvas.drawLine(
        rim,
        Offset(size.width - 2, size.height - 2),
        Paint()
          ..strokeWidth = 3.5 + extra
          ..strokeCap = StrokeCap.square
          ..color = tone(lens),
      );

      // Reticle ticks and a centre dot: the point being searched, not a
      // zoom, which a plus inside a lens would suggest
      final reticle =
          Paint()
            ..strokeWidth = 1.8 + extra
            ..color = tone(cross);
      for (final direction in const [
        Offset(1, 0),
        Offset(-1, 0),
        Offset(0, 1),
        Offset(0, -1),
      ]) {
        canvas.drawLine(
          centre + direction * (radius - 1),
          centre + direction * (radius - 1 - tick),
          reticle,
        );
      }
      canvas.drawCircle(centre, 1.8 + extra / 2, reticle);
    }
  }

  @override
  bool shouldRepaint(_SearchPainter oldDelegate) =>
      oldDelegate.lens != lens ||
      oldDelegate.cross != cross ||
      oldDelegate.halo != halo;
}
