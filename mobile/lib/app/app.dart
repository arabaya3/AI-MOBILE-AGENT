import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/preferences/app_preferences.dart';
import '../core/providers.dart';
import '../core/theme/app_theme.dart';
import '../features/documents/application/document_files.dart';
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
    );
  }
}
