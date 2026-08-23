import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class TeamTicketsScreen extends StatefulWidget {
  const TeamTicketsScreen({super.key});

  @override
  State<TeamTicketsScreen> createState() => _TeamTicketsScreenState();
}

class _TeamTicketsScreenState extends State<TeamTicketsScreen> {
  final urlController = TextEditingController();
  final priceController = TextEditingController();
  List tickets = [];
  bool isLoading = false;
  late int teamId;

  @override
  void initState() {
    super.initState();
    teamId = Get.arguments;
    load();
  }

  Future<void> load() async {
    setState(() => isLoading = true);
    final res = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/get_team_tickets.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'team_id': teamId}),
    );
    final data = jsonDecode(res.body);
    if (data['status'] == 'success') {
      tickets = data['tickets'];
    }
    setState(() => isLoading = false);
  }

  Future<void> addTicket() async {
    final url = urlController.text.trim();
    final price = priceController.text.trim();
    if (url.isEmpty || price.isEmpty) return;
    setState(() => isLoading = true);
    await http.post(
      Uri.parse('https://sportotekaapp.ru/api/add_team_ticket.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'team_id': teamId, 'url': url, 'price': price}),
    );
    urlController.clear();
    priceController.clear();
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Билеты на матчи',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.primary,
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
              child: Column(
                children: [
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: 'Ссылка на билет',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Цена (BYN)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : addTicket,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(Icons.add, color: Colors.white),
                      label: Text(
                        isLoading ? 'Добавление...' : 'Добавить билет',
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
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Доступные билеты',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (tickets.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(
                  child: Text(
                    'Нет доступных билетов',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...tickets.map((ticket) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    onTap: () async {
                      final uri = Uri.tryParse(ticket['url']);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor: colors.primary.withOpacity(0.1),
                      child: Icon(Icons.confirmation_number,
                          color: colors.primary),
                    ),
                    title: Text(
                      'Цена: ${ticket['price']} BYN',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      ticket['url'],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface.withOpacity(0.6),
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: colors.onSurface.withOpacity(0.4)),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
