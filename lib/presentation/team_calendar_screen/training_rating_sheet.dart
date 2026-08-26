import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/utils/confirm_dialogs.dart';

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
      onClose: closeWindow,
    ),
  );

  overlay.insert(entry);
  return completer.future;
}

/// Совместимость со старыми точками входа.
/// Вместо плавающей модалки оценки открываются справа как рабочая панель.
class _TrainingRatingRightPane extends StatelessWidget {
  final String apiBase;
  final int teamId;
  final int eventId;
  final int coachId;
  final String title;
  final VoidCallback onClose;

  const _TrainingRatingRightPane({
    required this.apiBase,
    required this.teamId,
    required this.eventId,
    required this.coachId,
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(520.0, math.max(320.0, media.size.width - 16)).toDouble();

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
                  Container(
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
                                title,
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
                            onTap: onClose,
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
                  ),
                  Expanded(
                    child: TrainingRatingSheet(
                      apiBase: apiBase,
                      teamId: teamId,
                      eventId: eventId,
                      coachId: coachId,
                      title: title,
                      embedded: true,
                      onClose: onClose,
                      onSaved: onClose,
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
    this.color = const Color(0xFF00A750),
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
  const _RatingBrandDots({this.color = const Color(0xFF00A750)});

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
  final VoidCallback? onClose;
  final bool embedded;
  final VoidCallback? onSaved;

  const TrainingRatingSheet({
    super.key,
    required this.apiBase,
    required this.teamId,
    required this.eventId,
    required this.coachId,
    required this.title,
    this.onClose,
    this.embedded = false,
    this.onSaved,
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

  Color get primary => _WinColors.green;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      players = await _fetchPlayers(widget.teamId);
      final existing = await _fetchRatings(widget.eventId);

      ratingByPlayerId.clear();
      ratingByPlayerId.addAll(existing);

      for (final p in players) {
        ratingByPlayerId.putIfAbsent(p.id, () => 0);
      }
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

      Get.snackbar('Оценка', 'Сохранено', snackPosition: SnackPosition.BOTTOM);
      widget.onSaved?.call();
      if (mounted && !widget.embedded) _close();
    } catch (e) {
      Get.snackbar('Ошибка', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }

    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Column(
        children: [
          Expanded(child: _buildRatingsBody()),
          _CmrBottomBar(
            child: Row(
              children: [
                Expanded(child: _GhostButton(text: saving ? 'Сброс...' : 'Сбросить', icon: Icons.restart_alt_rounded, onTap: saving ? null : _resetRatings)),
                const SizedBox(width: 10),
                Expanded(child: _PrimaryButton(text: 'Сохранить оценки', saving: saving, onTap: saving ? null : _save)),
              ],
            ),
          ),
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

    final isCompact = size.width < 760;
    final windowWidth = _windowMaximized
        ? math.max(320.0, size.width - 28)
        : math.min(isCompact ? size.width - 22 : 760.0, size.width - 28);
    final windowHeight = _windowMaximized
        ? math.max(420.0, size.height - 28 - bottomInset)
        : math.min(isCompact ? size.height - 32 - bottomInset : 620.0, size.height - 36 - bottomInset);

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
                  _CmrBottomBar(
                    child: Row(
                      children: [
                        Expanded(
                          child: _GhostButton(
                            text: saving ? 'Сброс...' : 'Сбросить',
                            icon: Icons.restart_alt_rounded,
                            onTap: saving ? null : _resetRatings,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PrimaryButton(
                            text: 'Сохранить оценки',
                            saving: saving,
                            onTap: saving ? null : _save,
                          ),
                        ),
                      ],
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
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Оценки сброшены')),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Row(
            children: [
              const _RatingBrandDots(),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Оценки игроков',
                  style: AppTypography.formLabel(
                    color: const Color(0xFF0B0F14),
                  ),
                ),
              ),
              Text(
                '${ratingByPlayerId.values.where((v) => v > 0).length}/${players.length}',
                style: AppTypography.captionMedium(
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),
        _RatingsSummaryBar(
          playersCount: players.length,
          ratedCount: ratingByPlayerId.values.where((v) => v > 0).length,
          avg: _averageRating(),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: players.length,
            itemBuilder: (_, i) {
              final p = players[i];
              final r = ratingByPlayerId[p.id] ?? 0;

              return _PlayerRow(
                primary: primary,
                p: p,
                rating: r,
                onChanged: (v) => setState(() => ratingByPlayerId[p.id] = v),
              );
            },
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
                        color: _WinColors.tint(_WinColors.green, opacity: .10),
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
      height: 58,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _WinColors.tint(_WinColors.green, opacity: .060),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _WinColors.tint(_WinColors.green, opacity: .12),
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
              color: _WinColors.tint(_WinColors.green, opacity: .10),
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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: rated
            ? _WinColors.tint(primary, opacity: .055)
            : const Color(0xFFF7F8F7),
        borderRadius: BorderRadius.circular(9),
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
          padding: const EdgeInsets.all(1),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? activeColor : const Color(0xFF9CA3AF),
            size: 18,
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
          color: _WinColors.tint(_WinColors.green, opacity: .10),
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
        border: Border.all(color: _WinColors.red.withOpacity(.12)),
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
  static const Color green = Color(0xFF00A750);
  static const Color slate = Color(0xFF64748B);
  static const Color red = Color(0xFFD92D20);

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
