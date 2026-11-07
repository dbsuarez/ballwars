import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Explicit notices for bundled visual assets, alongside Flutter's package notices.
class AppLicenses {
  static bool _registered = false;
  static void register() {
    if (_registered) {
      return;
    }
    _registered = true;
    LicenseRegistry.addLicense(entries);
  }

  static Stream<LicenseEntry> entries() async* {
    for (final item in [
      ('Inter', 'assets/fonts/Inter-OFL.txt'),
      ('Manrope', 'assets/fonts/Manrope-OFL.txt'),
      ('JetBrains Mono', 'assets/fonts/JetBrainsMono-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        item.$1,
      ], await rootBundle.loadString(item.$2));
    }
    yield LicenseEntryWithLineBreaks(
      ['Material Design icons (Google)'],
      'Material Design icons by Google. Distributed with Flutter SDK 3.38.5.\n'
      'Source: https://github.com/google/material-design-icons\n'
      'License: Creative Commons Attribution 4.0 International. The font is unmodified.\n\n'
      '${await rootBundle.loadString('assets/licenses/material-icons-license.txt')}',
    );
  }
}
