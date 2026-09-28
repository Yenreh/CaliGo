import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Shared beat for the arrival countdowns below it.
///
/// Only the widgets that call [LiveClock.watch] rebuild on each beat,
/// not the screen around them. The beat stops while the subtree cannot
/// be seen, such as when another screen covers it, and catches up the
/// moment it shows again.
class LiveClock extends StatefulWidget {
  final Widget child;
  final Duration interval;

  const LiveClock({
    super.key,
    required this.child,
    this.interval = const Duration(seconds: 15),
  });

  /// Rebuild [context] on every beat; does nothing without a clock above
  static void watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<_LiveClockScope>();
  }

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  final _beat = ValueNotifier<int>(0);
  Timer? _timer;
  ValueListenable<bool>? _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Turned off by the navigator for screens covered by another one
    final visible = TickerMode.getNotifier(context);
    if (visible != _visible) {
      _visible?.removeListener(_sync);
      _visible = visible..addListener(_sync);
      _sync();
    }
  }

  void _sync() {
    final visible = _visible?.value ?? false;
    if (visible && _timer == null) {
      _beat.value++;
      _timer = Timer.periodic(widget.interval, (_) => _beat.value++);
    } else if (!visible) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _visible?.removeListener(_sync);
    _timer?.cancel();
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _LiveClockScope(notifier: _beat, child: widget.child);
}

class _LiveClockScope extends InheritedNotifier<ValueNotifier<int>> {
  const _LiveClockScope({required super.notifier, required super.child});
}
