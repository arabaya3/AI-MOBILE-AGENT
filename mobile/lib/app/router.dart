import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/account_screens.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/password_recovery_screens.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/chat/presentation/chat_list_screen.dart';
import '../features/chat/presentation/conversation_screen.dart';
import '../features/foundation_preview/presentation/foundation_preview_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/links/pending_link.dart';
import '../features/spaces/application/space_controller.dart';
import '../features/spaces/presentation/space_screens.dart';

const _publicRoutes = {
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
};
const _transientRoutes = {'/splash', '/session-problem'};

/// Where the user may be, given auth, space and pending-link state. Null keeps the location.
String? appRedirect({
  required AuthState auth,
  required SpaceState space,
  required PendingLink? link,
  required String location,
}) {
  String? goTo(String target) => location == target ? null : target;

  switch (auth) {
    case AuthStarting() || AuthVerifying():
      return goTo('/splash');
    case AuthUnverified():
      return goTo('/session-problem');
    case AuthSignedOut():
      if (link?.kind == LinkKind.resetPassword) return goTo('/reset-password');
      return _publicRoutes.contains(location) ? null : '/login';
    case AuthSignedIn():
      if (link?.kind == LinkKind.resetPassword) return goTo('/reset-password');
      if (link?.kind == LinkKind.invite) return goTo('/invite');
      final selected = space is SpaceSelected;
      final resolving = space is SpaceIdle || space is SpaceLoading;
      // While the stored space is being validated, wait on the splash screen.
      if (resolving &&
          (location == '/splash' || _publicRoutes.contains(location))) {
        return location == '/reset-password' ? null : goTo('/splash');
      }
      final landing = selected ? '/home' : '/spaces';
      if ((_publicRoutes.contains(location) && location != '/reset-password') ||
          _transientRoutes.contains(location)) {
        return landing;
      }
      final needsSpace =
          location == '/home' ||
          location == '/chat' ||
          location.startsWith('/chat/');
      if ((needsSpace && !selected) || (location == '/spaces' && selected)) {
        return landing;
      }
      return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  void bump() => refresh.value++;
  ref.listen(authControllerProvider, (_, _) => bump());
  ref.listen(spaceControllerProvider, (_, _) => bump());
  ref.listen(pendingLinkProvider, (_, _) => bump());
  final devTools = ref.read(appConfigProvider).isDev && !kReleaseMode;

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      auth: ref.read(authControllerProvider),
      space: ref.read(spaceControllerProvider),
      link: ref.read(pendingLinkProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/session-problem',
        builder: (_, _) => const SessionProblemScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, state) => LoginScreen(notice: state.extra as String?),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(path: '/spaces', builder: (_, _) => const SpacePickerScreen()),
      GoRoute(path: '/invite', builder: (_, _) => const AcceptInviteScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/chat',
        builder: (_, _) => const ChatListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const ConversationScreen()),
          GoRoute(
            path: 'c/:sessionId',
            builder: (_, state) => ConversationScreen(
              sessionId: state.pathParameters['sessionId'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/account',
        builder: (_, _) => const AccountScreen(),
        routes: [
          GoRoute(
            path: 'password',
            builder: (_, _) => const ChangePasswordScreen(),
          ),
        ],
      ),
      if (devTools)
        GoRoute(
          path: '/dev/preview',
          builder: (_, _) => const FoundationPreviewScreen(),
        ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
