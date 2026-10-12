import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../preferences/app_preferences.dart';
import '../theme/app_theme.dart';
import 'section.dart';

class AppearanceSettings extends ConsumerWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return Section(
      title: l10n.sectionAppearance,
      children: [
        Text(l10n.themeLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text(l10n.themeSystem),
            ),
            ButtonSegment(value: ThemeMode.light, label: Text(l10n.themeLight)),
            ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
          ],
          selected: {themeMode},
          showSelectedIcon: false,
          onSelectionChanged: (value) =>
              ref.read(themeModeProvider.notifier).select(value.first),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.languageLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'system', label: Text(l10n.languageSystem)),
            ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
            ButtonSegment(value: 'ar', label: Text(l10n.languageArabic)),
          ],
          selected: {locale?.languageCode ?? 'system'},
          showSelectedIcon: false,
          onSelectionChanged: (value) {
            final code = value.first;
            ref
                .read(localeProvider.notifier)
                .select(code == 'system' ? null : Locale(code));
          },
        ),
      ],
    );
  }
}
