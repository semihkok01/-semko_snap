import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    Map<String, dynamic>? payload,
  }) : payload = payload ?? const <String, dynamic>{};

  final String message;
  final int? statusCode;
  final Map<String, dynamic> payload;

  bool get isDuplicateExpense =>
      statusCode == 409 && payload['code'] == 'duplicate_expense';

  @override
  String toString() => message;
}

class ApiService {
  /// Development: http://localhost:8000/  (PHP built-in server)
  /// Production: https://it-dienst-hamburg.de/semkosnap/api/
  static String _baseUrl = 'https://it-dienst-hamburg.de/semkosnap/api/';

  static String get baseUrl => _baseUrl;

  /// Configure API endpoint (call this before any API requests)
  /// For development: setBaseUrl('http://localhost:8000/')
  /// For production: setBaseUrl('https://it-dienst-hamburg.de/semkosnap/api/')
  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url : '$url/';
  }

  static const String tokenKey = 'semkosnap_jwt_token';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  Future<Map<String, String>> _buildHeaders({
    bool authenticated = true,
    bool json = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};

    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    if (authenticated) {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw ApiException(
          'Kein Authentifizierungs-Token gefunden.',
          statusCode: 401,
        );
      }

      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );

    try {
      final response = await http.get(
        uri,
        headers: await _buildHeaders(authenticated: authenticated),
      );

      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } catch (exception) {
      throw _mapTransportException(exception);
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _buildHeaders(authenticated: authenticated),
        body: jsonEncode(body ?? <String, dynamic>{}),
      );

      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } catch (exception) {
      throw _mapTransportException(exception);
    }
  }

  Future<Map<String, dynamic>> multipart(
    String endpoint, {
    required Map<String, String> fields,
    required Map<String, String> files,
    bool authenticated = true,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      );

      request.headers.addAll(
        await _buildHeaders(authenticated: authenticated, json: false),
      );

      request.fields.addAll(fields);

      for (final entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(entry.key, entry.value),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } catch (exception) {
      throw _mapTransportException(exception);
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> payload = {};

    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      } catch (_) {
        throw ApiException('Ungültige Serverantwort (kein JSON).');
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }

    final validationMessage = _extractValidationMessage(payload);
    final rawMessage = validationMessage ?? (payload['message'] as String?);
    final message = _localizeServerMessage(
      rawMessage,
      statusCode: response.statusCode,
      payload: payload,
    );

    throw ApiException(
      message,
      statusCode: response.statusCode,
      payload: payload,
    );
  }

  String? _extractValidationMessage(Map<String, dynamic> payload) {
    final errors = payload['errors'];
    if (errors is! Map) {
      return null;
    }

    for (final value in errors.values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is List) {
        for (final item in value) {
          if (item is String && item.trim().isNotEmpty) {
            return item.trim();
          }
        }
      }
    }

    return null;
  }

  String _localizeServerMessage(
    String? rawMessage, {
    required int statusCode,
    required Map<String, dynamic> payload,
  }) {
    final message = (rawMessage ?? '').trim();

    const mappedMessages = <String, String>{
      'Internal server error.':
          'Interner Serverfehler. Bitte später erneut versuchen.',
      'Method not allowed.': 'Methode nicht erlaubt.',
      'Missing bearer token.': 'Anmeldung fehlt. Bitte erneut einloggen.',
      'Invalid or expired token.': 'Sitzung abgelaufen. Bitte erneut anmelden.',
      'Token subject is invalid.': 'Anmeldung ist ungültig.',
      'Authenticated user not found.': 'Benutzerkonto wurde nicht gefunden.',
      'Validation failed.': 'Bitte prüfe deine Eingaben.',
      'Category not found.': 'Kategorie wurde nicht gefunden.',
      'Expense not found.': 'Ausgabe wurde nicht gefunden.',
      'Authentication token missing.': 'Authentifizierungs-Token fehlt.',
      'A valid month and year are required.':
          'Bitte gib einen gültigen Monat und ein gültiges Jahr an.',
      'Receipt image exceeds the 8 MB limit.':
          'Das Belegbild darf höchstens 8 MB groß sein.',
      'Temporary file could not be created.':
          'Temporäre Datei konnte nicht erstellt werden.',
      'Unsupported image type. Only JPEG, PNG and WEBP are allowed.':
          'Nur JPEG-, PNG- und WEBP-Bilder sind erlaubt.',
      'Receipt upload directory could not be created.':
          'Upload-Ordner für Belege konnte nicht erstellt werden.',
      'Receipt image could not be stored.':
          'Das Belegbild konnte nicht gespeichert werden.',
      'Receipt image upload failed.':
          'Das Hochladen des Belegbilds ist fehlgeschlagen.',
      'Uploaded receipt image is invalid.':
          'Das hochgeladene Belegbild ist ungültig.',
      'Uploaded receipt image could not be read.':
          'Das hochgeladene Belegbild konnte nicht gelesen werden.',
      'Receipt image is not valid base64 data.':
          'Das Belegbild enthält ungültige Base64-Daten.',
      'expense added': 'Beleg wurde gespeichert.',
    };

    if (message.isNotEmpty) {
      final mapped = mappedMessages[message];
      if (mapped != null) {
        return mapped;
      }

      if (_looksGerman(message)) {
        return message;
      }
    }

    switch (statusCode) {
      case 401:
        return 'Sitzung abgelaufen. Bitte erneut anmelden.';
      case 403:
        return 'Für diese Aktion fehlt die Berechtigung.';
      case 404:
        return 'Die angeforderte Ressource wurde nicht gefunden.';
      case 409:
        return message.isNotEmpty
            ? message
            : 'Es besteht ein Konflikt mit vorhandenen Daten.';
      case 422:
        return message.isNotEmpty ? message : 'Bitte prüfe deine Eingaben.';
      default:
        if (statusCode >= 500) {
          return 'Interner Serverfehler. Bitte später erneut versuchen.';
        }

        return message.isNotEmpty ? message : 'Anfrage fehlgeschlagen.';
    }
  }

  bool _looksGerman(String message) {
    const germanMarkers = <String>[
      'Bitte',
      'Kategorie',
      'Ausgabe',
      'Beleg',
      'ungültig',
      'fehlgeschlagen',
      'geladen',
      'erstellt',
      'aktualisiert',
      'gefunden',
      'Serverfehler',
      'Sitzung',
      'Anmeldung',
      'Doppel',
      'Monat',
      'Jahr',
      'Bild',
    ];

    for (final marker in germanMarkers) {
      if (message.contains(marker)) {
        return true;
      }
    }

    return false;
  }

  ApiException _mapTransportException(Object exception) {
    if (exception is SocketException) {
      return ApiException(
        'Verbindung zum Server fehlgeschlagen. Bitte Internetverbindung prüfen.',
      );
    }

    if (exception is HandshakeException) {
      return ApiException(
        'Die sichere Verbindung zum Server konnte nicht aufgebaut werden.',
      );
    }

    if (exception is HttpException) {
      return ApiException('Der Server konnte nicht erreicht werden.');
    }

    if (exception is FormatException) {
      return ApiException('Die Serverantwort konnte nicht gelesen werden.');
    }

    return ApiException('Unbekannter Verbindungsfehler.');
  }

  Future<Map<String, dynamic>> login(String email, String password) {
    return post(
      'login.php',
      body: {
        'email': email,
        'password': password,
      },
      authenticated: false,
    );
  }
}
