import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/config_error_app.dart';
import 'core/config/app_config.dart';
import 'core/providers.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/links/link_listener.dart';

Future<void> bootstrap(AppEnvironment environment) async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment(
      environment,
      isReleaseBuild: kReleaseMode,
    );
  } on ConfigException catch (e) {
    if (kDebugMode) debugPrint(e.message);
    runApp(const ConfigErrorApp());
    return;
  }

  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const TeiaApp()),
  );
  unawaited(container.read(authControllerProvider.notifier).initialize());
  unawaited(listenForAppLinks(container));
}
