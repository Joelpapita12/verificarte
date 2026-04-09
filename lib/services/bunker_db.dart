import 'dart:convert';
import 'package:http/http.dart' as http;

class BunkerDB {
  static const String _url = 'https://verificarte.softapatio.mx/api_master.php';
  static const String _apiKey = 'T4t3W4r1_S3cr3t_2026_X';

  static Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Authorization": _apiKey,
      };

  static Future<Map<String, dynamic>> login(String correo, String password) async {
    final response = await http.post(
      Uri.parse(_url),
      headers: _headers,
      body: jsonEncode({
        "action": "login",
        "correo": correo,
        "password": password,
      }),
    );
    return _decodeMap(response.body);
  }

  static Future<Map<String, dynamic>> register({
    required String usuario,
    required String nombre,
    required String correo,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(_url),
      headers: _headers,
      body: jsonEncode({
        "action": "register",
        "usuario": usuario,
        "nombre": nombre,
        "correo": correo,
        "password": password,
      }),
    );
    return _decodeMap(response.body);
  }

  static Future<Map<String, dynamic>> googleLogin({
    required String googleSub,
    required String correo,
    required String nombre,
  }) async {
    final response = await http.post(
      Uri.parse(_url),
      headers: _headers,
      body: jsonEncode({
        "action": "google_login",
        "google_sub": googleSub,
        "correo": correo,
        "nombre": nombre,
      }),
    );
    return _decodeMap(response.body);
  }

  static Future<List<dynamic>> query(String query, [List<dynamic> params = const []]) async {
    final response = await http.post(
      Uri.parse(_url),
      headers: _headers,
      body: jsonEncode({
        "query": query,
        "params": params,
      }),
    );
    return _decodeList(response.body);
  }

  static Future<dynamic> consulta(String sql, {Map<String, dynamic>? params}) async {
    final response = await http.post(
      Uri.parse(_url),
      headers: _headers,
      body: jsonEncode({
        "query": sql,
        "params": params ?? {},
      }),
    );
    return _decodeAny(response.body);
  }

  static Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return {"status": "error", "message": "Respuesta inesperada del servidor"};
  }

  static List<dynamic> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded;
    }
    return [decoded];
  }

  static dynamic _decodeAny(String body) {
    return jsonDecode(body);
  }
}
