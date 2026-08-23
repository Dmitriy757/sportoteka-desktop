// lib/presentation/team_screen/team_detail_screen.dart
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';

class TeamDetailScreen extends StatefulWidget {
  final int teamId;
  final String teamName;

  const TeamDetailScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen>
    with TickerProviderStateMixin {
  late final TabController _tab;

  // Data
  List<dynamic> players = [];
  String description = 'Загрузка...';
  List<dynamic> matches = [];
  List<dynamic> tickets = [];

  // ✅ тренерский штаб
  List<dynamic> staff = [];

  // State
  bool loading = true;
  bool err = false;
  String? errMsg;

  final String baseUrl = 'https://sportotekaapp.ru';

  // ✅ API
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getTeamTrainersUrl = "$apiBase/get_team_trainers.php";
  static const String getTrainerProfileUrl = "$apiBase/get_trainer_profile.php";

  // ✅ ЧАТ (direct/private 1:1)
  // ВАЖНО: если у тебя другие названия — просто переименуй endpoints ниже.
  static const String findDirectChatUrl = "$apiBase/find_direct_chat.php";
  static const String createDirectChatUrl = "$apiBase/create_direct_chat.php";

  Color get _bg => const Color(0xFFF3F5F8);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ------------------- DATA -------------------

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      err = false;
      errMsg = null;
    });

    try {
      await Future.wait([
        _fetchPlayers(),
        _fetchDescription(),
        _fetchMatches(),
        _fetchTickets(),
        _fetchStaffByTeam(),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        err = true;
        errMsg = e.toString();
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _fetchPlayers() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/get_players_by_team.php?team_id=${widget.teamId}'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map && data['status'] == 'success') {
          if (mounted) setState(() => players = data['players'] ?? []);
          return;
        }
      }
      if (mounted) setState(() => players = []);
    } catch (_) {
      if (mounted) setState(() => players = []);
    }
  }

  Future<void> _fetchDescription() async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/get_team_description.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'team_id': widget.teamId}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        if (data is Map && data['status'] == 'success') {
          if (mounted) {
            setState(() => description = data['description'] ?? 'Описание недоступно');
          }
          return;
        }
      }
      if (mounted) setState(() => description = 'Описание недоступно');
    } catch (_) {
      if (mounted) setState(() => description = 'Не удалось загрузить описание');
    }
  }

  Future<void> _fetchMatches() async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/get_team_matches.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'team_id': widget.teamId}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        if (data is Map && data['status'] == 'success') {
          if (mounted) setState(() => matches = data['matches'] ?? []);
          return;
        }
      }
      if (mounted) setState(() => matches = []);
    } catch (_) {
      if (mounted) setState(() => matches = []);
    }
  }

  Future<void> _fetchTickets() async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/get_team_tickets.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'team_id': widget.teamId}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        if (data is Map && data['status'] == 'success') {
          if (mounted) setState(() => tickets = data['tickets'] ?? data['data'] ?? []);
          return;
        }
      }
      if (mounted) setState(() => tickets = []);
    } catch (_) {
      if (mounted) setState(() => tickets = []);
    }
  }

  Future<List<Map<String, dynamic>>> _postList(
    String url,
    Map<String, dynamic> body,
    String key,
  ) async {
    final resp = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: jsonEncode(body),
    );

    final data = jsonDecode(resp.body);

    final ok = (data is Map) &&
        (data["status"] == "success" || data["success"] == true);

    if (!ok) {
      final msg =
          (data is Map ? (data["message"] ?? data["error"]) : null) ??
              "Не удалось загрузить данные";
      throw msg;
    }

    if (data is Map) {
      return List<Map<String, dynamic>>.from(data[key] ?? []);
    }
    return [];
  }

  /// ✅ Тренерский штаб по команде
  Future<void> _fetchStaffByTeam() async {
    try {
      final list = await _postList(
        getTeamTrainersUrl,
        {"team_id": widget.teamId},
        "trainers",
      );

      final enriched = await _enrichStaffWithProfiles(list);
      if (mounted) setState(() => staff = enriched);
    } catch (_) {
      if (mounted) setState(() => staff = []);
    }
  }

  /// Обогащаем тренеров данными визитки (position/experience/bio/birthday/email/photo).
  Future<List<Map<String, dynamic>>> _enrichStaffWithProfiles(
    List<Map<String, dynamic>> list,
  ) async {
    if (list.isEmpty) return list;

    Future<Map<String, dynamic>?> loadProfile(int trainerId) async {
      try {
        final resp = await http.post(
          Uri.parse(getTrainerProfileUrl),
          headers: const {"Content-Type": "application/json; charset=utf-8"},
          body: jsonEncode({"trainer_id": trainerId}),
        );
        final data = jsonDecode(resp.body);

        if (data is Map) {
          final ok = (data["status"] == "success" || data["success"] == true);
          final obj = data["trainer"] ?? data["profile"];
          if (ok && obj is Map) {
            return Map<String, dynamic>.from(obj);
          }
        }
      } catch (_) {}
      return null;
    }

    const int chunk = 6;
    final out = <Map<String, dynamic>>[];

    for (int i = 0; i < list.length; i += chunk) {
      final part = list.skip(i).take(chunk).toList();

      final futures = part.map((t) async {
        final m = Map<String, dynamic>.from(t);

        final tid = _pickTrainerId(m);
        final hasPosition =
            _s(m["position"]).isNotEmpty || _s(m["role_title"]).isNotEmpty;

        if (tid > 0 && !hasPosition) {
          final prof = await loadProfile(tid);
          if (prof != null) {
            if (_s(m["position"]).isEmpty) m["position"] = prof["position"];
            if (_s(m["birthday"]).isEmpty) m["birthday"] = prof["birthday"];
            if (_s(m["experience"]).isEmpty) m["experience"] = prof["experience"];
            if (_s(m["bio"]).isEmpty) m["bio"] = prof["bio"];
            if (_s(m["photo"]).isEmpty) m["photo"] = prof["photo"];
            if (_s(m["photo_url"]).isEmpty) m["photo_url"] = prof["photo_url"];
            if (_s(m["email"]).isEmpty) m["email"] = prof["email"];
            // На всякий случай: user_id тренера (если сервер отдаёт)
            if (_s(m["user_id"]).isEmpty && _s(prof["user_id"]).isNotEmpty) {
              m["user_id"] = prof["user_id"];
            }
          }
        }

        return m;
      }).toList();

      out.addAll(await Future.wait(futures));
    }

    // сортировка по ФИО
    out.sort((a, b) {
      final al = _s(a["last_name"]).toLowerCase();
      final af = _s(a["first_name"]).toLowerCase();
      final bl = _s(b["last_name"]).toLowerCase();
      final bf = _s(b["first_name"]).toLowerCase();
      final c1 = al.compareTo(bl);
      if (c1 != 0) return c1;
      return af.compareTo(bf);
    });

    return out;
  }

  // ------------------- HELPERS -------------------

  String _s(dynamic v) => (v ?? '').toString().trim();

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return int.tryParse(v.toString()) ?? 0;
  }

  /// ✅ Супер-устойчиво достаем trainerId из любого ответа API
  int _pickTrainerId(Map<String, dynamic> t) {
    final candidates = [
      t["trainer_id"],
      t["trainerId"],
      t["id"],
      t["user_id"],
      t["uid"],
      t["trainer_user_id"],
      t["trainer_profile_id"],
    ];

    for (final c in candidates) {
      final v = _asInt(c);
      if (v > 0) return v;
    }
    return 0;
  }

  /// ✅ Текущий userId (исправляет твою ошибку Object -> int)
  int _currentUserId() {
    try {
      final dynamic v = PrefUtils.getUserId();
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return int.tryParse(v.toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String _fio(Map<String, dynamic> x) {
    final last = _s(x["last_name"]);
    final first = _s(x["first_name"]);
    final middle = _s(x["middle_name"]);
    final fio = [last, first, middle].where((e) => e.isNotEmpty).join(" ");
    return fio.isEmpty ? _s(x["name"]) : fio;
  }

  String _fullUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    if (v.startsWith('http')) return v;
    if (v.startsWith('/')) return '$baseUrl$v';
    return '$baseUrl/$v';
  }

  Widget _netImage(String? url, {IconData fallback = Icons.person}) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return Icon(fallback, color: const Color(0xFF94A3B8));
    return Image.network(
      _fullUrl(u),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Icon(fallback, color: const Color(0xFF94A3B8)),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }

  void _openPlayerProfile(Map<String, dynamic> player) {
    int? extractId(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return int.tryParse(v.toString());
    }

    final int? userId =
        extractId(player['user_id']) ??
        extractId(player['id']) ??
        extractId(player['player_id']);

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

  Widget _empty(String text, {IconData icon = Icons.info_outline}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Попробуйте обновить данные',
              style: TextStyle(color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadAll, child: const Text('Обновить')),
          ],
        ),
      ),
    );
  }

  // ------------------- CHAT (1:1 private) -------------------

  Future<Map<String, dynamic>?> _safeJson(http.Response res) async {
    try {
      final raw = res.body.trimLeft();
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Открыть/создать приватный чат (1:1) с тренером и перейти в ChatRoomScreen
  Future<void> _openChatWithTrainer({
    required int trainerUserId,
    required String trainerName,
  }) async {
    final me = _currentUserId();
    if (me <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выполните вход')),
      );
      return;
    }
    if (trainerUserId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить ID тренера')),
      );
      return;
    }

    try {
      // 1) пробуем найти уже существующий direct chat
      final findUri = Uri.parse(
        '$findDirectChatUrl?user_id=$me&other_id=$trainerUserId',
      );
      final findRes = await http.get(findUri, headers: {'Accept': 'application/json'});
      final findData = await _safeJson(findRes);

      int chatId = 0;
      String chatName = 'Чат';

      if (findRes.statusCode == 200 &&
          findData != null &&
          (findData['success'] == true || findData['status'] == 'success')) {
        final obj = (findData['chat'] ?? findData['data']) ?? findData;
        if (obj is Map) {
          chatId = _asInt(obj['id'] ?? obj['chat_id']);
          chatName = (obj['name'] ?? 'Чат с $trainerName').toString();
        }
      }

      // 2) если не нашли — создаём
      if (chatId <= 0) {
        final createRes = await http.post(
          Uri.parse(createDirectChatUrl),
          headers: {'Accept': 'application/json'},
          body: {
            'user_id': me.toString(),
            'other_id': trainerUserId.toString(),
            'name': 'Чат с $trainerName',
            'is_private': '1',
          },
        );

        final createData = await _safeJson(createRes);

        if (createRes.statusCode == 200 &&
            createData != null &&
            (createData['success'] == true || createData['status'] == 'success')) {
          chatId = _asInt(createData['chat_id'] ?? createData['id'] ?? (createData['chat']?['id']));
          chatName = (createData['name'] ??
                  createData['chat_name'] ??
                  (createData['chat']?['name']) ??
                  'Чат с $trainerName')
              .toString();
        } else {
          final errText = (createData?['error'] ?? createData?['message'] ?? '').toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errText.isNotEmpty
                    ? 'Не удалось создать чат: $errText'
                    : 'Не удалось создать чат (HTTP ${createRes.statusCode})',
              ),
            ),
          );
          return;
        }
      }

      // 3) открываем комнату
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            chatId: chatId,
            userId: me,
            chatName: chatName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка чата: $e')),
      );
    }
  }

  // ------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    final bg = _bg;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.teamName,
          style: const TextStyle(fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _tabsHeader(bg)),
            SliverToBoxAdapter(child: const SizedBox(height: 8)),
            if (loading) ...[
              SliverToBoxAdapter(child: _skeleton()),
            ] else if (err) ...[
              SliverFillRemaining(hasScrollBody: false, child: _errorView()),
            ] else ...[
              SliverFillRemaining(
                hasScrollBody: true,
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _tabPlayers(),
                    _tabDescription(),
                    _tabMatches(),
                    _tabTickets(),
                    _tabStaff(), // ✅ штаб
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tabsHeader(Color bg) {
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: _MatteSurface(
        padding: const EdgeInsets.all(6),
        child: TabBar(
          controller: _tab,
          isScrollable: true,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF93C5FD)),
          ),
          labelColor: const Color(0xFF1D4ED8),
          unselectedLabelColor: const Color(0xFF334155),
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          tabs: const [
            _MatteTab(icon: Icons.people_outline, text: "Состав"),
            _MatteTab(icon: Icons.info_outline, text: "Описание"),
            _MatteTab(icon: Icons.event_outlined, text: "Матчи"),
            _MatteTab(icon: Icons.confirmation_number_outlined, text: "Билеты"),
            _MatteTab(icon: Icons.groups_2_outlined, text: "Тренерский штаб"),
          ],
        ),
      ),
    );
  }

  // ------------------- TABS -------------------

  Widget _tabPlayers() {
    if (players.isEmpty) {
      return _empty("Нет данных о составе", icon: Icons.people_outline);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: players.length,
      itemBuilder: (_, i) {
        final p = Map<String, dynamic>.from(players[i]);
        final fullName = '${_s(p['first_name'])} ${_s(p['last_name'])}'.trim();
        final pos = _s(p['position']);
        final num = _s(p['number']);
        final subtitle = [
          if (pos.isNotEmpty) pos,
          if (num.isNotEmpty) '№$num',
        ].join(' • ');

        final photo =
            _s(p['photo_url']).isNotEmpty ? _s(p['photo_url']) : _s(p['photo']);

        return _MatteSurface(
          onTap: () => _openPlayerProfile(p),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  color: const Color(0xFFF8FAFC),
                  child: _netImage(photo),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'Без имени' : fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        );
      },
    );
  }

  Widget _tabDescription() {
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _MatteSurface(
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Icon(Icons.info_outline, color: primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Описание команды",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _MatteSurface(
          padding: const EdgeInsets.all(14),
          child: Text(
            description,
            style: const TextStyle(fontSize: 15, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _tabMatches() {
    if (matches.isEmpty) {
      return _empty("Нет данных о матчах", icon: Icons.sports_soccer);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: matches.length,
      itemBuilder: (_, i) {
        final m = Map<String, dynamic>.from(matches[i]);
        final opp = _s(m['opponent']).isEmpty ? 'Соперник неизвестен' : _s(m['opponent']);
        final date = _s(m['date']);
        final loc = _s(m['location']);

        return _MatteSurface(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: const Icon(Icons.sports_soccer_rounded, color: Color(0xFF1D4ED8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opp,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [if (date.isNotEmpty) date, if (loc.isNotEmpty) loc].join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabTickets() {
    if (tickets.isEmpty) {
      return _empty("Билеты не найдены", icon: Icons.confirmation_number_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: tickets.length,
      itemBuilder: (_, i) {
        final t = Map<String, dynamic>.from(tickets[i]);
        final title = _s(t['title']).isEmpty ? 'Билет' : _s(t['title']);
        final price = _s(t['price']);
        final link = _s(t['link']);

        return _MatteSurface(
          onTap: link.isEmpty
              ? null
              : () async {
                  final uri = Uri.tryParse(link);
                  if (uri == null) return;
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Icon(Icons.confirmation_number_outlined, color: Color(0xFF0EA5E9)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (price.isNotEmpty) 'Цена: $price',
                        if (link.isNotEmpty) 'Открыть ссылку',
                      ].join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (link.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(Icons.open_in_new_rounded, color: Color(0xFF94A3B8)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// ✅ Тренерский штаб + кнопка "Написать" (в чат) + визитка + профиль
  Widget _tabStaff() {
    if (staff.isEmpty) {
      return _empty("Тренеры команды не назначены.", icon: Icons.groups_2_outlined);
    }

    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: staff.map((raw) {
        final t = Map<String, dynamic>.from(raw);
        final fio = _fio(t);

        final photo = _s(t["photo_url"]).isNotEmpty ? _s(t["photo_url"]) : _s(t["photo"]);

        final position = _s(t["position"]);
        final roleTitle = _s(t["role_title"]);
        final subtitle = position.isNotEmpty
            ? position
            : (roleTitle.isNotEmpty ? roleTitle : "Тренер");

        final trainerId = _pickTrainerId(t);
        final trainerName = fio.isNotEmpty ? fio : "Тренер #$trainerId";

        return _MatteSurface(
          onTap: () {
            if (trainerId <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Не найден trainer_id. Ключи: ${t.keys.toList()}")),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TrainerProfileViewScreen(
                  trainerId: trainerId,
                  trainerName: trainerName,
                  trainerPhotoRaw: (t["photo_url"] ?? t["photo"])?.toString(),
                  trainerEmailRaw: (t["email"])?.toString(),
                  onOpenChat: () => _openChatWithTrainer(
                    trainerUserId: trainerId,
                    trainerName: trainerName,
                  ),
                ),
              ),
            );
          },
          child: Row(
            children: [
              _MatteAvatarSquare(
                name: trainerName,
                photoUrl: photo,
                primary: primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Написать",
                onPressed: () => _openChatWithTrainer(
                  trainerUserId: trainerId,
                  trainerName: trainerName,
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0EA5E9)),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ------------------- STATES -------------------

  Widget _skeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: List.generate(
          6,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MatteSurface(
              child: Row(
                children: const [
                  _MatteLogoBadge(logo: '', fallbackIcon: Icons.shield_rounded),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _SkeletonLine(widthFactor: 1.0),
                        SizedBox(height: 8),
                        _SkeletonLine(widthFactor: 0.6),
                        SizedBox(height: 6),
                        _SkeletonLine(widthFactor: 0.4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('Ошибка загрузки',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              errMsg ?? 'Попробуйте ещё раз',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadAll, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

// ===================== MATTE UI ATOMS =====================

class _MatteSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const _MatteSurface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }
}

class _MatteLogoBadge extends StatelessWidget {
  final String logo;
  final IconData fallbackIcon;
  final double size;

  const _MatteLogoBadge({
    required this.logo,
    required this.fallbackIcon,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: logo.isNotEmpty
          ? Image.network(
              logo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: const Color(0xFF0EA5E9)),
            )
          : Icon(fallbackIcon, color: const Color(0xFF0EA5E9)),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  const _SkeletonLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _MatteTab extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MatteTab({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _MatteAvatarSquare extends StatelessWidget {
  final String name;
  final String photoUrl;
  final Color primary;

  const _MatteAvatarSquare({
    required this.name,
    required this.photoUrl,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final u = photoUrl.trim();
    final letter = (name.isNotEmpty ? name.substring(0, 1) : "Т").toUpperCase();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: (u.isNotEmpty && (u.startsWith("http") || u.startsWith("/")))
          ? Image.network(
              u.startsWith("http") ? u : "https://sportotekaapp.ru$u",
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(letter),
            )
          : _fallback(letter),
    );
  }

  Widget _fallback(String letter) {
    return Container(
      color: primary.withOpacity(0.10),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: primary,
        ),
      ),
    );
  }
}

// ======================================================
// ✅ ВИЗИТКА ТРЕНЕРА: кнопка "Написать" -> ЧАТ, + "Профиль"
// ======================================================

class TrainerProfileViewScreen extends StatefulWidget {
  final int trainerId;
  final String trainerName;
  final String? trainerPhotoRaw;
  final String? trainerEmailRaw;

  /// ✅ 콜бэк “Открыть чат” (передаём из TeamDetailScreen)
  final VoidCallback onOpenChat;

  const TrainerProfileViewScreen({
    super.key,
    required this.trainerId,
    required this.trainerName,
    this.trainerPhotoRaw,
    this.trainerEmailRaw,
    required this.onOpenChat,
  });

  @override
  State<TrainerProfileViewScreen> createState() => _TrainerProfileViewScreenState();
}

class _TrainerProfileViewScreenState extends State<TrainerProfileViewScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getUrl = "$apiBase/get_trainer_profile.php";

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _profile = {};

  String _s(dynamic v) => (v ?? "").toString().trim();

  Map<String, dynamic> _decode(String s) {
    try {
      final j = jsonDecode(s);
      return (j is Map) ? Map<String, dynamic>.from(j) : {};
    } catch (_) {
      return {};
    }
  }

  String? _normalizeImage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    String url = raw.trim();

    if (url.startsWith("http://") || url.startsWith("https://")) return url;
    if (url.startsWith("//")) return "https:$url";
    if (url.startsWith("sportotekaapp.ru/")) return "https://$url";
    if (url.startsWith("www.sportotekaapp.ru/")) return "https://$url";
    if (url.startsWith("/")) return "https://sportotekaapp.ru$url";
    if (url.startsWith("uploads/")) return "https://sportotekaapp.ru/$url";

    return "https://sportotekaapp.ru/uploads/$url";
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http.post(
        Uri.parse(getUrl),
        headers: const {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode({"trainer_id": widget.trainerId}),
      );

      final data = _decode(resp.body);

      final ok = data["status"] == "success" || data["success"] == true;
      final obj = data["trainer"] ?? data["profile"];

      if (ok && obj is Map) {
        _profile = Map<String, dynamic>.from(obj);
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _isLoading = false;
          _error = _s(data["message"]).isEmpty
              ? "Не удалось загрузить"
              : _s(data["message"]);
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Ошибка загрузки: $e";
      });
    }
  }

  void _openTrainerProfile() {
    // ✅ Переход в профиль пользователя тренера
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyProfileScreen(userId: widget.trainerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = _normalizeImage(
      _s(_profile["photo_url"]).isNotEmpty
          ? _s(_profile["photo_url"])
          : (_s(_profile["photo"]).isNotEmpty
              ? _s(_profile["photo"])
              : (widget.trainerPhotoRaw ?? "")),
    );

    final email = _s(_profile["email"]).isNotEmpty
        ? _s(_profile["email"])
        : _s(widget.trainerEmailRaw);

    final position = _s(_profile["position"]);
    final bio = _s(_profile["bio"]);
    final birthdayRaw = _s(_profile["birthday"]);
    final birthday =
        birthdayRaw.length >= 10 ? birthdayRaw.substring(0, 10) : birthdayRaw;
    final experience = _s(_profile["experience"]);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => Get.back(),
        ),
        title: const Text(
          "Визитка тренера",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryGreen),
            onPressed: _loadProfile,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _TrainerErrorState(error: _error!, onRetry: _loadProfile)
              : RefreshIndicator(
                  color: AppColors.primaryGreen,
                  backgroundColor: AppColors.background,
                  onRefresh: () async => _loadProfile(),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: _TrainerProfileCardView(
                            name: widget.trainerName.isEmpty
                                ? "Тренер #${widget.trainerId}"
                                : widget.trainerName,
                            email: email,
                            photo: photo,
                            position: position,
                            trainerId: widget.trainerId,
                            onWrite: widget.onOpenChat, // ✅ В ЧАТ
                            onOpenProfile: _openTrainerProfile,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (birthday.isNotEmpty)
                              _TrainerInfoCard(
                                icon: Icons.cake_rounded,
                                title: "Дата рождения",
                                content: birthday,
                              ),
                            if (birthday.isNotEmpty) const SizedBox(height: 12),
                            if (experience.isNotEmpty)
                              _TrainerInfoCard(
                                icon: Icons.work_history_rounded,
                                title: "Опыт / карьера",
                                content: experience,
                              ),
                            if (experience.isNotEmpty) const SizedBox(height: 12),
                            if (bio.isNotEmpty)
                              _TrainerInfoCard(
                                icon: Icons.description_rounded,
                                title: "О тренере",
                                content: bio,
                              ),
                            if (birthday.isEmpty && experience.isEmpty && bio.isEmpty)
                              const _TrainerEmptyInfoHint(),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _TrainerProfileCardView extends StatelessWidget {
  final String name;
  final String email;
  final String? photo;
  final String position;
  final int trainerId;

  final VoidCallback onWrite; // ✅ чат
  final VoidCallback onOpenProfile;

  const _TrainerProfileCardView({
    required this.name,
    required this.email,
    required this.photo,
    required this.position,
    required this.trainerId,
    required this.onWrite,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _TrainerCircleNetworkImage(
            imageUrl: photo,
            size: 104,
            borderColor: AppColors.primaryGreen.withOpacity(0.25),
            borderWidth: 2,
            glow: AppColors.primaryGreen.withOpacity(0.20),
            fallback: Container(
              color: AppColors.primaryGreen.withOpacity(0.10),
              child: Icon(
                Icons.person_outline_rounded,
                color: AppColors.primaryGreen,
                size: 52,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (email.isNotEmpty)
            Text(
              email,
              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            )
          else
            Text(
              "ID: $trainerId",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.9),
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: 14),
          if (position.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                position,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryGreen,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                "Должность не указана",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onWrite, // ✅ чат
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text("Написать", style: TextStyle(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenProfile,
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
                  label: const Text("Профиль", style: TextStyle(fontWeight: FontWeight.w900)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: BorderSide(color: AppColors.primaryGreen.withOpacity(0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainerInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _TrainerInfoCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerCircleNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double borderWidth;
  final Color borderColor;
  final Color? glow;
  final Widget fallback;

  const _TrainerCircleNetworkImage({
    required this.imageUrl,
    required this.size,
    required this.borderWidth,
    required this.borderColor,
    required this.fallback,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        boxShadow: glow != null
            ? [
                BoxShadow(
                  color: glow!,
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: (imageUrl == null || imageUrl!.isEmpty)
            ? fallback
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (context, _) => const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, _, __) => fallback,
              ),
      ),
    );
  }
}

class _TrainerEmptyInfoHint extends StatelessWidget {
  const _TrainerEmptyInfoHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.textSecondary.withOpacity(0.7)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Информация о тренере пока не заполнена.",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _TrainerErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text("Повторить"),
            ),
          ],
        ),
      ),
    );
  }
}
