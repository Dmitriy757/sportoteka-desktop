import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/community_screen/news_detail_screen.dart';

/// Совместимая точка входа для пользовательских публикаций.
///
/// Используем общий NewsDetailScreen, потому что именно он уже связан
/// с лайками/комментариями в проекте. Так пост из ленты и тот же пост из
/// профиля открываются одинаково и не расходятся по логике.
class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  String _text(dynamic value) => (value ?? '').toString().trim();

  String _imageUrl(dynamic raw) {
    final value = _text(raw);
    if (value.isEmpty || value.toLowerCase() == 'null') return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final clean = value.startsWith('/') ? value.substring(1) : value;
    return 'https://sportotekaapp.ru/$clean';
  }

  @override
  Widget build(BuildContext context) {
    final title = _text(post['title']);
    final body = _text(
      post['body'] ?? post['text'] ?? post['caption'] ?? post['description'],
    );
    final image = _imageUrl(
      post['image'] ?? post['image_url'] ?? post['photo'] ?? post['cover'],
    );
    final postId = _asInt(post['id'] ?? post['post_id']);

    return NewsDetailScreen(
      title: title.isEmpty ? 'Публикация' : title,
      body: body,
      newsId: postId,
      imageUrl: image,
    );
  }
}
