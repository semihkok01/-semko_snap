import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;
  final ApiService _api = ApiService();

  bool _isInitialized = false;
  bool _isBusy = false;
  String? _token;
  String? _email;

  bool get isInitialized => _isInitialized;
  bool get isBusy => _isBusy;
  bool get isAuthenticated => (_token ?? '').isNotEmpty;
  String? get email => _email;

  // =========================
  // APP START
  // =========================

  Future<void> bootstrap() async {
    final session = await _authService.restoreSession();

    _token = session['token'];
    _email = session['email'];

    if ((_token ?? '').isNotEmpty) {
      final isValid = await _authService.validateStoredSession();
      if (!isValid) {
        _token = null;
        _email = null;
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  // =========================
  // LOGIN (🔥 FULL FIX)
  // =========================

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _runBusy(() async {
      final response = await _authService.login(
        email: email,
        password: password,
      );

      final token = response['token'] as String?;
      final user = response['user'] as Map<String, dynamic>?;

      if (token == null || token.isEmpty) {
        throw ApiException('Authentifizierungs-Token fehlt.');
      }

      _token = token;
      _email = user?['email'] as String?;

      // 🔥 EN KRİTİK FIX
      await _api.saveToken(token);

      // 🔥 TOKEN DİSK’E YAZILMASINI GARANTİLE
      await Future.delayed(const Duration(milliseconds: 150));
    });
  }

  // =========================
  // REGISTER
  // =========================

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _runBusy(() async {
      final response = await _authService.register(
        email: email,
        password: password,
      );

      final token = response['token'] as String?;
      final user = response['user'] as Map<String, dynamic>?;

      if (token == null || token.isEmpty) {
        throw ApiException('Authentifizierungs-Token fehlt.');
      }

      _token = token;
      _email = user?['email'] as String?;

      await _api.saveToken(token);

      // 🔥 aynı fix burada da
      await Future.delayed(const Duration(milliseconds: 150));
    });
  }

  // =========================
  // LOGOUT
  // =========================

  Future<void> logout() async {
    await _api.clearToken();
    await _authService.logout();

    _token = null;
    _email = null;

    notifyListeners();
  }

  // =========================
  // BUSY HANDLER
  // =========================

  Future<void> _runBusy(Future<void> Function() task) async {
    _isBusy = true;
    notifyListeners();

    try {
      await task();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException("Unbekannter Fehler beim Anmelden.");
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
