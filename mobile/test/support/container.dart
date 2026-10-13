import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teia_ai/core/providers.dart';
import 'package:teia_ai/core/storage/token_store.dart';

import 'fake_backend.dart';
import 'test_app.dart';

Future<ProviderContainer> makeContainer(
  FakeBackend backend, {
  TokenStore? store,
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(testConfig()),
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
      tokenStoreProvider.overrideWithValue(store ?? InMemoryTokenStore()),
      dioProvider.overrideWithValue(backend.dio),
      testCacheRoot(),
      ...overrides,
    ],
  );
  return container;
}

Future<void> settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
