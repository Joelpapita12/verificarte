import '../models/api_models.dart';
import 'bunker_db.dart';

class AdminApi {
  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _ensureAdmin(int userId) async {
    final rows = _rows(
      await BunkerDB.consulta(
        "SELECT rol FROM usuario WHERE id_usuario = :id LIMIT 1",
        params: <String, dynamic>{'id': userId},
      ),
    );
    final role = rows.isEmpty ? '' : (rows.first['rol'] ?? '').toString();
    if (role != 'administrador') {
      throw Exception('Acceso denegado');
    }
  }

  Future<List<AdminReportDto>> fetchReports({required int userId}) async {
    await _ensureAdmin(userId);
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT
          d.id_denuncia,
          d.tipo_denuncia,
          d.descripcion,
          d.estado,
          d.id_publicacion,
          d.id_usuario_denunciante,
          d.fecha_denuncia,
          du.nombre_usuario AS denunciante_usuario,
          p.id_artista AS artista_id,
          au.nombre_usuario AS artista_usuario,
          COALESCE(p.titulo, 'Soporte') AS publicacion_titulo
        FROM denuncia d
        LEFT JOIN usuario du ON du.id_usuario = d.id_usuario_denunciante
        LEFT JOIN publicacion p ON p.id_publicacion = d.id_publicacion
        LEFT JOIN usuario au ON au.id_usuario = p.id_artista
        ORDER BY d.fecha_denuncia DESC
        ''',
      ),
    );
    return rows.map(AdminReportDto.fromJson).toList();
  }

  Future<List<AdminUserDto>> fetchUsers({
    required int userId,
    String? query,
  }) async {
    await _ensureAdmin(userId);
    final q = query?.trim() ?? '';
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT id_usuario, nombre_usuario, nombre_publico, correo, rol, estado_cuenta, transfer_code
        FROM usuario
        WHERE (:query = '' OR nombre_usuario LIKE :query_like OR nombre_publico LIKE :query_like OR correo LIKE :query_like)
        ORDER BY fecha_registro DESC
        ''',
        params: <String, dynamic>{
          'query': q,
          'query_like': '%$q%',
        },
      ),
    );
    return rows.map(AdminUserDto.fromJson).toList();
  }

  Future<List<AdminPostDto>> fetchPosts({
    required int userId,
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    await _ensureAdmin(userId);
    final q = query?.trim() ?? '';
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT p.id_publicacion, p.titulo, p.descripcion_corta, p.activa, p.id_artista, u.nombre_usuario
        FROM publicacion p
        JOIN usuario u ON u.id_usuario = p.id_artista
        WHERE (:query = '' OR p.titulo LIKE :query_like OR u.nombre_usuario LIKE :query_like OR u.nombre_publico LIKE :query_like)
          AND (:date_from IS NULL OR DATE(p.fecha_publicacion) >= :date_from)
          AND (:date_to IS NULL OR DATE(p.fecha_publicacion) <= :date_to)
        ORDER BY p.fecha_publicacion DESC
        ''',
        params: <String, dynamic>{
          'query': q,
          'query_like': '%$q%',
          'date_from': fromDate?.toIso8601String().substring(0, 10),
          'date_to': toDate?.toIso8601String().substring(0, 10),
        },
      ),
    );
    return rows.map(AdminPostDto.fromJson).toList();
  }

  Future<List<AdminActionDto>> fetchActions({required int userId}) async {
    await _ensureAdmin(userId);
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT
          a.id_accion,
          a.tipo_accion,
          a.detalle,
          a.fecha,
          ua.nombre_usuario AS admin_usuario,
          uo.nombre_usuario AS objetivo_usuario
        FROM adminaccion a
        JOIN usuario ua ON ua.id_usuario = a.id_admin
        LEFT JOIN usuario uo ON uo.id_usuario = a.id_objetivo
        ORDER BY a.fecha DESC
        ''',
      ),
    );
    return rows.map(AdminActionDto.fromJson).toList();
  }

  Future<List<MyCertificateDto>> fetchCertificatesByOwner({
    required int userId,
    required int ownerUserId,
  }) async {
    await _ensureAdmin(userId);
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT
          c.*,
          p.titulo,
          p.imagen_obra,
          p.id_artista,
          p.hash_obra,
          p.estado_obra,
          pe.imagen_obra AS edicion_imagen,
          pe.numero_edicion,
          pe.total_ediciones,
          CONCAT(pe.numero_edicion, '/', pe.total_ediciones) AS edicion_label,
          od.tecnica_materiales,
          od.nombre_autor_completo,
          od.dimensiones,
          od.anio_creacion,
          u.nombre_usuario AS artista_username,
          u.nombre_publico AS artista_publico,
          u.nombre_publico AS artista_nombre,
          u.nombre_usuario AS artista_apodo,
          uf.firma_hash AS firma_hash_artista,
          uf.firma_encriptada AS firma_encriptada_artista,
          uf.firma_encriptada AS signature_image_url
        FROM certificadodigital c
        JOIN publicacion p ON p.id_publicacion = c.id_publicacion
        LEFT JOIN publicacionedicion pe ON pe.id_edicion = c.id_edicion
        LEFT JOIN obradetalle od ON od.id_publicacion = p.id_publicacion
        LEFT JOIN usuario u ON u.id_usuario = p.id_artista
        LEFT JOIN usuariofirma uf ON uf.id_usuario = p.id_artista AND uf.activa = 1
        WHERE c.id_propietario_actual = :owner_id
          AND c.activo = 1
        ORDER BY c.fecha_emision DESC
        ''',
        params: <String, dynamic>{'owner_id': ownerUserId},
      ),
    );
    return rows.map(MyCertificateDto.fromJson).toList();
  }

  Future<void> resolveReport({
    required int userId,
    required int reportId,
    required String status,
  }) async {
    await _ensureAdmin(userId);
    await BunkerDB.consulta(
      'UPDATE denuncia SET estado = :status WHERE id_denuncia = :id',
      params: <String, dynamic>{'status': status, 'id': reportId},
    );
  }

  Future<void> deletePost({
    required int userId,
    required int postId,
    String? reason,
  }) async {
    await _ensureAdmin(userId);
    await BunkerDB.consulta(
      'UPDATE publicacion SET activa = 0 WHERE id_publicacion = :id',
      params: <String, dynamic>{'id': postId},
    );
    await BunkerDB.consulta(
      'INSERT INTO adminaccion (id_admin, id_objetivo, tipo_accion, detalle) VALUES (:admin_id, NULL, :tipo, :detalle)',
      params: <String, dynamic>{
        'admin_id': userId,
        'tipo': 'eliminar_publicacion',
        'detalle': 'Post=$postId; Motivo=${reason?.trim().isEmpty == true ? 'sin motivo' : reason?.trim() ?? 'sin motivo'}',
      },
    );
  }

  Future<void> deleteUser({
    required int userId,
    required int targetUserId,
    String? reason,
  }) async {
    await _ensureAdmin(userId);
    await BunkerDB.consulta(
      '''
      UPDATE usuario
      SET estado_cuenta = 'eliminada',
          suspension_motivo = :reason
      WHERE id_usuario = :target_id
      ''',
      params: <String, dynamic>{
        'target_id': targetUserId,
        'reason': reason?.trim().isEmpty == true ? 'Cuenta eliminada por administración' : reason?.trim() ?? 'Cuenta eliminada por administración',
      },
    );
    await BunkerDB.consulta(
      'INSERT INTO adminaccion (id_admin, id_objetivo, tipo_accion, detalle) VALUES (:admin_id, :target_id, :tipo, :detalle)',
      params: <String, dynamic>{
        'admin_id': userId,
        'target_id': targetUserId,
        'tipo': 'eliminar_cuenta',
        'detalle': reason?.trim().isEmpty == true ? 'sin motivo' : reason?.trim() ?? 'sin motivo',
      },
    );
  }

  Future<void> suspendUser({
    required int userId,
    required int targetUserId,
    required String mode,
    String? reason,
  }) async {
    await _ensureAdmin(userId);
    String state = 'activa';
    String? untilSql;
    if (mode == 'week') {
      state = 'suspendida';
      untilSql = 'DATE_ADD(NOW(), INTERVAL 7 DAY)';
    } else if (mode == 'month') {
      state = 'suspendida';
      untilSql = 'DATE_ADD(NOW(), INTERVAL 30 DAY)';
    } else if (mode == 'permanent') {
      state = 'suspendida';
      untilSql = null;
    }

    if (mode == 'active') {
      await BunkerDB.consulta(
        '''
        UPDATE usuario
        SET estado_cuenta = 'activa',
            suspendida_hasta = NULL,
            suspension_motivo = NULL
        WHERE id_usuario = :target_id
        ''',
        params: <String, dynamic>{'target_id': targetUserId},
      );
    } else {
      await BunkerDB.consulta(
        '''
        UPDATE usuario
        SET estado_cuenta = :state,
            suspendida_hasta = ${untilSql ?? 'NULL'},
            suspension_motivo = :reason
        WHERE id_usuario = :target_id
        ''',
        params: <String, dynamic>{
          'state': state,
          'reason': reason?.trim().isEmpty == true ? 'Suspensión aplicada por administración' : reason?.trim() ?? 'Suspensión aplicada por administración',
          'target_id': targetUserId,
        },
      );
    }
    await BunkerDB.consulta(
      'INSERT INTO adminaccion (id_admin, id_objetivo, tipo_accion, detalle) VALUES (:admin_id, :target_id, :tipo, :detalle)',
      params: <String, dynamic>{
        'admin_id': userId,
        'target_id': targetUserId,
        'tipo': mode == 'active' ? 'reactivar_cuenta' : 'suspender_cuenta',
        'detalle': 'Modo=$mode; Motivo=${reason?.trim().isEmpty == true ? 'sin motivo' : reason?.trim() ?? 'sin motivo'}',
      },
    );
  }

  Future<AdminStrikeResult> addStrike({
    required int userId,
    required int targetUserId,
    int? postId,
    String? reason,
  }) async {
    await _ensureAdmin(userId);
    await BunkerDB.consulta(
      '''
      INSERT INTO strike (id_usuario, id_publicacion, motivo)
      VALUES (:target_id, :post_id, :reason)
      ''',
      params: <String, dynamic>{
        'target_id': targetUserId,
        'post_id': postId,
        'reason': reason?.trim().isEmpty == true ? 'Strike administrativo' : reason?.trim() ?? 'Strike administrativo',
      },
    );
    final countRows = _rows(
      await BunkerDB.consulta(
        'SELECT COUNT(*) AS total FROM strike WHERE id_usuario = :target_id',
        params: <String, dynamic>{'target_id': targetUserId},
      ),
    );
    final level = countRows.isEmpty ? 0 : _toInt(countRows.first['total']);
    String state = 'activa';
    String? suspendedUntil;
    if (level >= 10) {
      await suspendUser(userId: userId, targetUserId: targetUserId, mode: 'permanent', reason: reason);
      state = 'suspendida';
    } else if (level >= 4) {
      await suspendUser(userId: userId, targetUserId: targetUserId, mode: 'month', reason: reason);
      state = 'suspendida';
      suspendedUntil = DateTime.now().add(const Duration(days: 30)).toIso8601String();
    } else if (level >= 2) {
      await suspendUser(userId: userId, targetUserId: targetUserId, mode: 'week', reason: reason);
      state = 'suspendida';
      suspendedUntil = DateTime.now().add(const Duration(days: 7)).toIso8601String();
    }
    return AdminStrikeResult(level: level, state: state, suspendedUntil: suspendedUntil);
  }

  Future<void> reassignCertificate({
    required int userId,
    required int certificateId,
    required int targetUserId,
  }) async {
    await _ensureAdmin(userId);
    final rows = _rows(
      await BunkerDB.consulta(
        'SELECT id_publicacion, id_edicion, id_propietario_actual FROM certificadodigital WHERE id_certificado = :id LIMIT 1',
        params: <String, dynamic>{'id': certificateId},
      ),
    );
    if (rows.isEmpty) {
      throw Exception('No se encontró el certificado');
    }
    final cert = rows.first;
    await BunkerDB.consulta(
      'UPDATE certificadodigital SET id_propietario_actual = :target_id WHERE id_certificado = :id',
      params: <String, dynamic>{'target_id': targetUserId, 'id': certificateId},
    );
    await BunkerDB.consulta(
      '''
      INSERT INTO historialpropiedad (
        id_publicacion, id_edicion, id_propietario_anterior, id_nuevo_propietario, mostrar_nombre
      ) VALUES (
        :post_id, :edition_id, :previous_id, :target_id, 1
      )
      ''',
      params: <String, dynamic>{
        'post_id': cert['id_publicacion'],
        'edition_id': cert['id_edicion'],
        'previous_id': cert['id_propietario_actual'],
        'target_id': targetUserId,
      },
    );
    await BunkerDB.consulta(
      'INSERT INTO adminaccion (id_admin, id_objetivo, tipo_accion, detalle) VALUES (:admin_id, :target_id, :tipo, :detalle)',
      params: <String, dynamic>{
        'admin_id': userId,
        'target_id': targetUserId,
        'tipo': 'reasignar_certificado',
        'detalle': 'Certificado=$certificateId',
      },
    );
  }
}

class AdminReportDto {
  AdminReportDto({
    required this.id,
    required this.type,
    required this.description,
    required this.status,
    required this.postId,
    required this.reporterId,
    required this.reporterUsername,
    required this.artistId,
    required this.artistUsername,
    required this.postTitle,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String description;
  final String status;
  final int? postId;
  final int? reporterId;
  final String reporterUsername;
  final int? artistId;
  final String artistUsername;
  final String postTitle;
  final DateTime createdAt;

  factory AdminReportDto.fromJson(Map<String, dynamic> json) {
    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return AdminReportDto(
      id: toInt(json['id_denuncia']) ?? 0,
      type: (json['tipo_denuncia'] ?? '').toString(),
      description: (json['descripcion'] ?? '').toString(),
      status: (json['estado'] ?? '').toString(),
      postId: toInt(json['id_publicacion']),
      reporterId: toInt(json['id_usuario_denunciante']),
      reporterUsername: (json['denunciante_usuario'] ?? '').toString(),
      artistId: toInt(json['artista_id']),
      artistUsername: (json['artista_usuario'] ?? '').toString(),
      postTitle: (json['publicacion_titulo'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['fecha_denuncia'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class AdminUserDto {
  AdminUserDto({
    required this.id,
    required this.username,
    required this.publicName,
    required this.email,
    required this.role,
    required this.accountStatus,
    required this.transferCode,
  });

  final int id;
  final String username;
  final String publicName;
  final String email;
  final String role;
  final String accountStatus;
  final String transferCode;

  factory AdminUserDto.fromJson(Map<String, dynamic> json) => AdminUserDto(
    id: json['id_usuario'] is num ? (json['id_usuario'] as num).toInt() : int.tryParse('${json['id_usuario']}') ?? 0,
    username: (json['nombre_usuario'] ?? '').toString(),
    publicName: (json['nombre_publico'] ?? '').toString(),
    email: (json['correo'] ?? '').toString(),
    role: (json['rol'] ?? '').toString(),
    accountStatus: (json['estado_cuenta'] ?? '').toString(),
    transferCode: (json['transfer_code'] ?? '').toString(),
  );
}

class AdminPostDto {
  AdminPostDto({
    required this.id,
    required this.title,
    required this.description,
    required this.active,
    required this.artistId,
    required this.artistUsername,
  });

  final int id;
  final String title;
  final String description;
  final bool active;
  final int artistId;
  final String artistUsername;

  factory AdminPostDto.fromJson(Map<String, dynamic> json) => AdminPostDto(
    id: json['id_publicacion'] is num ? (json['id_publicacion'] as num).toInt() : int.tryParse('${json['id_publicacion']}') ?? 0,
    title: (json['titulo'] ?? '').toString(),
    description: (json['descripcion_corta'] ?? '').toString(),
    active: json['activa'] == true || json['activa'] == 1 || json['activa']?.toString() == '1',
    artistId: json['id_artista'] is num ? (json['id_artista'] as num).toInt() : int.tryParse('${json['id_artista']}') ?? 0,
    artistUsername: (json['nombre_usuario'] ?? '').toString(),
  );
}

class AdminStrikeResult {
  AdminStrikeResult({
    required this.level,
    required this.state,
    required this.suspendedUntil,
  });

  final int level;
  final String state;
  final String? suspendedUntil;
}

class AdminActionDto {
  AdminActionDto({
    required this.id,
    required this.type,
    required this.detail,
    required this.createdAt,
    required this.adminUser,
    required this.targetUser,
  });

  final int id;
  final String type;
  final String detail;
  final DateTime createdAt;
  final String adminUser;
  final String? targetUser;

  factory AdminActionDto.fromJson(Map<String, dynamic> json) => AdminActionDto(
    id: json['id_accion'] is num ? (json['id_accion'] as num).toInt() : int.tryParse('${json['id_accion']}') ?? 0,
    type: (json['tipo_accion'] ?? '').toString(),
    detail: (json['detalle'] ?? '').toString(),
    createdAt: DateTime.tryParse((json['fecha'] ?? '').toString()) ?? DateTime.now(),
    adminUser: (json['admin_usuario'] ?? '').toString(),
    targetUser: json['objetivo_usuario']?.toString(),
  );
}
