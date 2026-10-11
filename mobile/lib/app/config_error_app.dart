import 'package:flutter/material.dart';

import '../core/preferences/app_preferences.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/feedback.dart';
import '../l10n/gen/app_localizations.dart';
import 'app.dart';

/// Shown instead of the app when the build configuration is unsafe; makes no network calls.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      supportedLocales: supportedAppLocales,
      localizationsDelegates: localizationsDelegates,
      localeListResolutionCallback: (deviceLocales, _) =>
          resolveAppLocale(null, deviceLocales),
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: StatusBanner(
                    tone: StatusTone.error,
                    title: l10n.configErrorTitle,
                    message: l10n.configErrorBody,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
