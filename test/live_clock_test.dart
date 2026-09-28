import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miocard/presentation/widgets/live_clock.dart';

/// Counts its own builds, rebuilding on every beat of the clock above
class _Watcher extends StatelessWidget {
  final List<int> builds;

  const _Watcher(this.builds);

  @override
  Widget build(BuildContext context) {
    LiveClock.watch(context);
    builds.add(1);
    return const SizedBox();
  }
}

Widget _clock(List<int> builds, {bool visible = true}) => TickerMode(
      enabled: visible,
      child: LiveClock(
        interval: const Duration(seconds: 15),
        child: _Watcher(builds),
      ),
    );

void main() {
  testWidgets('rebuilds what watches it on every beat', (tester) async {
    final builds = <int>[];
    await tester.pumpWidget(_clock(builds));
    final before = builds.length;

    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 15));

    expect(builds.length, before + 2);
  });

  testWidgets('stays still while hidden and catches up when shown',
      (tester) async {
    final builds = <int>[];
    await tester.pumpWidget(_clock(builds, visible: false));
    final before = builds.length;

    await tester.pump(const Duration(minutes: 1));
    expect(builds.length, before);

    await tester.pumpWidget(_clock(builds));
    await tester.pump();
    expect(builds.length, greaterThan(before));
  });
}
