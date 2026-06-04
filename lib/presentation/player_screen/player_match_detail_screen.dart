import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:sportoteka/presentation/team_video_analysis/match_video_player_screen.dart';

class PlayerMatchDetailScreen extends StatefulWidget {
  final int matchId;
  final int playerId;
  final String playerName;
  final String? opponent;
  final String? tournament;
  final String? score;
  final String? matchDate;
  final String? videoUrl;

  const PlayerMatchDetailScreen({
    super.key,
    required this.matchId,
    required this.playerId,
    required this.playerName,
    this.opponent,
    this.tournament,
    this.score,
    this.matchDate,
    this.videoUrl,
  });

  @override
  State<PlayerMatchDetailScreen> createState() => _PlayerMatchDetailScreenState();
}

class _PlayerMatchDetailScreenState extends State<PlayerMatchDetailScreen> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';

  bool isLoading = true;
  String? error;

  List<Map<String, dynamic>> players = [];
  List<Map<String, dynamic>> episodes = [];
  List<Map<String, dynamic>> mainReport = [];
  List<Map<String, dynamic>> passReport = [];
  List<Map<String, dynamic>> goalkeeperReport = [];
  List<Map<String, dynamic>> playerVideoTotals = [];

  Map<String, dynamic>? selectedPlayerMain;
  Map<String, dynamic>? selectedPlayerPass;
  Map<String, dynamic>? selectedPlayerGoalkeeper;
  Map<String, dynamic>? selectedPlayerTotals;
  List<Map<String, dynamic>> selectedPlayerEpisodes = [];

  int _asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
  String _asStr(dynamic v) => (v ?? '').toString();

  @override
  void initState() {
    super.initState();
    _loadMatchDetail();
  }

  String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return 'https://sportotekaapp.ru${s.startsWith('/') ? s : '/$s'}';
  }

  void _watchVideo() {
    final normalized = _normalizeUrl(widget.videoUrl) ?? '';
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Видео отсутствует')),
      );
      return;
    }

    Get.to(
      () => MatchVideoPlayerScreen(
        videoUrl: normalized,
        title: 'Матч — ${widget.playerName}',
      ),
    );
  }

  Future<void> _loadMatchDetail() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final uri = Uri.parse('$_apiBase/get_match_ttd_report.php?match_id=${widget.matchId}');
      final res = await http.get(uri).timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        throw 'Ошибка сервера: ${res.statusCode}';
      }

      final body = res.body.trim();
      if (body.isEmpty) throw 'Сервер вернул пустой ответ';

      final data = jsonDecode(body);
      if (data is! Map || data['success'] != true) {
        throw (data is Map
                ? (data['message'] ?? 'Ошибка загрузки отчёта')
                : 'Ошибка загрузки отчёта')
            .toString();
      }

      players = ((data['players'] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      episodes = ((data['episodes'] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      mainReport = ((data['main_report'] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      passReport = ((data['pass_report'] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      goalkeeperReport = ((data['goalkeeper_report'] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      playerVideoTotals = ((data['player_video_totals'] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      _bindSelectedPlayerData();

      if (!mounted) return;
      setState(() => isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }

  void _bindSelectedPlayerData() {
    selectedPlayerMain = null;
    selectedPlayerPass = null;
    selectedPlayerGoalkeeper = null;
    selectedPlayerTotals = null;
    selectedPlayerEpisodes = [];

    for (final row in mainReport) {
      if (_asInt(row['player_id']) == widget.playerId) {
        selectedPlayerMain = row;
        break;
      }
    }

    for (final row in passReport) {
      if (_asInt(row['player_id']) == widget.playerId) {
        selectedPlayerPass = row;
        break;
      }
    }

    for (final row in goalkeeperReport) {
      if (_asInt(row['player_id']) == widget.playerId) {
        selectedPlayerGoalkeeper = row;
        break;
      }
    }

    for (final row in playerVideoTotals) {
      if (_asInt(row['player_id']) == widget.playerId) {
        selectedPlayerTotals = row;
        break;
      }
    }

    selectedPlayerEpisodes = episodes.where((e) {
      final pid = _asInt(e['player_id']);
      final playerMap = e['player'];
      final nestedPlayerId = playerMap is Map ? _asInt(playerMap['id']) : 0;
      return pid == widget.playerId || nestedPlayerId == widget.playerId;
    }).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String _prettyDate(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '-';
    final d = DateTime.tryParse(s.replaceAll(' ', 'T'));
    if (d == null) return s;
    return DateFormat('dd.MM.yyyy').format(d);
  }

  String _normalizeMetricTitle(String key) {
    const map = {
      'feint_dribble': 'Обводки / финты',
      'shot_on_goal': 'Удар по воротам',
      'tackle_duel': 'Единоборство / отбор',
      'interception': 'Перехват',
      'recovery': 'Подбор',
      'header_play': 'Игра головой',
      'throw_ins': 'Аут',
      'pass_avp': 'Острая передача',
      'forward_short': 'Вперёд короткая',
      'forward_medium': 'Вперёд средняя',
      'forward_long': 'Вперёд длинная',
      'side_short': 'Поперёк короткая',
      'side_medium': 'Поперёк средняя',
      'side_long': 'Поперёк длинная',
      'back_short': 'Назад короткая',
      'back_medium': 'Назад средняя',
      'back_long': 'Назад длинная',
      'hand_distribution': 'Ввод рукой',
      'coming_out': 'Игра на выходах',
      'close_combat': 'Ближний бой',
      'interceptions_gk': 'Перехват вратаря',
      'outside_box': 'Игра вне штрафной',
      'pass_short': 'Короткая передача',
      'pass_medium': 'Средняя передача',
      'pass_long': 'Длинная передача',
      'saves': 'Сейв',
      'conceded': 'Пропущенный гол',
      'goal': 'Гол',
      'assist': 'Голевая передача',
      'yellow_card': 'Жёлтая карточка',
      'red_card': 'Красная карточка',
      'substitution': 'Замена',
      'injury': 'Травма',
      'offside': 'Офсайд',
      'foul': 'Фол',
      'foul_on': 'Фол на себе',
      'penalty': 'Пенальти',
      'save': 'Сейв',
      'corner': 'Угловой',
      'free_kick': 'Штрафной удар',
      'kick_off': 'Начальный удар',
      'throw_in': 'Аут',
      'goal_kick': 'Удар от ворот',
    };
    return map[key] ?? key;
  }

  EdgeInsets _pagePadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 420) return const EdgeInsets.fromLTRB(10, 8, 10, 20);
    if (w < 720) return const EdgeInsets.fromLTRB(12, 10, 12, 22);
    return const EdgeInsets.fromLTRB(20, 14, 20, 28);
  }

  Widget _matteSurface({required Widget child, VoidCallback? onTap, double radius = 28}) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.018),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return _matteSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _CmrColors.greenSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: _CmrColors.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: _CmrText.section(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _pill(String title, String value, {Color? color}) {
    final c = color ?? _CmrColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: _softFor(c),
        borderRadius: BorderRadius.circular(99),
      ),
      child: RichText(
        text: TextSpan(
          style: _CmrText.muted(13),
          children: [
            TextSpan(text: '$title: '),
            TextSpan(
              text: value,
              style: TextStyle(
                color: c,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String title, String value, {Color? accentColor}) {
    final c = accentColor ?? _CmrColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: _CmrText.value(14),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              color: c,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return _sectionCard(
      title: 'Общая информация',
      icon: Icons.emoji_events_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pill('Соперник', widget.opponent?.isNotEmpty == true ? widget.opponent! : '-'),
          _pill('Турнир', widget.tournament?.isNotEmpty == true ? widget.tournament! : '-'),
          _pill('Дата', _prettyDate(widget.matchDate)),
          _pill('Счёт', widget.score?.isNotEmpty == true ? widget.score! : '-', color: _CmrColors.blue),
        ],
      ),
    );
  }

  Widget _buildPlayerMainStats() {
    final row = selectedPlayerMain;
    if (row == null) {
      return _sectionCard(
        title: 'Основные ТТД',
        icon: Icons.analytics_rounded,
        child: Text('Нет данных по ТТД игрока', style: _CmrText.muted(14)),
      );
    }

    final keys = [
      'feint_dribble',
      'shot_on_goal',
      'tackle_duel',
      'interception',
      'recovery',
      'header_play',
      'throw_ins',
      'pass_avp',
    ];

    return _sectionCard(
      title: 'Основные ТТД',
      icon: Icons.analytics_rounded,
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('Всего', _asStr(row['ttd_total'])),
              _pill('Эффективность', '${_asStr(row['effect_percent'])}%', color: _CmrColors.blue),
            ],
          ),
          const SizedBox(height: 14),
          ...keys.map((key) => _metricTile(_normalizeMetricTitle(key), _asStr(row[key]))),
        ],
      ),
    );
  }

  Widget _buildPassStats() {
    final row = selectedPlayerPass;
    if (row == null) return const SizedBox.shrink();

    final keys = [
      'forward_short',
      'forward_medium',
      'forward_long',
      'side_short',
      'side_medium',
      'side_long',
      'back_short',
      'back_medium',
      'back_long',
    ];

    return _sectionCard(
      title: 'Передачи',
      icon: Icons.compare_arrows_rounded,
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('Всего', _asStr(row['total'])),
              _pill('Эффективность', '${_asStr(row['effect_percent'])}%', color: _CmrColors.purple),
            ],
          ),
          const SizedBox(height: 14),
          ...keys.map((key) => _metricTile(
                _normalizeMetricTitle(key),
                _asStr(row[key]),
                accentColor: _CmrColors.purple,
              )),
        ],
      ),
    );
  }

  Widget _buildGoalkeeperStats() {
    final row = selectedPlayerGoalkeeper;
    if (row == null) return const SizedBox.shrink();

    final keys = [
      'conceded',
      'saves',
      'hand_distribution',
      'coming_out',
      'close_combat',
      'interceptions',
      'outside_box',
      'pass_short',
      'pass_medium',
      'pass_long',
    ];

    return _sectionCard(
      title: 'Вратарская статистика',
      icon: Icons.shield_rounded,
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('Всего', _asStr(row['ttd_total'])),
              _pill('Эффективность', '${_asStr(row['effect_percent'])}%', color: _CmrColors.orange),
            ],
          ),
          const SizedBox(height: 14),
          ...keys.map((key) => _metricTile(
                _normalizeMetricTitle(key),
                _asStr(row[key]),
                accentColor: _CmrColors.orange,
              )),
        ],
      ),
    );
  }

  Widget _buildVideoTotals() {
    final row = selectedPlayerTotals;
    if (row == null) return const SizedBox.shrink();

    final success = (row['success'] is Map)
        ? Map<String, dynamic>.from(row['success'])
        : <String, dynamic>{};
    final fail = (row['fail'] is Map)
        ? Map<String, dynamic>.from(row['fail'])
        : <String, dynamic>{};
    final single = (row['single'] is Map)
        ? Map<String, dynamic>.from(row['single'])
        : <String, dynamic>{};

    final keys = <String>{...success.keys, ...fail.keys, ...single.keys}.toList()..sort();

    return _sectionCard(
      title: 'Видеоотчёт',
      icon: Icons.video_collection_rounded,
      child: Column(
        children: keys.map((key) {
          final hasPair = success.containsKey(key) || fail.containsKey(key);
          final value = hasPair ? '${_asInt(success[key])}/${_asInt(fail[key])}' : _asStr(single[key]);
          return _metricTile(_normalizeMetricTitle(key), value, accentColor: _CmrColors.teal);
        }).toList(),
      ),
    );
  }

  Widget _buildEpisodes() {
    return _sectionCard(
      title: 'Моменты игрока',
      icon: Icons.movie_creation_outlined,
      child: selectedPlayerEpisodes.isEmpty
          ? Text('По этому игроку эпизоды пока не найдены', style: _CmrText.muted(14))
          : Column(
              children: selectedPlayerEpisodes.map((episode) {
                final title = _asStr(episode['event_title']).isNotEmpty
                    ? _asStr(episode['event_title'])
                    : (_asStr(episode['event_type']).isNotEmpty
                        ? _normalizeMetricTitle(_asStr(episode['event_type']))
                        : 'Эпизод');
                final note = _asStr(episode['note']);
                final minute = _asInt(episode['minute']);
                final second = _asInt(episode['second']);
                final snapshotUrl = _asStr(episode['snapshot_url']);
                final children = (episode['children'] is List)
                    ? List<Map<String, dynamic>>.from((episode['children'] as List).whereType<Map>())
                    : <Map<String, dynamic>>[];

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _CmrColors.soft,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (snapshotUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            snapshotUrl,
                            width: double.infinity,
                            height: MediaQuery.of(context).size.width < 520 ? 170 : 220,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 150,
                              color: _CmrColors.greenSoft,
                              child: const Center(child: Icon(Icons.broken_image_outlined)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: _CmrText.value(15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _CmrColors.greenSoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              "${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                color: _CmrColors.green,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notes_rounded, size: 18, color: _CmrColors.muted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(note, style: _CmrText.body(14)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (children.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Действия в эпизоде', style: _CmrText.value(14)),
                        const SizedBox(height: 8),
                        ...children.map((child) {
                          final rawType = _asStr(child['event_type']);
                          final childTitle = rawType.isNotEmpty ? _normalizeMetricTitle(rawType) : 'Действие';
                          final isPositive = _asInt(child['is_positive']) > 0;
                          final color = isPositive ? _CmrColors.green : _CmrColors.red;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _softFor(color),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isPositive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  size: 19,
                                  color: color,
                                ),
                                const SizedBox(width: 9),
                                Expanded(child: Text(childTitle, style: _CmrText.value(14))),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildVideoButton() {
    final url = _normalizeUrl(widget.videoUrl);
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    return _matteSurface(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _watchVideo,
          icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white),
          label: const Text(
            'Смотреть видео матча',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _CmrColors.green,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
    );
  }

  Widget _buildStateMessage({required IconData icon, required String text, bool loading = false}) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _CmrColors.soft,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? const CircularProgressIndicator(color: _CmrColors.green)
                : Icon(icon, color: _CmrColors.green, size: 34),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: _CmrText.muted(15)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _CmrColors.panel,
      appBar: AppBar(
        backgroundColor: _CmrColors.panel,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _CmrColors.text,
        titleSpacing: 0,
        title: Text(
          'Матч — ${widget.playerName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _CmrText.title(19),
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loadMatchDetail,
            icon: const Icon(Icons.refresh_rounded, color: _CmrColors.green),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMatchDetail,
        color: _CmrColors.green,
        child: isLoading
            ? _buildStateMessage(icon: Icons.analytics_rounded, text: 'Загружаем данные матча', loading: true)
            : error != null
                ? _buildStateMessage(icon: Icons.error_outline_rounded, text: error!)
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: ListView(
                        padding: _pagePadding(context),
                        children: [
                          _buildOverview(),
                          const SizedBox(height: 12),
                          _buildVideoButton(),
                          const SizedBox(height: 12),
                          _buildPlayerMainStats(),
                          if (selectedPlayerPass != null) ...[
                            const SizedBox(height: 12),
                            _buildPassStats(),
                          ],
                          if (selectedPlayerGoalkeeper != null) ...[
                            const SizedBox(height: 12),
                            _buildGoalkeeperStats(),
                          ],
                          if (selectedPlayerTotals != null) ...[
                            const SizedBox(height: 12),
                            _buildVideoTotals(),
                          ],
                          const SizedBox(height: 12),
                          _buildEpisodes(),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Color _softFor(Color color) {
    if (color == _CmrColors.blue) return _CmrColors.blueSoft;
    if (color == _CmrColors.purple) return _CmrColors.purpleSoft;
    if (color == _CmrColors.orange) return _CmrColors.orangeSoft;
    if (color == _CmrColors.teal) return _CmrColors.tealSoft;
    if (color == _CmrColors.red) return _CmrColors.redSoft;
    return _CmrColors.greenSoft;
  }
}

class _CmrColors {
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF6F8FA);
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color green = Color(0xFF1F7A4D);
  static const Color greenSoft = Color(0xFFF2F7F4);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);
  static const Color purple = Color(0xFF6D5BD0);
  static const Color purpleSoft = Color(0xFFF3F1FF);
  static const Color orange = Color(0xFFB85C00);
  static const Color orangeSoft = Color(0xFFFFF4E8);
  static const Color teal = Color(0xFF008C7A);
  static const Color tealSoft = Color(0xFFEAF8F6);
  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFFF1F0);
}

class _CmrText {
  static TextStyle title(double size) => TextStyle(
        color: _CmrColors.text,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.15,
      );

  static TextStyle section() => const TextStyle(
        color: _CmrColors.text,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        height: 1.2,
      );

  static TextStyle value(double size) => TextStyle(
        color: _CmrColors.text,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.3,
      );

  static TextStyle body(double size) => TextStyle(
        color: _CmrColors.text,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.35,
      );

  static TextStyle muted(double size) => TextStyle(
        color: _CmrColors.muted,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.38,
      );
}
