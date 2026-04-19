import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AuthService {
  AuthService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static const String emailKey = 'semkosnap_user_email';

  // =========================
  // LOGIN
  // =========================

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post(
      'login.php',
      authenticated: false,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    final token = response['token'] as String?;
    final user = response['user'] as Map<String, dynamic>?;

    if (token == null || token.isEmpty) {
      throw ApiException('Authentifizierungs-Token fehlt.');
    }

    // 🔥 TOKEN → ApiService'e
    await _apiService.saveToken(token);

    // 🔥 EMAIL → Local
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(emailKey, user?['email'] ?? '');

    return response;
  }

  // =========================
  // REGISTER
  // =========================

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post(
      'register.php',
      authenticated: false,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    final token = response['token'] as String?;
    final user = response['user'] as Map<String, dynamic>?;

    if (token == null || token.isEmpty) {
      throw ApiException('Authentifizierungs-Token fehlt.');
    }

    await _apiService.saveToken(token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(emailKey, user?['email'] ?? '');

    return response;
  }

  // =========================
  // RESTORE SESSION
  // =========================

  Future<Map<String, String?>> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'token': prefs.getString(ApiService.tokenKey), // 🔥 önemli
      'email': prefs.getString(emailKey),
    };
  }

  Future<bool> validateStoredSession() async {
    try {
      await _apiService.get('get_archive.php');
      return true;
    } on ApiException catch (exception) {
      if (exception.statusCode == 401) {
        await logout();
        return false;
      }

      // Keep session for transient issues (offline/server hiccup).
      return true;
    } catch (_) {
      return true;
    }
  }

  // =========================
  // LOGOUT
  // =========================

  Future<void> logout() async {
    await _apiService.clearToken(); // 🔥 token temizle

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(emailKey);
  }
}
