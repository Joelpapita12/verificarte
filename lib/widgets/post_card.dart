import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/post.dart';
import 'security_watermark.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    this.forceOwnOptions = false,
    this.onEditPost,
    this.onDeletePost,
  });

  final Post post;
  final int? currentUserId;
  final bool forceOwnOptions;
  final ValueChanged<Post>? onEditPost;
  final ValueChanged<Post>? onDeletePost;

  bool get _isOwner =>
      forceOwnOptions || (currentUserId != null && currentUserId == post.ownerId);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.azulProfundo,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black38,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Align(
            alignment: Alignment.topRight,
            child: PopupMenuButton<String>(
              color: AppColors.azulMarino,
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'edit') {
                  onEditPost?.call(post);
                } else if (value == 'delete') {
                  onDeletePost?.call(post);
                }
              },
              itemBuilder: (context) {
                if (_isOwner) {
                  return const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text(
                        'Modificar publicación',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        'Eliminar publicación',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ];
                }
                return const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Text(
                      'Denunciar plagio',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'history',
                    child: Text(
                      'Historial de certificados',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'certificate',
                    child: Text(
                      'Ver certificado',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ];
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: post.available
                  ? AppColors.statusAvailable
                  : AppColors.statusUnavailable,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              post.available ? 'Disponible' : 'No disponible',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.25,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                child: post.imageUrl == null || post.imageUrl!.trim().isEmpty
                    ? const Center(
                        child: Text(
                          '[Imagen]',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : SecurityWatermark(
                        userLabel: 'verificARTE',
                        timestampLabel: DateTime.now().toIso8601String(),
                        child: Image.network(
                          post.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Text(
                                'No se pudo cargar la imagen',
                                style: TextStyle(color: Colors.white70),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            post.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            post.description,
            style: const TextStyle(color: Colors.white70, fontSize: 13.5),
          ),
          if ((post.edicion ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Edición: ${post.edicion}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          if ((post.tecnicaMateriales ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Técnica: ${post.tecnicaMateriales}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          if ((post.medidas ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Dimensiones: ${post.medidas}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _MetricChip(icon: Icons.favorite_border, value: post.likeCount),
              const SizedBox(width: 10),
              _MetricChip(icon: Icons.comment_outlined, value: post.commentCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

