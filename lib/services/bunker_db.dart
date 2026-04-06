import 'dart:convert';

import 'package:http/http.dart' as http;

class BunkerDB {
  // Aqui vive la vuelta completa: todo sale por el puente PHP y con la misma llave.
  static const String _url = 'https://verificarte.softapatio.mx/api_master.php';
  static const String _apiKey = 'T4t3W4r1_S3cr3t_2026_X';

  static Future<dynamic> consulta(
    String sql, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: const {
          'Content-Type': 'application/json',
          'Authorization': _apiKey,
        },
        body: json.encode({
          'query': sql,
          'params': params ?? <String, dynamic>{},
        }),
      );

      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode == 200) {
        return json.decode(body);
      }

      return {
        'error': 'Acceso denegado o error de servidor: ${response.statusCode}',
        'body': body,
      };
    } catch (e) {
      return {'error': 'Error de red: $e'};
    }
  }
}
