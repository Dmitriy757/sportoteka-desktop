// lib/presentation/school_detail_screen/school_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// как в чате (переход в профиль пользователя)
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';

class SchoolDetailScreen extends StatefulWidget {
  final int schoolId;
  final String name;

  const SchoolDetailScreen({
    super.key,
    required this.schoolId,
    required this.name,
  });

  @override
  State<SchoolDetailScreen> createState() => _SchoolDetailScreenState();
}

class _SchoolDetailScreenState extends State<SchoolDetailScreen>
    with TickerProviderStateMixin {
  final String baseUrl = 'https://sportotekaapp.ru';

  late TabController _tabController;

  // Профиль школы
  Map<String, dynamic>? school;
  // Ученики
  List<dynamic> students = [];
  // События
  List<dynamic> events = [];
  // Площадки
  List<dynamic> venues = [];
  // Руководство
  List<dynamic> management = [];

  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      await Future.wait([
        _fetchSchoolProfile(),
        _fetchStudents(),
        _fetchEvents(),
        _fetchVenues(),
        _fetchManagement(),
      ]);
    } catch (e) {
      errorMessage = 'Не удалось загрузить некоторые данные';
      debugPrint('SchoolDetail fetchAll error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchSchoolProfile() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/api/get_school_detail.php?id=${widget.schoolId}'),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        setState(() => school = data is Map<String, dynamic> ? data : {});
      } else {
        setState(() => school = {});
      }
    } catch (e) {
      debugPrint('fetchSchoolProfile error: $e');
      setState(() => school = {});
    }
  }

  Future<void> _fetchStudents() async {
    try {
      // поддержка разных эндпойнтов / корпусов ответа
      final uriCandidates = <Uri>[
        Uri.parse('$baseUrl/api/get_students_by_school.php?school_id=${widget.schoolId}'),
        Uri.parse('$baseUrl/api/get_school_students.php?school_id=${widget.schoolId}'),
      ];

      http.Response? resp;
      for (final u in uriCandidates) {
        resp = await http.get(u);
        if (resp.statusCode == 200 && (resp.body.isNotEmpty)) break;
      }
      if (resp == null) throw Exception('No students response');

      final map = json.decode(utf8.decode(resp.bodyBytes));
      final list = map['students'] ?? map['pupils'] ?? map['data'] ?? [];
      if (list is List) {
        setState(() => students = list);
      } else {
        setState(() => students = []);
      }
    } catch (e) {
      debugPrint('fetchStudents error: $e');
      setState(() => students = []);
    }
  }

  Future<void> _fetchEvents() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/api/get_school_events.php?school_id=${widget.schoolId}'),
      );
      if (resp.statusCode == 200) {
        final map = json.decode(utf8.decode(resp.bodyBytes));
        final list = map['events'] ?? map['activities'] ?? map['data'] ?? [];
        setState(() => events = list is List ? list : []);
      } else {
        setState(() => events = []);
      }
    } catch (e) {
      debugPrint('fetchEvents error: $e');
      setState(() => events = []);
    }
  }

  Future<void> _fetchVenues() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/api/get_school_venues.php?school_id=${widget.schoolId}'),
      );
      if (resp.statusCode == 200) {
        final map = json.decode(utf8.decode(resp.bodyBytes));
        final list = map['venues'] ?? map['grounds'] ?? map['data'] ?? [];
        setState(() => venues = list is List ? list : []);
      } else {
        setState(() => venues = []);
      }
    } catch (e) {
      debugPrint('fetchVenues error: $e');
      setState(() => venues = []);
    }
  }

  Future<void> _fetchManagement() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/api/get_school_management.php?school_id=${widget.schoolId}'),
      );
      if (resp.statusCode == 200) {
        final map = json.decode(utf8.decode(resp.bodyBytes));
        final list = map['management'] ?? map['managers'] ?? map['data'] ?? [];
        setState(() => management = list is List ? list : []);
      } else {
        setState(() => management = []);
      }
    } catch (e) {
      debugPrint('fetchManagement error: $e');
      setState(() => management = []);
    }
  }

  // ========= Helpers =========
  Widget _netImage(String? url, {BoxFit fit = BoxFit.cover}) {
    if (url == null || url.isEmpty) {
      return const ColoredBox(color: Color(0xFFEAEFF6));
    }
    final full = url.startsWith('http') ? url : '$baseUrl$url';
    return Image.network(
      full,
      fit: fit,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFEAEFF6)),
      loadingBuilder: (context, child, lp) {
        if (lp == null) return child;
        return const Center(child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ));
      },
    );
  }

  void _openUserProfile(dynamic item) {
    int? parseId(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    final userId = parseId(item['user_id']) ??
        parseId(item['id']) ??
        parseId(item['student_id']);

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль пользователя недоступен')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyProfileScreen(userId: userId)),
    );
  }

  Future<void> _openLink(String? link) async {
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ========= Tabs content =========

  Widget _tabProfile() {
    final name = school?['name'] ?? widget.name;
    final address = school?['address'] ?? school?['location'] ?? 'Адрес не указан';
    final description = school?['description'] ?? 'Описание отсутствует';
    final phone = school?['phone'];
    final email = school?['email'];
    final site = school?['site'] ?? school?['website'];
    final banner = school?['banner'] ?? school?['image'] ?? school?['cover'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Баннер
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 180,
            child: _netImage(banner, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF005AAB),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(child: Text(address, style: const TextStyle(fontSize: 16))),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Описание',
          style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF005AAB)),
        ),
        const SizedBox(height: 8),
        Text(description, style: const TextStyle(fontSize: 16)),

        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (phone != null && phone.toString().isNotEmpty)
              _contactChip(
                icon: Icons.phone,
                label: phone.toString(),
                onTap: () => _openLink('tel:$phone'),
              ),
            if (email != null && email.toString().isNotEmpty)
              _contactChip(
                icon: Icons.email,
                label: email.toString(),
                onTap: () => _openLink('mailto:$email'),
              ),
            if (site != null && site.toString().isNotEmpty)
              _contactChip(
                icon: Icons.language,
                label: Uri.tryParse(site.toString())?.host ?? 'Сайт',
                onTap: () => _openLink(site.toString()),
              ),
          ],
        ),
      ],
    );
  }

  Widget _contactChip({required IconData icon, required String label, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F7FF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE0ECFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1E74C4)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Color(0xFF1E74C4))),
          ],
        ),
      ),
    );
  }

  Widget _tabStudents() {
    if (students.isEmpty) {
      return _emptyState(
        icon: Icons.school_outlined,
        title: 'Ученики не найдены',
        subtitle: 'Добавьте учеников в школе, чтобы увидеть их здесь.',
        action: _fetchStudents,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final s = Map<String, dynamic>.from(students[i]);
        final first = (s['first_name'] ?? s['name'] ?? '').toString();
        final last = (s['last_name'] ?? s['surname'] ?? '').toString();
        final fullName = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
        final photo = s['photo'] ?? s['avatar'];

        final details = <String>[];
        if ((s['sport'] ?? '').toString().isNotEmpty) details.add(s['sport'].toString());
        if ((s['class'] ?? '').toString().isNotEmpty) details.add('Класс: ${s['class']}');
        if ((s['age'] ?? '').toString().isNotEmpty) details.add('Возраст: ${s['age']}');

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFEAF2FF),
              child: ClipOval(
                child: SizedBox(width: 52, height: 52, child: _netImage(photo)),
              ),
            ),
            title: Text(fullName.isEmpty ? 'Без имени' : fullName),
            subtitle: details.isEmpty ? null : Text(details.join(' • ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openUserProfile(s),
          ),
        );
      },
    );
  }

  Widget _tabEvents() {
    if (events.isEmpty) {
      return _emptyState(
        icon: Icons.event_outlined,
        title: 'Событий нет',
        subtitle: 'Когда появятся события, они отобразятся здесь.',
        action: _fetchEvents,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (_, i) {
        final e = Map<String, dynamic>.from(events[i]);
        final title = e['title'] ?? 'Событие';
        final date = e['date'] ?? e['datetime'] ?? '';
        final place = e['location'] ?? e['place'] ?? '';
        final link = e['link'] ?? e['url'];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.event, size: 36),
            title: Text(title.toString()),
            subtitle: Text([date, place].where((x) => x.toString().isNotEmpty).join(' • ')),
            trailing: link != null ? const Icon(Icons.open_in_new) : null,
            onTap: link != null ? () => _openLink(link.toString()) : null,
          ),
        );
      },
    );
  }

  Widget _tabVenues() {
    if (venues.isEmpty) {
      return _emptyState(
        icon: Icons.sports_soccer_outlined,
        title: 'Площадки не найдены',
        subtitle: 'Добавьте площадки школы, чтобы видеть их здесь.',
        action: _fetchVenues,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: venues.length,
      itemBuilder: (_, i) {
        final v = Map<String, dynamic>.from(venues[i]);
        final title = v['title'] ?? v['name'] ?? 'Площадка';
        final address = v['address'] ?? v['location'] ?? '';
        final photo = v['photo'] ?? v['image'];
        final link = v['link'] ?? v['url'];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (photo != null && photo.toString().isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: _netImage(photo, fit: BoxFit.cover),
                  ),
                ),
              ListTile(
                title: Text(title.toString()),
                subtitle: address.toString().isEmpty ? null : Text(address.toString()),
                trailing: link != null ? const Icon(Icons.open_in_new) : null,
                onTap: link != null ? () => _openLink(link.toString()) : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabManagement() {
    if (management.isEmpty) {
      return _emptyState(
        icon: Icons.manage_accounts_outlined,
        title: 'Нет данных о руководстве',
        subtitle: 'Когда данные появятся, вы увидите их здесь.',
        action: _fetchManagement,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: management.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final m = Map<String, dynamic>.from(management[i]);
        final name = m['name'] ?? 'Неизвестно';
        final pos = m['position'] ?? 'Должность не указана';
        final photo = m['photo'];
        final desc = m['description'];

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: _netImage(photo),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(pos.toString(), style: TextStyle(color: Colors.grey[600])),
                      if (desc != null && desc.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          desc.toString(),
                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(onPressed: action, child: const Text('Обновить')),
            ],
          ],
        ),
      ),
    );
  }

  // ========= UI =========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Профиль'),
            Tab(icon: Icon(Icons.group), text: 'Ученики'),
            Tab(icon: Icon(Icons.event), text: 'События'),
            Tab(icon: Icon(Icons.place), text: 'Площадки'),
            Tab(icon: Icon(Icons.manage_accounts), text: 'Руководство'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _tabProfile(),
                    _tabStudents(),
                    _tabEvents(),
                    _tabVenues(),
                    _tabManagement(),
                  ],
                ),
    );
  }
}
