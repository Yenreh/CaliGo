import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show pi;
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../data/datasources/map_tile_cache.dart';
import '../../l10n/app_localizations.dart';

/// Pieces every map in the app shares: the tiles, their credits and the
/// frameless controls drawn on top of them.
///
/// Tiles come from CARTO when the build carries a key: its styles leave
/// out the bus stops and shops OpenStreetMap draws into its own tiles,
/// which only add noise next to the stops the app shows. Without a key
/// the maps fall back to OpenStreetMap.

/// Passed with --dart-define or --dart-define-from-file, never committed
const String cartoKey = String.fromEnvironment('CARTO_KEY');

/// The controls sit on the tiles, so they take the tiles' colours
LabPalette tilesPalette({required bool dark}) =>
    dark ? LabPalette.dark : LabPalette.light;

/// Voyager's cream paper sits close to the light theme; Dark Matter
/// is the dark one, only when the settings ask for it. OpenStreetMap
/// only has light tiles, so those are inverted instead.
Widget mapTileLayer(BuildContext context, {required bool dark}) {
  const key = cartoKey;
  if (key.isEmpty) {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: AppInfo.packageId,
      panBuffer: 0,
      tileProvider: NetworkTileProvider(cachingProvider: MapTileCache.provider),
      tileBuilder: dark ? darkModeTileBuilder : null,
    );
  }

  final style = dark ? 'dark_all' : 'voyager';
  return TileLayer(
    // A new style is a new set of tiles, not an update of the old ones
    key: ValueKey(style),
    urlTemplate:
        'https://basemaps.cartocdn.com/rastertiles/'
        '$style/{z}/{x}/{y}{r}.png?key=$key',
    retinaMode: RetinaMode.isHighDensity(context),
    userAgentPackageName: AppInfo.packageId,
    // Only what is on screen: the default ring of hidden tiles around
    // it roughly triples what a first look downloads
    panBuffer: 0,
    tileProvider: NetworkTileProvider(cachingProvider: MapTileCache.provider),
  );
}

