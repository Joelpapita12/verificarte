import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'bunker_db.dart';

class AuthApi {
  static const String _googleClientId =
      '121361058946-m2hav07b8e4sp7rsh316l08p655lbvfc.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _googleClientId,
    scopes: <String>['email', 'profile', 'openid'],
  );

  int? _parseUserId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _parseRole(dynamic value) {
    final role = value?.toString().trim();
    if (role == null || role.isEmpty) return null;
    return role;
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<void> _ensureLegalColumns() async {
    try {
      await BunkerDB.consulta(
        'ALTER TABLE usuario ADD COLUMN IF NOT EXISTS accepted_terms_at DATETIME NULL',
      );
    } catch (_) {}
    try {
      await BunkerDB.consulta(
        'ALTER TABLE usuario ADD COLUMN IF NOT EXISTS accepted_privacy_at DATETIME NULL',
      );
    } catch (_) {}
  }

  String _normalizeRole(String accountType) {
    switch (accountType.trim()) {
      case 'artist':
      case 'artista':
        return 'artista';
      case 'administrador':
        return 'administrador';
      default:
        return 'seguidor';
    }
  }

  String _generateTransferCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      10,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  Future<String> _uniqueTransferCode() async {
    while (true) {
      final candidate = _generateTransferCode();
      final rows = _asList(
        await BunkerDB.consulta(
          'SELECT id_usuario FROM usuario WHERE transfer_code = :code LIMIT 1',
          params: <String, dynamic>{'code': candidate},
        ),
      );
      if (rows.isEmpty) return candidate;
    }
  }

  Future<String> _uniqueUsername(String seed) async {
    final base = seed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        .trim();
    final cleanBase = base.isEmpty ? 'usuario' : base;
    var candidate = cleanBase;
    var suffix = 1;
    while (true) {
      final rows = _asList(
        await BunkerDB.consulta(
          'SELECT id_usuario FROM usuario WHERE nombre_usuario = :username LIMIT 1',
          params: <String, dynamic>{'username': candidate},
        ),
      );
      if (rows.isEmpty) return candidate;
      suffix += 1;
      candidate = '$cleanBase$suffix';
    }
  }

  Future<AuthResult> register({
    required String username,
    required String publicName,
    required String email,
    required String password,
    required String accountType,
    required bool acceptedTerms,
    required bool acceptedPrivacy,
  }) async {
    if (!acceptedTerms || !acceptedPrivacy) {
      return AuthResult.fail(
        'Debes aceptar los términos y el aviso de privacidad',
      );
    }
    try {
      await _ensureLegalColumns();
      final cleanEmail = email.trim().toLowerCase();
      final cleanUsername = username.trim();
      final duplicates = _asList(
        await BunkerDB.consulta(
          '''
          SELECT id_usuario
          FROM usuario
          WHERE correo = :email OR nombre_usuario = :username
          LIMIT 1
          ''',
          params: <String, dynamic>{
            'email': cleanEmail,
            'username': cleanUsername,
          },
        ),
      );
      if (duplicates.isNotEmpty) {
        return AuthResult.conflict('Cuenta ya creada');
      }

      final transferCode = await _uniqueTransferCode();
      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());
      final insert = await BunkerDB.consulta(
        '''
        INSERT INTO usuario (
          nombre_usuario,
          nombre_publico,
          correo,
          password_hash,
          rol,
          estado_cuenta,
          transfer_code,
          accepted_terms_at,
          accepted_privacy_at
        ) VALUES (
          :username,
          :public_name,
          :email,
          :password_hash,
          :role,
          'activa',
          :transfer_code,
          NOW(),
          NOW()
        )
        ''',
        params: <String, dynamic>{
          'username': cleanUsername,
          'public_name': publicName.trim(),
          'email': cleanEmail,
          'password_hash': hashedPassword,
          'role': _normalizeRole(accountType),
          'transfer_code': transferCode,
        },
      );
      final userId = _parseUserId((insert as Map?)?['last_id']);
      if (userId == null || userId <= 0) {
        return AuthResult.fail('No se pudo crear la cuenta');
      }
      return AuthResult.ok(userId: userId, role: _normalizeRole(accountType));
    } catch (_) {
      return AuthResult.fail('No se pudo crear la cuenta');
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final rows = _asList(
        await BunkerDB.consulta(
          '''
          SELECT id_usuario, password_hash, rol, estado_cuenta, suspendida_hasta, suspension_motivo
          FROM usuario
          WHERE correo = :email
          LIMIT 1
          ''',
          params: <String, dynamic>{'email': email.trim().toLowerCase()},
        ),
      );
      if (rows.isEmpty) {
        return AuthResult.fail('Credenciales inválidas');
      }
      final user = rows.first;
      final hash = (user['password_hash'] ?? '').toString();
      if (hash.isEmpty || !BCrypt.checkpw(password, hash)) {
        return AuthResult.fail('Credenciales inválidas');
      }
      final state = (user['estado_cuenta'] ?? '').toString();
      if (state == 'suspendida') {
        final until = (user['suspendida_hasta'] ?? '').toString().trim();
        final reason = (user['suspension_motivo'] ?? '').toString().trim();
        final extra = until.isEmpty ? reason : 'Vuelve el $until';
        return AuthResult.fail(
          extra.isEmpty ? 'Cuenta suspendida' : 'Cuenta suspendida. $extra',
        );
      }
      if (state == 'eliminada') {
        return AuthResult.fail('Cuenta eliminada');
      }
      return AuthResult.ok(
        userId: _parseUserId(user['id_usuario']),
        role: _parseRole(user['rol']),
      );
    } catch (_) {
      return AuthResult.fail('No se pudo iniciar sesión');
    }
  }

  Future<AuthResult> loginWithGoogle({
    String? accountType,
    bool acceptedTerms = false,
    bool acceptedPrivacy = false,
  }) async {
    try {
      await _ensureLegalColumns();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return AuthResult.fail('Inicio con Google cancelado');
      }
      final rows = _asList(
        await BunkerDB.consulta(
          '''
          SELECT id_usuario, rol, accepted_terms_at, accepted_privacy_at
          FROM usuario
          WHERE google_sub = :google_sub OR correo = :email
          LIMIT 1
          ''',
          params: <String, dynamic>{
            'google_sub': account.id,
            'email': account.email.trim().toLowerCase(),
          },
        ),
      );

      if (rows.isNotEmpty) {
        final user = rows.first;
        await BunkerDB.consulta(
          '''
          UPDATE usuario
          SET google_sub = :google_sub,
              foto_perfil = COALESCE(:photo_url, foto_perfil),
              accepted_terms_at = CASE
                WHEN accepted_terms_at IS NULL AND :accepted_terms = 1 THEN NOW()
                ELSE accepted_terms_at
              END,
              accepted_privacy_at = CASE
                WHEN accepted_privacy_at IS NULL AND :accepted_privacy = 1 THEN NOW()
                ELSE accepted_privacy_at
              END
          WHERE id_usuario = :user_id
          ''',
          params: <String, dynamic>{
            'google_sub': account.id,
            'photo_url': account.photoUrl,
            'accepted_terms': acceptedTerms ? 1 : 0,
            'accepted_privacy': acceptedPrivacy ? 1 : 0,
            'user_id': user['id_usuario'],
          },
        );
        return AuthResult.ok(
          userId: _parseUserId(user['id_usuario']),
          role: _parseRole(user['rol']),
        );
      }

      if (!acceptedTerms || !acceptedPrivacy) {
        return AuthResult.fail(
          'Debes aceptar los términos y el aviso de privacidad',
        );
      }

      final emailPrefix = account.email.split('@').first;
      final uniqueUsername = await _uniqueUsername(emailPrefix);
      final transferCode = await _uniqueTransferCode();
      final insert = await BunkerDB.consulta(
        '''
        INSERT INTO usuario (
          nombre_usuario,
          nombre_publico,
          correo,
          password_hash,
          rol,
          descripcion_breve,
          foto_perfil,
          estado_cuenta,
          transfer_code,
          google_sub,
          accepted_terms_at,
          accepted_privacy_at
        ) VALUES (
          :username,
          :public_name,
          :email,
          '',
          :role,
          NULL,
          :photo_url,
          'activa',
          :transfer_code,
          :google_sub,
          NOW(),
          NOW()
        )
        ''',
        params: <String, dynamic>{
          'username': uniqueUsername,
          'public_name': (account.displayName ?? emailPrefix).trim(),
          'email': account.email.trim().toLowerCase(),
          'role': _normalizeRole(accountType ?? 'seguidor'),
          'photo_url': account.photoUrl,
          'transfer_code': transferCode,
          'google_sub': account.id,
        },
      );
      final userId = _parseUserId((insert as Map?)?['last_id']);
      if (userId == null || userId <= 0) {
        return AuthResult.fail('No se pudo iniciar sesión con Google');
      }
      return AuthResult.ok(
        userId: userId,
        role: _normalizeRole(accountType ?? 'seguidor'),
      );
    } catch (_) {
      return AuthResult.fail('No se pudo iniciar sesión con Google');
    }
  }

  Future<UserProfileResult> fetchMe({required int userId}) async {
    try {
      final rows = _asList(
        await BunkerDB.consulta(
          '''
          SELECT u.id_usuario, u.nombre_usuario, u.nombre_publico, u.correo, u.rol,
                 COALESCE(u.descripcion_breve, '') AS descripcion_breve,
                 COALESCE(u.foto_perfil, '') AS foto_perfil,
                 COALESCE(u.transfer_code, '') AS transfer_code
          FROM usuario u
          WHERE u.id_usuario = :id
          LIMIT 1
          ''',
          params: <String, dynamic>{'id': userId},
        ),
      );
      if (rows.isEmpty) {
        return UserProfileResult.fail('No se pudo cargar perfil');
      }
      final user = rows.first;
      return UserProfileResult.ok(
        UserProfile(
          id: _parseUserId(user['id_usuario']) ?? 0,
          username: (user['nombre_usuario'] ?? '').toString(),
          publicName: (user['nombre_publico'] ?? '').toString(),
          email: (user['correo'] ?? '').toString(),
          role: _parseRole(user['rol']) ?? '',
          description: (user['descripcion_breve'] ?? '').toString(),
          photoUrl: (user['foto_perfil'] ?? '').toString(),
          transferCode: (user['transfer_code'] ?? '').toString(),
        ),
      );
    } catch (_) {
      return UserProfileResult.fail('No se pudo cargar perfil');
    }
  }

  Future<AuthResult> updateProfile({
    required int userId,
    required String publicName,
    required String description,
    String? photoUrl,
    String? externalLinks,
  }) async {
    try {
      final cleanPhoto = (photoUrl ?? '').trim();
      final cleanLinks = (externalLinks ?? '').trim();
      await BunkerDB.consulta(
        '''
        UPDATE usuario
        SET nombre_publico = :public_name,
            descripcion_breve = :description,
            foto_perfil = :photo_url
        WHERE id_usuario = :id
        ''',
        params: <String, dynamic>{
          'public_name': publicName.trim(),
          'description': description.trim(),
          'photo_url': cleanPhoto.isEmpty ? null : cleanPhoto,
          'id': userId,
        },
      );
      await BunkerDB.consulta(
        '''
        INSERT INTO perfilartista (id_usuario, biografia, enlaces_externos)
        VALUES (:id, :description, :links)
        ON DUPLICATE KEY UPDATE
          biografia = :description_update,
          enlaces_externos = :links_update
        ''',
        params: <String, dynamic>{
          'id': userId,
          'description': description.trim(),
          'links': cleanLinks.isEmpty ? null : cleanLinks,
          'description_update': description.trim(),
          'links_update': cleanLinks.isEmpty ? null : cleanLinks,
        },
      );
      return AuthResult.ok(userId: userId);
    } catch (_) {
      return AuthResult.fail('No se pudo actualizar el perfil');
    }
  }

  Future<AuthResult> deleteAccount({
    required int userId,
    String? reason,
  }) async {
    try {
      final motivo = (reason ?? '').trim();
      await BunkerDB.consulta(
        '''
        UPDATE usuario
        SET estado_cuenta = 'eliminada',
            suspension_motivo = :reason
        WHERE id_usuario = :id
        ''',
        params: <String, dynamic>{
          'reason': motivo.isEmpty ? 'Cuenta eliminada por el usuario' : motivo,
          'id': userId,
        },
      );
      await BunkerDB.consulta(
        'UPDATE publicacion SET activa = 0 WHERE id_artista = :id',
        params: <String, dynamic>{'id': userId},
      );
      return AuthResult.ok(userId: userId);
    } catch (_) {
      return AuthResult.fail('No se pudo eliminar la cuenta');
    }
  }

  Future<String> fetchContentPreference({required int userId}) async {
    try {
      final rows = _asList(
        await BunkerDB.consulta(
          '''
          SELECT preferencia_contenido
          FROM configuracioncuenta
          WHERE id_usuario = :id
          LIMIT 1
          ''',
          params: <String, dynamic>{'id': userId},
        ),
      );
      if (rows.isEmpty) return 'todo';
      final pref = (rows.first['preferencia_contenido'] ?? 'todo').toString();
      if (pref == 'sin_18' || pref == 'solo_18') return pref;
      return 'todo';
    } catch (_) {
      return 'todo';
    }
  }

  Future<AuthResult> saveContentPreference({
    required int userId,
    required String preference,
  }) async {
    try {
      final normalized = switch (preference) {
        'sin_18' => 'sin_18',
        'solo_18' => 'solo_18',
        _ => 'todo',
      };
      await BunkerDB.consulta(
        '''
        INSERT INTO configuracioncuenta (
          id_usuario,
          privacidad_historial,
          notificaciones,
          verificacion_dos_pasos,
          preferencia_contenido
        )
        VALUES (:id, 1, 1, 0, :preference)
        ON DUPLICATE KEY UPDATE
          preferencia_contenido = :preference_update
        ''',
        params: <String, dynamic>{
          'id': userId,
          'preference': normalized,
          'preference_update': normalized,
        },
      );
      return AuthResult.ok(userId: userId);
    } catch (_) {
      return AuthResult.fail('No se pudo guardar preferencias');
    }
  }

  Future<TransferCodeLookupResult> resolveTransferCode({
    required String code,
  }) async {
    try {
      final normalized = code.trim().toUpperCase();
      if (normalized.isEmpty) {
        return TransferCodeLookupResult.fail('Código inválido');
      }
      final rows = _asList(
        await BunkerDB.consulta(
          '''
          SELECT id_usuario, nombre_usuario, nombre_publico, foto_perfil
          FROM usuario
          WHERE transfer_code = :code
            AND estado_cuenta = 'activa'
          LIMIT 1
          ''',
          params: <String, dynamic>{'code': normalized},
        ),
      );
      if (rows.isEmpty) {
        return TransferCodeLookupResult.fail('Código no encontrado');
      }
      final user = rows.first;
      return TransferCodeLookupResult.ok(
        TransferCodeUser(
          id: _parseUserId(user['id_usuario']) ?? 0,
          username: (user['nombre_usuario'] ?? '').toString(),
          publicName: (user['nombre_publico'] ?? '').toString(),
          photoUrl: user['foto_perfil']?.toString(),
        ),
      );
    } catch (_) {
      return TransferCodeLookupResult.fail('No se pudo validar código');
    }
  }
}

