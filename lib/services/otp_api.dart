import 'dart:convert';
import 'package:http/http.dart' as http;

class OtpApi {
  static const String _baseUrl = 'https://verificarte.softapatio.mx';
  static const String _apiKey = 'T4t3W4r1_S3cr3t_2026_X';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': _apiKey,
      };

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(response.body);
      return _asMap(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<bool> requestTwoFactorCode({required String email}) async {
    final data = await _post('bunker_otp.php', {
      'action': 'request_otp',
      'email': email.trim().toLowerCase(),
    });
    return data != null && data['ok'] == true;
  }

  Future<bool> verifyTwoFactorCode({
    required String email,
    required String code,
  }) async {
    final data = await _post('bunker_otp.php', {
      'action': 'verify_otp',
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    });
    return data != null && data['valid'] == true;
  }

  Future<bool> requestResetCode({required String email}) async {
    final data = await _post('bunker_otp.php', {
      'action': 'request_reset',
      'email': email.trim().toLowerCase(),
    });
    return data != null && data['ok'] == true;
  }

  Future<bool> verifyResetCodeAndChangePassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final data = await _post('bunker_otp.php', {
      'action': 'verify_reset',
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
      'new_password': newPassword,
    });
    return data != null && data['ok'] == true;
  }
}
