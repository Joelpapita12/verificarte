
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/api_models.dart';
import '../models/chat_message.dart';
import '../models/feed_post.dart';
import 'bunker_db.dart';

class FeedApi {
  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool _toBool(dynamic value) =>
      value == true || value == 1 || value?.toString() == '1';

  String _mimeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/png';
  }

  String _dataUrl(Uint8List bytes, String fileName) =>
      'data:${_mimeFor(fileName)};base64,${base64Encode(bytes)}';

  String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();

  String _token(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().millisecondsSinceEpoch}';

  Future<String> _contentPreference(int userId) async {
    final rows = _rows(
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
    final value = (rows.first['preferencia_contenido'] ?? 'todo').toString();
    return value.isEmpty ? 'todo' : value;
  }

  Future<List<FeedPostDto>> fetchPosts({
    String? query,
    int? artistId,
    int? userId,
  }) async {
    final where = <String>['p.activa = 1'];
    final params = <String, dynamic>{};

    if (artistId != null) {
      where.add('p.id_artista = :artist_id');
      params['artist_id'] = artistId;
    }

    final q = query?.trim() ?? '';
    if (q.isNotEmpty) {
      where.add(
        '(p.titulo LIKE :query OR u.nombre_usuario LIKE :query OR u.nombre_publico LIKE :query)',
      );
      params['query'] = '%$q%';
    }

    if (userId != null) {
      final pref = await _contentPreference(userId);
      if (pref == 'sin_18') {
        where.add('COALESCE(p.es_mayor_18, 0) = 0');
      } else if (pref == 'solo_18') {
        where.add('COALESCE(p.es_mayor_18, 0) = 1');
      }
    }

    final posts = _rows(
      await BunkerDB.consulta(
        '''
        SELECT
          p.id_publicacion,
          p.id_artista,
          p.titulo,
          p.descripcion_corta,
          p.imagen_obra,
          p.fecha_publicacion,
          p.estado_obra,
          p.hash_obra,
          p.es_mayor_18,
          u.nombre_usuario,
          u.nombre_publico,
          od.edicion,
          od.nombre_autor_completo,
          od.tecnica_materiales,
          od.anio_creacion,
          od.dimensiones,
          od.declaracion_autenticidad,
          (
            SELECT COUNT(*)
            FROM `like` l
            WHERE l.id_publicacion = p.id_publicacion
          ) AS like_count,
          (
            SELECT COUNT(*)
            FROM comentario c
            WHERE c.id_publicacion = p.id_publicacion
          ) AS comment_count,
          (
            SELECT COUNT(*)
            FROM favorito f
            WHERE f.id_publicacion = p.id_publicacion
          ) AS favorite_count
        FROM publicacion p
        JOIN usuario u ON u.id_usuario = p.id_artista
        LEFT JOIN obradetalle od ON od.id_publicacion = p.id_publicacion
        WHERE ${where.join(' AND ')}
        ORDER BY p.fecha_publicacion DESC
        LIMIT 50
        ''',
        params: params,
      ),
    );

    final result = <FeedPostDto>[];
    for (final row in posts) {
      final postId = _toInt(row['id_publicacion']);
      final editions = _rows(
        await BunkerDB.consulta(
          '''
          SELECT
            id_edicion,
            numero_edicion,
            total_ediciones,
            imagen_obra,
            CONCAT(numero_edicion, '/', total_ediciones) AS edicion_label
          FROM publicacionedicion
          WHERE id_publicacion = :post_id
          ORDER BY numero_edicion ASC
          ''',
          params: <String, dynamic>{'post_id': postId},
        ),
      );

      final dto = FeedPostDto.fromJson(<String, dynamic>{
        ...row,
        'descripcion_corta': row['descripcion_corta'],
        'propietario_cuenta': null,
        'propietario_anonimo': 0,
        'ediciones_json': editions,
      });
      result.add(dto);
    }
    return result;
  }

  Future<List<AccountSearchDto>> fetchAccounts({required String query}) async {
    final q = query.trim();
    if (q.isEmpty) return const <AccountSearchDto>[];
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT id_usuario, nombre_usuario, nombre_publico, rol, foto_perfil
        FROM usuario
        WHERE estado_cuenta = 'activa'
          AND (nombre_usuario LIKE :query OR nombre_publico LIKE :query)
        ORDER BY nombre_publico ASC, nombre_usuario ASC
        LIMIT 30
        ''',
        params: <String, dynamic>{'query': '%$q%'},
      ),
    );
    return rows.map(AccountSearchDto.fromJson).toList();
  }

  Future<String> uploadPostImage({
    required Uint8List bytes,
    required String fileName,
  }) async => _dataUrl(bytes, fileName);

  Future<bool> hasUserSignature({required int userId}) async {
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT id_firma
        FROM usuariofirma
        WHERE id_usuario = :id
          AND activa = 1
        LIMIT 1
        ''',
        params: <String, dynamic>{'id': userId},
      ),
    );
    return rows.isNotEmpty;
  }

  Future<void> uploadUserSignature({
    required int userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final encoded = _dataUrl(bytes, fileName);
    final hash = _sha256(encoded);
    await BunkerDB.consulta(
      '''
      INSERT INTO usuariofirma (
        id_usuario,
        firma_hash,
        firma_encriptada,
        mime_type,
        file_name,
        activa
      )
      VALUES (:user_id, :firma_hash, :firma_encriptada, :mime_type, :file_name, 1)
      ON DUPLICATE KEY UPDATE
        firma_hash = :firma_hash_update,
        firma_encriptada = :firma_encriptada_update,
        mime_type = :mime_type_update,
        file_name = :file_name_update,
        activa = 1
      ''',
      params: <String, dynamic>{
        'user_id': userId,
        'firma_hash': hash,
        'firma_encriptada': encoded,
        'mime_type': _mimeFor(fileName),
        'file_name': fileName,
        'firma_hash_update': hash,
        'firma_encriptada_update': encoded,
        'mime_type_update': _mimeFor(fileName),
        'file_name_update': fileName,
      },
    );
  }

  Future<UserSignatureDto> getMySignature({required int userId}) async {
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT activa, file_name, updated_at
        FROM usuariofirma
        WHERE id_usuario = :id
        LIMIT 1
        ''',
        params: <String, dynamic>{'id': userId},
      ),
    );
    if (rows.isEmpty) {
      return UserSignatureDto(hasSignature: false);
    }
    final row = rows.first;
    return UserSignatureDto(
      hasSignature: _toBool(row['activa']),
      fileName: row['file_name']?.toString(),
      updatedAt: row['updated_at']?.toString(),
    );
  }

  Future<void> deleteMySignature({required int userId}) async {
    await BunkerDB.consulta(
      'UPDATE usuariofirma SET activa = 0 WHERE id_usuario = :id',
      params: <String, dynamic>{'id': userId},
    );
  }

  Future<int> createPost({
    required int artistId,
    required String title,
    required String description,
    required String? imageUrl,
    List<String> imageUrls = const <String>[],
    required String tecnicaMateriales,
    required int anioCreacion,
    required String dimensiones,
    required String estadoObra,
    required bool esMayor18,
    String? propietarioCuenta,
    required bool propietarioAnonimo,
    required String nombreAutorCompleto,
    String? pseudonimo,
    String? edicion,
    required String declaracionAutenticidad,
  }) async {
    final roleRows = _rows(
      await BunkerDB.consulta(
        'SELECT rol FROM usuario WHERE id_usuario = :id LIMIT 1',
        params: <String, dynamic>{'id': artistId},
      ),
    );
    final role = roleRows.isEmpty ? '' : (roleRows.first['rol'] ?? '').toString();
    final normalizedImages = imageUrls.where((e) => e.trim().isNotEmpty).toList();
    final totalEditions = normalizedImages.isEmpty ? 1 : normalizedImages.length;
    final primaryImage = normalizedImages.isEmpty ? imageUrl : normalizedImages.first;

    final insertPost = _map(
      await BunkerDB.consulta(
        '''
        INSERT INTO publicacion (
          id_artista, titulo, descripcion_corta, imagen_obra, estado_obra, hash_obra, es_mayor_18
        ) VALUES (
          :artist_id, :title, :description, :image_url, :estado_obra, :hash_obra, :es_mayor_18
        )
        ''',
        params: <String, dynamic>{
          'artist_id': artistId,
          'title': title.trim(),
          'description': description.trim(),
          'image_url': primaryImage,
          'estado_obra': estadoObra,
          'hash_obra': _sha256(
            '${title.trim()}|$nombreAutorCompleto|$tecnicaMateriales|$anioCreacion',
          ),
          'es_mayor_18': esMayor18 ? 1 : 0,
        },
      ),
    );
    final postId = _toInt(insertPost?['last_id']);
    if (postId <= 0) {
      throw Exception('No se pudo crear la publicación');
    }

    final declaration = StringBuffer(declaracionAutenticidad.trim());
    if (estadoObra == 'con_propietario') {
      declaration.write(
        propietarioAnonimo
            ? ' | Propietario: anonimo'
            : ' | Propietario: ${propietarioCuenta?.trim() ?? ''}',
      );
    }

    await BunkerDB.consulta(
      '''
      INSERT INTO obradetalle (
        id_publicacion, tecnica_materiales, anio_creacion, dimensiones,
        edicion, nombre_autor_completo, pseudonimo, declaracion_autenticidad
      ) VALUES (
        :post_id, :tecnica, :anio, :dimensiones, :edicion, :autor, :pseudonimo, :declaracion
      )
      ''',
      params: <String, dynamic>{
        'post_id': postId,
        'tecnica': tecnicaMateriales.trim(),
        'anio': anioCreacion,
        'dimensiones': dimensiones.trim(),
        'edicion': edicion?.trim().isEmpty == true ? null : edicion?.trim(),
        'autor': nombreAutorCompleto.trim(),
        'pseudonimo': pseudonimo?.trim().isEmpty == true ? null : pseudonimo?.trim(),
        'declaracion': declaration.toString(),
      },
    );

    final editionImages = normalizedImages.isEmpty
        ? <String?>[primaryImage]
        : normalizedImages.cast<String?>();
    for (var i = 0; i < editionImages.length; i += 1) {
      final editionInsert = _map(
        await BunkerDB.consulta(
          '''
          INSERT INTO publicacionedicion (
            id_publicacion, numero_edicion, total_ediciones, imagen_obra
          ) VALUES (
            :post_id, :numero, :total, :image_url
          )
          ''',
          params: <String, dynamic>{
            'post_id': postId,
            'numero': i + 1,
            'total': totalEditions,
            'image_url': editionImages[i],
          },
        ),
      );

      final editionId = _toInt(editionInsert?['last_id']);
      if (role != 'administrador') {
        final certToken = _token('cert-$postId-e${i + 1}');
        final payloadHash = _sha256(
          '$title|$nombreAutorCompleto|$tecnicaMateriales|$anioCreacion|$postId|${i + 1}/$totalEditions',
        );
        final signatureRows = _rows(
          await BunkerDB.consulta(
            '''
            SELECT firma_encriptada, firma_hash
            FROM usuariofirma
            WHERE id_usuario = :id
              AND activa = 1
            LIMIT 1
            ''',
            params: <String, dynamic>{'id': artistId},
          ),
        );
        final signatureB64 = signatureRows.isEmpty
            ? null
            : signatureRows.first['firma_encriptada'];
        await BunkerDB.consulta(
          '''
          INSERT INTO certificadodigital (
            id_publicacion, id_propietario_actual, link_unico, codigo_qr, id_edicion,
            payload_hash, firma_digital_b64, algoritmo_firma, huella_llave, timestamp_firma
          ) VALUES (
            :post_id, :owner_id, :link_unico, :codigo_qr, :edition_id,
            :payload_hash, :firma_digital_b64, 'sha256', :huella_llave, NOW()
          )
          ''',
          params: <String, dynamic>{
            'post_id': postId,
            'owner_id': artistId,
            'link_unico': certToken,
            'codigo_qr': certToken,
            'edition_id': editionId <= 0 ? null : editionId,
            'payload_hash': payloadHash,
            'firma_digital_b64': signatureB64,
            'huella_llave': _sha256('$artistId|$payloadHash'),
          },
        );
      }
    }

    return postId;
  }

  Future<void> updatePost({
    required int userId,
    required int postId,
    required String title,
    required String description,
    String? imageUrl,
    String? estadoObra,
    String? tecnicaMateriales,
    String? dimensiones,
    int? anioCreacion,
    required String? edicion,
    String? nombreAutorCompleto,
    required bool propietarioAnonimo,
    String? propietarioCuenta,
  }) async {
    final finalTechnique = (tecnicaMateriales ?? '').trim();
    final finalDimensions = (dimensiones ?? '').trim();
    final finalYear = anioCreacion ?? 0;
    final finalAuthor = (nombreAutorCompleto ?? '').trim();
    await BunkerDB.consulta(
      '''
      UPDATE publicacion
      SET titulo = :title,
          descripcion_corta = :description,
          imagen_obra = COALESCE(:image_url, imagen_obra),
          estado_obra = COALESCE(:estado_obra, estado_obra),
          hash_obra = :hash_obra
      WHERE id_publicacion = :post_id
        AND id_artista = :user_id
      ''',
      params: <String, dynamic>{
        'title': title.trim(),
        'description': description.trim(),
        'image_url': imageUrl,
        'estado_obra': estadoObra,
        'hash_obra': _sha256('$title|$finalAuthor|$finalTechnique|$finalYear'),
        'post_id': postId,
        'user_id': userId,
      },
    );

    await BunkerDB.consulta(
      '''
      UPDATE obradetalle
      SET tecnica_materiales = :tecnica,
          anio_creacion = :anio,
          dimensiones = :dimensiones,
          edicion = :edicion,
          nombre_autor_completo = :autor,
          declaracion_autenticidad = :declaracion
      WHERE id_publicacion = :post_id
      ''',
      params: <String, dynamic>{
        'tecnica': finalTechnique.isEmpty ? null : finalTechnique,
        'anio': finalYear <= 0 ? null : finalYear,
        'dimensiones': finalDimensions.isEmpty ? null : finalDimensions,
        'edicion': edicion?.trim().isEmpty == true ? null : edicion?.trim(),
        'autor': finalAuthor.isEmpty ? null : finalAuthor,
        'declaracion': propietarioAnonimo
            ? 'Propietario: anonimo'
            : 'Propietario: ${propietarioCuenta?.trim() ?? ''}',
        'post_id': postId,
      },
    );
  }

  Future<void> deletePost({required int userId, required int postId}) async {
    await BunkerDB.consulta(
      'UPDATE publicacion SET activa = 0 WHERE id_publicacion = :post_id AND id_artista = :user_id',
      params: <String, dynamic>{'post_id': postId, 'user_id': userId},
    );
  }

  Future<LikeResult> toggleLike({
    required int userId,
    required int postId,
  }) async {
    final rows = _rows(
      await BunkerDB.consulta(
        'SELECT id_like FROM `like` WHERE id_usuario = :user_id AND id_publicacion = :post_id LIMIT 1',
        params: <String, dynamic>{'user_id': userId, 'post_id': postId},
      ),
    );
    final liked = rows.isEmpty;
    if (liked) {
      await BunkerDB.consulta(
        'INSERT INTO `like` (id_usuario, id_publicacion) VALUES (:user_id, :post_id)',
        params: <String, dynamic>{'user_id': userId, 'post_id': postId},
      );
    } else {
      await BunkerDB.consulta(
        'DELETE FROM `like` WHERE id_like = :id',
        params: <String, dynamic>{'id': rows.first['id_like']},
      );
    }
    final total = _rows(
      await BunkerDB.consulta(
        'SELECT COUNT(*) AS total FROM `like` WHERE id_publicacion = :post_id',
        params: <String, dynamic>{'post_id': postId},
      ),
    );
    return LikeResult(liked: liked, likeCount: _toInt(total.first['total']));
  }

  Future<FavoriteResult> toggleFavorite({
    required int userId,
    required int postId,
  }) async {
    final rows = _rows(
      await BunkerDB.consulta(
        'SELECT id_favorito FROM favorito WHERE id_usuario = :user_id AND id_publicacion = :post_id LIMIT 1',
        params: <String, dynamic>{'user_id': userId, 'post_id': postId},
      ),
    );
    final favorited = rows.isEmpty;
    if (favorited) {
      await BunkerDB.consulta(
        'INSERT INTO favorito (id_usuario, id_publicacion) VALUES (:user_id, :post_id)',
        params: <String, dynamic>{'user_id': userId, 'post_id': postId},
      );
    } else {
      await BunkerDB.consulta(
        'DELETE FROM favorito WHERE id_favorito = :id',
        params: <String, dynamic>{'id': rows.first['id_favorito']},
      );
    }
    final total = _rows(
      await BunkerDB.consulta(
        'SELECT COUNT(*) AS total FROM favorito WHERE id_publicacion = :post_id',
        params: <String, dynamic>{'post_id': postId},
      ),
    );
    return FavoriteResult(
      favorited: favorited,
      favoriteCount: _toInt(total.first['total']),
    );
  }

  Future<PostCommentDto> addComment({
    required int userId,
    required int postId,
    required String content,
  }) async {
    final insert = _map(
      await BunkerDB.consulta(
        'INSERT INTO comentario (id_usuario, id_publicacion, contenido) VALUES (:user_id, :post_id, :content)',
        params: <String, dynamic>{
          'user_id': userId,
          'post_id': postId,
          'content': content.trim(),
        },
      ),
    );
    final commentId = _toInt(insert?['last_id']);
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT c.id_comentario, c.id_usuario, c.contenido, c.fecha,
               u.nombre_usuario, u.nombre_publico
        FROM comentario c
        JOIN usuario u ON u.id_usuario = c.id_usuario
        WHERE c.id_comentario = :id
        LIMIT 1
        ''',
        params: <String, dynamic>{'id': commentId},
      ),
    );
    return PostCommentDto.fromJson(rows.first);
  }

  Future<List<PostCommentDto>> fetchComments({required int postId}) async {
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT c.id_comentario, c.id_usuario, c.contenido, c.fecha,
               u.nombre_usuario, u.nombre_publico
        FROM comentario c
        JOIN usuario u ON u.id_usuario = c.id_usuario
        WHERE c.id_publicacion = :post_id
        ORDER BY c.fecha ASC
        ''',
        params: <String, dynamic>{'post_id': postId},
      ),
    );
    return rows.map(PostCommentDto.fromJson).toList();
  }

  Future<void> updateComment({
    required int userId,
    required int commentId,
    required String content,
  }) async {
    await BunkerDB.consulta(
      'UPDATE comentario SET contenido = :content WHERE id_comentario = :comment_id AND id_usuario = :user_id',
      params: <String, dynamic>{
        'content': content.trim(),
        'comment_id': commentId,
        'user_id': userId,
      },
    );
  }

  Future<void> deleteComment({
    required int userId,
    required int commentId,
  }) async {
    await BunkerDB.consulta(
      'DELETE FROM comentario WHERE id_comentario = :comment_id AND id_usuario = :user_id',
      params: <String, dynamic>{'comment_id': commentId, 'user_id': userId},
    );
  }

  Future<List<FeedPostDto>> fetchFavoritePosts({required int userId}) async {
    final favoriteRows = _rows(
      await BunkerDB.consulta(
        'SELECT id_publicacion FROM favorito WHERE id_usuario = :user_id ORDER BY fecha_agregado DESC',
        params: <String, dynamic>{'user_id': userId},
      ),
    );
    if (favoriteRows.isEmpty) return const <FeedPostDto>[];
    final all = await fetchPosts(userId: userId);
    final ids = favoriteRows.map((row) => _toInt(row['id_publicacion'])).toSet();
    return all.where((post) => ids.contains(post.id)).toList();
  }

  Future<List<ChatThreadDto>> fetchChatThreads(int userId) async {
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT
          t.other_id,
          COALESCE(u.nombre_publico, u.nombre_usuario) AS other_name,
          u.foto_perfil AS other_avatar,
          m.contenido AS last_message,
          m.fecha AS last_time,
          (
            SELECT COUNT(*)
            FROM mensaje mu
            WHERE mu.id_emisor = t.other_id
              AND mu.id_receptor = :user_id
              AND mu.leido = 0
          ) AS unread_count,
          COALESCE(cm.pinned, 0) AS pinned,
          COALESCE(cm.blocked, 0) AS blocked
        FROM (
          SELECT
            CASE WHEN id_emisor = :user_id THEN id_receptor ELSE id_emisor END AS other_id,
            MAX(fecha) AS last_time
          FROM mensaje
          WHERE id_emisor = :user_id OR id_receptor = :user_id
          GROUP BY other_id
        ) t
        JOIN mensaje m ON (
          ((m.id_emisor = :user_id AND m.id_receptor = t.other_id)
            OR (m.id_emisor = t.other_id AND m.id_receptor = :user_id))
          AND m.fecha = t.last_time
        )
        JOIN usuario u ON u.id_usuario = t.other_id
        LEFT JOIN chatmeta cm
          ON cm.id_usuario = :user_id AND cm.id_otro_usuario = t.other_id
        WHERE COALESCE(cm.deleted, 0) = 0
        ORDER BY COALESCE(cm.pinned, 0) DESC, t.last_time DESC
        ''',
        params: <String, dynamic>{'user_id': userId},
      ),
    );
    return rows.map(ChatThreadDto.fromJson).toList();
  }

  Future<List<ChatMessageDto>> fetchConversation({
    required int userId,
    required int otherUserId,
  }) async {
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT id_mensaje, id_emisor, id_receptor, contenido, fecha, leido
        FROM mensaje
        WHERE (id_emisor = :user_id AND id_receptor = :other_id)
           OR (id_emisor = :other_id AND id_receptor = :user_id)
        ORDER BY fecha ASC
        ''',
        params: <String, dynamic>{'user_id': userId, 'other_id': otherUserId},
      ),
    );
    return rows.map(ChatMessageDto.fromJson).toList();
  }

  Future<void> sendMessage({
    required int senderId,
    required int receiverId,
    required String content,
  }) async {
    await BunkerDB.consulta(
      'INSERT INTO mensaje (id_emisor, id_receptor, contenido) VALUES (:sender_id, :receiver_id, :content)',
      params: <String, dynamic>{
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': content.trim(),
      },
    );
  }

  Future<void> markChatRead({
    required int userId,
    required int otherUserId,
  }) async {
    await BunkerDB.consulta(
      'UPDATE mensaje SET leido = 1 WHERE id_emisor = :other_id AND id_receptor = :user_id',
      params: <String, dynamic>{'other_id': otherUserId, 'user_id': userId},
    );
  }

  Future<void> _upsertChatMeta({
    required int userId,
    required int otherUserId,
    bool? pinned,
    bool? blocked,
    bool? deleted,
  }) async {
    await BunkerDB.consulta(
      '''
      INSERT INTO chatmeta (id_usuario, id_otro_usuario, pinned, blocked, deleted)
      VALUES (:user_id, :other_id, :pinned, :blocked, :deleted)
      ON DUPLICATE KEY UPDATE
        pinned = :pinned_update,
        blocked = :blocked_update,
        deleted = :deleted_update
      ''',
      params: <String, dynamic>{
        'user_id': userId,
        'other_id': otherUserId,
        'pinned': pinned == true ? 1 : 0,
        'blocked': blocked == true ? 1 : 0,
        'deleted': deleted == true ? 1 : 0,
        'pinned_update': pinned == true ? 1 : 0,
        'blocked_update': blocked == true ? 1 : 0,
        'deleted_update': deleted == true ? 1 : 0,
      },
    );
  }

  Future<void> pinChat({
    required int userId,
    required int otherUserId,
    required bool pinned,
  }) => _upsertChatMeta(userId: userId, otherUserId: otherUserId, pinned: pinned);

  Future<void> blockChat({
    required int userId,
    required int otherUserId,
    required bool blocked,
  }) => _upsertChatMeta(userId: userId, otherUserId: otherUserId, blocked: blocked);

  Future<void> deleteChat({
    required int userId,
    required int otherUserId,
  }) => _upsertChatMeta(userId: userId, otherUserId: otherUserId, deleted: true);

  Future<List<NotificationDto>> fetchNotifications(int userId) async {
    final lastSeenRows = _rows(
      await BunkerDB.consulta(
        'SELECT last_seen FROM notificacionestado WHERE id_usuario = :id LIMIT 1',
        params: <String, dynamic>{'id': userId},
      ),
    );
    final lastSeen = lastSeenRows.isEmpty ? '1970-01-01 00:00:00' : (lastSeenRows.first['last_seen'] ?? '1970-01-01 00:00:00').toString();
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT * FROM (
          SELECT
            'like' AS type,
            l.id_publicacion AS post_id,
            l.id_usuario AS other_user_id,
            CASE WHEN l.fecha_like > :last_seen THEN 1 ELSE 0 END AS unread,
            COALESCE(u.nombre_publico, u.nombre_usuario) AS actor_name,
            u.foto_perfil AS actor_avatar,
            NULL AS comment_text,
            l.fecha_like AS created_at
          FROM `like` l
          JOIN publicacion p ON p.id_publicacion = l.id_publicacion
          JOIN usuario u ON u.id_usuario = l.id_usuario
          WHERE p.id_artista = :user_id
            AND l.id_usuario <> :user_id

          UNION ALL

          SELECT
            'comment' AS type,
            c.id_publicacion AS post_id,
            c.id_usuario AS other_user_id,
            CASE WHEN c.fecha > :last_seen THEN 1 ELSE 0 END AS unread,
            COALESCE(u.nombre_publico, u.nombre_usuario) AS actor_name,
            u.foto_perfil AS actor_avatar,
            c.contenido AS comment_text,
            c.fecha AS created_at
          FROM comentario c
          JOIN publicacion p ON p.id_publicacion = c.id_publicacion
          JOIN usuario u ON u.id_usuario = c.id_usuario
          WHERE p.id_artista = :user_id
            AND c.id_usuario <> :user_id

          UNION ALL

          SELECT
            'chat' AS type,
            NULL AS post_id,
            m.id_emisor AS other_user_id,
            CASE WHEN m.leido = 0 THEN 1 ELSE 0 END AS unread,
            COALESCE(u.nombre_publico, u.nombre_usuario) AS actor_name,
            u.foto_perfil AS actor_avatar,
            m.contenido AS comment_text,
            m.fecha AS created_at
          FROM mensaje m
          JOIN usuario u ON u.id_usuario = m.id_emisor
          WHERE m.id_receptor = :user_id
        ) notifications
        ORDER BY created_at DESC
        LIMIT 80
        ''',
        params: <String, dynamic>{'user_id': userId, 'last_seen': lastSeen},
      ),
    );
    return rows.map(NotificationDto.fromJson).toList();
  }

  Future<void> markNotificationsRead(int userId) async {
    await BunkerDB.consulta(
      '''
      INSERT INTO notificacionestado (id_usuario, last_seen)
      VALUES (:id, NOW())
      ON DUPLICATE KEY UPDATE last_seen = NOW()
      ''',
      params: <String, dynamic>{'id': userId},
    );
  }

  Future<void> createReport({
    required int userId,
    required int postId,
    required String reportType,
    String? description,
  }) async {
    await BunkerDB.consulta(
      '''
      INSERT INTO denuncia (id_usuario_denunciante, id_publicacion, tipo_denuncia, descripcion, estado)
      VALUES (:user_id, :post_id, :tipo, :descripcion, 'pendiente')
      ''',
      params: <String, dynamic>{
        'user_id': userId,
        'post_id': postId,
        'tipo': reportType.trim(),
        'descripcion': description?.trim(),
      },
    );
  }

  Future<void> createSupportReport({
    required int userId,
    required String reasonType,
    String? description,
  }) async {
    await createReport(
      userId: userId,
      postId: 0,
      reportType: reasonType,
      description: description,
    );
  }

  Future<List<OwnershipHistoryDto>> fetchOwnershipHistory({
    required int postId,
    int? editionId,
  }) async {
    final whereEdition = editionId == null ? '' : 'AND h.id_edicion = :edition_id';
    final params = <String, dynamic>{
      'post_id': postId,
      ...?editionId == null ? null : <String, dynamic>{'edition_id': editionId},
    };
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT
          h.id_historial,
          h.id_edicion,
          h.fecha_transferencia,
          h.mostrar_nombre,
          ua.nombre_usuario AS anterior_username,
          ua.nombre_publico AS anterior_publico,
          un.nombre_usuario AS nuevo_username,
          un.nombre_publico AS nuevo_publico
        FROM historialpropiedad h
        LEFT JOIN usuario ua ON ua.id_usuario = h.id_propietario_anterior
        LEFT JOIN usuario un ON un.id_usuario = h.id_nuevo_propietario
        WHERE h.id_publicacion = :post_id
          $whereEdition
        ORDER BY h.fecha_transferencia DESC
        ''',
        params: params,
      ),
    );
    return rows.map(OwnershipHistoryDto.fromJson).toList();
  }

  Future<CertificateDto?> fetchCertificate({
    required int postId,
    int? editionId,
  }) async {
    final whereEdition = editionId == null ? '' : 'AND c.id_edicion = :edition_id';
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT
          c.*,
          p.hash_obra,
          p.estado_obra,
          p.imagen_obra,
          p.id_artista,
          pe.imagen_obra AS edicion_imagen,
          pe.numero_edicion,
          pe.total_ediciones,
          CONCAT(pe.numero_edicion, '/', pe.total_ediciones) AS edicion_label,
          od.tecnica_materiales,
          od.nombre_autor_completo,
          od.dimensiones,
          od.anio_creacion,
          u.nombre_usuario AS artista_apodo,
          u.nombre_publico AS artista_nombre,
          uf.firma_hash AS firma_hash_artista,
          uf.firma_encriptada AS signature_image_url
        FROM certificadodigital c
        JOIN publicacion p ON p.id_publicacion = c.id_publicacion
        LEFT JOIN publicacionedicion pe ON pe.id_edicion = c.id_edicion
        LEFT JOIN obradetalle od ON od.id_publicacion = p.id_publicacion
        LEFT JOIN usuario u ON u.id_usuario = p.id_artista
        LEFT JOIN usuariofirma uf ON uf.id_usuario = p.id_artista AND uf.activa = 1
        WHERE c.id_publicacion = :post_id
          AND c.activo = 1
          $whereEdition
        ORDER BY c.id_certificado ASC
        LIMIT 1
        ''',
        params: <String, dynamic>{
          'post_id': postId,
          ...?editionId == null ? null : <String, dynamic>{'edition_id': editionId},
        },
      ),
    );
    if (rows.isEmpty) return null;
    return CertificateDto.fromJson(rows.first);
  }

  Future<List<MyCertificateDto>> fetchMyCertificates({required int userId}) async {
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
        WHERE c.id_propietario_actual = :user_id
          AND c.activo = 1
        ORDER BY c.fecha_emision DESC
        ''',
        params: <String, dynamic>{'user_id': userId},
      ),
    );
    return rows.map(MyCertificateDto.fromJson).toList();
  }

  Future<void> transferCertificate({
    required int userId,
    int? postId,
    int? certificateId,
    int? editionId,
    required String targetCode,
  }) async {
    final targetRows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT id_usuario
        FROM usuario
        WHERE transfer_code = :code
          AND estado_cuenta = 'activa'
        LIMIT 1
        ''',
        params: <String, dynamic>{'code': targetCode.trim().toUpperCase()},
      ),
    );
    if (targetRows.isEmpty) {
      throw Exception('No se encontró la cuenta destino');
    }
    final targetUserId = _toInt(targetRows.first['id_usuario']);

    final certRows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT id_certificado, id_publicacion, id_edicion, id_propietario_actual
        FROM certificadodigital
        WHERE (:certificate_id IS NULL OR id_certificado = :certificate_id)
          AND (:post_id IS NULL OR id_publicacion = :post_id)
          AND (:edition_id IS NULL OR id_edicion = :edition_id)
          AND id_propietario_actual = :user_id
          AND activo = 1
        ORDER BY id_certificado ASC
        LIMIT 1
        ''',
        params: <String, dynamic>{
          'certificate_id': certificateId,
          'post_id': postId,
          'edition_id': editionId,
          'user_id': userId,
        },
      ),
    );
    if (certRows.isEmpty) {
      throw Exception('No tienes acceso a ese certificado');
    }
    final cert = certRows.first;

    await BunkerDB.consulta(
      'UPDATE certificadodigital SET id_propietario_actual = :target_id WHERE id_certificado = :certificate_id',
      params: <String, dynamic>{
        'target_id': targetUserId,
        'certificate_id': cert['id_certificado'],
      },
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
        'previous_id': userId,
        'target_id': targetUserId,
      },
    );
  }

  Future<ArtistStatsDto> fetchArtistStats({required int artistId}) async {
    final totalsRows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT
          (SELECT COUNT(*) FROM `like` l JOIN publicacion p ON p.id_publicacion = l.id_publicacion WHERE p.id_artista = :artist_id AND p.activa = 1) AS likes,
          (SELECT COUNT(*) FROM comentario c JOIN publicacion p ON p.id_publicacion = c.id_publicacion WHERE p.id_artista = :artist_id AND p.activa = 1) AS comments,
          (SELECT COUNT(*) FROM favorito f JOIN publicacion p ON p.id_publicacion = f.id_publicacion WHERE p.id_artista = :artist_id AND p.activa = 1) AS favorites,
          (SELECT COUNT(*) FROM mensaje m WHERE m.id_receptor = :artist_id) AS messages
        ''',
        params: <String, dynamic>{'artist_id': artistId},
      ),
    );
    final likers = _rows(
      await BunkerDB.consulta(
        '''
        SELECT u.id_usuario, u.nombre_usuario, u.nombre_publico, u.foto_perfil, COUNT(*) AS total
        FROM `like` l
        JOIN publicacion p ON p.id_publicacion = l.id_publicacion
        JOIN usuario u ON u.id_usuario = l.id_usuario
        WHERE p.id_artista = :artist_id
          AND p.activa = 1
        GROUP BY u.id_usuario, u.nombre_usuario, u.nombre_publico, u.foto_perfil
        ORDER BY total DESC, u.nombre_publico ASC
        ''',
        params: <String, dynamic>{'artist_id': artistId},
      ),
    );
    final commenters = _rows(
      await BunkerDB.consulta(
        '''
        SELECT u.id_usuario, u.nombre_usuario, u.nombre_publico, u.foto_perfil, COUNT(*) AS total
        FROM comentario c
        JOIN publicacion p ON p.id_publicacion = c.id_publicacion
        JOIN usuario u ON u.id_usuario = c.id_usuario
        WHERE p.id_artista = :artist_id
          AND p.activa = 1
        GROUP BY u.id_usuario, u.nombre_usuario, u.nombre_publico, u.foto_perfil
        ORDER BY total DESC, u.nombre_publico ASC
        ''',
        params: <String, dynamic>{'artist_id': artistId},
      ),
    );
    return ArtistStatsDto.fromJson(<String, dynamic>{
      'totals': totalsRows.isEmpty ? <String, dynamic>{} : totalsRows.first,
      'likers': likers,
      'commenters': commenters,
    });
  }
}
