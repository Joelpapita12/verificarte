import 'package:flutter/material.dart';

import '../models/post.dart';
import 'post_card.dart';

class Gallery extends StatelessWidget {
  const Gallery({super.key, required this.posts, required this.currentUserId});

  final List<Post> posts;
  final int? currentUserId;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        mainAxisExtent: 520,
      ),
      itemBuilder: (context, index) {
        return PostCard(post: posts[index], currentUserId: currentUserId);
      },
    );
  }
}
