class LikeResult {
  LikeResult({required this.liked, required this.likeCount});

  final bool liked;
  final int likeCount;
}

class FavoriteResult {
  FavoriteResult({required this.favorited, required this.favoriteCount});

  final bool favorited;
  final int favoriteCount;
}

class NotificationDto {
  NotificationDto({
    required this.type,
    required this.postId,
    required this.otherUserId,
    required this.unread,
    required this.actorName,
    required this.actorAvatar,
    required this.commentText,
    required this.createdAt,
  });

  final String type;
  final int? postId;
  final int? otherUserId;
  final bool unread;
  final String actorName;
  final String? actorAvatar;
  final String? commentText;
  final DateTime createdAt;

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return NotificationDto(
      type: (json['type'] ?? '').toString(),
      postId: toInt(json['post_id']),
      otherUserId: toInt(json['other_user_id']),
      unread: json['unread'] == 1 || json['unread'] == true,
      actorName: (json['actor_name'] ?? '').toString(),
      actorAvatar: json['actor_avatar']?.toString(),
      commentText: json['comment_text']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class UserSignatureDto {
  UserSignatureDto({required this.hasSignature, this.fileName, this.updatedAt});

  final bool hasSignature;
  final String? fileName;
  final String? updatedAt;
}

class OwnershipHistoryDto {
  OwnershipHistoryDto({
    required this.id,
    required this.editionId,
    required this.createdAt,
    required this.showName,
    required this.fromName,
    required this.toName,
  });

  final int id;
  final int? editionId;
  final DateTime createdAt;
  final bool showName;
  final String fromName;
  final String toName;

  factory OwnershipHistoryDto.fromJson(Map<String, dynamic> json) {
    String bestName(dynamic publicName, dynamic userName) {
      final public = (publicName ?? '').toString().trim();
      if (public.isNotEmpty) return public;
      return (userName ?? '').toString().trim();
    }

    return OwnershipHistoryDto(
      id: (json['id_historial'] as num?)?.toInt() ?? 0,
      editionId: (json['id_edicion'] as num?)?.toInt(),
      createdAt:
          DateTime.tryParse(json['fecha_transferencia']?.toString() ?? '') ??
          DateTime.now(),
      showName: json['mostrar_nombre'] == true || json['mostrar_nombre'] == 1,
      fromName: bestName(json['anterior_publico'], json['anterior_username']),
      toName: bestName(json['nuevo_publico'], json['nuevo_username']),
    );
  }
}

class CertificateDto {
  CertificateDto({
    required this.id,
    required this.postId,
    required this.editionId,
    required this.ownerId,
    required this.link,
    required this.qrCode,
    required this.createdAt,
    required this.active,
    required this.edicionLabel,
    required this.numeroEdicion,
    required this.totalEdiciones,
    this.imageUrl,
    this.signatureHash,
    this.artworkHash,
    this.registrationTimestamp,
    this.certificateCreatedAt,
    this.artistName,
    this.artistAlias,
    this.artworkState,
    this.dimensions,
    this.creationYear,
    this.authorFullName,
    this.certificateSignatureB64,
    this.certificatePayloadHash,
    this.signatureAlgorithm,
    this.keyFingerprint,
    this.signatureTimestamp,
    this.signatureImageUrl,
  });

  final int id;
  final int postId;
  final int? editionId;
  final int ownerId;
  final String? link;
  final String? qrCode;
  final DateTime createdAt;
  final bool active;
  final String edicionLabel;
  final int numeroEdicion;
  final int totalEdiciones;
  final String? imageUrl;
  final String? signatureHash;
  final String? artworkHash;
  final String? registrationTimestamp;
  final String? certificateCreatedAt;
  final String? artistName;
  final String? artistAlias;
  final String? artworkState;
  final String? dimensions;
  final int? creationYear;
  final String? authorFullName;
  final String? certificateSignatureB64;
  final String? certificatePayloadHash;
  final String? signatureAlgorithm;
  final String? keyFingerprint;
  final String? signatureTimestamp;
  final String? signatureImageUrl;

  factory CertificateDto.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return CertificateDto(
      id: toInt(json['id_certificado']),
      postId: toInt(json['id_publicacion']),
      editionId: (json['id_edicion'] as num?)?.toInt(),
      ownerId: toInt(json['id_propietario_actual']),
      link: json['link_unico']?.toString(),
      qrCode: json['codigo_qr']?.toString(),
      createdAt:
          DateTime.tryParse(json['fecha_emision']?.toString() ?? '') ??
          DateTime.now(),
      active: json['activo'] == true || json['activo'] == 1,
      edicionLabel: (json['edicion_label'] ?? '').toString(),
      numeroEdicion: toInt(json['numero_edicion']),
      totalEdiciones: toInt(json['total_ediciones']),
      imageUrl: json['imagen_obra']?.toString(),
      signatureHash: json['firma_hash_artista']?.toString(),
      artworkHash: json['hash_obra']?.toString(),
      registrationTimestamp: json['timestamp_registro']?.toString(),
      certificateCreatedAt: json['fecha_creacion_certificado']?.toString(),
      artistName: json['artista_nombre']?.toString(),
      artistAlias: json['artista_apodo']?.toString(),
      artworkState: json['estado_obra']?.toString(),
      dimensions: json['dimensiones']?.toString(),
      creationYear: toInt(json['anio_creacion']) == 0
          ? null
          : toInt(json['anio_creacion']),
      authorFullName: json['nombre_autor_completo']?.toString(),
      certificateSignatureB64: json['firma_digital_b64']?.toString(),
      certificatePayloadHash: json['payload_hash']?.toString(),
      signatureAlgorithm: json['algoritmo_firma']?.toString(),
      keyFingerprint: json['huella_llave']?.toString(),
      signatureTimestamp: json['timestamp_firma']?.toString(),
      signatureImageUrl: json['signature_image_url']?.toString(),
    );
  }
}

class MyCertificateDto {
  MyCertificateDto({
    required this.certificateId,
    required this.postId,
    required this.ownerId,
    required this.link,
    required this.qrCode,
    required this.createdAt,
    required this.active,
    required this.postTitle,
    required this.postImageUrl,
    required this.artistId,
    required this.artistUsername,
    required this.artistPublicName,
    required this.editionId,
    required this.numeroEdicion,
    required this.totalEdiciones,
    required this.edicionLabel,
    this.signatureHash,
    this.signatureEncrypted,
    this.artworkHash,
    this.registrationTimestamp,
    this.certificateCreatedAt,
    this.artistName,
    this.artistAlias,
    this.artworkState,
    this.tecnicaMateriales,
    this.authorFullName,
    this.dimensions,
    this.creationYear,
    this.certificatePayloadHash,
    this.certificateSignatureB64,
    this.signatureAlgorithm,
    this.keyFingerprint,
    this.signatureTimestamp,
    this.validationState,
    this.signatureImageUrl,
  });

