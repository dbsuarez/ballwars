import 'package:flutter/material.dart';
import 'package:ballwars/core/widgets/app_frame.dart';
import 'package:ballwars/core/legal/app_licenses.dart';
import 'package:ballwars/features/lobby/presentation/game_ui_gallery.dart';

/// Standalone workbench: flutter run -t tools/ux/game_ui_gallery.dart -d chrome
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLicenses.register();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (_, child) => AppFrame(child: child!),
      home: const GameUiGallery(),
    ),
  );
}
