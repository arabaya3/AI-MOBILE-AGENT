import 'package:flutter_test/flutter_test.dart';
import 'package:teia_ai/app/router.dart';
import 'package:teia_ai/core/session/session_manager.dart';
import 'package:teia_ai/features/auth/application/auth_controller.dart';
import 'package:teia_ai/features/auth/data/auth_models.dart';
import 'package:teia_ai/features/links/pending_link.dart';
import 'package:teia_ai/features/spaces/application/space_controller.dart';
import 'package:teia_ai/features/spaces/data/spaces_api.dart';

const user = CurrentUser(
  id: 'u1',
  email: 'u1@example.com',
  role: UserRole.viewer,
);
const signedIn = AuthSignedIn(user, 1);
const space = Space(id: 's1', name: 'S', isActive: true);
const selected = SpaceSelected(
  space,
  SpaceMembership(
    spaceId: 's1',
    role: SpaceRole.member,
    status: 'active',
    canUploadDocuments: false,
  ),
  [space],
);
const reset = PendingLink(LinkKind.resetPassword, 'tttttttttttttttttttt');
const invite = PendingLink(LinkKind.invite, 'tttttttttttttttttttt');

String? go(
  AuthState auth,
  String location, {
  SpaceState space = const SpaceIdle(),
  PendingLink? link,
}) => appRedirect(auth: auth, space: space, link: link, location: location);

void main() {
  test('startup and verification stay on the splash screen', () {
    expect(go(const AuthStarting(), '/home'), '/splash');
    expect(go(const AuthVerifying(), '/splash'), isNull);
  });

  test('unverified sessions go to the retry screen', () {
    expect(go(const AuthUnverified(), '/home'), '/session-problem');
  });

  test('signed-out users may only use public routes', () {
    expect(go(const AuthSignedOut(), '/home'), '/login');
    expect(go(const AuthSignedOut(), '/account'), '/login');
    expect(go(const AuthSignedOut(), '/invite'), '/login');
    for (final route in [
      '/login',
      '/register',
      '/forgot-password',
      '/reset-password',
    ]) {
      expect(
        go(const AuthSignedOut(SessionEndReason.expired), route),
        isNull,
        reason: route,
      );
    }
  });

  test('a reset link opens the reset screen whether or not signed in', () {
    expect(go(const AuthSignedOut(), '/login', link: reset), '/reset-password');
    expect(
      go(signedIn, '/home', space: selected, link: reset),
      '/reset-password',
    );
  });

  test('an invitation waits for sign-in, then opens the invite screen', () {
    expect(go(const AuthSignedOut(), '/login', link: invite), isNull);
    expect(go(signedIn, '/login', link: invite), '/invite');
  });

  test('signed-in users land on spaces until one is validated, then home', () {
    expect(go(signedIn, '/login', space: const SpaceLoading()), '/splash');
    expect(go(signedIn, '/splash', space: const SpaceLoading()), isNull);
    expect(go(signedIn, '/splash', space: const SpaceChoosing([])), '/spaces');
    expect(go(signedIn, '/home', space: const SpaceChoosing([])), '/spaces');
    expect(go(signedIn, '/splash', space: selected), '/home');
    expect(go(signedIn, '/spaces', space: selected), '/home');
    expect(go(signedIn, '/account', space: const SpaceChoosing([])), isNull);
    expect(go(signedIn, '/account/password', space: selected), isNull);
  });
}
