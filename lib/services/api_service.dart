import 'dart:convert';

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
  static const String baseUrl = 'https://it-dienst-hamburg.de/semkosnap/api/';
  static const String _tokenKey = 'semkosnap_jwt_token';

  Future<Map<String, String>> _buildHeaders({
    bool authenticated = true,
    bool json = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};

    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    if (authenticated) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);

      if (token == null || token.isEmpty) {
        throw ApiException('Kein Authentifizierungs-Token gefunden.', statusCode: 401);
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

    final response = await http.get(
      uri,
      headers: await _buildHeaders(authenticated: authenticated),
    );

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _buildHeaders(authenticated: authenticated),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> multipart(
    String endpoint, {
    required Map<String, String> fields,
    required Map<String, String> files,
    bool authenticated = true,
  }) async {
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
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> payload = <String, dynamic>{};

    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }

    throw ApiException(
      (payload['message'] as String?) ?? 'Anfrage fehlgeschlagen.',
      statusCode: response.statusCode,
      payload: payload,
    );
  }
}
