import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/preferences/app_preferences.dart';
import '../core/providers.dart';
import '../core/session/session_manager.dart';
import '../core/theme/app_theme.dart';
import '../features/foundation_preview/presentation/foundation_preview_screen.dart';
import '../l10n/gen/app_localizations.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const FoundationPreviewScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

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
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionStatusProvider, (previous, next) {
      if (next.value != SessionStatus.expired) return;
      final messenger = _messengerKey.currentState;
      final context = _messengerKey.currentContext;
      if (messenger == null || context == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).sessionExpiredMessage),
        ),
      );
    });

    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      scaffoldMessengerKey: _messengerKey,
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
