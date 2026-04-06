import 'bunker_db.dart';

class OtpApi {
  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  Future<bool> requestTwoFactorCode({required String email}) async {
    try {
      final data = _asMap(
        await BunkerDB.consulta(
          'CALL BUNKER_OTP_REQUEST',
          params: <String, dynamic>{'email': email.trim().toLowerCase()},
        ),
      );
      return data != null && data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyTwoFactorCode({
    required String email,
    required String code,
  }) async {
    try {
      final data = _asMap(
        await BunkerDB.consulta(
          'CALL BUNKER_OTP_VERIFY',
          params: <String, dynamic>{
            'email': email.trim().toLowerCase(),
            'code': code.trim(),
          },
        ),
      );
      return data != null && data['valid'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestResetCode({required String email}) async {
    try {
      final data = _asMap(
        await BunkerDB.consulta(
          'CALL BUNKER_PASSWORD_REQUEST',
          params: <String, dynamic>{'email': email.trim().toLowerCase()},
        ),
      );
      return data != null && data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyResetCodeAndChangePassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final data = _asMap(
        await BunkerDB.consulta(
          'CALL BUNKER_PASSWORD_VERIFY',
          params: <String, dynamic>{
            'email': email.trim().toLowerCase(),
            'code': code.trim(),
            'new_password': newPassword,
          },
        ),
      );
      return data != null && data['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
