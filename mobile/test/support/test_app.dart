import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teia_ai/app/app.dart';
import 'package:teia_ai/core/config/app_config.dart';
import 'package:teia_ai/core/providers.dart';
import 'package:teia_ai/core/storage/token_store.dart';

AppConfig testConfig([AppEnvironment env = AppEnvironment.dev]) =>
    AppConfig.parse(
      environment: env,
      rawApiBaseUrl: env == AppEnvironment.dev
          ? 'http://10.0.2.2:8001/api/v1'
          : 'https://api.example.com/api/v1',
      isReleaseBuild: false,
    );

/// Pumps the real app with fake storage at a compact phone size.
Future<ProviderContainer> pumpTeiaApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  AppConfig? config,
  Size size = const Size(360, 740),
  double textScale = 1.0,
  Locale? deviceLocale,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  if (deviceLocale != null) {
    tester.platformDispatcher.localesTestValue = [deviceLocale];
  }
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config ?? testConfig()),
      sharedPreferencesProvider.overrideWithValue(preferences),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TeiaApp()),
  );
  await tester.pumpAndSettle();
  return container;
}
