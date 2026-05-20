import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sportoteka/presentation/community_screen/news_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart'; // оставить — нужно для ссылок



class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;
  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final title = (post['title'] ?? '').toString();
    final body = (post['body'] ?? post['description'] ?? '').toString();
    final image = (post['image'] ?? '').toString();
    final author = (post['author'] ?? '').toString();
    final createdAt = (post['created_at'] ?? '').toString();
    final link = (post['link'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? 'Пост' : title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(image, fit: BoxFit.cover),
            ),
          const SizedBox(height: 12),
          if (title.isNotEmpty)
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          if (author.isNotEmpty || createdAt.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              [if (author.isNotEmpty) author, if (createdAt.isNotEmpty) createdAt].join(' • '),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(fontSize: 15, height: 1.35)),
          if (link.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(link);
                if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.link),
              label: const Text('Открыть ссылку'),
            ),
          ],
        ],
      ),
    );
  }
}
