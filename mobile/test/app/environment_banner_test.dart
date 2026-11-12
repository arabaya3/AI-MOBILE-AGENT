import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/app/app.dart';
import 'package:teia_ai/core/config/app_config.dart';

Future<void> pumpBanner(WidgetTester tester, AppEnvironment env) =>
    tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            EnvironmentBanner(environment: env, child: child!),
        home: const Scaffold(body: Text('screen')),
      ),
    );

void main() {
  testWidgets('staging builds are marked on every screen', (tester) async {
    await pumpBanner(tester, AppEnvironment.staging);
    final banner = tester.widget<Banner>(find.byType(Banner).last);
    expect(banner.message, 'STAGING');
    expect(find.text('screen'), findsOneWidget);
  });

  testWidgets('dev builds are marked too', (tester) async {
    await pumpBanner(tester, AppEnvironment.dev);
    expect(tester.widget<Banner>(find.byType(Banner).last).message, 'DEV');
  });

  testWidgets('production builds carry no environment marker', (tester) async {
    await pumpBanner(tester, AppEnvironment.prod);
    expect(
      find.byWidgetPredicate((w) => w is Banner && w.message != 'DEBUG'),
      findsNothing,
    );
  });
}
