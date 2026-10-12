import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pending_link.dart';

/// Forwards incoming links to [pendingLinkProvider]. Links are never logged:
/// they may carry reset or invitation tokens.
Future<StreamSubscription<Uri>> listenForAppLinks(
  ProviderContainer container, {
  AppLinks? appLinks,
}) async {
  final links = appLinks ?? AppLinks();
  void deliver(Uri uri) =>
      container.read(pendingLinkProvider.notifier).deliver(uri);
  try {
    final initial = await links.getInitialLink();
    if (initial != null) deliver(initial);
  } catch (_) {
    // A malformed launch link is ignored.
  }
  return links.uriLinkStream.listen(deliver, onError: (Object _) {});
}
