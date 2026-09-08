import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/utils/confirm_dialogs.dart';

import 'training_lifecycle_api.dart';

/// Открывает оценки как независимое CMR-окно поверх всего приложения.
/// Это не bottom sheet и не переход на отдельный экран: окно можно двигать,
/// свернуть, развернуть и закрыть, как внутреннее desktop-окно.
Future<void> showTrainingRatingWindow(
  BuildContext context, {
  required String apiBase,
  required int teamId,
  required int eventId,
  required int coachId,
  required String title,
  int clubId = 0,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  late OverlayEntry entry;

  void closeWindow() {
    if (entry.mounted) entry.remove();
    if (!completer.isCompleted) completer.complete();
  }

  entry = OverlayEntry(
    builder: (_) => _TrainingRatingRightPane(
      apiBase: apiBase,
      teamId: teamId,
      eventId: eventId,
      coachId: coachId,
      title: title,
      clubId: clubId,
      onClose: closeWindow,
    ),
  );

  overlay.insert(entry);
  return completer.future;
}

/// Совместимость со старыми точками входа.
/// Вместо плавающей модалки оценки открываются справа как рабочая панель.
class _TrainingRatingRightPane extends StatefulWidget {
  final String apiBase;
  final int teamId;
  final int eventId;
  final int coachId;
  final String title;
  final int clubId;
  final VoidCallback onClose;

  const _TrainingRatingRightPane({
    required this.apiBase,
    required this.teamId,
    required this.eventId,
    required this.coachId,
    required this.title,
    this.clubId = 0,
    required this.onClose,
  });

  @override
  State<_TrainingRatingRightPane> createState() => _TrainingRatingRightPaneState();
}

class _TrainingRatingRightPaneState extends State<_TrainingRatingRightPane> {
  bool _headerExpanded = true;

  void _setHeaderExpanded(bool expanded) {
    if (_headerExpanded == expanded || !mounted) return;
    setState(() => _headerExpanded = expanded);
  }

  Widget _windowHeader() {
    if (!_headerExpanded) {
      return Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => _setHeaderExpanded(true),
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
              child: Row(
                children: [
                  const _RatingBrandDots(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Оценки · ${widget.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.formLabel(
                        color: const Color(0xFF0B0F14),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: Color(0xFF667085),
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: const Color(0xFFF7F8F7),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: widget.onClose,
                      borderRadius: BorderRadius.circular(8),
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 58,
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      color: Colors.white,
      child: Row(
        children: [
          const _RatingBrandDots(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Оценки тренировки',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subsectionTitle(
                    color: const Color(0xFF0B0F14),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: const Color(0xFFF7F8F7),
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(9),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF667085),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableWidth = math.max(300.0, media.size.width - 16.0).toDouble();
    final double width;
    if (media.size.width < 600) {
      width = availableWidth;
    } else if (media.size.width < 1100) {
      width = math.min(760.0, availableWidth).toDouble();
    } else {
      width = math.min(
        860.0,
        math.min(availableWidth, math.max(680.0, media.size.width * .52)),
      ).toDouble();
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            top: media.padding.top + 8,
            right: 8,
            bottom: media.padding.bottom + 8,
            width: width,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.10),
                    blurRadius: 34,
                    spreadRadius: -18,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 190),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _windowHeader(),
                  ),
                  Expanded(
                    child: TrainingRatingSheet(
                      apiBase: widget.apiBase,
                      teamId: widget.teamId,
                      eventId: widget.eventId,
                      coachId: widget.coachId,
                      title: widget.title,
                      clubId: widget.clubId,
                      embedded: true,
                      onClose: widget.onClose,
                      onChromeExpandedChanged: _setHeaderExpanded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBrandDot extends StatelessWidget {
  final double size;
  final double opacity;
  final Color color;
  final bool glow;

  const _RatingBrandDot({
    required this.size,
    required this.opacity,
    this.color = const Color(0xFF14915D),
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: color.withOpacity(.18),
                    blurRadius: size * 1.9,
                    spreadRadius: .25,
                  ),
                  BoxShadow(
                    color: color.withOpacity(.08),
                    blurRadius: size * 3.2,
                    spreadRadius: .6,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _RatingBrandDots extends StatelessWidget {
  final Color color;
  const _RatingBrandDots({this.color = const Color(0xFF14915D)});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RatingBrandDot(size: 3.5, opacity: .22, color: color),
        const SizedBox(width: 3),
        _RatingBrandDot(size: 4.5, opacity: .42, color: color),
        const SizedBox(width: 3),
        _RatingBrandDot(size: 5.5, opacity: .68, color: color),
        const SizedBox(width: 3),
        _RatingBrandDot(size: 6.5, opacity: 1, color: color, glow: true),
      ],
    );
  }
}

class TrainingRatingSheet extends StatefulWidget {
  final String apiBase;
  final int teamId;
  final int eventId;
  final int coachId;
  final String title;
  final int clubId;
  final VoidCallback? onClose;
  final bool embedded;
  final VoidCallback? onSaved;
  final ValueChanged<bool>? onChromeExpandedChanged;

  const TrainingRatingSheet({
    super.key,
    required this.apiBase,
    required this.teamId,
    required this.eventId,
    required this.coachId,
    required this.title,
    this.clubId = 0,
    this.onClose,
    this.embedded = false,
    this.onSaved,
    this.onChromeExpandedChanged,
  });

  @override
  State<TrainingRatingSheet> createState() => _TrainingRatingSheetState();
}

class _TrainingRatingSheetState extends State<TrainingRatingSheet> {
  bool loading = true;
  bool saving = false;
  String? error;

  bool _windowMaximized = false;
  bool _windowMinimized = false;
  Offset? _windowOffset;

  List<_Player> players = [];
  final Map<int, int> ratingByPlayerId = {};
  final TextEditingController _noteC = TextEditingController();
  TrainingLifecycleState lifecycle = const TrainingLifecycleState();
  bool lifecycleSaving = false;
  bool _ratingsSaved = false;

  // На планшете и ПК верхняя служебная часть окна оценок автоматически
  // освобождает место списку игроков при прокрутке вниз и возвращается
  // при движении вверх.
  bool _ratingsChromeExpanded = true;
  double _ratingsLastScrollPixels = 0;

  Color get primary => _WinColors.green;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteC.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _setRatingsChromeExpanded(bool expanded) {
    if (_ratingsChromeExpanded == expanded || !mounted) return;
    setState(() => _ratingsChromeExpanded = expanded);
    widget.onChromeExpandedChanged?.call(expanded);
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      _ratingsChromeExpanded = true;
      _ratingsLastScrollPixels = 0;
    });
    widget.onChromeExpandedChanged?.call(true);

    try {
      players = await _fetchPlayers(widget.teamId);
      final existing = await _fetchRatings(widget.eventId);

      ratingByPlayerId.clear();
      ratingByPlayerId.addAll(existing);

      for (final p in players) {
        ratingByPlayerId.putIfAbsent(p.id, () => 0);
      }

      lifecycle = await TrainingLifecycleApi(
        apiBase: widget.apiBase,
        clubId: widget.clubId,
        teamId: widget.teamId,
        eventId: widget.eventId,
      ).load();
      _noteC.text = lifecycle.coachNote;
      final ratedCount = existing.values.where((value) => value > 0).length;
      _ratingsSaved = lifecycle.attendancePresent > 0
          ? ratedCount >= lifecycle.attendancePresent
          : ratedCount > 0;
    } catch (e) {
      error = e.toString();
    }

    if (mounted) setState(() => loading = false);
  }

  Future<List<_Player>> _fetchPlayers(int teamId) async {
    final url = Uri.parse('${widget.apiBase}/get_players_by_team.php?team_id=$teamId');
    final r = await http.get(url);
    if (r.statusCode != 200) throw 'players http ${r.statusCode}';

    final data = jsonDecode(r.body);
    final list = (data is Map ? (data['players'] ?? data['data'] ?? []) : []) as List;

    return list.map((x) {
      final m = (x as Map).map((k, v) => MapEntry(k.toString(), v));
      return _Player(
        id: _asInt(m['id'] ?? m['player_id']),
        firstName: (m['first_name'] ?? m['name'] ?? '').toString(),
        lastName: (m['last_name'] ?? m['surname'] ?? '').toString(),
        position: (m['position'] ?? '').toString(),
        photo: (m['photo_url'] ?? m['photo'] ?? '').toString(),
      );
    }).where((p) => p.id > 0).toList();
  }

  Future<Map<int, int>> _fetchRatings(int eventId) async {
    final url = Uri.parse('${widget.apiBase}/get_training_ratings.php?event_id=$eventId');
    final r = await http.get(url);
    if (r.statusCode != 200) throw 'ratings http ${r.statusCode}';

    final data = jsonDecode(r.body);
    if (data is Map && data['success'] == false) {
      throw (data['message'] ?? 'ratings error').toString();
    }

    final list = (data is Map ? (data['ratings'] ?? []) : []) as List;
    final out = <int, int>{};

    for (final x in list) {
      final m = (x as Map).map((k, v) => MapEntry(k.toString(), v));
      final pid = _asInt(m['player_id']);
      final rt = _asInt(m['rating']).clamp(0, 5);
      if (pid > 0) out[pid] = rt;
    }

    return out;
  }

  Future<void> _save() async {
    if (saving) return;
    if (!lifecycle.started) {
      Get.snackbar(
        'Тренировка',
        'Сначала начните тренировку во вкладке «Обзор»',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    setState(() => saving = true);

    try {
      final payload = {
        'team_id': widget.teamId,
        'event_id': widget.eventId,
        'coach_id': widget.coachId,
        'ratings': players.map((p) => {
          'player_id': p.id,
          'rating': (ratingByPlayerId[p.id] ?? 0).clamp(0, 5),
        }).toList(),
      };

      final url = Uri.parse('${widget.apiBase}/save_training_ratings.php');
      final r = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (r.statusCode != 200) throw 'save http ${r.statusCode}';

      final data = jsonDecode(r.body);
      if (data is Map && data['success'] != true) {
        throw (data['message'] ?? 'save error').toString();
      }

      final nextLifecycle = await TrainingLifecycleApi(
        apiBase: widget.apiBase,
        clubId: widget.clubId,
        teamId: widget.teamId,
        eventId: widget.eventId,
      ).markRatingsSaved(userId: widget.coachId);

      final required = nextLifecycle.attendancePresent;
      final complete = required > 0
          ? nextLifecycle.ratingsCount >= required
          : nextLifecycle.ratingsCount > 0;
      if (mounted) {
        setState(() {
          lifecycle = nextLifecycle;
          _ratingsSaved = complete;
        });
      }
      Get.snackbar(
        'Оценка',
        complete
            ? 'Оценки сохранены. Теперь можно завершить тренировку.'
            : 'Оценки сохранены: ${nextLifecycle.ratingsCount}/${nextLifecycle.attendancePresent}. Оцените всех присутствующих.',
        snackPosition: SnackPosition.BOTTOM,
      );
      widget.onSaved?.call();
    } catch (e) {
      Get.snackbar('Ошибка', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }

    if (mounted) setState(() => saving = false);
  }


  Future<void> _finishTraining() async {
    if (lifecycleSaving || lifecycle.finished) return;
    if (!lifecycle.started) {
      Get.snackbar(
        'Тренировка',
        'Сначала начните тренировку во вкладке «Обзор»',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!_ratingsSaved) {
      Get.snackbar(
        'Тренировка',
        'Сначала сохраните оценки игроков',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => lifecycleSaving = true);
    try {
      final next = await TrainingLifecycleApi(
        apiBase: widget.apiBase,
        clubId: widget.clubId,
        teamId: widget.teamId,
        eventId: widget.eventId,
      ).finish(
        userId: widget.coachId,
        coachNote: _noteC.text.trim(),
      );
      if (!mounted) return;
      setState(() => lifecycle = next);
      widget.onSaved?.call();
      Get.snackbar(
        'Тренировка',
        '${next.finishedByLabel} завершил тренировку. Итоги сохранены, клубный администратор получил уведомление.',
        snackPosition: SnackPosition.BOTTOM,
      );
      if (widget.onClose != null) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        _close();
      }
    } catch (e) {
      Get.snackbar(
        'Ошибка',
        'Не удалось завершить тренировку: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => lifecycleSaving = false);
    }
  }

  Widget _bottomActions() {
    final finishEnabled = lifecycle.started &&
        !lifecycle.finished &&
        _ratingsSaved &&
        !saving &&
        !lifecycleSaving;

    final finishText = lifecycle.finished
        ? 'Тренировка окончена'
        : !_ratingsSaved
            ? 'Сохраните оценки — затем окончите тренировку'
            : 'Окончить тренировку';

    return _CmrBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _GhostButton(
                  text: saving ? 'Сброс...' : 'Сбросить',
                  icon: Icons.restart_alt_rounded,
                  onTap: saving || lifecycle.finished ? null : _resetRatings,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PrimaryButton(
                  text: _ratingsSaved ? 'Оценки сохранены' : 'Сохранить оценки',
                  saving: saving,
                  onTap: saving || lifecycle.finished ? null : _save,
                ),
              ),
            ],
          ),
          if (lifecycle.started || lifecycle.finished) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: finishEnabled ? _finishTraining : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _WinColors.greenDark,
                  disabledBackgroundColor: const Color(0xFFE9ECEA),
                  disabledForegroundColor: const Color(0xFF8A9099),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: lifecycleSaving
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        lifecycle.finished
                            ? Icons.check_circle_rounded
                            : Icons.stop_circle_outlined,
                        size: 20,
                      ),
                label: Text(
                  finishText,
                  style: AppTypography.action(
                    color: finishEnabled ? Colors.white : const Color(0xFF8A9099),
                  ).copyWith(fontSize: 12.6, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Column(
        children: [
          Expanded(child: _buildRatingsBody()),
          _bottomActions(),
        ],
      );
    }

    final media = MediaQuery.of(context);
    final size = media.size;
    final bottomInset = media.viewInsets.bottom;

    if (_windowMinimized) {
      return Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              left: 18,
              bottom: 18 + bottomInset,
              child: _CmrMinimizedPill(
                icon: Icons.star_rate_rounded,
                title: 'Оценки тренировки',
                onRestore: () => setState(() => _windowMinimized = false),
                onClose: _close,
              ),
            ),
          ],
        ),
      );
    }

    final isCompact = size.width < 840;
    final windowWidth = _windowMaximized
        ? math.max(320.0, size.width - 28)
        : math.min(isCompact ? size.width - 22 : 900.0, size.width - 28);
    final windowHeight = _windowMaximized
        ? math.max(420.0, size.height - 28 - bottomInset)
        : math.min(isCompact ? size.height - 32 - bottomInset : 720.0, size.height - 36 - bottomInset);

    final defaultOffset = Offset(
      math.max(10, (size.width - windowWidth) / 2),
      math.max(10, (size.height - bottomInset - windowHeight) / 2),
    );

    final currentOffset = _windowMaximized
        ? const Offset(14, 14)
        : _clampOffset(_windowOffset ?? defaultOffset, Size(windowWidth, windowHeight), Size(size.width, size.height - bottomInset));

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            left: currentOffset.dx,
            top: currentOffset.dy,
            width: windowWidth,
            height: windowHeight,
            child: _CmrWindowFrame(
              icon: Icons.star_rate_rounded,
              title: 'Оценки тренировки',
              subtitle: widget.title,
              maximized: _windowMaximized,
              onClose: _close,
              onMinimize: () => setState(() => _windowMinimized = true),
              onToggleMaximize: () => setState(() {
                if (_windowMaximized) {
                  _windowMaximized = false;
                } else {
                  _windowOffset = currentOffset;
                  _windowMaximized = true;
                }
              }),
              onDrag: (delta) {
                if (_windowMaximized) return;
                setState(() {
                  _windowOffset = _clampOffset(
                    (_windowOffset ?? defaultOffset) + delta,
                    Size(windowWidth, windowHeight),
                    Size(size.width, size.height - bottomInset),
                  );
                });
              },
              child: Column(
                children: [
                  Expanded(child: _buildRatingsBody()),
                  _bottomActions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Offset _clampOffset(Offset offset, Size windowSize, Size bounds) {
    final maxX = math.max(8.0, bounds.width - windowSize.width - 8);
    final maxY = math.max(8.0, bounds.height - windowSize.height - 8);
    return Offset(
      offset.dx.clamp(8.0, maxX),
      offset.dy.clamp(8.0, maxY),
    );
  }

  Future<void> _resetRatings() async {
    final ok = await showResetConfirmDialog(
      context,
      title: 'Сбросить оценки?',
      description: 'Все оценки игроков за эту тренировку будут обнулены.\nОтменить будет невозможно.',
    );

    if (!ok || !mounted) return;

    setState(() {
      for (final p in players) {
        ratingByPlayerId[p.id] = 0;
      }
      _ratingsSaved = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Оценки сброшены')),
    );
  }

  bool _handleRatingsScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    final pixels = notification.metrics.pixels;

    if (notification is ScrollStartNotification) {
      _ratingsLastScrollPixels = pixels;
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ??
          (pixels - _ratingsLastScrollPixels);
      _ratingsLastScrollPixels = pixels;

      if (delta > 3.5 && pixels > 34) {
        _setRatingsChromeExpanded(false);
      }

      // Не разворачиваем окно оценок от первого же движения вверх. Шапка
      // возвращается только когда список дошёл примерно до первых двух игроков.
      if (delta < -3.0 && pixels <= 105) {
        _setRatingsChromeExpanded(true);
      }
    }

    if (pixels <= 4 && !_ratingsChromeExpanded) {
      _setRatingsChromeExpanded(true);
    }

    return false;
  }

  Widget _ratingsExpandedChrome() {
    final rated = ratingByPlayerId.values.where((v) => v > 0).length;
    final avg = _averageRating();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _RatingBrandDots(),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Оценки игроков',
                        style: AppTypography.subsectionTitle(
                          color: const Color(0xFF0B0F14),
                        ),
                      ),
                    ),
                    Text(
                      '$rated/${players.length}',
                      style: AppTypography.captionMedium(
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _RatingSummaryItem(
                        title: 'Игроков',
                        value: '${players.length}',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: const Color(0xFFE9ECEA),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RatingSummaryItem(
                        title: 'Оценено',
                        value: '$rated',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: const Color(0xFFE9ECEA),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RatingSummaryItem(
                        title: 'Средняя',
                        value: avg <= 0 ? '—' : avg.toStringAsFixed(1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildRatingsLifecycleBanner(),
        ],
      ),
    );
  }

  Widget _buildRatingsLifecycleBanner() {
    final bannerColor = lifecycle.finished
        ? _WinColors.tint(_WinColors.green, opacity: .08)
        : lifecycle.started
            ? _WinColors.tint(_WinColors.green, opacity: .055)
            : const Color(0xFFF8FAF9);
    final icon = lifecycle.finished
        ? Icons.check_circle_rounded
        : lifecycle.started
            ? Icons.play_circle_fill_rounded
            : Icons.schedule_rounded;
    final iconColor = lifecycle.finished
        ? _WinColors.green
        : lifecycle.started
            ? _WinColors.greenDark
            : _WinColors.muted2;
    final statusTitle = lifecycle.finished
        ? 'Тренировка завершена'
        : lifecycle.started
            ? (_ratingsSaved ? 'Оценки сохранены' : 'Тренировка идёт')
            : 'Сначала начните тренировку';
    final description = lifecycle.finished
        ? 'Итоги сохранены · ${lifecycle.finishedByLabel}'
        : lifecycle.started
            ? (_ratingsSaved
                ? 'Все оценки сохранены. Теперь тренировку можно окончить.'
                : 'Поставьте оценки игрокам и нажмите «Сохранить оценки».')
            : 'Сначала заполните «Журнал», затем начните тренировку во вкладке «Обзор».';
    final statusPill = lifecycle.finished
        ? 'ОКОНЧЕНА'
        : lifecycle.started
            ? (_ratingsSaved ? 'ГОТОВО' : 'ИДЁТ')
            : 'ЖУРНАЛ';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.72),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: AppTypography.formLabel(
                        color: const Color(0xFF0B0F14),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.captionMedium(
                        color: const Color(0xFF475467),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.74),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusPill,
                  style: AppTypography.captionMedium(
                    color: lifecycle.started || lifecycle.finished
                        ? _WinColors.greenDark
                        : const Color(0xFF667085),
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (!lifecycle.started) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.66),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_back_rounded,
                    size: 16,
                    color: Color(0xFF667085),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Сначала заполните «Журнал», затем запустите тренировку во вкладке «Обзор».',
                      style: AppTypography.captionMedium(
                        color: const Color(0xFF475467),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoachNoteCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: lifecycle.finished
              ? const Color(0xFFF7FBF8)
              : const Color(0xFFF7F8F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  lifecycle.finished
                      ? Icons.check_circle_rounded
                      : Icons.notes_rounded,
                  size: 17,
                  color: _WinColors.green,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Заметка тренера / итоги тренировки',
                    style: AppTypography.formLabel(
                      color: const Color(0xFF0B0F14),
                    ),
                  ),
                ),
                Text(
                  lifecycle.finished
                      ? 'ЗАВЕРШЕНА'
                      : lifecycle.started
                          ? 'ИДЁТ'
                          : 'НЕ НАЧАТА',
                  style: AppTypography.captionMedium(
                    color: lifecycle.started
                        ? _WinColors.green
                        : const Color(0xFF667085),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteC,
              enabled: !lifecycle.finished,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Что получилось, над чем работать, индивидуальные замечания...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(
                    color: _WinColors.green.withOpacity(.22),
                    width: .8,
                  ),
                ),
              ),
              style: AppTypography.formText(
                color: const Color(0xFF0B0F14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingsCollapsedChrome() {
    final rated = ratingByPlayerId.values.where((v) => v > 0).length;
    final avg = _averageRating();
    final stateLabel = lifecycle.finished
        ? 'Окончена'
        : lifecycle.started
            ? 'Идёт'
            : 'Не начата';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _setRatingsChromeExpanded(true),
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const _RatingBrandDots(),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Оценено $rated/${players.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.formLabel(
                      color: const Color(0xFF0B0F14),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _WinColors.tint(_WinColors.green, opacity: .065),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stateLabel,
                    style: AppTypography.captionMedium(
                      color: _WinColors.greenDark,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _WinColors.tint(_WinColors.green, opacity: .04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    avg <= 0 ? 'Средняя —' : 'Средняя ${avg.toStringAsFixed(1)}',
                    style: AppTypography.captionMedium(
                      color: _WinColors.greenDark,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Color(0xFF667085),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: _WinColors.green, strokeWidth: 2.4));
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _ErrorView(text: error!, onRetry: _load),
      );
    }

    if (players.isEmpty) {
      return Center(
        child: Text('В команде пока нет игроков для оценки', style: _WinText.muted(12.2)),
      );
    }

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 210),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _ratingsChromeExpanded
              ? _ratingsExpandedChrome()
              : _ratingsCollapsedChrome(),
        ),
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleRatingsScrollNotification,
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  12,
                  _ratingsChromeExpanded ? 0 : 2,
                  12,
                  18,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: players.length + 1,
                itemBuilder: (_, i) {
                  if (i == players.length) {
                    return _buildCoachNoteCard();
                  }

                  final p = players[i];
                  final r = ratingByPlayerId[p.id] ?? 0;

                  return _PlayerRow(
                    primary: primary,
                    p: p,
                    rating: r,
                    onChanged: (v) => setState(() {
                      ratingByPlayerId[p.id] = v;
                      _ratingsSaved = false;
                    }),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _averageRating() {
    final values = ratingByPlayerId.values.where((v) => v > 0).toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}

class _CmrWindowFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool maximized;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final ValueChanged<Offset> onDrag;
  final Widget child;

  const _CmrWindowFrame({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.maximized,
    required this.onClose,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onDrag,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final radius = maximized ? 20.0 : 26.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.10),
              blurRadius: 38,
              spreadRadius: -20,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => onDrag(d.delta),
              child: Container(
                height: 50,
                padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  
                ),
                child: Row(
                  children: [
                    _RoundWindowButton(icon: Icons.close_rounded, onTap: onClose),
                    const SizedBox(width: 7),
                    _RoundWindowButton(icon: Icons.remove_rounded, onTap: onMinimize),
                    const SizedBox(width: 7),
                    _RoundWindowButton(
                      icon: maximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
                      onTap: onToggleMaximize,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _WinColors.tint(_WinColors.green, opacity: .075),
                        borderRadius: BorderRadius.circular(14),
                                    ),
                      child: Icon(icon, color: _WinColors.green, size: 13),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _WinText.title(12.6)),
                          const SizedBox(height: 2),
                          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _WinText.muted(10.0)),
                        ],
                      ),
                    ),
                    const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _RatingSummaryItem extends StatelessWidget {
  final String title;
  final String value;

  const _RatingSummaryItem({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: _WinText.title(13.8),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _WinText.muted(9.8),
        ),
      ],
    );
  }
}

class _RatingsSummaryBar extends StatelessWidget {
  final int playersCount;
  final int ratedCount;
  final double avg;

  const _RatingsSummaryBar({
    required this.playersCount,
    required this.ratedCount,
    required this.avg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        
      ),
      child: Row(
        children: [
          Expanded(child: _MiniStat(icon: Icons.groups_rounded, label: 'Игроки', value: '$playersCount')),
          const SizedBox(width: 8),
          Expanded(child: _MiniStat(icon: Icons.check_circle_rounded, label: 'Оценено', value: '$ratedCount')),
          const SizedBox(width: 8),
          Expanded(child: _MiniStat(icon: Icons.star_rate_rounded, label: 'Средняя', value: avg <= 0 ? '—' : avg.toStringAsFixed(1))),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F7),
        borderRadius: BorderRadius.circular(10),
              ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _WinColors.tint(_WinColors.green, opacity: .085),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: _WinColors.green, size: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _WinText.title(13.0)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _WinText.muted(9.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CmrBottomBar extends StatelessWidget {
  final Widget child;
  const _CmrBottomBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        
      ),
      child: child,
    );
  }
}

class _RoundWindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundWindowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: _WinColors.slate, size: 14),
      ),
    );
  }
}

class _CmrMinimizedPill extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onRestore;
  final VoidCallback onClose;

  const _CmrMinimizedPill({
    required this.icon,
    required this.title,
    required this.onRestore,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 24, spreadRadius: -14, offset: const Offset(0, 14))],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _WinColors.tint(_WinColors.green, opacity: .075),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _WinColors.green, size: 13),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _WinText.title(13.0))),
          _RoundWindowButton(icon: Icons.open_in_full_rounded, onTap: onRestore),
          const SizedBox(width: 6),
          _RoundWindowButton(icon: Icons.close_rounded, onTap: onClose),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final Color primary;
  final _Player p;
  final int rating;
  final ValueChanged<int> onChanged;

  const _PlayerRow({
    required this.primary,
    required this.p,
    required this.rating,
    required this.onChanged,
  });

  String fio() {
    final a = [p.firstName.trim(), p.lastName.trim()].where((x) => x.isNotEmpty).toList();
    return a.isEmpty ? 'Игрок #${p.id}' : a.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final initials = fio().substring(0, 1).toUpperCase();
    final rated = rating > 0;

    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: rated
            ? _WinColors.tint(primary, opacity: .032)
            : Colors.white,
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFFE9ECEA),
            width: .65,
          ),
        ),
      ),
      child: Row(
        children: [
          _RatingBrandDot(
            size: 6,
            opacity: rated ? 1 : .28,
            color: rated ? primary : const Color(0xFF98A2B3),
            glow: rated,
          ),
          const SizedBox(width: 9),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: p.photo.trim().isEmpty ? _WinColors.tint(primary, opacity: .12) : const Color(0xFFF3F5F7),
              shape: BoxShape.circle,
              image: p.photo.trim().isNotEmpty ? DecorationImage(image: NetworkImage(p.photo), fit: BoxFit.cover) : null,
            ),
            child: p.photo.trim().isEmpty
                ? Center(child: Text(initials, style: _WinText.base(12.0, FontWeight.w600, primary, height: 1)))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(fio(), maxLines: 1, overflow: TextOverflow.ellipsis, style: _WinText.title(11.8)),
                const SizedBox(height: 2),
                Text(
                  p.position.trim().isEmpty ? 'позиция не указана' : p.position,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _WinText.muted(10.0),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Stars(activeColor: primary, value: rating, onChanged: onChanged),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final Color activeColor;
  final int value;
  final ValueChanged<int> onChanged;

  const _Stars({
    required this.activeColor,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget star(int i) {
      final filled = i <= value;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(i),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? activeColor : const Color(0xFF9CA3AF),
            size: 20,
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [for (int i = 1; i <= 5; i++) star(i)]);
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool saving;
  final VoidCallback? onTap;

  const _PrimaryButton({required this.text, required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: _WinColors.tint(_WinColors.green, opacity: .075),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Center(
          child: saving
              ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: _WinColors.green))
              : Text(text, style: _WinText.base(11.4, FontWeight.w600, _WinColors.green, height: 1)),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const _GhostButton({required this.text, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F9),
          borderRadius: BorderRadius.circular(13),
          ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _WinColors.slate, size: 15),
            const SizedBox(width: 7),
            Text(text, style: _WinText.base(11.2, FontWeight.w600, _WinColors.slate, height: 1)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _ErrorView({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _WinColors.tint(_WinColors.red, opacity: .055),
        borderRadius: BorderRadius.circular(16),
              ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: _WinText.base(11.2, FontWeight.w600, _WinColors.red)),
          const SizedBox(height: 10),
          _GhostButton(text: 'Повторить', icon: Icons.refresh_rounded, onTap: onRetry),
        ],
      ),
    );
  }
}

class _WinColors {
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF5F6670);
  static const Color muted2 = Color(0xFF8A9099);
  static const Color green = Color(0xFF14915D);
  static const Color greenDark = Color(0xFF315447);
  static const Color slate = Color(0xFF64748B);
  static const Color red = Color(0xFFB96D6D);

  static Color tint(Color color, {double opacity = .075}) => Color.alphaBlend(color.withOpacity(opacity), Colors.white);
}

class _WinText {
  static TextStyle base(double size, FontWeight weight, Color color, {double height = 1.18}) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: height,
      letterSpacing: 0,
    );
  }

  static TextStyle title(double size) => AppTypography.sectionTitle(color: _WinColors.text);
  static TextStyle muted(double size) => AppTypography.secondary(color: _WinColors.muted2);
}

class _Player {
  final int id;
  final String firstName;
  final String lastName;
  final String position;
  final String photo;

  _Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.position,
    required this.photo,
  });
}

int _asInt(dynamic v) => v is int ? v : int.tryParse((v ?? '').toString()) ?? 0;
