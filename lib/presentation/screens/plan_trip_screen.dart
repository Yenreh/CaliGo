import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/trip_entity.dart';
import '../../domain/trip_planner.dart';
import '../../domain/trip_timing.dart';
import '../../l10n/app_localizations.dart';
import '../providers/lines_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stops_provider.dart';
import '../providers/trip_provider.dart';
import '../widgets/lab.dart';
import '../widgets/map_parts.dart';
import '../widgets/shown_on_screen.dart';
import 'place_picker_screen.dart';

/// From one place to another on the MIO: where to walk, which buses to
/// take and where to change, with the trip drawn on the map
class PlanTripScreen extends ConsumerStatefulWidget {
  /// Where to go, when opened from a place already known, such as a stop
  final TripPlace? destination;

  const PlanTripScreen({super.key, this.destination});

  @override
  ConsumerState<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends ConsumerState<PlanTripScreen>
    with ShownOnScreen {
  bool _creditsOpen = false;

  TripPlace? _from;
  late TripPlace? _to = widget.destination;
  bool _locating = false;

  /// The ways the planner found, untimed; null until both places are
  /// known and the routes are in
  List<TripOption>? _plans;

  /// Each plan timed against the buses on their way, by its position in
  /// [_plans]
  final _timed = <int, TripOption>{};

  /// Positions in [_plans] as listed: by arrival, sorted again only when
  /// fresh arrivals come in, so rows do not jump while being read
  List<int> _order = const [];

  /// Line chosen for a ride by tapping it, by plan and then by ride
  final _pinned = <int, Map<int, String>>{};

  LiveArrivals? _live;
  Map<String, Duration> _headways = const {};

  /// What each line's rides were planned with, to read the live ones
  /// against the route alone
  Map<String, double> _rideFactors = const {};
  bool _fetchingLive = false;

  /// The plan opened to its steps and drawn on the map, by its position
  /// in [_plans]; none at first, so all can be compared at a glance
  int? _expanded;

  /// Times are worked out again this often from the arrivals already in
  /// hand: a bus due at a set time only needs the clock to move on
  static const Duration _retimeEvery = Duration(seconds: 20);

  /// Arrivals older than this are asked for again, but only while a
  /// trip is open and the screen in view
  static const Duration _liveMaxAge = Duration(minutes: 2);

  Timer? _ticker;

  /// Share of the screen the map takes while an option is open: the
  /// steps below it matter as much
  static const double _mapShare = 0.3;

  @override
  void initState() {
    super.initState();
    // Most trips start where the phone is; asked quietly, so no prompt
    // stands in front of someone who has not chosen anything yet
    _startFromDevice();
    _ticker = Timer.periodic(_retimeEvery, (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || _plans == null) return;
    final live = _live;
    final stale =
        live == null || DateTime.now().difference(live.fetchedAt) > _liveMaxAge;
    if (_expanded != null && shown && stale) {
      _refreshLive();
    } else {
      _retime();
    }
  }

  /// Back in view, the open trip catches up at once if its arrivals aged
  /// meanwhile; out of view, under the place picker or in the background,
  /// nothing is asked for
  @override
  void shownChanged(bool shown) {
    if (shown) _tick();
  }

  /// A fresh fix closer than this to the origin in use leaves the plan
  /// as it is: replanning would only shuffle the same options
  static const double _refineMeters = 100;

  TripPlace _devicePlace(Position position) => TripPlace(
    latitude: position.latitude,
    longitude: position.longitude,
    name: AppLocalizations.of(context)!.myLocation,
    isDevice: true,
  );

  /// Start at once from where the device was last seen, as the map does,
  /// then refine with a fresh fix
  Future<void> _startFromDevice() async {
    final known = await lastKnownDevicePosition();
    if (!mounted) return;
    if (known != null && _from == null) {
      _from = _devicePlace(known);
      _plan();
    }
    await _locate();
  }

  /// Ask for a fresh fix. Quietly, it only refines an origin that is the
  /// device and has moved; [force] is the button, which always takes it
  /// and may ask for the permission.
  Future<void> _locate({bool force = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await currentDevicePosition(requestPermission: force);
      if (!mounted) return;
      final from = _from;
      if (!force && from != null) {
        if (!from.isDevice) return;
        final moved = metersBetween(
          from.latitude,
          from.longitude,
          position.latitude,
          position.longitude,
        );
        if (moved < _refineMeters) return;
      }
      _from = _devicePlace(position);
      _plan();
    } catch (_) {
      // Quietly, no location only means the origin waits to be chosen
      if (force && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            labSnackBar(
              context,
              AppLocalizations.of(context)!.couldNotLocate,
              tone: LabTone.warn,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _choose({required bool origin}) async {
    final l10n = AppLocalizations.of(context)!;
    final place = await PlacePickerScreen.pick(
      context,
      title: origin ? l10n.chooseOrigin : l10n.chooseDestination,
      near: origin ? (_from ?? _to) : (_to ?? _from),
    );
    if (place == null || !mounted) return;
    if (origin) {
      _from = place;
    } else {
      _to = place;
    }
    _plan();
    // The picker may hand over where the device was last seen
    if (place.isDevice) _locate();
  }

  void _swap() {
    final from = _from;
    _from = _to;
    _to = from;
    _plan();
  }

  /// Counts plans asked for, so one finishing after a newer one started
  /// is dropped
  int _planRequest = 0;
  bool _planning = false;

  Future<void> _plan() async {
    final request = ++_planRequest;
    final from = _from;
    final to = _to;
    final network = ref.read(transitNetworkProvider).asData?.value.network;
    if (from == null || to == null || network == null) {
      setState(() {
        _plans = null;
        _timed.clear();
        _order = const [];
        _expanded = null;
        _planning = false;
      });
      return;
    }

    // Lines not running now would only send someone to an empty stop
    final now = DateTime.now();
    final hours = ref.read(lineHoursProvider).asData?.value ?? const {};
    final leaveOut = {
      for (final MapEntry(key: line, value: time) in hours.entries)
        if (!time.runsAt(now)) line,
    };

    setState(() => _planning = true);
    // What has been learned of each line picks the options, as it times them
    final repository = ref.read(stopsRepositoryProvider);
    final headways = await repository.lineHeadways(now);
    final rideFactors = await repository.rideFactors();
    final options = await planInBackground(
      network: network,
      from: from,
      to: to,
      leaveOut: leaveOut,
      headways: headways,
      rideFactors: rideFactors,
    );
    if (!mounted || request != _planRequest) return;
    setState(() {
      _plans = options;
      _headways = headways;
      _rideFactors = rideFactors;
      _pinned.clear();
      _expanded = null;
      _planning = false;
    });
    // Timed at once by the usual figures, then again with the live buses
    _retime(sort: true);
    await _refreshLive();
  }

  /// Set when arrivals were wanted while others were on their way, or came
  /// back for plans or an option no longer shown: asked for again once
  /// those land, mostly from the areas they just brought
  bool _liveAgain = false;

  /// Ask for the buses on their way to the stops the plans call at: a
  /// few requests, one per area, reusing any area asked about recently.
  /// With an option open only its stops are asked about, and the rest of
  /// the list keeps what it had.
  Future<void> _refreshLive({bool force = false}) async {
    final plans = _plans;
    if (plans == null) return;
    if (_fetchingLive) {
      _liveAgain = true;
      return;
    }
    final open = _expanded;
    final repository = ref.read(stopsRepositoryProvider);
    setState(() => _fetchingLive = true);
    try {
      final now = DateTime.now();
      final headways = await repository.lineHeadways(now);
      final stops = stopsWorthAsking(
        open == null ? plans : [plans[open]],
        start: now,
        headways: headways,
      );
      final live =
          stops.isEmpty
              ? LiveArrivals.none
              : await repository.arrivalsFor(
                stops,
                maxAge: force ? Duration.zero : const Duration(minutes: 1),
              );
      if (!mounted) return;
      if (!identical(plans, _plans)) {
        _liveAgain = true;
        return;
      }
      if (open != null && _expanded != null && open != _expanded) {
        _liveAgain = true;
      }
      _headways = headways;
      _live = open == null ? live : live.over(_live);
      _retime(sort: true);
      _learnRides(plans);
    } finally {
      if (mounted) {
        setState(() => _fetchingLive = false);
        if (_liveAgain) {
          _liveAgain = false;
          unawaited(_refreshLive());
        }
      }
    }
  }

  /// Rides just timed by following their bus teach the planner how each
  /// line runs against its estimate: one reading per line
  void _learnRides(List<TripOption> plans) {
    final readings = <String, double>{};
    for (final (i, plan) in plans.indexed) {
      if (_timed[i] case final timed?) {
        readings.addAll(
          rideReadings(plan, timed, rideFactors: _rideFactors),
        );
      }
    }
    if (readings.isEmpty) return;
    unawaited(ref.read(stopsRepositoryProvider).observeRides(readings));
  }

  /// Time every plan from now with what is known, without asking
  void _retime({bool sort = false}) {
    final plans = _plans;
    if (plans == null) return;
    final now = DateTime.now();
    setState(() {
      for (final (i, plan) in plans.indexed) {
        _timed[i] = timeTrip(
          plan,
          start: now,
          live: _live,
          headways: _headways,
          pinned: _pinned[i] ?? const {},
        );
      }
      if (sort || _order.length != plans.length) {
        // Ranked as the planner ranks them, now with the buses on their way
        _order = List.generate(plans.length, (i) => i)..sort(
          (a, b) => TripPlanner.cost(
            _timed[a]!,
          ).compareTo(TripPlanner.cost(_timed[b]!)),
        );
      }
    });
  }

  /// Show ride [rideIndex] of plan [plan] as made by [line]
  void _chooseLine(int plan, int rideIndex, String line) {
    (_pinned[plan] ??= {})[rideIndex] = line;
    _retime();
  }

  /// One per option row, to bring an opened one into view
  final _rowKeys = <int, GlobalKey>{};

  void _toggle(int index) {
    final opening = _expanded != index;
    setState(() {
      _expanded = opening ? index : null;
      _creditsOpen = false;
    });
    if (!opening) return;
    // The map appearing above pushes the list down: the opened row goes
    // to the top, its steps below it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _rowKeys[index]?.currentContext;
      if (row == null || !row.mounted) return;
      Scrollable.ensureVisible(
        row,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  /// The same search in Google Maps, to compare with its own routes
  Future<void> _openInGoogleMaps() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    await launchUrl(
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': '${from.latitude},${from.longitude}',
        'destination': '${to.latitude},${to.longitude}',
        'travelmode': 'transit',
      }),
      mode: LaunchMode.externalApplication,
    );
  }

  TripOption? get _open => switch (_expanded) {
    final index? => _timed[index],
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = LabPalette.of(context);
    final network = ref.watch(transitNetworkProvider);
    // Loaded alongside, to leave out the lines that are not running
    ref.watch(lineHoursProvider);

    ref.listen(transitNetworkProvider, (previous, next) {
      final arrived =
          next.asData?.value.network != null &&
          previous?.asData?.value.network == null;
      if (arrived) _plan();
    });
    ref.listen(lineHoursProvider, (previous, next) {
      if (next.hasValue && !(previous?.hasValue ?? false)) _plan();
    });

    final open = _open;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.planTrip),
        actions: [
          if (_plans != null)
            IconButton(
              tooltip: l10n.refreshTimes,
              onPressed: _fetchingLive ? null : () => _refreshLive(force: true),
              icon:
                  _fetchingLive
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.refresh_rounded),
            ),
          Tooltip(
            message: l10n.openInGoogleMaps,
            child: TextButton.icon(
              onPressed:
                  _from != null && _to != null ? _openInGoogleMaps : null,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Google Maps'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _PlacesPanel(
            from: _from,
            to: _to,
            locating: _locating,
            onLocate: () => _locate(force: true),
            onFrom: () => _choose(origin: true),
            onTo: () => _choose(origin: false),
            onSwap: _from == null && _to == null ? null : _swap,
          ),
          if (open != null) ...[
            Container(height: 1, color: p.rule),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * _mapShare,
              // A new map for each option, framing the whole trip; choosing
              // another line only redraws it
              child: _map(context, open, key: ValueKey(_expanded)),
            ),
          ],
          Container(height: 2, color: p.ink),
          Expanded(child: _results(context, network)),
        ],
      ),
    );
  }

  /// Every point of [option] and both places, to show it whole
  List<LatLng> _tripPoints(TripOption option) => [
    if (_from case final from?) LatLng(from.latitude, from.longitude),
    if (_to case final to?) LatLng(to.latitude, to.longitude),
    for (final ride in option.rides)
      for (final stop in ride.stops) LatLng(stop.latitude, stop.longitude),
  ];

  Widget _map(BuildContext context, TripOption option, {Key? key}) {
    final dark = ref.watch(settingsProvider.select((s) => s.darkMap));
    final sharp = ref.watch(settingsProvider.select((s) => s.sharpMap));
    final tiles = tilesPalette(dark: dark);
    final from = _from;
    final to = _to;

    return Stack(
      key: key,
      children: [
        FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: _tripPoints(option),
              padding: const EdgeInsets.all(32),
              maxZoom: 16,
            ),
            minZoom: 11,
            maxZoom: 18,
            // A trip reads north up; no compass to bring it back
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
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
                for (final leg in option.legs)
                  switch (leg) {
                    WalkLeg walk => Polyline(
                      points: [
                        LatLng(walk.fromLatitude, walk.fromLongitude),
                        LatLng(walk.toLatitude, walk.toLongitude),
                      ],
                      color: tiles.ink,
                      strokeWidth: 3,
                      pattern: const StrokePattern.dotted(),
                    ),
                    RideLeg ride => Polyline(
                      points: [
                        for (final stop in ride.stops)
                          LatLng(stop.latitude, stop.longitude),
                      ],
                      color: tiles.accent,
                      strokeWidth: 5,
                      borderColor: tiles.paper,
                      borderStrokeWidth: 1.5,
                    ),
                  },
              ],
            ),
            MarkerLayer(
              markers: [
                for (final ride in option.rides)
                  for (final stop in [ride.board, ride.alight])
                    Marker(
                      point: LatLng(stop.latitude, stop.longitude),
                      width: 20,
                      height: 20,
                      child: Tooltip(
                        message: stop.name,
                        child: _StopSquare(tiles: tiles),
                      ),
                    ),
                if (from != null)
                  Marker(
                    point: LatLng(from.latitude, from.longitude),
                    width: 24,
                    height: 24,
                    child: _OriginDot(tiles: tiles),
                  ),
                if (to != null)
                  Marker(
                    point: LatLng(to.latitude, to.longitude),
                    width: 24,
                    height: 24,
                    child: _DestinationSquare(tiles: tiles),
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
    );
  }

  Widget _results(BuildContext context, AsyncValue<NetworkLoad> network) {
    final l10n = AppLocalizations.of(context)!;
    final p = LabPalette.of(context);

    if (network.hasError && network.asData?.value.network == null) {
      return LabEmptyState(
        icon: Icons.cloud_off_outlined,
        message: l10n.couldNotLoadArrivals,
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(transitNetworkProvider),
        secondaryAction: true,
      );
    }

    final load = network.asData?.value;
    if (load?.network == null) {
      final done = load?.done ?? 0;
      final total = load?.total ?? 0;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.loadingRoutes(done, total),
                textAlign: TextAlign.center,
                style: LabText.statusLine(p),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: total > 0 ? done / total : null,
                color: p.accent,
                backgroundColor: p.rule,
              ),
            ],
          ),
        ),
      );
    }

    final plans = _plans;
    if (plans == null && _planning) {
      return const Center(child: CircularProgressIndicator());
    }
    if (plans == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.planHint,
            textAlign: TextAlign.center,
            style: LabText.statusLine(p),
          ),
        ),
      );
    }
    if (plans.isEmpty) {
      return LabEmptyState(
        icon: Icons.route_outlined,
        message: l10n.noTripFound,
      );
    }

    return ListView(
      children: [
        if (_planning) const LinearProgressIndicator(minHeight: 2),
        if (_live?.failed ?? false)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Container(width: 7, height: 7, color: p.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.liveUnavailable,
                    style: LabText.statusLine(p),
                  ),
                ),
              ],
            ),
          ),
        for (final (row, i) in _order.indexed)
          if (_timed[i] case final option?) ...[
            if (row > 0) const Divider(),
            _OptionTile(
              key: _rowKeys.putIfAbsent(i, GlobalKey.new),
              option: option,
              expanded: i == _expanded,
              onTap: () => _toggle(i),
              onChooseLine: (ride, line) => _chooseLine(i, ride, line),
            ),
          ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Text(l10n.tripEstimateNote, style: LabText.statusLine(p)),
        ),
      ],
    );
  }
}

