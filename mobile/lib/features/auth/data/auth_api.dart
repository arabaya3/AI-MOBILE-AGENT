import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/request_kind.dart';
import 'auth_models.dart';

class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  /// Returns the access token. Mutations are never retried automatically.
  Future<String> login(String email, String password) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/auth/login',
      method: 'POST',
      kind: RequestKind.public,
      includeSpace: false,
      data: {'email': email.trim(), 'password': password},
    );
    final token = response.data?['access_token'];
    if (token is! String || token.isEmpty) {
      throw const UnexpectedResponseException(message: 'Missing access token');
    }
    return token;
  }

  Future<void> signUp(SignUpData data) => _client.request<Object>(
    '/auth/signup',
    method: 'POST',
    kind: RequestKind.public,
    includeSpace: false,
    data: data.toJson(),
  );

  Future<CurrentUser> me() async {
    final response = await _client.request<Map<String, dynamic>>(
      '/auth/me',
      includeSpace: false,
    );
    return CurrentUser.fromJson(response.data!);
  }

  Future<void> forgotPassword(String email) => _client.request<Object>(
    '/auth/forgot-password',
    method: 'POST',
    kind: RequestKind.public,
    includeSpace: false,
    data: {'email': email.trim()},
  );

  Future<bool> validateResetToken(String token) async {
    final response = await _client.request<Map<String, dynamic>>(
      '/auth/reset-password/validate',
      method: 'POST',
      kind: RequestKind.public,
      includeSpace: false,
      data: {'token': token},
    );
    return response.data?['valid'] == true;
  }

  Future<void> resetPassword(String token, String newPassword) =>
      _client.request<Object>(
        '/auth/reset-password',
        method: 'POST',
        kind: RequestKind.public,
        includeSpace: false,
        data: {'token': token, 'new_password': newPassword},
      );

  /// The backend answers 400 for a wrong current password; older servers answered 401,
  /// so this is sent as a credential check that never ends the session.
  Future<void> changePassword(String currentPassword, String newPassword) =>
      _client.request<Object>(
        '/auth/change-password',
        method: 'POST',
        kind: RequestKind.credentialCheck,
        includeSpace: false,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
}
