import 'dart:async';

import 'package:flutter/widgets.dart';

/// Polls only while this screen is visible: the app is in the foreground and
/// the screen's route is the top one. Nothing runs in the background.
///
/// When the screen becomes visible again (app resumed), data older than the
/// interval is refreshed immediately.
mixin VisiblePolling<T extends StatefulWidget> on State<T> {
  Duration get pollInterval;

  /// Refetch the screen's data. Errors are swallowed; the providers keep
  /// showing the last good value.
  Future<void> poll();

  Timer? _pollTimer;
  late final _PollObserver _pollObserver = _PollObserver(this);
  bool _foreground = true;
  bool _polling = false;

  /// A tick passed while the screen was hidden, so data may be old.
  bool _stale = false;

  /// A manual refresh just ran; skip the next tick instead of repeating it.
  bool _skipNext = false;

  /// Call after any manual refresh so the next tick doesn't repeat it.
  void markPolled() {
    _skipNext = true;
    _stale = false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_pollObserver);
    _pollTimer = Timer.periodic(pollInterval, (_) => _tick());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_pollObserver);
    super.dispose();
  }

  bool get _visible => mounted && _foreground && (ModalRoute.of(context)?.isCurrent ?? true);

  void _tick() {
    if (!_visible) {
      _stale = true;
      return;
    }
    if (_skipNext) {
      _skipNext = false;
      return;
    }
    _run();
  }

  Future<void> _run() async {
    if (_polling) return;
    _polling = true;
    try {
      await poll();
    } catch (_) {
      // Keep the last good data on screen.
    } finally {
      _stale = false;
      _skipNext = false;
      _polling = false;
    }
  }

  void _onLifecycle(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _stale && _visible) _run();
  }
}

class _PollObserver with WidgetsBindingObserver {
  _PollObserver(this.owner);
  final VisiblePolling<StatefulWidget> owner;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => owner._onLifecycle(state);
}
