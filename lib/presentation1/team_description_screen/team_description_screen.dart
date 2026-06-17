import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class TeamDescriptionScreen extends StatefulWidget {
  const TeamDescriptionScreen({super.key});

  @override
  State<TeamDescriptionScreen> createState() => _TeamDescriptionScreenState();
}

class _TeamDescriptionScreenState extends State<TeamDescriptionScreen> {
  final TextEditingController _controller = TextEditingController();
  bool isLoading = false;
  int? teamId;

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    if (arg == null || !(arg is int) || arg == 0) {
      Get.snackbar('Ошибка', 'Идентификатор команды не передан');
      Get.back();
      return;
    }
    teamId = arg;
    fetch();
  }

  Future<void> fetch() async {
    if (teamId == null) return;
    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/get_team_description.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'team_id': teamId}),
      );
      final data = jsonDecode(res.body);
      if (data['status'] == 'success') {
        _controller.text = data['description'] ?? '';
      }
    } catch (_) {}
    setState(() => isLoading = false);
  }

  Future<void> save() async {
    if (teamId == null) return;
    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/save_team_description.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'team_id': teamId, 'description': _controller.text}),
      );
      final data = jsonDecode(res.body);
      if (data['status'] == 'success') {
        Get.snackbar('Успех', 'Описание сохранено');
      } else {
        Get.snackbar('Ошибка', data['message'] ?? 'Не удалось сохранить');
      }
    } catch (_) {
      Get.snackbar('Ошибка', 'Ошибка подключения');
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Описание команды',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.primary,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                maxLines: 6,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  labelText: 'Описание',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: colors.surfaceVariant.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  isLoading ? 'Сохранение...' : 'Сохранить',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isLoading ? null : save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