  final int certificateId;
  final int postId;
  final int ownerId;
  final String? link;
  final String? qrCode;
  final DateTime createdAt;
  final bool active;
  final String postTitle;
  final String? postImageUrl;
  final int artistId;
  final String artistUsername;
  final String artistPublicName;
  final int? editionId;
  final int numeroEdicion;
  final int totalEdiciones;
  final String edicionLabel;
  final String? signatureHash;
  final String? signatureEncrypted;
  final String? artworkHash;
  final String? registrationTimestamp;
  final String? certificateCreatedAt;
  final String? artistName;
  final String? artistAlias;
  final String? artworkState;
  final String? tecnicaMateriales;
  final String? authorFullName;
  final String? dimensions;
  final int? creationYear;
  final String? certificatePayloadHash;
  final String? certificateSignatureB64;
  final String? signatureAlgorithm;
  final String? keyFingerprint;
  final String? signatureTimestamp;
  final String? validationState;
  final String? signatureImageUrl;

  factory MyCertificateDto.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return MyCertificateDto(
      certificateId: toInt(json['id_certificado']),
      postId: toInt(json['id_publicacion']),
      ownerId: toInt(json['id_propietario_actual']),
      link: json['link_unico']?.toString(),
      qrCode: json['codigo_qr']?.toString(),
      createdAt:
          DateTime.tryParse(json['fecha_emision']?.toString() ?? '') ??
          DateTime.now(),
      active: json['activo'] == true || json['activo'] == 1,
      postTitle: (json['titulo'] ?? '').toString(),
      postImageUrl: json['edicion_imagen']?.toString().trim().isNotEmpty == true
          ? json['edicion_imagen']?.toString()
          : json['imagen_obra']?.toString(),
      artistId: toInt(json['id_artista']),
      artistUsername: (json['artista_username'] ?? '').toString(),
      artistPublicName: (json['artista_publico'] ?? '').toString(),
      editionId: (json['id_edicion'] as num?)?.toInt(),
      numeroEdicion: toInt(json['numero_edicion']),
      totalEdiciones: toInt(json['total_ediciones']),
      edicionLabel: (json['edicion_label'] ?? '').toString().trim().isNotEmpty
          ? (json['edicion_label'] ?? '').toString()
          : '${toInt(json['numero_edicion']) <= 0 ? 1 : toInt(json['numero_edicion'])}/${toInt(json['total_ediciones']) <= 0 ? 1 : toInt(json['total_ediciones'])}',
      signatureHash: json['firma_hash_artista']?.toString(),
      signatureEncrypted: json['firma_encriptada_artista']?.toString(),
      artworkHash: json['hash_obra']?.toString(),
      registrationTimestamp: json['timestamp_registro']?.toString(),
      certificateCreatedAt: json['fecha_creacion_certificado']?.toString(),
      artistName: json['artista_nombre']?.toString(),
      artistAlias: json['artista_apodo']?.toString(),
      artworkState: json['estado_obra']?.toString(),
      tecnicaMateriales: json['tecnica_materiales']?.toString(),
      authorFullName: json['nombre_autor_completo']?.toString(),
      dimensions: json['dimensiones']?.toString(),
      creationYear: toInt(json['anio_creacion']) == 0
          ? null
          : toInt(json['anio_creacion']),
      certificatePayloadHash: json['payload_hash']?.toString(),
      certificateSignatureB64: json['firma_digital_b64']?.toString(),
      signatureAlgorithm: json['algoritmo_firma']?.toString(),
      keyFingerprint: json['huella_llave']?.toString(),
      signatureTimestamp: json['timestamp_firma']?.toString(),
      validationState: json['estado_validacion']?.toString(),
      signatureImageUrl: json['signature_image_url']?.toString(),
    );
  }
}

