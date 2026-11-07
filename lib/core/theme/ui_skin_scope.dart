import 'dart:async';
import 'package:flutter/widgets.dart';
import '../offline/device_prefs.dart';
import 'ui_skin.dart';

/// Presentation-only choice. Never stored in shared/admin/game settings.
class UiSkinController extends ChangeNotifier {
  UiSkinController({UiSkin initial = UiSkin.classic}) : _value = initial;
  UiSkin _value;
  UiSkin get value => _value;
  bool saving = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() async {
    final generation = ++_generation;
    try {
      final saved = await DevicePrefs.readRequired('ui-skin');
      if (_disposed || generation != _generation) return;
      _value = UiSkin.fromId(saved);
      error = null;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      error =
          'Could not read your saved UI skin. Choose a skin to save it again.';
    }
    notifyListeners();
  }

  Future<bool> select(UiSkin skin) async {
    if (saving || _disposed) return false;
    ++_generation; // A late startup read must not replace this choice.
    saving = true;
    error = null;
    notifyListeners();
    try {
      await DevicePrefs.writeRequired('ui-skin', skin.id);
      if (_disposed) return false;
      _value = skin;
      return true;
    } catch (_) {
      if (!_disposed) {
        error =
            'Could not save the UI skin on this device. Your previous skin is still active. Please retry.';
      }
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class UiSkinScope extends InheritedNotifier<UiSkinController> {
  const UiSkinScope({
    super.key,
    required UiSkinController controller,
    required super.child,
  }) : super(notifier: controller);
  static UiSkinController? controllerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiSkinScope>()?.notifier;
  static UiSkin of(BuildContext context) =>
      controllerOf(context)?.value ?? UiSkin.classic;
}

/// Also lets isolated workbenches/settings routes function without an app root.
class UiSkinHost extends StatefulWidget {
  const UiSkinHost({
    super.key,
    this.controller,
    this.load = true,
    required this.child,
  });
  final UiSkinController? controller;
  final bool load;
  final Widget child;
  @override
  State<UiSkinHost> createState() => _UiSkinHostState();
}

class _UiSkinHostState extends State<UiSkinHost> {
  late final UiSkinController _controller =
      widget.controller ?? UiSkinController();
  @override
  void initState() {
    super.initState();
    if (widget.load) unawaited(_controller.load());
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      UiSkinScope(controller: _controller, child: widget.child);
}
