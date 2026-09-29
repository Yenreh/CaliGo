import 'package:caligo/presentation/widgets/shown_on_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records each change it hears of
class _Watching extends StatefulWidget {
  final List<bool> heard;

  const _Watching(this.heard);

  @override
  State<_Watching> createState() => _WatchingState();
}

class _WatchingState extends State<_Watching> with ShownOnScreen {
  @override
  void shownChanged(bool shown) => widget.heard.add(shown);

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  testWidgets('hears when another screen covers it and when it leaves',
      (tester) async {
    final heard = <bool>[];
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: _Watching(heard)),
    );
    await tester.pumpAndSettle();
    expect(heard, [true]);

    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    expect(heard, [true, false]);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(heard, [true, false, true]);
  });

  testWidgets('hears when the app goes to the background and comes back',
      (tester) async {
    final heard = <bool>[];
    await tester.pumpWidget(MaterialApp(home: _Watching(heard)));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(heard, [true, false]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(heard, [true, false, true]);
  });
}