class AuthResult {
  AuthResult._(this.ok, this.message, this.userId, this.role);

  final bool ok;
  final String? message;
  final int? userId;
  final String? role;

  factory AuthResult.ok({int? userId, String? role}) =>
      AuthResult._(true, null, userId, role);
  factory AuthResult.fail(String message) =>
      AuthResult._(false, message, null, null);
  factory AuthResult.conflict(String message) =>
      AuthResult._(false, message, null, null);
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.username,
    required this.publicName,
    required this.email,
    required this.role,
    required this.description,
    required this.photoUrl,
    required this.transferCode,
  });

  final int id;
  final String username;
  final String publicName;
  final String email;
  final String role;
  final String description;
  final String photoUrl;
  final String transferCode;
}

class UserProfileResult {
  UserProfileResult._(this.ok, this.message, this.profile);

  final bool ok;
  final String? message;
  final UserProfile? profile;

  factory UserProfileResult.ok(UserProfile profile) =>
      UserProfileResult._(true, null, profile);
  factory UserProfileResult.fail(String message) =>
      UserProfileResult._(false, message, null);
}

class TransferCodeUser {
  TransferCodeUser({
    required this.id,
    required this.username,
    required this.publicName,
    this.photoUrl,
  });

  final int id;
  final String username;
  final String publicName;
  final String? photoUrl;
}

class TransferCodeLookupResult {
  TransferCodeLookupResult._(this.ok, this.message, this.user);

  final bool ok;
  final String? message;
  final TransferCodeUser? user;

  factory TransferCodeLookupResult.ok(TransferCodeUser user) =>
      TransferCodeLookupResult._(true, null, user);
  factory TransferCodeLookupResult.fail(String message) =>
      TransferCodeLookupResult._(false, message, null);
}
