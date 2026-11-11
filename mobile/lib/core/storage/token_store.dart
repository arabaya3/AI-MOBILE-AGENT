import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _key = 'teia.access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

const _installMarkerKey = 'install.marker';

/// The iOS Keychain survives uninstalling the app, while preferences do not. On the first start
/// of a fresh install (no marker yet) a token left by an earlier install is deleted, so a
/// reinstall never resumes the previous user's session. Existing installs that predate the marker
/// are signed out once.
Future<void> forgetTokenFromPreviousInstall(
  SharedPreferences prefs,
  TokenStore store,
) async {
  if (prefs.getBool(_installMarkerKey) ?? false) return;
  await store.delete();
  await prefs.setBool(_installMarkerKey, true);
}

class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._token]);

  String? _token;
  int deleteCount = 0;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> delete() async {
    deleteCount++;
    _token = null;
  }
}
