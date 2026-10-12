import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../preferences/app_preferences.dart';

/// Lets signed-out users switch language before entering any details.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return TextButton.icon(
      onPressed: () => ref
          .read(localeProvider.notifier)
          .select(Locale(isArabic ? 'en' : 'ar')),
      icon: const Icon(Icons.translate),
      label: Text(isArabic ? l10n.languageEnglish : l10n.languageArabic),
    );
  }
}
