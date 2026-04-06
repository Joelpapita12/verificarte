class Post {
  Post({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.available,
    required this.hasOwner,
    this.likeCount = 0,
    this.commentCount = 0,
    this.edicion,
    this.medidas,
    this.autor,
    this.hasPropietario = false,
    this.propietarioAnonimo = false,
    this.propietarioCuenta,
    this.tecnicaMateriales,
    this.anioCreacion,
  });

  final int id;
  final int? ownerId;
  final String title;
  final String description;
  final String? imageUrl;
  final bool available;
  final bool hasOwner;
  final int likeCount;
  final int commentCount;
  final String? edicion;
  final String? medidas;
  final String? autor;
  final bool hasPropietario;
  final bool propietarioAnonimo;
  final String? propietarioCuenta;
  final String? tecnicaMateriales;
  final int? anioCreacion;
}
