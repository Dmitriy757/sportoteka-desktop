import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class PostsScreen extends StatefulWidget {
final String? selectedCategory;
final String? selectedTeam;

const PostsScreen({super.key, this.selectedCategory, this.selectedTeam});

@override
State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
List<Map<String, dynamic>> allPosts = [];
List<Map<String, dynamic>> filteredPosts = [];
String? selectedSport;
String? selectedTeam;

@override
void initState() {
super.initState();
selectedSport = widget.selectedCategory;
selectedTeam = widget.selectedTeam;
loadPosts();
}

Future<void> loadPosts() async {
try {
  final response = await http.get(Uri.parse('http://sportotekaapp.ru/api/get_posts.php'));
  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    setState(() {
      allPosts = List<Map<String, dynamic>>.from(data);
      applyFilters();
    });
  } else {
    throw Exception('Ошибка загрузки новостей: ${response.statusCode}');
  }
} catch (e) {
  print("Ошибка загрузки: $e");
}
}

void applyFilters() {
  setState(() {
    filteredPosts = allPosts.where((post) {
      // Исключаем парсенные посты с link
      final isUserPost = post['link'] == null || post['link'].toString().isEmpty;
      final matchesCategory = selectedSport == null || post['category']?.toLowerCase() == selectedSport!.toLowerCase();
      final matchesTeam = selectedTeam == null || post['team']?.toLowerCase() == selectedTeam!.toLowerCase();
      return isUserPost && matchesCategory && matchesTeam;
    }).toList();
  });
}

@override
Widget build(BuildContext context) {
final visiblePosts = filteredPosts.isEmpty ? [] : filteredPosts.take(5).toList();

return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    if (visiblePosts.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Text("Новостей нет", style: TextStyle(fontSize: 16, color: Colors.black54)),
      ),

    ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero, // 👉 минимальные отступы по краям
      itemCount: visiblePosts.length,
      itemBuilder: (context, index) {
        final post = visiblePosts[index];

        return GestureDetector(
          onTap: () => openLink(post['link']),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFDFDFE0), // обводка #DFDFE0
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post['image'] != null && post['image'].toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: Image.network(
                      post['image'],
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, size: 24, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post['author'] ?? '',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  post['created_at'] ?? '',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        post['title'] ?? '',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post['body'] ?? '',
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ],
);
}

void openLink(String? url) async {
if (url == null) return;
final Uri uri = Uri.parse(url);
if (await canLaunchUrl(uri)) {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
} else {
  print("Не удалось открыть ссылку");
}
}
}

