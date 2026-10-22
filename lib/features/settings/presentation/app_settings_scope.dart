import 'package:flutter/widgets.dart';
import '../../replay_export/data/short_link_repository.dart';
import '../data/app_settings_repository.dart';
import '../domain/app_settings.dart';

/// Makes the app-wide settings (headline, theme) and the admin services
/// available below the app root; widgets rebuild when the settings change.
class AppSettingsScope extends InheritedNotifier<ValueNotifier<AppSettings>> {
  /// Null where there is no backend (e.g. tests): settings stay at defaults
  /// and the admin section is hidden.
  final AppSettingsRepository? repository;
  final AdminAuth? adminAuth;

  /// Short share links (`?r=<code>`); null falls back to long links.
  final ShortLinkRepository? shortLinks;

  const AppSettingsScope({
    super.key,
    required ValueNotifier<AppSettings> settings,
    this.repository,
    this.adminAuth,
    this.shortLinks,
    required super.child,
  }) : super(notifier: settings);

  static AppSettingsScope? _scope(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();

  /// The current settings (defaults when there's no scope).
  static AppSettings of(BuildContext context) => _scope(context)?.notifier?.value ?? AppSettings.defaults;

  static AppSettingsScope? maybeScope(BuildContext context) => _scope(context);
}
