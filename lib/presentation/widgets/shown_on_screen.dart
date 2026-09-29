import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Tells a screen whether it can be seen: the app in front and no other
/// screen covering it, which is when polling a service is worth it.
///
/// [shown] starts false, so the first call to [shownChanged] is the
/// screen coming into view.
mixin ShownOnScreen<T extends StatefulWidget> on State<T> {
  ValueListenable<bool>? _uncovered;
  AppLifecycleListener? _lifecycle;
  bool _shown = false;

  /// What [shownChanged] was last told, so a change seen twice before it
  /// runs is told once
  bool _told = false;

  bool get shown => _shown;

  /// Called whenever [shown] changes, never in the middle of a build
  @protected
  void shownChanged(bool shown);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lifecycle ??= AppLifecycleListener(onStateChange: (_) => _sync());
    // Turned off by the navigator for screens covered by another one
    final uncovered = TickerMode.getNotifier(context);
    if (uncovered != _uncovered) {
      _uncovered?.removeListener(_sync);
      _uncovered = uncovered..addListener(_sync);
    }
    _sync();
  }

  void _sync() {
    final inFront = switch (WidgetsBinding.instance.lifecycleState) {
      null || AppLifecycleState.resumed => true,
      _ => false,
    };
    final shown = inFront && (_uncovered?.value ?? false);
    if (shown == _shown) return;
    _shown = shown;

    // Neither a provider nor this state may change while widgets build,
    // which is when the navigator covers or uncovers a screen
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tell());
    } else {
      _tell();
    }
  }

  void _tell() {
    if (!mounted || _shown == _told) return;
    _told = _shown;
    shownChanged(_shown);
  }

  @override
  void dispose() {
    _uncovered?.removeListener(_sync);
    _lifecycle?.dispose();
    super.dispose();
  }
}