class PostCommentDto {
  PostCommentDto({
    required this.commentId,
    required this.userId,
    required this.username,
    required this.publicName,
    required this.content,
    required this.createdAt,
  });

  final int commentId;
  final int userId;
  final String username;
  final String publicName;
  final String content;
  final DateTime createdAt;

  factory PostCommentDto.fromJson(Map<String, dynamic> json) {
    return PostCommentDto(
      commentId: json['id_comentario'] as int? ?? 0,
      userId: json['id_usuario'] as int? ?? 0,
      username: (json['nombre_usuario'] ?? '').toString(),
      publicName: (json['nombre_publico'] ?? '').toString(),
      content: (json['contenido'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ArtistStatsDto {
  ArtistStatsDto({
    required this.likes,
    required this.comments,
    required this.favorites,
    required this.messages,
    required this.likers,
    required this.commenters,
  });

  final int likes;
  final int comments;
  final int favorites;
  final int messages;
  final List<InteractionAccountDto> likers;
  final List<InteractionAccountDto> commenters;

  factory ArtistStatsDto.fromJson(Map<String, dynamic> json) {
    final totals = (json['totals'] as Map<String, dynamic>? ?? {});
    final likersRaw = json['likers'] as List<dynamic>? ?? [];
    final commentersRaw = json['commenters'] as List<dynamic>? ?? [];
    return ArtistStatsDto(
      likes: (totals['likes'] ?? 0) as int,
      comments: (totals['comments'] ?? 0) as int,
      favorites: (totals['favorites'] ?? 0) as int,
      messages: (totals['messages'] ?? 0) as int,
      likers: likersRaw
          .map((e) => InteractionAccountDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      commenters: commentersRaw
          .map((e) => InteractionAccountDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class InteractionAccountDto {
  InteractionAccountDto({
    required this.userId,
    required this.username,
    required this.publicName,
    required this.photoUrl,
    required this.total,
  });

  final int userId;
  final String username;
  final String publicName;
  final String? photoUrl;
  final int total;

  factory InteractionAccountDto.fromJson(Map<String, dynamic> json) {
    return InteractionAccountDto(
      userId: json['id_usuario'] as int? ?? 0,
      username: (json['nombre_usuario'] ?? '').toString(),
      publicName: (json['nombre_publico'] ?? '').toString(),
      photoUrl: json['foto_perfil']?.toString(),
      total: (json['total'] ?? 0) as int,
    );
  }
}

class AccountSearchDto {
  AccountSearchDto({
    required this.userId,
    required this.username,
    required this.publicName,
    required this.role,
    this.photoUrl,
  });

  final int userId;
  final String username;
  final String publicName;
  final String role;
  final String? photoUrl;

  factory AccountSearchDto.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return AccountSearchDto(
      userId: toInt(json['id_usuario']),
      username: (json['nombre_usuario'] ?? '').toString(),
      publicName: (json['nombre_publico'] ?? '').toString(),
      role: (json['rol'] ?? '').toString(),
      photoUrl: json['foto_perfil']?.toString(),
    );
  }
}