/// Info icon on the line of the map buttons, opening a paper panel above
/// it with the sources
class MapCredits extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;

  /// The icon sits on the tiles, so it follows them rather than the theme
  final LabPalette tiles;

  const MapCredits({
    super.key,
    required this.open,
    required this.onToggle,
    required this.tiles,
  });

  static void _launch(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    final l10n = AppLocalizations.of(context)!;

    Widget link(String label, String url) => InkWell(
      onTap: () => _launch(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '\u00a9 $label',
          style: LabText.mono(p, size: 12, color: p.accent),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (open) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: BoxDecoration(
              color: p.paper,
              border: Border.all(color: p.rule),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                link(
                  'OpenStreetMap contributors',
                  'https://openstreetmap.org/copyright',
                ),
                if (cartoKey.isNotEmpty)
                  link('CARTO', 'https://carto.com/attributions'),
                // The stops, routes and buses drawn on top are theirs
                link(AppInfo.dataSource, AppInfo.dataSourceUrl),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        Tooltip(
          message: l10n.mapCredits,
          child: InkResponse(
            onTap: onToggle,
            radius: MapButton.size / 2,
            child: SizedBox.square(
              dimension: MapButton.size,
              child: Icon(
                open ? Icons.close_rounded : Icons.info_outline_rounded,
                color: tiles.ink,
                size: 22,
                shadows: mapHalo(tiles.paper),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Map control drawn straight on the tiles, without a frame: a halo in
/// the tiles' paper keeps it readable. All share one tap size.
class MapButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;
  final Widget child;

  static const double size = 44;

  const MapButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: size / 2,
        child: SizedBox.square(dimension: size, child: Center(child: child)),
      ),
    );
  }
}

/// Thin halo around an icon glyph, standing in for the frame it lacks
List<Shadow> mapHalo(Color color) => [
  for (final offset in const [
    Offset(1.2, 0),
    Offset(-1.2, 0),
    Offset(0, 1.2),
    Offset(0, -1.2),
    Offset(0.9, 0.9),
    Offset(-0.9, 0.9),
    Offset(0.9, -0.9),
    Offset(-0.9, -0.9),
  ])
    Shadow(color: color, offset: offset, blurRadius: 1),
];

/// Width added to every stroke of the drawn glyphs for their halo
const double mapHaloWidth = 3;

/// Square stop marker: outlined on paper, filled with accent when chosen
class MapStopMarker extends StatelessWidget {
  final bool selected;
  final LabPalette palette;

  const MapStopMarker({
    super.key,
    required this.selected,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final size = selected ? 30.0 : 24.0;

    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: selected ? p.fill : p.paper,
          border: Border.all(color: selected ? p.accent : p.ink, width: 1.5),
        ),
        child: Icon(
          Icons.directions_bus_rounded,
          size: selected ? 18 : 15,
          color: selected ? p.onFill : p.ink,
        ),
      ),
    );
  }
}

/// Small instrument dial: a ring with the four cardinal ticks and a
/// needle whose red half points at true north. The whole dial turns with
/// the map.
class CompassNeedle extends StatelessWidget {
  final double rotationDegrees;
  final LabPalette tiles;

  const CompassNeedle({
    super.key,
    required this.rotationDegrees,
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationDegrees * pi / 180,
      child: CustomPaint(
        size: const Size.square(30),
        painter: CompassPainter(
          north: tiles.crit,
          south: tiles.muted,
          ring: tiles.ink,
          hub: tiles.paper,
        ),
      ),
    );
  }
}

class CompassPainter extends CustomPainter {
  final Color north;
  final Color south;
  final Color ring;
  final Color hub;

  const CompassPainter({
    required this.north,
    required this.south,
    required this.ring,
    required this.hub,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;

    // Halo behind the ring and needle, in the hub's paper colour
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + mapHaloWidth
        ..color = hub,
    );
    final stroke =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ring;
    canvas.drawCircle(centre, radius, stroke);

    // Cardinal ticks; north's is longer and red
    for (var i = 0; i < 4; i++) {
      final isNorth = i == 0;
      final angle = i * pi / 2;
      final direction = Offset(math.sin(angle), -math.cos(angle));
      final length = isNorth ? 5.0 : 3.0;
      canvas.drawLine(
        centre + direction * radius,
        centre + direction * (radius - length),
        Paint()
          ..strokeWidth = isNorth ? 2.4 : 1.6
          ..color = isNorth ? north : ring,
      );
    }

    // Slim needle, split lengthwise into its north and south halves
    const halfWidth = 4.0;
    final tip = radius - 4;
    canvas.drawPath(
      ui.Path()
        ..moveTo(centre.dx, centre.dy - tip)
        ..lineTo(centre.dx + halfWidth, centre.dy)
        ..lineTo(centre.dx, centre.dy + tip)
        ..lineTo(centre.dx - halfWidth, centre.dy)
        ..close(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = mapHaloWidth
        ..strokeJoin = StrokeJoin.round
        ..color = hub,
    );
    final fill = Paint()..style = PaintingStyle.fill;
    canvas.drawPath(
      ui.Path()
        ..moveTo(centre.dx, centre.dy - tip)
        ..lineTo(centre.dx + halfWidth, centre.dy)
        ..lineTo(centre.dx - halfWidth, centre.dy)
        ..close(),
      fill..color = north,
    );
    canvas.drawPath(
      ui.Path()
        ..moveTo(centre.dx, centre.dy + tip)
        ..lineTo(centre.dx + halfWidth, centre.dy)
        ..lineTo(centre.dx - halfWidth, centre.dy)
        ..close(),
      fill..color = south,
    );
    canvas.drawCircle(centre, 1.8, fill..color = hub);
  }

  @override
  bool shouldRepaint(CompassPainter oldDelegate) =>
      oldDelegate.north != north ||
      oldDelegate.south != south ||
      oldDelegate.ring != ring ||
      oldDelegate.hub != hub;
}
