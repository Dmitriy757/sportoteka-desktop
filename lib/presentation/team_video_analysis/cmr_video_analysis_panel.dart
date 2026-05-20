// lib/presentation/team_video_analysis/cmr_video_analysis_panel.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_video_analysis/team_video_analysis_screen.dart';
import 'package:sportoteka/presentation/team_video_analysis/video_match_review_screen.dart';

class CmrVideoAnalysisPanel extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;

  const CmrVideoAnalysisPanel({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<CmrVideoAnalysisPanel> createState() => _CmrVideoAnalysisPanelState();
}

class _CmrVideoAnalysisPanelState extends State<CmrVideoAnalysisPanel> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getMatchesUrl = '$apiBase/get_team_matches.php';
  static const String getTeamProfileUrl = '$apiBase/get_team_profile.php';
  static const String deleteVideoUrl = '$apiBase/delete_team_match_video.php';
  static const String deleteMatchUrl = '$apiBase/delete_team_match.php';

  final TextEditingController searchCtrl = TextEditingController();

  bool loading = true;
  bool refreshing = false;
  bool actionLoading = false;
  String? error;

  int coachId = 0;
  String actualTeamName = '';

  List<Map<String, dynamic>> matches = [];
  List<Map<String, dynamic>> filtered = [];
  Map<String, dynamic>? selectedMatch;

  @override
  void initState() {
    super.initState();
    searchCtrl.addListener(_applySearch);
    _init();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    coachId = await PrefUtils.getUserId() ?? 0;
    await _loadTeamProfile();
    await _loadMatches(initial: true);
  }

  Future<void> _loadTeamProfile() async {
    try {
      final response = await http
          .post(
            Uri.parse(getTeamProfileUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'team_id': widget.teamId}),
          )
          .timeout(const Duration(seconds: 12));

      final data = _decode(response.body);
      final ok =
          data is Map && (data['success'] == true || data['status'] == 'success');

      if (ok && data['team'] is Map) {
        final team = Map<String, dynamic>.from(data['team']);
        final serverName = _s(team['name']);
        if (serverName.isNotEmpty && mounted) {
          setState(() => actualTeamName = serverName);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadMatches({bool initial = false}) async {
    if (!mounted) return;

    setState(() {
      if (initial) {
        loading = true;
      } else {
        refreshing = true;
      }
      error = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(getMatchesUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'team_id': widget.teamId}),
          )
          .timeout(const Duration(seconds: 20));

      final data = _decode(response.body);

      if (data is Map && data['success'] == true && data['matches'] is List) {
        matches = (data['matches'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        matches = [];
      }

      matches.sort((a, b) => _s(b['match_date']).compareTo(_s(a['match_date'])));
      _applySearch(silent: true);

      final oldId = _asInt(selectedMatch?['id']);
      Map<String, dynamic>? next;

      if (oldId > 0) {
        for (final m in filtered) {
          if (_asInt(m['id']) == oldId) {
            next = m;
            break;
          }
        }
      }

      next ??= filtered.isNotEmpty ? filtered.first : null;

      if (!mounted) return;

      setState(() {
        selectedMatch = next;
        loading = false;
        refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        refreshing = false;
        error = '$e';
      });
    }
  }

  void _applySearch({bool silent = false}) {
    final q = searchCtrl.text.trim().toLowerCase();

    final list = q.isEmpty
        ? List<Map<String, dynamic>>.from(matches)
        : matches.where((item) {
            final title = _matchTitle(item).toLowerCase();
            final opponent = _s(item['opponent']).toLowerCase();
            final tournament = _s(item['tournament']).toLowerCase();
            final date = _s(item['match_date']).toLowerCase();

            return title.contains(q) ||
                opponent.contains(q) ||
                tournament.contains(q) ||
                date.contains(q);
          }).toList();

    if (silent || !mounted) {
      filtered = list;
      return;
    }

    setState(() {
      filtered = list;
      if (filtered.isNotEmpty && selectedMatch == null) {
        selectedMatch = filtered.first;
      }
    });
  }

  Future<void> _deleteVideo(Map<String, dynamic> item) async {
    final matchId = _asInt(item['id']);
    if (matchId <= 0) return;

    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Удалить видео?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Видео матча «${_matchTitle(item)}» будет удалено.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: _C.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => actionLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse(deleteVideoUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'match_id': matchId, 'team_id': widget.teamId}),
          )
          .timeout(const Duration(seconds: 14));

      final data = _decode(response.body);

      if (data is! Map || data['success'] != true) {
        throw data is Map
            ? (data['message'] ?? 'Не удалось удалить видео')
            : 'Не удалось удалить видео';
      }

      await _loadMatches();
      Get.snackbar('Готово', 'Видео удалено');
    } catch (e) {
      Get.snackbar('Ошибка', '$e');
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> _deleteMatch(Map<String, dynamic> item) async {
    final matchId = _asInt(item['id']);
    if (matchId <= 0) return;

    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Удалить матч?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Матч «${_matchTitle(item)}» будет удалён.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: _C.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => actionLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse(deleteMatchUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'match_id': matchId, 'team_id': widget.teamId}),
          )
          .timeout(const Duration(seconds: 14));

      final data = _decode(response.body);

      if (data is! Map || data['success'] != true) {
        throw data is Map
            ? (data['message'] ?? 'Не удалось удалить матч')
            : 'Не удалось удалить матч';
      }

      selectedMatch = null;
      await _loadMatches();
      Get.snackbar('Готово', 'Матч удалён');
    } catch (e) {
      Get.snackbar('Ошибка', '$e');
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  void _openFullModule() {
    Get.to(() => TeamVideoAnalysisScreen(
          teamId: widget.teamId,
          teamName: _displayTeamName,
          clubId: widget.clubId,
          clubName: widget.clubName,
        ));
  }

  void _openReview(Map<String, dynamic> item) {
    final matchId = _asInt(item['id']);
    final videoUrl = _normalizeUrl(_s(item['video_url'])) ?? '';

    if (matchId <= 0) {
      Get.snackbar('Видеоанализ', 'Некорректный match_id');
      return;
    }

    if (videoUrl.isEmpty) {
      Get.snackbar('Видеоанализ', 'Сначала загрузите видео матча');
      return;
    }

    Get.to(() => VideoMatchReviewScreen(
          matchId: matchId,
          teamId: widget.teamId,
          teamName: _displayTeamName,
          coachId: coachId,
          matchTitle: _matchTitle(item),
          videoUrl: videoUrl,
          videoId: matchId,
        ));
  }

  String get _displayTeamName {
    final server = actualTeamName.trim();
    if (server.isNotEmpty && !RegExp(r'^Команда\s+\d+$').hasMatch(server)) {
      return server;
    }

    final passed = widget.teamName.trim();
    if (passed.isNotEmpty && !RegExp(r'^Команда\s+\d+$').hasMatch(passed)) {
      return passed;
    }

    return 'Команда';
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  String _s(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  dynamic _decode(String body) {
    final trimmed = body.trim();
    final startObj = trimmed.indexOf('{');
    final startArr = trimmed.indexOf('[');
    final starts = [startObj, startArr].where((e) => e >= 0).toList();
    if (starts.isEmpty) return {};
    final start = starts.reduce((a, b) => a < b ? a : b);
    return jsonDecode(trimmed.substring(start));
  }

  String _matchTitle(Map<String, dynamic> item) {
    final explicit = _s(item['title']);
    if (explicit.isNotEmpty) return explicit;

    final opponent = _s(item['opponent']);
    final home = _s(item['home_team']);
    final away = _s(item['away_team']);

    if (home.isNotEmpty || away.isNotEmpty) {
      return '${home.isEmpty ? _displayTeamName : home} — ${away.isEmpty ? opponent : away}';
    }

    if (opponent.isNotEmpty) return 'Матч с $opponent';
    return 'Матч #${_asInt(item['id'])}';
  }

  String _score(Map<String, dynamic> item) {
    final score = _s(item['score']);
    if (score.isNotEmpty) return score;

    final home = _s(item['home_score']);
    final away = _s(item['away_score']);

    if (home.isNotEmpty || away.isNotEmpty) {
      return '${home.isEmpty ? '0' : home}:${away.isEmpty ? '0' : away}';
    }

    return '—';
  }

  String _date(Map<String, dynamic> item) {
    final d = _s(item['match_date']);
    if (d.length >= 10) return d.substring(0, 10);
    return d.isEmpty ? 'Дата не указана' : d;
  }

  String _videoStatus(Map<String, dynamic> item) {
    final video = _normalizeUrl(_s(item['video_url']));
    if (video != null && video.isNotEmpty) return 'Видео загружено';
    return 'Видео не загружено';
  }

  String? _normalizeUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == 'null') return null;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('/')) return '$apiBase$value';
    return '$apiBase/$value';
  }

  bool get _isBusy => refreshing || actionLoading;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < 700;

    if (loading) {
      return _LoadingCard(teamName: _displayTeamName, isPhone: isPhone);
    }

    if (error != null) {
      return _EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Не удалось загрузить видеоанализ',
        text: error!,
        actionText: 'Повторить',
        onAction: () => _loadMatches(initial: true),
        isPhone: isPhone,
      );
    }

    return Stack(
      children: [
        isPhone ? _buildMobileLayout() : _buildTabletLayout(),
        if (_isBusy)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(
              minHeight: 3,
              color: _C.primary,
              backgroundColor: _C.softGreen,
            ),
          ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        SizedBox(width: 420, child: _buildLeftColumn(isPhone: false)),
        const SizedBox(width: 12),
        Expanded(child: _buildDetails(isPhone: false)),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      color: _C.primary,
      onRefresh: () => _loadMatches(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 18),
        children: [
          _buildMobileHeader(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildSearchAndActions(isPhone: true),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildMobileSelectedCard(),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildMobileMatchesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    final withVideo = matches.where((m) => _normalizeUrl(_s(m['video_url'])) != null).length;
    final noVideo = matches.length - withVideo;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: _C.cardDecoration.copyWith(borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBox(icon: Icons.analytics_rounded, size: 46, iconSize: 23),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Видеоанализ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _C.title.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _displayTeamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderIconButton(icon: Icons.refresh_rounded, onTap: () => _loadMatches(), compact: true),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _HeroStat(value: '${matches.length}', title: 'матчей', icon: Icons.sports_soccer_rounded, compact: true)),
              const SizedBox(width: 8),
              Expanded(child: _HeroStat(value: '$withVideo', title: 'с видео', icon: Icons.videocam_rounded, compact: true)),
              const SizedBox(width: 8),
              Expanded(child: _HeroStat(value: '$noVideo', title: 'без видео', icon: Icons.videocam_off_rounded, compact: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSelectedCard() {
    final item = selectedMatch;
    if (item == null) {
      return _EmptyState(
        icon: Icons.video_library_outlined,
        title: 'Матч не выбран',
        text: 'Выберите матч ниже или откройте полный модуль для загрузки видео.',
        actionText: 'Полный модуль',
        onAction: _openFullModule,
        isPhone: true,
      );
    }
    return _buildDetailsCard(item, isPhone: true, insideMobile: true);
  }

  Widget _buildMobileMatchesList() {
    return Container(
      decoration: _C.cardDecoration.copyWith(borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Text('Матчи команды', style: _C.title.copyWith(fontSize: 16)),
                const Spacer(),
                Text('${filtered.length}', style: const TextStyle(color: _C.muted, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          if (filtered.isEmpty)
            const SizedBox(height: 120, child: _MiniEmpty(text: 'Матчи не найдены'))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final item = filtered[index];
                final active = _asInt(item['id']) == _asInt(selectedMatch?['id']);

                return _MatchTile(
                  title: _matchTitle(item),
                  date: _date(item),
                  score: _score(item),
                  tournament: _s(item['tournament']),
                  hasVideo: _normalizeUrl(_s(item['video_url'])) != null,
                  active: active,
                  compact: true,
                  onTap: () => setState(() => selectedMatch = item),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn({required bool isPhone}) {
    final withVideo = matches.where((m) => _normalizeUrl(_s(m['video_url'])) != null).length;

    return Container(
      decoration: _C.cardDecoration,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    const _IconBox(icon: Icons.analytics_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayTeamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _C.title.copyWith(fontSize: 19),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Видеоанализ команды',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _C.muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeaderIconButton(icon: Icons.refresh_rounded, onTap: () => _loadMatches()),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _HeroStat(value: '${matches.length}', title: 'матчей', icon: Icons.sports_soccer_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _HeroStat(value: '$withVideo', title: 'с видео', icon: Icons.videocam_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _HeroStat(value: '${matches.length - withVideo}', title: 'без видео', icon: Icons.videocam_off_rounded)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _buildSearchAndActions(isPhone: false),
          ),
          const Divider(height: 1, color: _C.border),
          Expanded(
            child: filtered.isEmpty
                ? const _MiniEmpty(text: 'Матчи не найдены')
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final item = filtered[index];
                      final active = _asInt(item['id']) == _asInt(selectedMatch?['id']);

                      return _MatchTile(
                        title: _matchTitle(item),
                        date: _date(item),
                        score: _score(item),
                        tournament: _s(item['tournament']),
                        hasVideo: _normalizeUrl(_s(item['video_url'])) != null,
                        active: active,
                        onTap: () => setState(() => selectedMatch = item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndActions({required bool isPhone}) {
    return Column(
      children: [
        TextField(
          controller: searchCtrl,
          style: TextStyle(
            color: _C.text,
            fontWeight: FontWeight.w700,
            fontSize: isPhone ? 13 : 14,
          ),
          decoration: InputDecoration(
            hintText: isPhone ? 'Поиск по матчам' : 'Поиск по матчу, сопернику, турниру',
            hintStyle: const TextStyle(color: _C.muted),
            prefixIcon: const Icon(Icons.search_rounded, color: _C.muted),
            suffixIcon: searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchCtrl.clear();
                      _applySearch();
                    },
                    icon: const Icon(Icons.close_rounded, color: _C.muted),
                  ),
            filled: true,
            fillColor: _C.soft,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isPhone ? 11 : 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isPhone ? 16 : 18),
              borderSide: const BorderSide(color: _C.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isPhone ? 16 : 18),
              borderSide: const BorderSide(color: _C.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isPhone ? 16 : 18),
              borderSide: const BorderSide(color: _C.primary, width: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _ToolButton(icon: Icons.open_in_new_rounded, text: isPhone ? 'Модуль' : 'Полный модуль', onTap: _openFullModule, compact: isPhone)),
            const SizedBox(width: 8),
            Expanded(child: _ToolButton(icon: Icons.cloud_upload_outlined, text: isPhone ? 'Видео' : 'Загрузка видео', onTap: _openFullModule, compact: isPhone)),
          ],
        ),
      ],
    );
  }

  Widget _buildDetails({required bool isPhone}) {
    final item = selectedMatch;

    if (item == null) {
      return _EmptyState(
        icon: Icons.video_library_outlined,
        title: 'Выберите матч',
        text: 'Слева выберите матч, чтобы открыть видео, статистику и действия внутри CMR.',
        actionText: 'Открыть полный модуль',
        onAction: _openFullModule,
        isPhone: isPhone,
      );
    }

    return _buildDetailsCard(item, isPhone: isPhone);
  }

  Widget _buildDetailsCard(Map<String, dynamic> item, {required bool isPhone, bool insideMobile = false}) {
    final videoUrl = _normalizeUrl(_s(item['video_url']));
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final notes = _s(item['notes']);
    final tournament = _s(item['tournament']);
    final location = _s(item['location']);
    final thumbnail = _normalizeUrl(_s(item['thumbnail_url'] ?? item['preview_url'] ?? item['image']));

    final header = Padding(
      padding: EdgeInsets.all(isPhone ? 14 : 18),
      child: isPhone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ThumbBox(url: thumbnail, hasVideo: hasVideo, compact: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_matchTitle(item), maxLines: 2, overflow: TextOverflow.ellipsis, style: _C.title.copyWith(fontSize: 16.5)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            _LightChip(text: _date(item), compact: true),
                            _LightChip(text: 'Счёт ${_score(item)}', compact: true),
                            _LightChip(text: hasVideo ? 'Видео есть' : 'Без видео', compact: true),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _HeaderButton(icon: Icons.play_circle_outline_rounded, text: 'AI-анализ', onTap: () => _openReview(item), compact: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _HeaderButton(icon: Icons.open_in_new_rounded, text: 'Модуль', onTap: _openFullModule, secondary: true, compact: true)),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ThumbBox(url: thumbnail, hasVideo: hasVideo),
                const SizedBox(width: 16),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 92),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_matchTitle(item), maxLines: 2, overflow: TextOverflow.ellipsis, style: _C.title.copyWith(fontSize: 22)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _LightChip(text: _date(item)),
                          _LightChip(text: 'Счёт ${_score(item)}'),
                          _LightChip(text: hasVideo ? 'Видео загружено' : 'Без видео'),
                          if (tournament.isNotEmpty) _LightChip(text: tournament),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 156,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderButton(icon: Icons.play_circle_outline_rounded, text: 'Анализ', onTap: () => _openReview(item)),
                      const SizedBox(height: 8),
                      _HeaderButton(icon: Icons.open_in_new_rounded, text: 'Полный экран', onTap: _openFullModule, secondary: true),
                    ],
                  ),
                ),
              ],
            ),
    );

    final content = ListView(
      shrinkWrap: insideMobile,
      physics: insideMobile ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.all(isPhone ? 14 : 18),
      children: [
        if (isPhone)
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _InfoCard(title: 'Дата', value: _date(item), icon: Icons.calendar_today_rounded, compact: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _InfoCard(title: 'Счёт', value: _score(item), icon: Icons.scoreboard_rounded, compact: true)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _InfoCard(title: 'Видео', value: hasVideo ? 'Есть' : 'Нет', icon: Icons.video_file_rounded, compact: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _InfoCard(title: 'Турнир', value: tournament.isEmpty ? '—' : tournament, icon: Icons.emoji_events_rounded, compact: true)),
                ],
              ),
            ],
          )
        else ...[
          Row(
            children: [
              Expanded(child: _InfoCard(title: 'Дата матча', value: _date(item), icon: Icons.calendar_today_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _InfoCard(title: 'Счёт', value: _score(item), icon: Icons.scoreboard_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _InfoCard(title: 'Видео', value: _videoStatus(item), icon: Icons.video_file_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _InfoCard(title: 'Турнир', value: tournament.isEmpty ? '—' : tournament, icon: Icons.emoji_events_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _InfoCard(title: 'Локация', value: location.isEmpty ? '—' : location, icon: Icons.place_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _InfoCard(title: 'ID матча', value: '${_asInt(item['id'])}', icon: Icons.tag_rounded)),
            ],
          ),
        ],
        SizedBox(height: isPhone ? 10 : 12),
        _SectionCard(
          title: 'Видео матча',
          icon: Icons.ondemand_video_rounded,
          compact: isPhone,
          accentColor: _C.blue,
          backgroundColor: _C.softBlue,
          child: hasVideo
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isPhone ? 12 : 14),
                      decoration: BoxDecoration(
                        color: _C.softBlue,
                        borderRadius: BorderRadius.circular(isPhone ? 16 : 18),
                        border: Border.all(color: _C.blue.withOpacity(.18)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_outline_rounded, color: _C.blue, size: isPhone ? 18 : 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Видео загружено. Прямая ссылка скрыта — используйте AI-анализ или полный модуль.',
                              style: TextStyle(color: _C.text, fontWeight: FontWeight.w800, height: 1.35, fontSize: isPhone ? 12.5 : 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    isPhone
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PrimaryButton(text: 'Открыть AI-анализ', icon: Icons.analytics_rounded, onTap: () => _openReview(item), compact: true),
                              const SizedBox(height: 8),
                              _DangerButton(text: 'Удалить видео', icon: Icons.delete_outline_rounded, onTap: () => _deleteVideo(item), compact: true),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: _PrimaryButton(text: 'Открыть AI-анализ', icon: Icons.analytics_rounded, onTap: () => _openReview(item))),
                              const SizedBox(width: 10),
                              _DangerButton(text: 'Удалить видео', icon: Icons.delete_outline_rounded, onTap: () => _deleteVideo(item)),
                            ],
                          ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Видео ещё не загружено. Для загрузки открой полный модуль.',
                      style: TextStyle(color: _C.text, fontWeight: FontWeight.w700, height: 1.45, fontSize: isPhone ? 13 : 14),
                    ),
                    const SizedBox(height: 12),
                    _PrimaryButton(text: 'Загрузить видео', icon: Icons.cloud_upload_outlined, onTap: _openFullModule, compact: isPhone),
                  ],
                ),
        ),
        SizedBox(height: isPhone ? 10 : 12),
        _SectionCard(
          title: 'Заметки тренера',
          icon: Icons.notes_rounded,
          compact: isPhone,
          accentColor: _C.orange,
          backgroundColor: _C.softOrange,
          child: Text(
            notes.isEmpty ? 'Заметки пока не заполнены.' : notes,
            style: TextStyle(color: _C.text, fontSize: isPhone ? 13.5 : 15, fontWeight: FontWeight.w700, height: 1.45),
          ),
        ),
        SizedBox(height: isPhone ? 10 : 12),
        _SectionCard(
          title: 'Быстрые действия',
          icon: Icons.tune_rounded,
          compact: isPhone,
          accentColor: _C.purple,
          backgroundColor: _C.softPurple,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionPill(icon: Icons.play_circle_outline_rounded, text: 'Видеоразбор', onTap: () => _openReview(item), compact: isPhone),
              _ActionPill(icon: Icons.cloud_upload_outlined, text: 'Загрузить', onTap: _openFullModule, compact: isPhone),
              _ActionPill(icon: Icons.refresh_rounded, text: 'Обновить', onTap: () => _loadMatches(), compact: isPhone),
              _ActionPill(icon: Icons.delete_outline_rounded, text: 'Удалить', danger: true, onTap: () => _deleteMatch(item), compact: isPhone),
            ],
          ),
        ),
      ],
    );

    return Container(
      decoration: _C.cardDecoration.copyWith(borderRadius: BorderRadius.circular(isPhone ? 24 : 28)),
      child: insideMobile
          ? Column(children: [header, const Divider(height: 1, color: _C.border), content])
          : Column(children: [header, const Divider(height: 1, color: _C.border), Expanded(child: content)]),
    );
  }
}

class _C {
  static const Color primary = Color(0xFF1F8A4C);
  static const Color primaryDark = Color(0xFF176B3A);
  static const Color dark = Color(0xFF0F172A);
  static const Color bg = Color(0xFFF7FAF8);
  static const Color card = Colors.white;
  static const Color soft = Color(0xFFF4F7F5);
  static const Color softGreen = Color(0xFFEAF5EF);
  static const Color active = Color(0xFFEFF7F2);
  static const Color text = Color(0xFF111827);
  static const Color muted = Color(0xFF667085);
  static const Color border = Color(0xFFE1E8E4);
  static const Color red = Color(0xFFDC2626);
  static const Color orange = Color(0xFFF97316);
  static const Color blue = Color(0xFF2563EB);
  static const Color purple = Color(0xFF7C3AED);
  static const Color softBlue = Color(0xFFEFF6FF);
  static const Color softOrange = Color(0xFFFFF7ED);
  static const Color softPurple = Color(0xFFF5F3FF);

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static const TextStyle title = TextStyle(
    color: text,
    fontSize: 18,
    fontWeight: FontWeight.w900,
    height: 1.15,
  );
}

class _LoadingCard extends StatelessWidget {
  final String teamName;
  final bool isPhone;

  const _LoadingCard({required this.teamName, this.isPhone = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _C.cardDecoration,
      child: Column(
        children: [
          const LinearProgressIndicator(minHeight: 3, color: _C.primary, backgroundColor: _C.softGreen),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IconBox(icon: Icons.analytics_rounded, size: isPhone ? 64 : 76, iconSize: isPhone ? 32 : 38),
                    SizedBox(height: isPhone ? 14 : 18),
                    Text(
                      'Загружаем видеоанализ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _C.text, fontSize: isPhone ? 20 : 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Матчи, видео и данные команды ${teamName.isEmpty ? '' : '«$teamName»'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _C.muted, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: isPhone ? 18 : 22),
                    const SizedBox(width: 42, height: 42, child: CircularProgressIndicator(strokeWidth: 3, color: _C.primary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;

  const _IconBox({required this.icon, this.size = 52, this.iconSize = 26});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _C.softGreen,
        borderRadius: BorderRadius.circular(size * .34),
        border: Border.all(color: _C.border),
      ),
      child: Icon(icon, color: _C.primaryDark, size: iconSize),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String title;
  final IconData icon;
  final bool compact;

  const _HeroStat({required this.value, required this.title, required this.icon, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 62 : 74,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: _C.soft,
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _C.primaryDark, size: compact ? 18 : 20),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _C.text, fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _C.muted, fontSize: compact ? 10 : 10.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool compact;

  const _ToolButton({required this.icon, required this.text, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 14 : 16),
      onTap: onTap,
      child: Container(
        height: compact ? 40 : 44,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
        decoration: BoxDecoration(
          color: _C.soft,
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _C.primaryDark, size: compact ? 17 : 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _C.text, fontSize: compact ? 11.5 : 12, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  const _HeaderIconButton({required this.icon, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 40.0 : 44.0;
    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 14 : 16),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _C.soft,
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          border: Border.all(color: _C.border),
        ),
        child: Icon(icon, color: _C.primaryDark, size: compact ? 20 : 22),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final String title;
  final String date;
  final String score;
  final String tournament;
  final bool hasVideo;
  final bool active;
  final VoidCallback onTap;
  final bool compact;

  const _MatchTile({
    required this.title,
    required this.date,
    required this.score,
    required this.tournament,
    required this.hasVideo,
    required this.active,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final line = [date, 'счёт $score', if (tournament.isNotEmpty) tournament].join(' • ');

    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 18 : 20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: active ? _C.active : _C.soft,
          borderRadius: BorderRadius.circular(compact ? 18 : 20),
          border: Border.all(color: active ? _C.primary.withOpacity(.35) : _C.border),
        ),
        child: Row(
          children: [
            _IconBox(icon: hasVideo ? Icons.play_circle_fill_rounded : Icons.sports_soccer_rounded, size: compact ? 42 : 48, iconSize: compact ? 22 : 25),
            SizedBox(width: compact ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _C.title.copyWith(fontSize: compact ? 13.5 : 14.5)),
                  const SizedBox(height: 5),
                  Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _C.muted, fontSize: compact ? 11.2 : 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Icon(hasVideo ? Icons.videocam_rounded : Icons.videocam_off_rounded, color: active ? _C.primaryDark : _C.muted, size: compact ? 20 : 24),
          ],
        ),
      ),
    );
  }
}

class _ThumbBox extends StatelessWidget {
  final String? url;
  final bool hasVideo;
  final bool compact;

  const _ThumbBox({required this.url, required this.hasVideo, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    final size = compact ? 74.0 : 92.0;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _C.soft,
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: _C.border),
      ),
      child: hasUrl
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(hasVideo ? Icons.play_circle_fill_rounded : Icons.video_library_outlined, color: _C.primaryDark, size: compact ? 34 : 42),
            )
          : Icon(hasVideo ? Icons.play_circle_fill_rounded : Icons.video_library_outlined, color: _C.primaryDark, size: compact ? 34 : 42),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool compact;

  const _InfoCard({required this.title, required this.value, required this.icon, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 66 : 76),
      child: Container(
        padding: EdgeInsets.all(compact ? 11 : 14),
        decoration: BoxDecoration(
          color: _C.soft,
          borderRadius: BorderRadius.circular(compact ? 16 : 18),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: _C.primaryDark, size: compact ? 18 : 21),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _C.muted, fontSize: compact ? 10.5 : 11.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _C.text, fontSize: compact ? 12.5 : 14, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool compact;
  final Color accentColor;
  final Color backgroundColor;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.compact = false,
    this.accentColor = _C.primaryDark,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: accentColor.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 30 : 34,
                height: compact ? 30 : 34,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: compact ? 17 : 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _C.title.copyWith(fontSize: compact ? 14.5 : 16),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          child,
        ],
      ),
    );
  }
}

class _LightChip extends StatelessWidget {
  final String text;
  final bool compact;

  const _LightChip({required this.text, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 6 : 7),
      decoration: BoxDecoration(
        color: _C.soft,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _C.border),
      ),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _C.text, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool secondary;
  final bool compact;

  const _HeaderButton({required this.icon, required this.text, required this.onTap, this.secondary = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 14 : 16),
      onTap: onTap,
      child: Container(
        height: compact ? 42.0 : null,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 10 : 11),
        decoration: BoxDecoration(
          color: secondary ? _C.soft : _C.primary,
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          border: secondary ? Border.all(color: _C.border) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: secondary ? _C.primaryDark : Colors.white, size: compact ? 17 : 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: secondary ? _C.text : Colors.white, fontSize: compact ? 11.5 : 12.5, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  const _PrimaryButton({required this.text, required this.icon, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: compact ? 18 : 20),
      label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: ElevatedButton.styleFrom(
        backgroundColor: _C.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: Size.fromHeight(compact ? 46.0 : 52.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(compact ? 16 : 18)),
        textStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: compact ? 12.5 : 14),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  const _DangerButton({required this.text, required this.icon, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: compact ? 18 : 20),
      label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: _C.red,
        side: const BorderSide(color: Color(0xFFFECACA)),
        minimumSize: Size(compact ? double.infinity : 158.0, compact ? 46.0 : 52.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(compact ? 16 : 18)),
        textStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: compact ? 12.5 : 14),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool danger;
  final bool compact;

  const _ActionPill({required this.icon, required this.text, required this.onTap, this.danger = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final bg = danger ? const Color(0xFFFFF1F2) : _C.soft;
    final border = danger ? const Color(0xFFFECACA) : _C.border;
    final color = danger ? _C.red : _C.text;
    final iconColor = danger ? _C.red : _C.primaryDark;

    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 14 : 16),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13, vertical: compact ? 9 : 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(compact ? 14 : 16), border: Border.all(color: border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: compact ? 17 : 18),
            const SizedBox(width: 7),
            Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: compact ? 12 : 13)),
          ],
        ),
      ),
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  final String text;

  const _MiniEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _C.muted, fontWeight: FontWeight.w700, height: 1.4)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String? actionText;
  final VoidCallback? onAction;
  final bool isPhone;

  const _EmptyState({required this.icon, required this.title, required this.text, this.actionText, this.onAction, this.isPhone = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _C.cardDecoration.copyWith(borderRadius: BorderRadius.circular(isPhone ? 24 : 28)),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: EdgeInsets.all(isPhone ? 18 : 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBox(icon: icon, size: isPhone ? 58 : 72, iconSize: isPhone ? 30 : 36),
              SizedBox(height: isPhone ? 12 : 14),
              Text(title, textAlign: TextAlign.center, style: _C.title.copyWith(fontSize: isPhone ? 18 : 22)),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center, style: TextStyle(color: _C.muted, height: 1.45, fontWeight: FontWeight.w600, fontSize: isPhone ? 12.5 : 14)),
              if (actionText != null && onAction != null) ...[
                SizedBox(height: isPhone ? 14 : 18),
                SizedBox(width: isPhone ? 190 : 230, child: _PrimaryButton(text: actionText!, icon: Icons.open_in_new_rounded, onTap: onAction!, compact: isPhone)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
