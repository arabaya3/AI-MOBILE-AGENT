import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teia_ai/core/config/app_config.dart';
import 'package:teia_ai/core/l10n/text_direction.dart';
import 'package:teia_ai/core/preferences/app_preferences.dart';
import 'package:teia_ai/core/session/session_manager.dart';
import 'package:teia_ai/core/providers.dart';
import 'package:teia_ai/core/widgets/section.dart';
import 'package:teia_ai/features/foundation_preview/presentation/foundation_preview_screen.dart';

import '../support/test_app.dart';

TextDirection directionOf(WidgetTester tester, Finder finder) =>
    Directionality.of(tester.element(finder));

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final lang in ['en', 'ar']) {
      testWidgets('renders in $lang / ${mode.name} without layout errors', (
        tester,
      ) async {
        await pumpTeiaApp(
          tester,
          prefs: {'theme_mode': mode.name, 'app_locale': lang},
        );

        final context = tester.element(find.byType(FoundationPreviewScreen));
        expect(
          Theme.of(context).brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(
          Directionality.of(context),
          lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          find.text(lang == 'ar' ? 'معاينة الأساس' : 'Foundation preview'),
          findsOneWidget,
        );

        await scrollTo(
          tester,
          find.byKey(FoundationPreviewScreen.lastSectionKey),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('survives 2x text scaling at compact phone size', (tester) async {
    await pumpTeiaApp(tester, textScale: 2.0, prefs: {'app_locale': 'ar'});
    await scrollTo(tester, find.byKey(FoundationPreviewScreen.lastSectionKey));
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to English for unsupported device locales', (
    tester,
  ) async {
    await pumpTeiaApp(tester, deviceLocale: const Locale('fr', 'FR'));
    expect(find.text('Foundation preview'), findsOneWidget);
  });

  testWidgets('follows an Arabic device locale when no preference is stored', (
    tester,
  ) async {
    await pumpTeiaApp(tester, deviceLocale: const Locale('ar', 'JO'));
    expect(
      directionOf(tester, find.byType(FoundationPreviewScreen)),
      TextDirection.rtl,
    );
  });

  testWidgets('language and theme choices apply immediately and persist', (
    tester,
  ) async {
    final container = await pumpTeiaApp(tester);
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(
      directionOf(tester, find.byType(FoundationPreviewScreen)),
      TextDirection.rtl,
    );

    await tester.tap(find.text('داكن'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(FoundationPreviewScreen))).brightness,
      Brightness.dark,
    );

    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getString('app_locale'), 'ar');
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets(
    'upcoming destinations are visibly unavailable and not interactive',
    (tester) async {
      await pumpTeiaApp(tester);
      await scrollTo(
        tester,
        find.byKey(FoundationPreviewScreen.lastSectionKey),
      );
      final tiles = tester.widgetList<ListTile>(
        find.descendant(
          of: find.byType(UnavailableDestination),
          matching: find.byType(ListTile),
        ),
      );
      expect(tiles, hasLength(4));
      expect(tiles.every((t) => !t.enabled && t.onTap == null), isTrue);
      expect(find.text('Not available yet'), findsNWidgets(4));
    },
  );

  testWidgets(
    'mixed-language samples keep their own direction inside the English UI',
    (tester) async {
      await pumpTeiaApp(tester);
      await scrollTo(
        tester,
        find.text(FoundationPreviewScreen.mixedSamples[3]),
      );
      expect(
        directionOf(tester, find.text(FoundationPreviewScreen.mixedSamples[0])),
        TextDirection.rtl,
      );
      expect(
        directionOf(tester, find.text(FoundationPreviewScreen.mixedSamples[1])),
        TextDirection.ltr,
      );
      expect(
        directionOf(tester, find.text(FoundationPreviewScreen.mixedSamples[2])),
        TextDirection.rtl,
      );
      expect(
        directionOf(tester, find.text(FoundationPreviewScreen.mixedSamples[3])),
        TextDirection.ltr,
      );
    },
  );

  testWidgets('developer details only appear in dev builds', (tester) async {
    await pumpTeiaApp(tester, config: testConfig(AppEnvironment.staging));
    await scrollTo(tester, find.byKey(FoundationPreviewScreen.lastSectionKey));
    expect(find.text('Developer build'), findsNothing);
    expect(find.textContaining('example.com'), findsNothing);
  });

  testWidgets('session expiry shows a single notice', (tester) async {
    final container = await pumpTeiaApp(tester);
    final session = container.read(sessionManagerProvider);
    await tester.runAsync(() => session.start('t1'));
    await tester.pump();
    await tester.runAsync(
      () => Future.wait([session.expire('t1'), session.expire('t1')]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Your session has expired. Please sign in again.'),
      findsOneWidget,
    );
    expect(session.status, SessionStatus.expired);
  });

  testWidgets('interactive controls meet the 48dp touch target', (
    tester,
  ) async {
    await pumpTeiaApp(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  test('locale resolution prefers saved choice, then device, then English', () {
    expect(
      resolveAppLocale(const Locale('ar'), [const Locale('en')]),
      const Locale('ar'),
    );
    expect(
      resolveAppLocale(null, [const Locale('de'), const Locale('ar', 'EG')]),
      const Locale('ar'),
    );
    expect(resolveAppLocale(null, [const Locale('de')]), const Locale('en'));
    expect(resolveAppLocale(null, null), const Locale('en'));
  });

  test('direction detection uses the first strong character', () {
    expect(detectTextDirection('123 مرحبا hello'), TextDirection.rtl);
    expect(detectTextDirection('«hello» مرحبا'), TextDirection.ltr);
    expect(
      detectTextDirection('123 ...', fallback: TextDirection.rtl),
      TextDirection.rtl,
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
}
