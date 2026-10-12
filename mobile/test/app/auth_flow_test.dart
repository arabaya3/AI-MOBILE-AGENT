import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/app/router.dart';
import 'package:teia_ai/core/storage/token_store.dart';
import 'package:teia_ai/features/auth/presentation/login_screen.dart';
import 'package:teia_ai/features/home/presentation/home_screen.dart';
import 'package:teia_ai/features/links/pending_link.dart';
import 'package:teia_ai/features/spaces/presentation/space_screens.dart';

import '../support/fake_adapter.dart';
import '../support/fake_backend.dart';
import '../support/test_app.dart';

const resetToken = 'ResetTokenResetTokenResetToken12';
const inviteToken = 'InviteTokenInviteTokenInvite1234';

Future<void> signIn(
  WidgetTester tester, {
  String password = 'Password123!',
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'u1@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await settleApp(tester);
}

void loginReturns(FakeBackend backend, String token) => backend.json(
  'POST /auth/login',
  200,
  {'access_token': token, 'token_type': 'bearer', 'expires_in': 86400},
);

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend()
      ..json('GET /auth/me', 200, userJson('u1', firstName: 'Lina'))
      ..json('GET /spaces', 200, [spaceJson('s1'), spaceJson('s2')])
      ..json('GET /spaces/s1/me', 200, membershipJson('s1'))
      ..json('GET /spaces/s2/me', 200, membershipJson('s2', role: 'admin'))
      ..json('GET /spaces/available', 200, <Object>[])
      ..json('GET /spaces/requests/mine', 200, <Object>[]);
  });

  testWidgets('shows distinct sign-in failures and keeps the session empty', (
    tester,
  ) async {
    final store = InMemoryTokenStore();
    await pumpTeiaApp(tester, backend, store: store);
    expect(find.byType(LoginScreen), findsOneWidget);

    backend.json('POST /auth/login', 401, {'detail': 'Invalid credentials'});
    await signIn(tester);
    expect(find.text('The email or password is incorrect.'), findsOneWidget);

    backend.json('POST /auth/login', 403, {'detail': 'Inactive account'});
    await signIn(tester);
    expect(
      find.text('This account is inactive. Contact your administrator.'),
      findsOneWidget,
    );

    backend.on('POST /auth/login', (_) => textBody(429, 'Rate limit exceeded'));
    await signIn(tester);
    expect(
      find.text('Too many requests. Please wait a moment and try again.'),
      findsOneWidget,
    );
    expect(await store.read(), isNull);
  });

  testWidgets('sign-in → choose space → home → switch → sign out', (
    tester,
  ) async {
    final store = InMemoryTokenStore();
    loginReturns(backend, 'tok');
    final container = await pumpTeiaApp(tester, backend, store: store);

    await signIn(tester);
    expect(find.byType(SpacePickerScreen), findsOneWidget);
    await tester.tap(find.text('Space s1'));
    await settleApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Hello, Lina'), findsOneWidget);
    expect(find.text('Space s1'), findsOneWidget);
    expect(find.text('Space administration'), findsNothing);

    await tester.tap(find.text('Switch space'));
    await settleApp(tester);
    await tester.tap(find.text('Space s2'));
    await settleApp(tester);
    expect(find.text('Space s2'), findsOneWidget);
    expect(find.text('Space administrator'), findsOneWidget);

    await tester.tap(find.byTooltip('Account'));
    await settleApp(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out').last);
    await settleApp(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out').last);
    await settleApp(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('You signed out on this device.'), findsOneWidget);
    expect(await store.read(), isNull);
    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString(),
      '/login',
    );
  });

  testWidgets('public registration never sends a role', (tester) async {
    backend.json('POST /auth/signup', 201, {
      'user_id': 'u1',
      'email': 'u1@example.com',
      'role': 'viewer',
    });
    loginReturns(backend, 'tok');
    await pumpTeiaApp(tester, backend);

    await tester.tap(find.text('Create an account'));
    await settleApp(tester);
    expect(find.textContaining('Role'), findsNothing);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'u1@example.com');
    await tester.enterText(fields.at(1), 'Password123!');
    await tester.enterText(fields.at(2), 'Password123!');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await settleApp(tester);

    final body = backend.bodyOf(backend.requestsTo('POST /auth/signup').single);
    expect(body.containsKey('role'), isFalse);
    expect(body['email'], 'u1@example.com');
    expect(find.byType(SpacePickerScreen), findsOneWidget);
  });

  testWidgets('forgot password shows the same generic confirmation', (
    tester,
  ) async {
    backend.json('POST /auth/forgot-password', 200, {'message': 'ignored'});
    await pumpTeiaApp(tester, backend);
    await tester.tap(find.text('Forgot password?'));
    await settleApp(tester);
    await tester.enterText(
      find.byType(TextFormField).first,
      'nobody@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await settleApp(tester);
    expect(
      find.textContaining('If an account exists for this email'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a reset link opens the reset form without exposing the token in the route',
    (tester) async {
      backend.json('POST /auth/reset-password/validate', 200, {'valid': true});
      backend.json('POST /auth/reset-password', 200, {'message': 'ok'});
      final container = await pumpTeiaApp(tester, backend);

      container
          .read(pendingLinkProvider.notifier)
          .deliver(Uri.parse('teia-dev://reset-password?token=$resetToken'));
      await settleApp(tester);
      final location = container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();
      expect(location, '/reset-password');
      expect(location.contains(resetToken), isFalse);
      expect(container.read(pendingLinkProvider), isNull);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'NewPassword1!');
      await tester.enterText(fields.at(1), 'NewPassword1!');
      await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
      await settleApp(tester);

      expect(
        backend.bodyOf(
          backend.requestsTo('POST /auth/reset-password').single,
        )['token'],
        resetToken,
      );
      expect(
        find.text('Your password was updated. Sign in with your new password.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('an expired reset link asks for a new one', (tester) async {
    backend.json('POST /auth/reset-password/validate', 200, {'valid': false});
    final container = await pumpTeiaApp(tester, backend);
    container
        .read(pendingLinkProvider.notifier)
        .deliver(Uri.parse('teia-dev://reset-password?token=$resetToken'));
    await settleApp(tester);
    expect(
      find.text(
        'This reset link is invalid or has expired. Request a new one.',
      ),
      findsOneWidget,
    );
    expect(find.text('Request a new link'), findsOneWidget);
  });

  testWidgets('an invitation waits for sign-in, then joins the space', (
    tester,
  ) async {
    loginReturns(backend, 'tok');
    backend.json('POST /spaces/invites/accept', 200, {
      'space_id': 's2',
      'status': 'accepted',
    });
    final container = await pumpTeiaApp(tester, backend);

    container
        .read(pendingLinkProvider.notifier)
        .deliver(Uri.parse('teia-dev://join-space?token=$inviteToken'));
    await settleApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    await signIn(tester);
    expect(find.byType(AcceptInviteScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Accept invitation'));
    await settleApp(tester);

    expect(
      backend.bodyOf(
        backend.requestsTo('POST /spaces/invites/accept').single,
      )['token'],
      inviteToken,
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Space s2'), findsOneWidget);
  });

  testWidgets('offline restore offers retry and keeps the stored session', (
    tester,
  ) async {
    backend.json('GET /auth/me', 503, {'detail': 'unavailable'});
    final store = InMemoryTokenStore('tok');
    await pumpTeiaApp(
      tester,
      backend,
      store: store,
      prefs: {'active_space.u1': 's1'},
    );
    expect(find.text("We couldn't confirm your session"), findsOneWidget);
    expect(await store.read(), 'tok');

    backend.json('GET /auth/me', 200, userJson('u1'));
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await settleApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  for (final lang in ['en', 'ar']) {
    for (final mode in ['light', 'dark']) {
      testWidgets('login, spaces and home lay out in $lang/$mode at 2x text', (
        tester,
      ) async {
        loginReturns(backend, 'tok');
        await pumpTeiaApp(
          tester,
          backend,
          textScale: 2.0,
          prefs: {'app_locale': lang, 'theme_mode': mode},
        );
        expect(tester.takeException(), isNull);
        final loginDir = Directionality.of(
          tester.element(find.byType(LoginScreen)),
        );
        expect(loginDir, lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'u1@example.com',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Password123!',
        );
        final submit = find.byType(FilledButton).first;
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await settleApp(tester);
        expect(find.byType(SpacePickerScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Space s1'));
        await settleApp(tester);
        expect(find.byType(HomeScreen), findsOneWidget);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
