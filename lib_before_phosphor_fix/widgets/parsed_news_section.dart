import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class ParsedNewsSection extends StatefulWidget {
  final String sport;
  const ParsedNewsSection({super.key, required this.sport});

  @override
  State<ParsedNewsSection> createState() => _ParsedNewsSectionState();
}

class _ParsedNewsSectionState extends State<ParsedNewsSection> {
  List<Map<String, dynamic>> news = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    try {
      final uri = Uri.parse(
          'https://sportotekaapp.ru/api/get_parsed_news.php?category=${Uri.encodeComponent(widget.sport)}');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          news = List<Map<String, dynamic>>.from(data);
          news.sort((a, b) {
            final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
            final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
            return bDate.compareTo(aDate); // От новых к старым
          });
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Ошибка загрузки новостей: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (news.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Нет новостей по этой категории."),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: news.length,
      itemBuilder: (context, index) {
  return Padding(
    padding: EdgeInsets.only(left: index == 0 ? 16 : 0, right: 12),
    child: _buildNewsCard(news[index]),
  );
}
      ),
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () {
        if (post['link'] != null && post['link'].toString().isNotEmpty) {
          launchUrl(Uri.parse(post['link']), mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: post['image'] != null && post['image'].toString().isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(post['image']),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.3), BlendMode.darken),
                )
              : null,
          color: const Color(0xFF1E74C4),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post['title'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Spacer(),
            Text(
              post['created_at'] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