/// Start from where the device is now: a fresh fix, on demand
class _LocateButton extends StatelessWidget {
  final bool locating;
  final VoidCallback onPressed;

  const _LocateButton({required this.locating, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = LabPalette.of(context);

    return Tooltip(
      message: l10n.updateLocation,
      child: InkResponse(
        onTap: locating ? null : onPressed,
        radius: 20,
        child: SizedBox(
          width: 32,
          height: 24,
          child: Center(
            child:
                locating
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.accent,
                      ),
                    )
                    : Icon(Icons.my_location_rounded, size: 20, color: p.muted),
          ),
        ),
      ),
    );
  }
}

/// Origin and destination, each opening the picker, and a way to swap
class _PlacesPanel extends StatelessWidget {
  final TripPlace? from;
  final TripPlace? to;
  final bool locating;
  final VoidCallback onLocate;
  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback? onSwap;

  const _PlacesPanel({
    required this.from,
    required this.to,
    required this.locating,
    required this.onLocate,
    required this.onFrom,
    required this.onTo,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = LabPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _PlaceField(
                  marker: _OriginDot(tiles: p),
                  text: from?.name,
                  placeholder: l10n.chooseOrigin,
                  onTap: onFrom,
                  trailing: _LocateButton(
                    locating: locating,
                    onPressed: onLocate,
                  ),
                ),
                const SizedBox(height: 8),
                _PlaceField(
                  marker: _DestinationSquare(tiles: p),
                  text: to?.name,
                  placeholder: l10n.chooseDestination,
                  onTap: onTo,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          LabIconButton(
            icon: Icons.swap_vert_rounded,
            onPressed: onSwap,
            tooltip: l10n.swapPlaces,
            size: 44,
          ),
        ],
      ),
    );
  }
}

