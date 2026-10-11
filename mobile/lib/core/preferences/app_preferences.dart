import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

const supportedAppLocales = [Locale('en'), Locale('ar')];

/// English is the fallback for any unsupported device locale.
Locale resolveAppLocale(Locale? selected, List<Locale>? deviceLocales) {
  if (selected != null) return selected;
  for (final device in deviceLocales ?? const <Locale>[]) {
    for (final supported in supportedAppLocales) {
      if (supported.languageCode == device.languageCode) return supported;
    }
  }
  return supportedAppLocales.first;
}

class LocaleController extends Notifier<Locale?> {
  static const _key = 'app_locale';

  @override
  Locale? build() {
    final code = ref.watch(sharedPreferencesProvider).getString(_key);
    return supportedAppLocales.where((l) => l.languageCode == code).firstOrNull;
  }

  /// `null` follows the device language.
  Future<void> select(Locale? locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values.where((m) => m.name == name).firstOrNull ??
        ThemeMode.system;
  }

  Future<void> select(ThemeMode mode) async {
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
