import 'dart:convert';

class FeedPostDto {
  FeedPostDto({
    required this.id,
    required this.artistId,
    required this.title,
    required this.description,
    required this.artistName,
    required this.publicName,
    required this.createdAt,
    required this.imageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    required this.esMayor18,
    required this.edicion,
    required this.nombreAutorCompleto,
    required this.tecnicaMateriales,
    required this.anioCreacion,
    required this.dimensiones,
    required this.propietarioCuenta,
    required this.propietarioAnonimo,
    required this.ediciones,
  });

  final int id;
  final int artistId;
  final String title;
  final String description;
  final String artistName;
  final String publicName;
  final DateTime createdAt;
  final String? imageUrl;
  final int likeCount;
  final int commentCount;
  final int favoriteCount;
  final bool esMayor18;
  final String? edicion;
  final String? nombreAutorCompleto;
  final String? tecnicaMateriales;
  final int? anioCreacion;
  final String? dimensiones;
  final String? propietarioCuenta;
  final bool propietarioAnonimo;
  final List<FeedPostEditionDto> ediciones;

  factory FeedPostDto.fromJson(Map<String, dynamic> json) {
    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return FeedPostDto(
      id: toInt(json['id_publicacion']) ?? 0,
      artistId: toInt(json['id_artista']) ?? 0,
      title: (json['titulo'] ?? '').toString(),
      description: (json['descripcion_corta'] ?? '').toString(),
      artistName: (json['nombre_usuario'] ?? '').toString(),
      publicName: (json['nombre_publico'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['fecha_publicacion']?.toString() ?? '') ??
          DateTime.now(),
      imageUrl: json['imagen_obra']?.toString(),
      likeCount: toInt(json['like_count']) ?? 0,
      commentCount: toInt(json['comment_count']) ?? 0,
      favoriteCount: toInt(json['favorite_count']) ?? 0,
      esMayor18:
          json['es_mayor_18'] == true ||
          json['es_mayor_18'] == 1 ||
          json['es_mayor_18']?.toString() == '1',
      edicion: json['edicion']?.toString(),
      nombreAutorCompleto: json['nombre_autor_completo']?.toString(),
      tecnicaMateriales: json['tecnica_materiales']?.toString(),
      anioCreacion: toInt(json['anio_creacion']),
      dimensiones: json['dimensiones']?.toString(),
      propietarioCuenta: json['propietario_cuenta']?.toString(),
      propietarioAnonimo:
          json['propietario_anonimo'] == true ||
          json['propietario_anonimo'] == 1 ||
          json['propietario_anonimo']?.toString() == '1',
      ediciones: FeedPostEditionDto.parseList(json['ediciones_json']),
    );
  }
}

class FeedPostEditionDto {
  FeedPostEditionDto({
    required this.idEdicion,
    required this.numeroEdicion,
    required this.totalEdiciones,
    required this.edicionLabel,
    this.imageUrl,
  });

  final int idEdicion;
  final int numeroEdicion;
  final int totalEdiciones;
  final String edicionLabel;
  final String? imageUrl;

  factory FeedPostEditionDto.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final numero = toInt(json['numero_edicion']);
    final total = toInt(json['total_ediciones']);
    final fallbackLabel =
        '${numero <= 0 ? 1 : numero}/${total <= 0 ? 1 : total}';
    return FeedPostEditionDto(
      idEdicion: toInt(json['id_edicion']),
      numeroEdicion: numero <= 0 ? 1 : numero,
      totalEdiciones: total <= 0 ? 1 : total,
      edicionLabel: (json['edicion_label'] ?? fallbackLabel).toString(),
      imageUrl: json['imagen_obra']?.toString(),
    );
  }

  static List<FeedPostEditionDto> parseList(dynamic raw) {
    dynamic parsed = raw;
    if (raw is String) {
      try {
        parsed = jsonDecode(raw);
      } catch (_) {
        return [];
      }
    }
    if (parsed is! List) return [];
    return parsed
        .whereType<Map>()
        .map(
          (item) => FeedPostEditionDto.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }
}

