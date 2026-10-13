import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teia_ai/app/app.dart';
import 'package:teia_ai/core/config/app_config.dart';
import 'package:teia_ai/core/preferences/app_preferences.dart';
import 'package:teia_ai/core/providers.dart';
import 'package:teia_ai/core/storage/token_store.dart';
import 'package:teia_ai/core/theme/app_theme.dart';
import 'package:teia_ai/features/auth/application/auth_controller.dart';
import 'package:teia_ai/features/documents/application/document_files.dart';
import 'package:teia_ai/features/foundation_preview/presentation/foundation_preview_screen.dart';

import 'fake_backend.dart';

/// A fresh private directory standing in for the app cache.
Override testCacheRoot() {
  final dir = Directory.systemTemp.createTempSync('teia-test-cache-');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return documentsCacheRootProvider.overrideWithValue(Future.value(dir));
}

AppConfig testConfig([AppEnvironment env = AppEnvironment.dev]) =>
    AppConfig.parse(
      environment: env,
      rawApiBaseUrl: env == AppEnvironment.dev
          ? 'http://10.0.2.2:8001/api/v1'
          : 'https://api.example.com/api/v1',
      isReleaseBuild: false,
    );

Future<SharedPreferences> _prepare(
  WidgetTester tester, {
  required Map<String, Object> prefs,
  required Size size,
  required double textScale,
  Locale? deviceLocale,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  if (deviceLocale != null) {
    tester.platformDispatcher.localesTestValue = [deviceLocale];
  }
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  return SharedPreferences.getInstance();
}

/// The Phase 0 design preview with real theme and locale handling.
Future<ProviderContainer> pumpPreview(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  AppConfig? config,
  Size size = const Size(360, 740),
  double textScale = 1.0,
  Locale? deviceLocale,
}) async {
  final preferences = await _prepare(
    tester,
    prefs: prefs,
    size: size,
    textScale: textScale,
    deviceLocale: deviceLocale,
  );
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config ?? testConfig()),
      sharedPreferencesProvider.overrideWithValue(preferences),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          final locale = ref.watch(localeProvider);
          return MaterialApp(
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            themeMode: ref.watch(themeModeProvider),
            locale: locale,
            supportedLocales: supportedAppLocales,
            localizationsDelegates: localizationsDelegates,
            localeListResolutionCallback: (devices, _) =>
                resolveAppLocale(locale, devices),
            home: const FoundationPreviewScreen(),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The full app (router, auth, spaces) against a scripted backend.
Future<ProviderContainer> pumpTeiaApp(
  WidgetTester tester,
  FakeBackend backend, {
  TokenStore? store,
  Map<String, Object> prefs = const {},
  Size size = const Size(360, 740),
  double textScale = 1.0,
  List<Override> overrides = const [],
}) async {
  final preferences = await _prepare(
    tester,
    prefs: prefs,
    size: size,
    textScale: textScale,
  );
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(testConfig()),
      sharedPreferencesProvider.overrideWithValue(preferences),
      tokenStoreProvider.overrideWithValue(store ?? InMemoryTokenStore()),
      dioProvider.overrideWithValue(backend.dio),
      testCacheRoot(),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TeiaApp()),
  );
  await tester.runAsync(
    () => container.read(authControllerProvider.notifier).initialize(),
  );
  await settleApp(tester);
  return container;
}

/// Lets fake network futures complete and the UI settle.
Future<void> settleApp(WidgetTester tester) async {
  // Bounded: loading indicators animate forever, so pumpAndSettle cannot be used.
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}
