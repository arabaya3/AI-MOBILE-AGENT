import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/preferences/app_preferences.dart';
import '../core/config/app_config.dart';
import '../core/providers.dart';
import '../core/theme/app_theme.dart';
import '../core/files/private_files.dart';
import '../features/documents/application/document_files.dart';
import '../features/notifications/application/notifications_controller.dart';
import '../l10n/gen/app_localizations.dart';
import 'router.dart';

const localizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class TeiaApp extends ConsumerStatefulWidget {
  const TeiaApp({super.key});

  @override
  ConsumerState<TeiaApp> createState() => _TeiaAppState();
}

class _TeiaAppState extends ConsumerState<TeiaApp> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onStateChange: (state) => ref
        .read(appForegroundProvider.notifier)
        .set(state == AppLifecycleState.resumed),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps downloaded copies tied to the current account and space.
    ref.watch(documentFilesProvider);
    ref.watch(privateFilesProvider);
    // Starts the live notification link once signed in; it follows the account and app lifecycle.
    ref.listen(notificationsControllerProvider, (_, _) {});
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: ref.watch(routerProvider),
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: localizationsDelegates,
      localeListResolutionCallback: (deviceLocales, _) =>
          resolveAppLocale(locale, deviceLocales),
      builder: (context, child) => EnvironmentBanner(
        environment: ref.watch(appConfigProvider).environment,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Marks every non-production build on every screen, so a staging or dev app is never mistaken
/// for the production one (also in release builds, where Flutter's DEBUG banner is absent).
class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({
    super.key,
    required this.environment,
    required this.child,
  });

  final AppEnvironment environment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = switch (environment) {
      AppEnvironment.prod => null,
      AppEnvironment.staging => 'STAGING',
      AppEnvironment.dev => 'DEV',
    };
    if (label == null) return child;
    return Banner(
      message: label,
      location: BannerLocation.bottomStart,
      color: environment == AppEnvironment.staging
          ? const Color(0xFFB45309)
          : const Color(0xFF475569),
      child: child,
    );
  }
}
