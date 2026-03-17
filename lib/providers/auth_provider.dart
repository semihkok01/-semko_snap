import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  bool _isInitialized = false;
  bool _isBusy = false;
  String? _token;
  String? _email;

  bool get isInitialized => _isInitialized;
  bool get isBusy => _isBusy;
  bool get isAuthenticated => (_token ?? '').isNotEmpty;
  String? get email => _email;

  Future<void> bootstrap() async {
    final session = await _authService.restoreSession();
    _token = session['token'];
    _email = session['email'];
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    await _runBusy(() async {
      final response = await _authService.login(
        email: email,
        password: password,
      );
      _token = response['token'] as String?;
      final user = response['user'] as Map<String, dynamic>?;
      _email = user?['email'] as String?;
    });
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _runBusy(() async {
      final response = await _authService.register(
        email: email,
        password: password,
      );
      _token = response['token'] as String?;
      final user = response['user'] as Map<String, dynamic>?;
      _email = user?['email'] as String?;
    });
  }

  Future<void> logout() async {
    await _authService.logout();
    _token = null;
    _email = null;
    notifyListeners();
  }

  Future<void> _runBusy(Future<void> Function() task) async {
    _isBusy = true;
    notifyListeners();

    try {
      await task();
    } on ApiException {
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
