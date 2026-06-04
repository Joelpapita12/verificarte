
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/api_models.dart';
import '../models/chat_message.dart';
import '../models/feed_post.dart';
import 'bunker_db.dart';
import 'current_user_store.dart';
import 'e2e_crypto.dart';

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
        '(p.titulo LIKE :query1 OR u.nombre_usuario LIKE :query2 OR u.nombre_publico LIKE :query3)',
      );
      params['query1'] = '%$q%';
      params['query2'] = '%$q%';
      params['query3'] = '%$q%';
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
          u.foto_perfil AS foto_perfil_artista,
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
          ) AS favorite_count,
          (
            SELECT COUNT(*) FROM `like` lu
            WHERE lu.id_publicacion = p.id_publicacion AND lu.id_usuario = :like_uid
          ) AS liked_by_me,
          (
            SELECT COUNT(*) FROM favorito fu
            WHERE fu.id_publicacion = p.id_publicacion AND fu.id_usuario = :fav_uid
          ) AS favorited_by_me
        FROM publicacion p
        JOIN usuario u ON u.id_usuario = p.id_artista
        LEFT JOIN (
          SELECT id_publicacion, edicion, nombre_autor_completo,
                 tecnica_materiales, anio_creacion, dimensiones, declaracion_autenticidad
          FROM obradetalle
          GROUP BY id_publicacion
        ) od ON od.id_publicacion = p.id_publicacion
        WHERE ${where.join(' AND ')}
        ORDER BY p.fecha_publicacion DESC
        LIMIT 50
        ''',
        params: {...params, 'like_uid': userId ?? 0, 'fav_uid': userId ?? 0},
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

      final estadoObra = (row['estado_obra'] ?? '').toString();
      final decl = (row['declaracion_autenticidad'] ?? '').toString();
      String? propietarioCuenta;
      bool propietarioAnonimo = false;
      if (estadoObra == 'con_propietario') {
        final match = RegExp(r'Propietario:\s*(.*)$').firstMatch(decl);
        if (match != null) {
          final val = (match.group(1) ?? '').trim();
          if (val == 'anonimo') {
            propietarioAnonimo = true;
          } else if (val.isNotEmpty) {
            propietarioCuenta = val;
          }
        }
      }

      final dto = FeedPostDto.fromJson(<String, dynamic>{
        ...row,
        'descripcion_corta': row['descripcion_corta'],
        'propietario_cuenta': propietarioCuenta,
        'propietario_anonimo': propietarioAnonimo ? 1 : 0,
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
          AND (nombre_usuario LIKE :query1 OR nombre_publico LIKE :query2)
        ORDER BY nombre_publico ASC, nombre_usuario ASC
        LIMIT 30
        ''',
        params: <String, dynamic>{'query1': '%$q%', 'query2': '%$q%'},
      ),
    );
    return rows.map(AccountSearchDto.fromJson).toList();
  }

  static const String _uploadUrl = 'https://verificarte.softapatio.mx/bunker_upload.php';
  static const String _apiKey = 'T4t3W4r1_S3cr3t_2026_X';

  Future<String> uploadPostImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_uploadUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _apiKey,
        },
        body: jsonEncode(<String, dynamic>{
          'content_b64': base64Encode(bytes),
          'file_name': fileName,
        }),
      );
      final data = jsonDecode(response.body);
      if (data is Map && data['ok'] == true) {
        final url = (data['imageUrl'] as String?)?.trim() ?? '';
        if (url.isNotEmpty) return url;
      }
    } catch (_) {}
    return _dataUrl(bytes, fileName);
  }

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
    if (title.trim().isEmpty) {
      throw Exception('El título de la obra es obligatorio');
    }
    if (tecnicaMateriales.trim().isEmpty) {
      throw Exception('La técnica o materiales es obligatoria');
    }
    if (dimensiones.trim().isEmpty) {
      throw Exception('Las dimensiones son obligatorias');
    }
    if (nombreAutorCompleto.trim().isEmpty) {
      throw Exception('El nombre del autor es obligatorio');
    }

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

    final insertPostRaw = await BunkerDB.consulta(
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
    );
    int postId = 0;
    if (insertPostRaw is Map) {
      postId = _toInt(insertPostRaw['last_id']);
    } else if (insertPostRaw is List && insertPostRaw.isNotEmpty) {
      postId = _toInt((insertPostRaw.first as Map?)?['last_id']);
    }
    if (postId <= 0) {
      // Fallback: buscar el último insert del artista
      final fallback = _rows(
        await BunkerDB.consulta(
          'SELECT id_publicacion FROM publicacion WHERE id_artista = :aid ORDER BY id_publicacion DESC LIMIT 1',
          params: <String, dynamic>{'aid': artistId},
        ),
      );
      if (fallback.isNotEmpty) postId = _toInt(fallback.first['id_publicacion']);
    }
    if (postId <= 0) {
      throw Exception('No se pudo registrar la obra en el servidor. Verifica los datos e intenta de nuevo.');
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
        // Firma ECDSA-SHA256 si hay keypair disponible; fallback a firma legada
        final ecKeyPair = CurrentUserStore.ecKeyPair;
        String? firmab64;
        String algoritmo;
        if (ecKeyPair != null) {
          final payloadBytes = Uint8List.fromList(
            payloadHash.codeUnits,
          );
          firmab64 = E2eCrypto.signPayload(
            payload: payloadBytes,
            privateKey: ecKeyPair.privateKey,
          );
          algoritmo = 'ECDSA_SHA256';
        } else {
          firmab64 = signatureRows.isEmpty
              ? null
              : signatureRows.first['firma_encriptada']?.toString();
          algoritmo = 'sha256';
        }

        await BunkerDB.consulta(
          '''
          INSERT INTO certificadodigital (
            id_publicacion, id_propietario_actual, link_unico, codigo_qr, id_edicion,
            payload_hash, firma_digital_b64, algoritmo_firma, huella_llave, timestamp_firma
          ) VALUES (
            :post_id, :owner_id, :link_unico, :codigo_qr, :edition_id,
            :payload_hash, :firma_digital_b64, :algoritmo, :huella_llave, NOW()
          )
          ''',
          params: <String, dynamic>{
            'post_id': postId,
            'owner_id': artistId,
            'link_unico': certToken,
            'codigo_qr': certToken,
            'edition_id': editionId <= 0 ? null : editionId,
            'payload_hash': payloadHash,
            'firma_digital_b64': firmab64,
            'algoritmo': algoritmo,
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
        'declaracion': estadoObra == 'con_propietario'
            ? (propietarioAnonimo
                ? 'Propietario: anonimo'
                : 'Propietario: ${propietarioCuenta?.trim() ?? ''}')
            : '',
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
    final insertResult = await BunkerDB.consulta(
      'INSERT INTO comentario (id_usuario, id_publicacion, contenido) VALUES (:user_id, :post_id, :content)',
      params: <String, dynamic>{
        'user_id': userId,
        'post_id': postId,
        'content': content.trim(),
      },
    );
    int commentId = 0;
    if (insertResult is Map) {
      commentId = _toInt(insertResult['last_id']);
    } else if (insertResult is List && insertResult.isNotEmpty) {
      commentId = _toInt((insertResult.first as Map?)?['last_id']);
    }

    final List<Map<String, dynamic>> rows;
    if (commentId > 0) {
      rows = _rows(
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
    } else {
      rows = _rows(
        await BunkerDB.consulta(
          '''
          SELECT c.id_comentario, c.id_usuario, c.contenido, c.fecha,
                 u.nombre_usuario, u.nombre_publico
          FROM comentario c
          JOIN usuario u ON u.id_usuario = c.id_usuario
          WHERE c.id_usuario = :user_id AND c.id_publicacion = :post_id
          ORDER BY c.id_comentario DESC
          LIMIT 1
          ''',
          params: <String, dynamic>{'user_id': userId, 'post_id': postId},
        ),
      );
    }
    if (rows.isEmpty) throw Exception('No se pudo obtener el comentario');
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
        'SELECT id_publicacion FROM favorito WHERE id_usuario = :user_id',
        params: <String, dynamic>{'user_id': userId},
      ),
    );
    if (favoriteRows.isEmpty) return const <FeedPostDto>[];
    final all = await fetchPosts(userId: userId);
    final ids = favoriteRows.map((row) => _toInt(row['id_publicacion'])).toSet();
    return all.where((post) => ids.contains(post.id)).toList();
  }

  Future<Map<String, String>?> fetchUserBasicInfo({required int userId}) async {
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT nombre_publico, nombre_usuario, foto_perfil
        FROM usuario
        WHERE id_usuario = :id
        LIMIT 1
        ''',
        params: <String, dynamic>{'id': userId},
      ),
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return <String, String>{
      'nombre_publico': (row['nombre_publico'] ?? '').toString(),
      'nombre_usuario': (row['nombre_usuario'] ?? '').toString(),
      'foto_perfil': (row['foto_perfil'] ?? '').toString(),
    };
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
              AND mu.id_receptor = :uid1
              AND mu.leido = 0
          ) AS unread_count,
          COALESCE(cm.pinned, 0) AS pinned,
          COALESCE(cm.blocked, 0) AS blocked
        FROM (
          SELECT
            CASE WHEN id_emisor = :uid2 THEN id_receptor ELSE id_emisor END AS other_id,
            MAX(fecha) AS last_time
          FROM mensaje
          WHERE id_emisor = :uid3 OR id_receptor = :uid4
          GROUP BY other_id
        ) t
        JOIN mensaje m ON (
          ((m.id_emisor = :uid5 AND m.id_receptor = t.other_id)
            OR (m.id_emisor = t.other_id AND m.id_receptor = :uid6))
          AND m.fecha = t.last_time
        )
        JOIN usuario u ON u.id_usuario = t.other_id
        LEFT JOIN chatmeta cm
          ON cm.id_usuario = :uid7 AND cm.id_otro_usuario = t.other_id
        WHERE COALESCE(cm.deleted, 0) = 0
        ORDER BY COALESCE(cm.pinned, 0) DESC, t.last_time DESC
        ''',
        params: <String, dynamic>{
          'uid1': userId,
          'uid2': userId,
          'uid3': userId,
          'uid4': userId,
          'uid5': userId,
          'uid6': userId,
          'uid7': userId,
        },
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
        SELECT id_mensaje, id_emisor, id_receptor, contenido,
               COALESCE(cifrado, 0) AS cifrado, fecha, leido
        FROM mensaje
        WHERE (id_emisor = :user_id AND id_receptor = :other_id)
           OR (id_emisor = :other_id2 AND id_receptor = :user_id2)
        ORDER BY fecha ASC
        ''',
        params: <String, dynamic>{
          'user_id': userId,
          'other_id': otherUserId,
          'user_id2': userId,
          'other_id2': otherUserId,
        },
      ),
    );
    final msgs = rows.map(ChatMessageDto.fromJson).toList();

    final keyPair = CurrentUserStore.ecKeyPair;
    if (keyPair == null) return msgs;

    return msgs.map((m) {
      if (!m.cifrado) return m;
      final plain = E2eCrypto.decryptMessage(
        encryptedJson: m.content,
        privateKey: keyPair.privateKey,
      );
      return m.copyWith(content: plain ?? '[Mensaje cifrado]');
    }).toList();
  }

  /// Obtiene la clave pública EC de un usuario desde `usuarioclavedigital`.
  Future<String?> _fetchRecipientPublicKey(int userId) async {
    try {
      final rows = _rows(
        await BunkerDB.consulta(
          'SELECT public_key_pem FROM usuarioclavedigital WHERE id_usuario = :id LIMIT 1',
          params: <String, dynamic>{'id': userId},
        ),
      );
      if (rows.isEmpty) return null;
      final key = (rows.first['public_key_pem'] ?? '').toString().trim();
      return key.isEmpty ? null : key;
    } catch (_) {
      return null;
    }
  }

  Future<void> sendMessage({
    required int senderId,
    required int receiverId,
    required String content,
  }) async {
    var finalContent = content.trim();
    var cifrado = 0;

    // Cifrar si el receptor tiene clave pública registrada
    final senderKeyPair = CurrentUserStore.ecKeyPair;
    if (senderKeyPair != null) {
      final recipPubKey = await _fetchRecipientPublicKey(receiverId);
      if (recipPubKey != null) {
        try {
          finalContent = E2eCrypto.encryptMessage(
            plaintext: finalContent,
            recipientPublicKeyB64: recipPubKey,
          );
          cifrado = 1;
        } catch (_) {
          // Si falla el cifrado, enviar en claro
          finalContent = content.trim();
          cifrado = 0;
        }
      }
    }

    await BunkerDB.consulta(
      '''
      INSERT INTO mensaje (id_emisor, id_receptor, contenido, cifrado)
      VALUES (:sender_id, :receiver_id, :content, :cifrado)
      ''',
      params: <String, dynamic>{
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': finalContent,
        'cifrado': cifrado,
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
    // Crear la tabla si no existe
    await BunkerDB.consulta(
      '''
      CREATE TABLE IF NOT EXISTS notificacionestado (
        id_estado INT AUTO_INCREMENT PRIMARY KEY,
        id_usuario INT NOT NULL,
        last_seen DATETIME NOT NULL,
        UNIQUE KEY uniq_user (id_usuario)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
      ''',
    );

    final lastSeenRows = _rows(
      await BunkerDB.consulta(
        'SELECT last_seen FROM notificacionestado WHERE id_usuario = :id LIMIT 1',
        params: <String, dynamic>{'id': userId},
      ),
    );
    final lastSeen = lastSeenRows.isEmpty
        ? '1970-01-01 00:00:00'
        : (lastSeenRows.first['last_seen'] ?? '1970-01-01 00:00:00').toString();

    // PDO no permite el mismo parámetro nombrado más de una vez por query,
    // por eso se usan nombres únicos por cada aparición.
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT * FROM (
          SELECT
            'like' AS type,
            l.id_publicacion AS post_id,
            l.id_usuario AS other_user_id,
            CASE WHEN l.fecha > :ls1 THEN 1 ELSE 0 END AS unread,
            COALESCE(u.nombre_publico, u.nombre_usuario) AS actor_name,
            u.foto_perfil AS actor_avatar,
            NULL AS comment_text,
            l.fecha AS created_at
          FROM `like` l
          JOIN publicacion p ON p.id_publicacion = l.id_publicacion
          JOIN usuario u ON u.id_usuario = l.id_usuario
          WHERE p.id_artista = :uid1
            AND l.id_usuario <> :uid1b

          UNION ALL

          SELECT
            'comment' AS type,
            c.id_publicacion AS post_id,
            c.id_usuario AS other_user_id,
            CASE WHEN c.fecha > :ls2 THEN 1 ELSE 0 END AS unread,
            COALESCE(u.nombre_publico, u.nombre_usuario) AS actor_name,
            u.foto_perfil AS actor_avatar,
            c.contenido AS comment_text,
            c.fecha AS created_at
          FROM comentario c
          JOIN publicacion p ON p.id_publicacion = c.id_publicacion
          JOIN usuario u ON u.id_usuario = c.id_usuario
          WHERE p.id_artista = :uid2
            AND c.id_usuario <> :uid2b

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
          WHERE m.id_receptor = :uid3
        ) notifications
        ORDER BY created_at DESC
        LIMIT 80
        ''',
        params: <String, dynamic>{
          'uid1': userId,
          'uid1b': userId,
          'uid2': userId,
          'uid2b': userId,
          'uid3': userId,
          'ls1': lastSeen,
          'ls2': lastSeen,
        },
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
    final rows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT
          h.id_historial,
          h.id_edicion,
          h.fecha_transferencia,
          h.mostrar_nombre,
          -- Prioridad: snapshot guardado → JOIN actual → fallback
          COALESCE(h.nombre_anterior, ua.nombre_publico, ua.nombre_usuario, 'Propietario anterior') AS anterior_publico,
          COALESCE(ua.nombre_usuario, '') AS anterior_username,
          COALESCE(h.nombre_nuevo, un.nombre_publico, un.nombre_usuario, 'Propietario') AS nuevo_publico,
          COALESCE(un.nombre_usuario, '') AS nuevo_username
        FROM historialpropiedad h
        LEFT JOIN usuario ua ON ua.id_usuario = h.id_propietario_anterior
        LEFT JOIN usuario un ON un.id_usuario = h.id_propietario_nuevo
        WHERE h.id_publicacion = :post_id
        ORDER BY h.fecha_transferencia DESC
        ''',
        params: <String, dynamic>{'post_id': postId},
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
          od.declaracion_autenticidad,
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
          od.declaracion_autenticidad,
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
    bool anonymous = false,
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
        WHERE (:certificate_id_check IS NULL OR id_certificado = :certificate_id_val)
          AND (:post_id_check IS NULL OR id_publicacion = :post_id_val)
          AND (:edition_id_check IS NULL OR id_edicion = :edition_id_val)
          AND id_propietario_actual = :user_id
          AND activo = 1
        ORDER BY id_certificado ASC
        LIMIT 1
        ''',
        params: <String, dynamic>{
          'certificate_id_check': certificateId,
          'certificate_id_val': certificateId,
          'post_id_check': postId,
          'post_id_val': postId,
          'edition_id_check': editionId,
          'edition_id_val': editionId,
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
    // Obtener nombres actuales para guardar snapshot en el historial.
    final senderRows = _rows(await BunkerDB.consulta(
      'SELECT nombre_publico, nombre_usuario FROM usuario WHERE id_usuario = :id LIMIT 1',
      params: <String, dynamic>{'id': userId},
    ));
    final receiverRows = _rows(await BunkerDB.consulta(
      'SELECT nombre_publico, nombre_usuario FROM usuario WHERE id_usuario = :id LIMIT 1',
      params: <String, dynamic>{'id': targetUserId},
    ));
    String pickName(List<Map<String, dynamic>> rows) {
      if (rows.isEmpty) return '';
      final pub = (rows.first['nombre_publico'] ?? '').toString().trim();
      if (pub.isNotEmpty) return pub;
      return (rows.first['nombre_usuario'] ?? '').toString().trim();
    }
    final senderName = pickName(senderRows);
    final receiverName = anonymous ? 'Anónimo' : pickName(receiverRows);

    await BunkerDB.consulta(
      '''
      INSERT INTO historialpropiedad (
        id_publicacion, id_edicion, id_propietario_anterior, id_propietario_nuevo,
        mostrar_nombre, nombre_anterior, nombre_nuevo
      ) VALUES (
        :post_id, :edition_id, :previous_id, :target_id,
        :mostrar_nombre, :nombre_anterior, :nombre_nuevo
      )
      ''',
      params: <String, dynamic>{
        'post_id': cert['id_publicacion'],
        'edition_id': cert['id_edicion'],
        'previous_id': userId,
        'target_id': targetUserId,
        'mostrar_nombre': anonymous ? 0 : 1,
        'nombre_anterior': senderName,
        'nombre_nuevo': receiverName,
      },
    );
  }

  Future<ArtistStatsDto> fetchArtistStats({required int artistId}) async {
    final totalsRows = _rows(
      await BunkerDB.consulta(
        '''
        SELECT
          (SELECT COUNT(*) FROM `like` l JOIN publicacion p ON p.id_publicacion = l.id_publicacion WHERE p.id_artista = :aid1 AND p.activa = 1) AS likes,
          (SELECT COUNT(*) FROM comentario c JOIN publicacion p ON p.id_publicacion = c.id_publicacion WHERE p.id_artista = :aid2 AND p.activa = 1) AS comments,
          (SELECT COUNT(*) FROM favorito f JOIN publicacion p ON p.id_publicacion = f.id_publicacion WHERE p.id_artista = :aid3 AND p.activa = 1) AS favorites,
          (SELECT COUNT(*) FROM mensaje m WHERE m.id_receptor = :aid4) AS messages
        ''',
        params: <String, dynamic>{
          'aid1': artistId,
          'aid2': artistId,
          'aid3': artistId,
          'aid4': artistId,
        },
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
