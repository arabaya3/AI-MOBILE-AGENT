import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

enum LinkKind { resetPassword, invite }

class PendingLink {
  const PendingLink(this.kind, this.token);

  final LinkKind kind;
  final String token;
}

/// Development-only scheme; release builds accept only verified https hosts.
const devLinkScheme = 'teia-dev';

final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{16,256}$');

bool isPlausibleToken(String value) => _tokenPattern.hasMatch(value);

/// Accepts reset and invite links from trusted sources only:
/// `teia-dev://reset-password?token=…` / `teia-dev://join-space?token=…` (dev builds), or
/// `https://<trusted host>/auth?token=…` / `/join-space?token=…` (the web links sent by email).
PendingLink? parseAppLink(
  Uri uri, {
  required bool allowDevScheme,
  required Set<String> trustedHosts,
}) {
  final LinkKind? kind;
  if (allowDevScheme && uri.scheme == devLinkScheme) {
    kind = switch (uri.host) {
      'reset-password' => LinkKind.resetPassword,
      'join-space' => LinkKind.invite,
      _ => null,
    };
  } else if (uri.scheme == 'https' &&
      trustedHosts.contains(uri.host.toLowerCase()) &&
      !uri.hasPort) {
    kind = _kindForPath(uri.path);
  } else {
    kind = null;
  }
  if (kind == null || uri.userInfo.isNotEmpty) return null;
  final tokens = uri.queryParametersAll['token'] ?? const [];
  if (tokens.length != 1 || !isPlausibleToken(tokens.single)) return null;
  return PendingLink(kind, tokens.single);
}

/// For text the user pastes: a bare token, or any link of the expected shape.
String? tokenFromPastedText(String input, LinkKind expected) {
  final text = input.trim();
  if (isPlausibleToken(text)) return text;
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme) return null;
  final kind = uri.scheme == devLinkScheme
      ? (uri.host == 'reset-password'
            ? LinkKind.resetPassword
            : (uri.host == 'join-space' ? LinkKind.invite : null))
      : _kindForPath(uri.path);
  final tokens = uri.queryParametersAll['token'] ?? const [];
  if (kind != expected ||
      tokens.length != 1 ||
      !isPlausibleToken(tokens.single)) {
    return null;
  }
  return tokens.single;
}

LinkKind? _kindForPath(String path) => switch (path) {
  '/auth' || '/auth/' || '/reset-password' => LinkKind.resetPassword,
  '/join-space' || '/join-space/' => LinkKind.invite,
  _ => null,
};

/// Holds at most one link token in memory; it is never persisted or put in a route.
class PendingLinkController extends Notifier<PendingLink?> {
  @override
  PendingLink? build() => null;

  /// Returns whether the link was accepted.
  bool deliver(Uri uri) {
    final config = ref.read(appConfigProvider);
    final link = parseAppLink(
      uri,
      allowDevScheme: config.isDev,
      trustedHosts: config.trustedLinkHosts,
    );
    if (link == null) return false;
    state = link;
    return true;
  }

  void hold(PendingLink link) => state = link;

  /// Hands the token to the screen that uses it and forgets it.
  String? take(LinkKind kind) {
    final link = state;
    if (link == null || link.kind != kind) return null;
    state = null;
    return link.token;
  }

  void clear() => state = null;
}

final pendingLinkProvider =
    NotifierProvider<PendingLinkController, PendingLink?>(
      PendingLinkController.new,
    );
