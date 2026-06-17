import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final nameController = TextEditingController();
  final roleController = TextEditingController();
  List managers = [];
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
      Uri.parse('https://sportotekaapp.ru/api/get_team_management.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'team_id': teamId}),
    );
    final data = jsonDecode(res.body);
    if (data['status'] == 'success') {
      setState(() => managers = data['managers']);
    }
    setState(() => isLoading = false);
  }

  Future<void> addManager() async {
    final name = nameController.text.trim();
    final role = roleController.text.trim();
    if (name.isEmpty || role.isEmpty) return;

    setState(() => isLoading = true);
    await http.post(
      Uri.parse('https://sportotekaapp.ru/api/add_team_manager.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'team_id': teamId, 'name': name, 'role': role}),
    );
    nameController.clear();
    roleController.clear();
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
          'Руководство команды',
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
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Container(
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
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'ФИО',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: roleController,
                        decoration: InputDecoration(
                          labelText: 'Должность',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: addManager,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: Text(
                          'Добавить руководителя',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Текущее руководство',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (managers.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Нет данных о руководстве',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: managers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final manager = managers[index];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        onTap: () {},
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: colors.primary.withOpacity(0.1),
                          child: Icon(Icons.person, color: colors.primary),
                        ),
                        title: Text(
                          manager['name'],
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          manager['role'],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface.withOpacity(0.6),
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right,
                            color: colors.onSurface.withOpacity(0.4)),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