class _PlaceField extends StatelessWidget {
  final Widget marker;
  final String? text;
  final String placeholder;
  final VoidCallback onTap;
  final Widget? trailing;

  const _PlaceField({
    required this.marker,
    required this.text,
    required this.placeholder,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    final theme = Theme.of(context);

    return Material(
      color: p.paper,
      shape: RoundedRectangleBorder(side: BorderSide(color: p.rule)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              SizedBox.square(dimension: 20, child: marker),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text ?? placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: text == null ? p.muted : p.ink,
                  ),
                ),
              ),
              if (trailing case final trailing?) trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// One way to get there: time and the legs at a glance, and each step
/// once opened
class _OptionTile extends StatelessWidget {
  final TripOption option;
  final bool expanded;
  final VoidCallback onTap;
  final void Function(int ride, String line) onChooseLine;

  const _OptionTile({
    super.key,
    required this.option,
    required this.expanded,
    required this.onTap,
    required this.onChooseLine,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = LabPalette.of(context);
    final theme = Theme.of(context);
    final arrivesAt = option.arrivesAt ?? DateTime.now().add(option.duration);
    final arrival = _clock(context, arrivesAt);
    final firstRide = option.firstRide;

    final facts = [
      if (firstRide != null) l10n.transfersCount(option.transfers),
      l10n.walkDistance(_roundTo10(option.walkMeters)),
    ].join(' · ');

    return Material(
      color: expanded ? p.paper2 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: expanded ? p.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(13, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    l10n.minutesShort(_minutes(option.duration)),
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    option.isLive
                        ? l10n.arriveAt(arrival)
                        : l10n.arriveAround(arrival),
                    style: LabText.statusLine(p),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 22,
                    color: p.muted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _LegsStrip(option: option),
              const SizedBox(height: 8),
              if (firstRide != null) _FirstBus(ride: firstRide),
              Text(facts, style: LabText.statusLine(p)),
              if (expanded) ...[
                const SizedBox(height: 12),
                _Steps(option: option, onChooseLine: onChooseLine),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The legs in a row: minutes on foot, then the line chips
class _LegsStrip extends StatelessWidget {
  final TripOption option;

  /// Walks shorter than this are a step across a station, not a leg
  static const double _minWalkMeters = 60;

  const _LegsStrip({required this.option});

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    final shown = [
      for (final leg in option.legs)
        if (leg is RideLeg ||
            (leg is WalkLeg &&
                (leg.meters >= _minWalkMeters || option.rides.isEmpty)))
          leg,
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, leg) in shown.indexed) ...[
          if (i > 0)
            Icon(Icons.chevron_right_rounded, size: 16, color: p.muted),
          switch (leg) {
            WalkLeg walk => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_walk_rounded, size: 18, color: p.muted),
                Text(
                  '${_minutes(walk.duration)}',
                  style: LabText.mono(p, size: 13, color: p.muted),
                ),
              ],
            ),
            RideLeg ride => LabLineChip(ride.lines.join(' / ')),
          },
        ],
      ],
    );
  }
}

/// When the first bus leaves: a live one's time, or the usual wait
/// when none is on its way
class _FirstBus extends StatelessWidget {
  final RideLeg ride;

