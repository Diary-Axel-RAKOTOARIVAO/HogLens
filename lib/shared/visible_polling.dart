import 'dart:async';

import 'package:flutter/widgets.dart';

/// Polls only while this screen is visible: the app is in the foreground and
/// the screen's route is the top one. Nothing runs in the background.
///
/// When the screen becomes visible again (back from another page, or the
/// app resumed), data older than [staleAfter] is refreshed immediately.
mixin VisiblePolling<T extends StatefulWidget> on State<T> {
  Duration get pollInterval;

  /// Refetch the screen's data. Errors are swallowed; the providers keep
  /// showing the last good value.
  Future<void> poll();

  /// How old data may be before a return to the screen refreshes it.
  Duration get staleAfter => pollInterval < const Duration(seconds: 15) ? pollInterval : const Duration(seconds: 15);

  static const _step = Duration(seconds: 5);

  Timer? _pollTimer;
  late final _PollObserver _pollObserver = _PollObserver(this);
  bool _foreground = true;
  bool _polling = false;
  bool _wasVisible = true;

  // Two clocks: ticks count time the timer saw; the wall clock catches
  // time the OS spent with the app suspended, when timers don't run.
  Duration _sinceTicks = Duration.zero;
  DateTime _lastWall = DateTime.now();

  Duration get _sincePoll {
    final wall = DateTime.now().difference(_lastWall);
    return wall > _sinceTicks ? wall : _sinceTicks;
  }

  /// Call after any manual refresh so the next tick doesn't repeat it.
  void markPolled() {
    _sinceTicks = Duration.zero;
    _lastWall = DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_pollObserver);
    _pollTimer = Timer.periodic(_step, (_) => _onTick());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute.of registers a dependency, so this runs again whenever the
    // route stops or starts being the top one.
    final visible = _visible;
    if (visible && !_wasVisible) _onBecameVisible();
    _wasVisible = visible;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_pollObserver);
    super.dispose();
  }

  bool get _visible => mounted && _foreground && (ModalRoute.of(context)?.isCurrent ?? true);

  void _onTick() {
    _sinceTicks += _step;
    if (_visible && _sincePoll >= pollInterval) _run();
  }

  void _onBecameVisible() {
    if (_sincePoll >= staleAfter) _run();
  }

  Future<void> _run() async {
    if (_polling) return;
    _polling = true;
    try {
      await poll();
    } catch (_) {
      // Keep the last good data on screen.
    } finally {
      markPolled();
      _polling = false;
    }
  }

  void _onLifecycle(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!mounted) return;
    final visible = _visible;
    if (visible && !_wasVisible) _onBecameVisible();
    _wasVisible = visible;
  }
}

class _PollObserver with WidgetsBindingObserver {
  _PollObserver(this.owner);
  final VisiblePolling<StatefulWidget> owner;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => owner._onLifecycle(state);
}

/// Wraps a screen whose build is stateless and polls [onPoll] while it is
/// visible.
class RefreshWhileVisible extends StatefulWidget {
  const RefreshWhileVisible({super.key, required this.interval, required this.onPoll, required this.child});
  final Duration interval;
  final Future<void> Function() onPoll;
  final Widget child;

  @override
  State<RefreshWhileVisible> createState() => _RefreshWhileVisibleState();
}

class _RefreshWhileVisibleState extends State<RefreshWhileVisible> with VisiblePolling {
  @override
  Duration get pollInterval => widget.interval;

  @override
  Future<void> poll() => widget.onPoll();

  @override
  Widget build(BuildContext context) => widget.child;
}
