import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'network/api_client.dart';
import 'session/session_manager.dart';
import 'storage/token_store.dart';

/// Overridden in bootstrap and tests.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider'),
);
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider'),
);
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final manager = SessionManager(ref.watch(tokenStoreProvider));
  ref.onDispose(manager.dispose);
  return manager;
});

final sessionStatusProvider = StreamProvider<SessionStatus>((ref) {
  final manager = ref.watch(sessionManagerProvider);
  return manager.changes;
});

class ActiveSpaceController extends Notifier<String?> {
  static const _key = 'active_space_id';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(_key);

  Future<void> select(String? spaceId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (spaceId == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, spaceId);
    }
    state = spaceId;
  }
}

final activeSpaceProvider = NotifierProvider<ActiveSpaceController, String?>(
  ActiveSpaceController.new,
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(sessionManagerProvider);
  return ApiClient(
    dio: createDio(ref.watch(appConfigProvider)),
    readToken: () => session.token,
    readSpaceId: () => ref.read(activeSpaceProvider),
    onSessionExpired: (token) => session.expire(token),
  );
});