  const _FirstBus({required this.ride});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = LabPalette.of(context);
    final departsAt = ride.departsAt;

    final String text;
    if (ride.liveWait && departsAt != null) {
      final minutes =
          (departsAt.difference(DateTime.now()).inSeconds / 60).round();
      text =
          minutes <= 0
              ? l10n.nextBusNow(ride.line)
              : l10n.busLeavesAt(
                ride.line,
                _clock(context, departsAt),
                minutes,
              );
    } else {
      text = l10n.noLiveBus(_minutes(ride.wait));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 7, height: 7, color: ride.liveWait ? p.ok : p.warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$text · ${ride.board.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LabText.mono(p, size: 12, color: p.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Each step of the chosen option, in words
class _Steps extends StatelessWidget {
  final TripOption option;
  final void Function(int ride, String line) onChooseLine;

  const _Steps({required this.option, required this.onChooseLine});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = LabPalette.of(context);
    final theme = Theme.of(context);

    Widget step(
      IconData icon,
      String text, {
      String? detail,
      Color? tone,
      Widget? below,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone ?? p.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.bodyMedium),
                if (detail != null) Text(detail, style: LabText.statusLine(p)),
                if (below != null) ...[const SizedBox(height: 8), below],
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.rule))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final leg in option.legs)
            ...switch (leg) {
              WalkLeg walk => [
                step(
                  Icons.directions_walk_rounded,
                  walk.toStop == null
                      ? l10n.stepWalkToDestination(_minutes(walk.duration))
                      : l10n.stepWalkTo(
                        _minutes(walk.duration),
                        walk.toStop!.name,
                      ),
                  detail: l10n.walkDistance(_roundTo10(walk.meters)),
                ),
              ],
              RideLeg ride => [
                step(
                  Icons.directions_bus_rounded,
                  l10n.stepRide(ride.line, ride.towards),
                  detail: [
                    if (ride.liveWait && ride.departsAt != null)
                      l10n.leavesAt(_clock(context, ride.departsAt!))
                    else
                      l10n.waitAbout(_minutes(ride.wait)),
                    l10n.stopsCount(ride.stopCount),
                    '${ride.liveRide ? '' : '~'}'
                        '${l10n.minutesShort(_minutes(ride.duration))}',
                  ].join(' · '),
                  tone: p.accent,
                  below:
                      ride.lines.length < 2
                          ? null
                          : _LineChoice(
                            ride: ride,
                            onChoose:
                                (line) => onChooseLine(
                                  option.rides.toList().indexOf(ride),
                                  line,
                                ),
                          ),
                ),
                step(
                  Icons.logout_rounded,
                  l10n.stepGetOff(ride.alight.name),
                  tone: p.accent,
                ),
              ],
            },
        ],
      ),
    );
  }
}

