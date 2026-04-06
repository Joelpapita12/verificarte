import 'package:flutter/foundation.dart';

/// Almacena el estado global del usuario que ha iniciado sesión.
///
/// Funciona como un singleton estático para acceder a los datos del usuario
/// desde cualquier parte de la aplicación de forma síncrona.
class CurrentUserStore {
  static int? _userId;
  static String? _role;
  static String? _publicName;
  static String? _photoUrl;

  /// Notificador que se actualiza cuando el perfil del usuario cambia.
  ///
  /// Los widgets pueden escuchar este notificador para reconstruirse
  /// automáticamente cuando se actualizan los datos del perfil (p. ej., el avatar).
  /// Se incrementa su valor para forzar la notificación.
  static final ValueNotifier<int> profileRevision = ValueNotifier<int>(0);

  static int? get userId => _userId;
  static String? get role => _role;
  static String? get publicName => _publicName;
  static String? get photoUrl => _photoUrl;

  static void setUserId(int? id) {
    _userId = id;
  }

  static void setRole(String? value) {
    _role = value;
  }

  /// Actualiza los datos del perfil y notifica a los oyentes.
  static void setProfile({String? publicName, String? photoUrl}) {
    _publicName = publicName;
    _photoUrl = photoUrl;
    profileRevision.value++;
  }

  /// Limpia todos los datos del usuario al cerrar sesión.
  static void clear() {
    _userId = null;
    _role = null;
    _publicName = null;
    _photoUrl = null;
    profileRevision.value++;
  }
}

