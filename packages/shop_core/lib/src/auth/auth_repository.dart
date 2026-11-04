import '../errors/app_failure.dart';
import '../models/user.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';

class AuthRepository {
  AuthRepository({required this.api, required this.storage});

  final ApiClient api;
  final TokenStorage storage;

  Future<User> login({required String email, required String password}) =>
      _tokenCall('/auth/login', {'email': email, 'password': password});

  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) =>
      _tokenCall('/auth/register', {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });

  /// Restores the session on app start. Returns null when signed out or the
  /// stored token is no longer valid.
  Future<User?> restoreSession() async {
    if (await storage.read() == null) return null;
    try {
      final json = await api.getJson('/auth/me');
      return User.fromJson((json['data'] as Map).cast<String, dynamic>());
    } on UnauthenticatedFailure {
      await storage.clear();
      return null;
    }
  }

  /// Always clears the local token, even if the server call fails.
  Future<void> logout() async {
    try {
      await api.postEmpty('/auth/logout');
    } on AppFailure {
      // Token may already be invalid or the server unreachable: still sign out.
    } finally {
      await storage.clear();
    }
  }

  Future<User> _tokenCall(String path, Map<String, dynamic> body) async {
    final json = await api.postJson(path, body: body, options: ApiClient.noAuth());
    await storage.write(json['access_token'] as String);
    return User.fromJson((json['user'] as Map).cast<String, dynamic>());
  }
}