/// The lines that make one ride, as buttons: the one shown is lit, and
/// tapping another draws its own route and platforms
class _LineChoice extends StatelessWidget {
  final RideLeg ride;
  final ValueChanged<String> onChoose;

  const _LineChoice({required this.ride, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = LabPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final line in ride.lines)
              Semantics(
                button: true,
                selected: line == ride.line,
                child: Material(
                  color: line == ride.line ? p.accent : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: p.accent),
                  ),
                  child: InkWell(
                    onTap: line == ride.line ? null : () => onChoose(line),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        line,
                        textAlign: TextAlign.center,
                        style: LabText.mono(
                          p,
                          size: 13,
                          color: line == ride.line ? p.paper : p.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(l10n.lineChoiceHint, style: LabText.statusLine(p)),
      ],
    );
  }
}

/// Where the trip starts: a round dot, unlike the square stops
class _OriginDot extends StatelessWidget {
  final LabPalette tiles;

  const _OriginDot({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: tiles.ink,
          shape: BoxShape.circle,
          border: Border.all(color: tiles.paper, width: 2.5),
        ),
      ),
    );
  }
}

/// Where the trip ends: a filled red square
class _DestinationSquare extends StatelessWidget {
  final LabPalette tiles;

  const _DestinationSquare({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: tiles.crit,
          border: Border.all(color: tiles.paper, width: 2),
        ),
      ),
    );
  }
}

/// A stop where a bus is boarded or left
class _StopSquare extends StatelessWidget {
  final LabPalette tiles;

  const _StopSquare({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: tiles.paper,
          border: Border.all(color: tiles.ink, width: 2),
        ),
      ),
    );
  }
}

/// Whole minutes, never zero: a step always takes some time
int _minutes(Duration duration) =>
    math.max(1, (duration.inSeconds / 60).round());

int _roundTo10(double meters) => (meters / 10).round() * 10;

/// A time of day as the device writes it
String _clock(BuildContext context, DateTime time) =>
    TimeOfDay.fromDateTime(time).format(context);
