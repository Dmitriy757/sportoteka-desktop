import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_video_analysis/video_match_review_screen.dart';

class TeamVideoAnalysisScreen extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;

  const TeamVideoAnalysisScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<TeamVideoAnalysisScreen> createState() =>
      _TeamVideoAnalysisScreenState();
}

class _TeamVideoAnalysisScreenState extends State<TeamVideoAnalysisScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getMatchesUrl = "$apiBase/get_team_matches.php";
  static const String uploadMatchUrl = "$apiBase/upload_team_match_video.php";

  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _filteredMatches = [];

  bool _loading = true;
  bool _uploading = false;
  int _coachId = 0;

  @override
  void initState() {
    super.initState();
    _init();
    _searchCtrl.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _coachId = await PrefUtils.getUserId() ?? 0;
    await _loadMatches();
  }

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      final start = body.indexOf('{');
      if (start == -1) {
        return {
          "success": false,
          "message": "Некорректный ответ сервера",
        };
      }
      final clean = body.substring(start);
      final j = jsonDecode(clean);
      if (j is Map<String, dynamic>) return j;
      return {"success": false, "message": "Пустой JSON"};
    } catch (_) {
      return {"success": false, "message": "Ошибка разбора ответа"};
    }
  }

  String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    return "https://sportotekaapp.ru${s.startsWith('/') ? s : '/$s'}";
  }

  String _s(dynamic v) => (v ?? "").toString().trim();

  String _eventTypeLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'championship':
        return 'Чемпионат';
      case 'friendly':
        return 'Товарищеский';
      case 'tournament':
        return 'Турнир';
      default:
        return raw.isEmpty ? 'Матч' : raw;
    }
  }

  String _buildMatchTitle(Map<String, dynamic> item) {
    final readyTitle = _s(item["title"]);
    if (readyTitle.isNotEmpty) return readyTitle;

    final opponent = _s(item["opponent"]);
    final ourScore =
        _s(item["our_score"]).isEmpty ? "0" : _s(item["our_score"]);
    final oppScore = _s(item["opponent_score"]).isEmpty
        ? "0"
        : _s(item["opponent_score"]);

    if (opponent.isNotEmpty) {
      return "${widget.teamName} $ourScore:$oppScore $opponent";
    }
    return widget.teamName;
  }

  Future<Map<String, dynamic>> uploadMatchVideo({
    required int matchId,
    required int teamId,
    required int coachId,
    required File video,
    File? thumbnail,
    String notes = "",
  }) async {
    final req = http.MultipartRequest(
      "POST",
      Uri.parse(uploadMatchUrl),
    );

    req.fields["match_id"] = matchId.toString();
    req.fields["team_id"] = teamId.toString();
    req.fields["coach_id"] = coachId.toString();
    req.fields["notes"] = notes;

    req.files.add(
      await http.MultipartFile.fromPath("video", video.path),
    );

    if (thumbnail != null) {
      req.files.add(
        await http.MultipartFile.fromPath("thumbnail", thumbnail.path),
      );
    }

    final streamed = await req.send().timeout(const Duration(seconds: 180));
    final resp = await http.Response.fromStream(streamed);

    final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
    final start = body.indexOf('{');

    if (start == -1) {
      return {
        "success": false,
        "message": "Некорректный ответ сервера: $body",
      };
    }

    final clean = body.substring(start);
    final decoded = jsonDecode(clean);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {
      "success": false,
      "message": "Сервер вернул неожиданный формат ответа",
    };
  }

  Future<void> _loadMatches() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final resp = await http.post(
        Uri.parse(getMatchesUrl),
        headers: const {
          "Content-Type": "application/json; charset=utf-8",
        },
        body: jsonEncode({
          "team_id": widget.teamId,
        }),
      ).timeout(const Duration(seconds: 20));

      final data = _decode(resp);

      if (data["success"] == true && data["matches"] is List) {
        _matches = List<Map<String, dynamic>>.from(data["matches"]);
      } else {
        _matches = [];
      }
    } catch (_) {
      _matches = [];
    }

    _applySearch();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _applySearch() {
    final query = _searchCtrl.text.trim().toLowerCase();

    if (query.isEmpty) {
      _filteredMatches = List<Map<String, dynamic>>.from(_matches);
    } else {
      _filteredMatches = _matches.where((item) {
        final title = _buildMatchTitle(item).toLowerCase();
        final opponent = _s(item["opponent"]).toLowerCase();
        final competition = _s(item["competition_name"]).toLowerCase();
        final eventType =
            _eventTypeLabel(_s(item["event_type"])).toLowerCase();
        final date = _s(item["match_date"]).toLowerCase();

        return title.contains(query) ||
            opponent.contains(query) ||
            competition.contains(query) ||
            eventType.contains(query) ||
            date.contains(query);
      }).toList();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showUploadVideoSheet(Map<String, dynamic> match) async {
    final notesCtrl = TextEditingController(
      text: _s(match["notes"]),
    );

    XFile? pickedVideo;
    XFile? pickedThumb;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isTablet = MediaQuery.of(ctx).size.width > 700;

        return StatefulBuilder(
          builder: (ctx, setSB) {
            Future<void> pickVideo() async {
              final x = await ImagePicker().pickVideo(
                source: ImageSource.gallery,
              );
              if (x != null) {
                setSB(() => pickedVideo = x);
              }
            }

            Future<void> pickThumb() async {
              final x = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: 1400,
              );
              if (x != null) {
                setSB(() => pickedThumb = x);
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: isTablet ? 24 : 16,
                  right: isTablet ? 24 : 16,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Загрузить видео матча",
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _buildMatchTitle(match),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: "Комментарий к видео",
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: isTablet ? 240 : double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: pickVideo,
                              icon: const Icon(Icons.video_library_outlined),
                              label: Text(
                                pickedVideo == null
                                    ? "Выбрать видео"
                                    : "Видео выбрано",
                              ),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: isTablet ? 240 : double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: pickThumb,
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                pickedThumb == null
                                    ? "Выбрать превью"
                                    : "Превью выбрано",
                              ),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _uploading
                              ? null
                              : () async {
                                  if (pickedVideo == null) {
                                    Get.snackbar(
                                      "Ошибка",
                                      "Сначала выберите видео матча",
                                    );
                                    return;
                                  }

                                  Navigator.pop(ctx);

                                  await _uploadVideoForMatch(
                                    matchId: int.tryParse(_s(match["id"])) ?? 0,
                                    notes: notesCtrl.text.trim(),
                                    video: File(pickedVideo!.path),
                                    thumbnail: pickedThumb != null
                                        ? File(pickedThumb!.path)
                                        : null,
                                  );
                                },
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: Text(
                            _uploading ? "Загрузка..." : "Сохранить видео",
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _uploadVideoForMatch({
    required int matchId,
    required String notes,
    required File video,
    File? thumbnail,
  }) async {
    if (matchId <= 0) {
      Get.snackbar("Ошибка", "Некорректный match_id");
      return;
    }

    if (mounted) {
      setState(() => _uploading = true);
    }

    try {
      final result = await uploadMatchVideo(
        matchId: matchId,
        teamId: widget.teamId,
        coachId: _coachId,
        video: video,
        thumbnail: thumbnail,
        notes: notes,
      );

      if (result["success"] == true) {
        Get.snackbar("Готово", "Видео прикреплено к матчу");
        await _loadMatches();
      } else {
        Get.snackbar(
          "Ошибка",
          _s(result["message"]).isNotEmpty
              ? _s(result["message"])
              : "Не удалось загрузить видео",
        );
      }
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");
      Get.snackbar("Ошибка", "Сбой при загрузке видео");
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Widget _buildSearchBar(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: "Поиск по матчу, сопернику, турниру, дате",
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                _applySearch();
              },
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 22 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Видеоанализ команды",
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 26 : 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.teamName,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _infoChip(Icons.groups_2_outlined, "Команда выбрана"),
              _infoChip(
                Icons.sports_soccer_outlined,
                "${_matches.length} матчей",
              ),
              _infoChip(Icons.video_library_outlined, "Видеоразбор"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> item, bool isTablet) {
    final matchId = int.tryParse(_s(item["id"])) ?? 0;
    final title = _buildMatchTitle(item);
    final opponent = _s(item["opponent"]);
    final competition = _s(item["competition_name"]);
    final date = _s(item["match_date"]);
    final eventType = _eventTypeLabel(_s(item["event_type"]));
    final thumb = _normalizeUrl(_s(item["thumbnail_url"]));
    final videoUrl = _normalizeUrl(_s(item["video_url"])) ?? "";
    final hasVideo = videoUrl.isNotEmpty;

    final score =
        "${_s(item["our_score"]).isEmpty ? "0" : _s(item["our_score"])}:"
        "${_s(item["opponent_score"]).isEmpty ? "0" : _s(item["opponent_score"])}";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: const Color(0xFF111827),
                    child: thumb != null && thumb.isNotEmpty
                        ? Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.sports_soccer_rounded,
                                color: Colors.white,
                                size: 60,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.sports_soccer_rounded,
                              color: Colors.white,
                              size: 60,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: hasVideo
                            ? Colors.green.withOpacity(0.9)
                            : Colors.orange.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        hasVideo ? "Видео есть" : "Без видео",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 16 : 14,
              14,
              isTablet ? 16 : 14,
              isTablet ? 16 : 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "$eventType • Счёт $score",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (competition.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    competition,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (opponent.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Соперник: $opponent",
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: hasVideo
                          ? ElevatedButton.icon(
                              onPressed: () {
                                Get.to(
                                  () => VideoMatchReviewScreen(
                                    matchId: matchId,
                                    teamId: widget.teamId,
                                    teamName: widget.teamName,
                                    coachId: _coachId,
                                    matchTitle: title,
                                    videoUrl: videoUrl,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.play_circle_outline),
                              label: const Text("Открыть разбор"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => _showUploadVideoSheet(item),
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text("Загрузить видео"),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                    ),
                    if (hasVideo) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showUploadVideoSheet(item),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text("Обновить видео"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 28 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.video_library_outlined,
            size: isTablet ? 64 : 52,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            _searchCtrl.text.trim().isEmpty
                ? "Пока нет добавленных матчей"
                : "Ничего не найдено",
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchCtrl.text.trim().isEmpty
                ? "Сначала добавь матчи команды в разделе «Матчи», после этого здесь можно будет прикрепить видео и открыть разбор."
                : "Попробуй изменить поисковый запрос",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 800;
    final crossAxisCount = isTablet ? 3 : 2;
    final childAspectRatio = isTablet ? 0.95 : 0.84;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Видеоанализ",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: isTablet ? 24 : 20,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Обновить",
            onPressed: _loadMatches,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMatches,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 24 : 16,
                  8,
                  isTablet ? 24 : 16,
                  90,
                ),
                children: [
                  _buildTopHeader(isTablet),
                  const SizedBox(height: 16),
                  _buildSearchBar(isTablet),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Матчи команды",
                          style: TextStyle(
                            fontSize: isTablet ? 22 : 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        "Найдено: ${_filteredMatches.length}",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_filteredMatches.isEmpty)
                    _buildEmpty(isTablet)
                  else
                    GridView.builder(
                      itemCount: _filteredMatches.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (_, i) =>
                          _buildMatchCard(_filteredMatches[i], isTablet),
                    ),
                ],
              ),
            ),
    );
  }
}