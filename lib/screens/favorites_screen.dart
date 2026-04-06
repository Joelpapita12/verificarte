import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/current_user_store.dart';
import '../services/feed_api.dart';
import '../widgets/post_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  static const routeName = '/favoritos';

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FeedApi _api = FeedApi();
  bool _loading = true;
  String? _error;
  List<Post> _posts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = CurrentUserStore.userId;
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Inicia sesión para ver favoritos';
      });
      return;
    }

    try {
      final rows = await _api.fetchFavoritePosts(userId: userId);
      setState(() {
        _posts = rows
            .map(
              (p) => Post(
                id: p.id,
                ownerId: p.artistId,
                title: p.title,
                description: p.description,
                imageUrl: p.imageUrl,
                available: true,
                hasOwner: false,
                likeCount: p.likeCount,
                commentCount: p.commentCount,
                edicion: p.edicion,
                medidas: p.dimensiones,
                autor: p.nombreAutorCompleto,
                hasPropietario:
                    p.propietarioCuenta != null &&
                    p.propietarioCuenta!.isNotEmpty,
                propietarioAnonimo: p.propietarioAnonimo,
                propietarioCuenta: p.propietarioCuenta,
                tecnicaMateriales: p.tecnicaMateriales,
                anioCreacion: p.anioCreacion,
              ),
            )
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar los favoritos';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _posts.isEmpty
          ? const Center(child: Text('Aún no tienes favoritos'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _posts.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(
                  post: _posts[index],
                  currentUserId: CurrentUserStore.userId,
                ),
              ),
            ),
    );
  }
}

