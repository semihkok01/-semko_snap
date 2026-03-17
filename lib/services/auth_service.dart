import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AuthService {
  AuthService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static const String tokenKey = 'semkosnap_jwt_token';
  static const String emailKey = 'semkosnap_user_email';

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post(
      'login.php',
      authenticated: false,
      body: {'email': email.trim(), 'password': password},
    );

    await _persistSession(response);
    return response;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post(
      'register.php',
      authenticated: false,
      body: {'email': email.trim(), 'password': password},
    );

    await _persistSession(response);
    return response;
  }

  Future<void> _persistSession(Map<String, dynamic> response) async {
    final token = response['token'] as String?;
    final user = response['user'] as Map<String, dynamic>?;

    if (token == null || token.isEmpty) {
      throw ApiException('Authentication token missing from response.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    await prefs.setString(emailKey, (user?['email'] as String?) ?? '');
  }

  Future<Map<String, String?>> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'token': prefs.getString(tokenKey),
      'email': prefs.getString(emailKey),
    };
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(emailKey);
  }
}
