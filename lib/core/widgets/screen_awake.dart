import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps a visible, running match awake; releases on pause, background or exit.
class ScreenAwake extends StatefulWidget {
  const ScreenAwake({super.key, required this.enabled, required this.child, this.setEnabled});

  final bool enabled;
  final Widget child;
  final Future<void> Function(bool)? setEnabled;

  @override
  State<ScreenAwake> createState() => _ScreenAwakeState();
}

class _ScreenAwakeState extends State<ScreenAwake> with WidgetsBindingObserver {
  bool _foreground = true;
  bool? _requested;
  Future<void> _pending = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void didUpdateWidget(ScreenAwake oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _request(bool enabled) {
    if (_requested == enabled) return;
    _requested = enabled;
    _pending = _pending.then((_) async {
      try {
        final setter = widget.setEnabled;
        if (setter != null) {
          await setter(enabled);
        } else {
          await WakelockPlus.toggle(enable: enabled);
        }
      } catch (_) {
        // Browsers can deny wake-lock requests, and widget tests lack a plugin.
        // Allow a later lifecycle transition to retry the request.
        _requested = null;
      }
    });
    unawaited(_pending);
  }

  void _sync() => _request(widget.enabled && _foreground);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _request(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
