import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoglens/shared/visible_polling.dart';

class _Poller extends StatefulWidget {
  const _Poller({required this.onPoll});
  final VoidCallback onPoll;
  @override
  State<_Poller> createState() => _PollerState();
}

class _PollerState extends State<_Poller> with VisiblePolling {
  @override
  Duration get pollInterval => const Duration(seconds: 10);
  @override
  Future<void> poll() async => widget.onPoll();
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('polls only while visible and in the foreground', (tester) async {
    var polls = 0;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: _Poller(onPoll: () => polls++)));

    await tester.pump(const Duration(seconds: 31));
    expect(polls, 3, reason: 'visible: one poll per interval');

    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    final covered = polls;
    await tester.pump(const Duration(seconds: 60));
    expect(polls, covered, reason: 'another page on top: no polling');

    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(polls, covered + 1, reason: 'back on top with stale data: refresh right away');
    await tester.pump(const Duration(seconds: 11));
    expect(polls, covered + 2, reason: 'and keep polling');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final paused = polls;
    await tester.pump(const Duration(seconds: 60));
    expect(polls, paused, reason: 'app in background: no polling');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(polls, paused + 1, reason: 'resume with stale data: refresh immediately');
  });

  testWidgets('a quick round trip does not refetch', (tester) async {
    var polls = 0;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: _Poller(onPoll: () => polls++)));
    await tester.pump(const Duration(seconds: 10));
    final before = polls;
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(polls, before, reason: 'data is younger than the stale threshold');
  });

  testWidgets('stops for good once the screen is disposed', (tester) async {
    var polls = 0;
    await tester.pumpWidget(MaterialApp(home: _Poller(onPoll: () => polls++)));
    await tester.pump(const Duration(seconds: 11));
    final before = polls;
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(minutes: 5));
    expect(polls, before);
  });
}
