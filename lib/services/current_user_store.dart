import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

import 'e2e_crypto.dart';

class CurrentUserStore {
  static int? _userId;
  static String? _role;
  static String? _publicName;
  static String? _photoUrl;
  static E2eKeyPair? _ecKeyPair;

  static final ValueNotifier<int> profileRevision = ValueNotifier<int>(0);

  static int? get userId => _userId;
  static String? get role => _role;
  static String? get publicName => _publicName;
  static String? get photoUrl => _photoUrl;
  static E2eKeyPair? get ecKeyPair => _ecKeyPair;

  static void setUserId(int? id) => _userId = id;
  static void setRole(String? value) => _role = value;
  static void setEcKeyPair(E2eKeyPair? keyPair) => _ecKeyPair = keyPair;

  static void setProfile({String? publicName, String? photoUrl}) {
    _publicName = publicName;
    _photoUrl = photoUrl;
    profileRevision.value++;
  }

  /// Guarda userId y role en localStorage para sobrevivir refresco de página.
  static void saveToLocalStorage() {
    try {
      final storage = html.window.localStorage;
      if (_userId != null) {
        storage['vc_user_id'] = _userId.toString();
        storage['vc_role'] = _role ?? '';
      } else {
        storage.remove('vc_user_id');
        storage.remove('vc_role');
      }
    } catch (_) {}
  }

  /// Restaura la sesión desde localStorage al arrancar la app.
  /// Devuelve true si había sesión guardada.
  static bool restoreFromLocalStorage() {
    try {
      final storage = html.window.localStorage;
      final idStr = storage['vc_user_id'];
      final role = storage['vc_role'];
      if (idStr != null && idStr.isNotEmpty) {
        _userId = int.tryParse(idStr);
        _role = (role != null && role.isNotEmpty) ? role : null;
        return _userId != null;
      }
    } catch (_) {}
    return false;
  }

  /// Limpia todos los datos del usuario al cerrar sesión.
  static void clear() {
    _userId = null;
    _role = null;
    _publicName = null;
    _photoUrl = null;
    _ecKeyPair = null;
    profileRevision.value++;
    try {
      final storage = html.window.localStorage;
      storage.remove('vc_user_id');
      storage.remove('vc_role');
    } catch (_) {}
  }
}

