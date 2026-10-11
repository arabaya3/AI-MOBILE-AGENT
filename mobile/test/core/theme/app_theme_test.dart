import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/app/config_error_app.dart';
import 'package:teia_ai/core/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    test('${brightness.name} theme meets WCAG AA text contrast', () {
      final s = buildAppTheme(brightness).colorScheme;
      expect(contrast(s.onSurface, s.surface), greaterThanOrEqualTo(4.5));
      expect(
        contrast(s.onSurfaceVariant, s.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(s.onSurfaceVariant, s.surfaceContainerLow),
        greaterThanOrEqualTo(4.5),
      );
      expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
      expect(contrast(s.primary, s.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(s.error, s.surfaceContainer), greaterThanOrEqualTo(4.5));
      expect(contrast(s.outline, s.surface), greaterThanOrEqualTo(3.0));
    });

    test('${brightness.name} buttons have 48dp minimum size', () {
      final theme = buildAppTheme(brightness);
      expect(
        theme.filledButtonTheme.style?.minimumSize?.resolve({}),
        minTouchTarget,
      );
      expect(
        theme.outlinedButtonTheme.style?.minimumSize?.resolve({}),
        minTouchTarget,
      );
      expect(
        theme.textButtonTheme.style?.minimumSize?.resolve({}),
        minTouchTarget,
      );
    });
  }

  testWidgets(
    'configuration error screen explains the failure without connecting',
    (tester) async {
      await tester.pumpWidget(const ConfigErrorApp());
      await tester.pumpAndSettle();
      expect(find.text('This build cannot start'), findsOneWidget);
    },
  );
}
