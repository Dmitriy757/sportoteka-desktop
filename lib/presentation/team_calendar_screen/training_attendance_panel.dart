import 'dart:convert';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import 'training_lifecycle_api.dart';

class TrainingAttendancePanel extends StatefulWidget {
  final String apiBase;
  final int teamId;
  final int eventId;
  final int clubId;
  final String eventTitle;
  final VoidCallback? onOpenRatings;
  final ValueChanged<TrainingLifecycleState>? onLifecycleChanged;
  final ValueChanged<bool>? onChromeExpandedChanged;

  const TrainingAttendancePanel({
    super.key,
    required this.apiBase,
    required this.teamId,
    required this.eventId,
    this.clubId = 0,
    this.eventTitle = 'Тренировка',
    this.onOpenRatings,
    this.onLifecycleChanged,
    this.onChromeExpandedChanged,
  });

  @override
  State<TrainingAttendancePanel> createState() => _TrainingAttendancePanelState();
}

class _TrainingAttendancePanelState extends State<TrainingAttendancePanel> {
  static const Color _green = Color(0xFF14915D);
  static const Color _greenSoft = Color(0xFFF7FBF8);
  static const Color _line = Color(0xFFE5ECE8);
  static const Color _soft = Color(0xFFF8FAF9);
  static const Color _text = Color(0xFF0B0F14);
  static const Color _muted = Color(0xFF5F6670);

  bool loading = true;
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> players = [];
  final Map<int, String> status = {};
  final Set<int> savingPlayers = {};
  TrainingLifecycleState lifecycle = const TrainingLifecycleState();
  bool lifecycleLoading = true;
  bool lifecycleSaving = false;

  // При прокрутке списка вниз служебная часть журнала сворачивается,
  // чтобы игроки поднимались максимально высоко в рабочей области.
  bool _chromeExpanded = true;
  double _lastScrollPixels = 0;

  static const _statuses = <_AttendanceStatus>[
    _AttendanceStatus('present', 'Присутствует', 'П', Color(0xFF2F8F62)),
    _AttendanceStatus('absent', 'Отсутствует', 'Н', Color(0xFFB96D6D)),
    _AttendanceStatus('late', 'Болен', 'Б', Color(0xFFB78B42)),
    _AttendanceStatus('injured', 'Травма', 'Т', Color(0xFF7B73A8)),
    _AttendanceStatus('individual', 'Индивидуально', 'И', Color(0xFF5D8FA7)),
    _AttendanceStatus('dayoff', 'Выходной', 'В', Color(0xFF87939E)),
  ];

  TextStyle _style(double size, {FontWeight weight = FontWeight.w400, Color color = _text}) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: 1.2,
      letterSpacing: 0,
      features: const [FontFeature.tabularFigures()],
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _id(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;

  String _name(Map<String, dynamic> player) {
    final fullName = '${player['fullName'] ?? player['full_name'] ?? player['name'] ?? ''}'.trim();
    if (fullName.isNotEmpty && fullName != 'null') return fullName;
    final value = '${player['first_name'] ?? ''} ${player['last_name'] ?? ''}'.trim();
    return value.isEmpty ? 'Игрок' : value;
  }

  String _position(Map<String, dynamic> player) {
    return '${player['position'] ?? player['role'] ?? player['amplua'] ?? ''}'.trim();
  }

  String _number(Map<String, dynamic> player) {
    return '${player['number'] ?? player['player_number'] ?? player['shirt_number'] ?? ''}'.trim();
  }

  String? _photo(Map<String, dynamic> player) {
    final value = '${player['photo_url'] ?? player['avatar_url'] ?? player['photo'] ?? player['avatar'] ?? ''}'.trim();
    if (value.isEmpty || value == 'null') return null;
    if (value.startsWith('http')) return value;
    if (value.startsWith('/')) return 'https://sportotekaapp.ru$value';
    return 'https://sportotekaapp.ru/uploads/$value';
  }

  String _initials(String name) {
    final parts = name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'И';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }


  Map<String, Map<String, dynamic>> _normalizeAttendanceItems(dynamic decoded) {
    dynamic raw = decoded;
    if (decoded is Map) {
      raw = decoded['items'] ??
          decoded['attendance'] ??
          decoded['rows'] ??
          decoded['records'] ??
          decoded['data'] ??
          const <dynamic>[];
    }

    final out = <String, Map<String, dynamic>>{};

    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map) {
          final row = Map<String, dynamic>.from(value);
          final id = _id(
            row['player_id'] ?? row['playerId'] ?? row['id'] ?? key,
          );
          if (id > 0) out['$id'] = row;
        } else {
          final id = _id(key);
          if (id > 0) out['$id'] = <String, dynamic>{'status': value};
        }
      });
      return out;
    }

    if (raw is List) {
      for (final value in raw) {
        if (value is! Map) continue;
        final row = Map<String, dynamic>.from(value);
        final id = _id(
          row['player_id'] ??
              row['playerId'] ??
              row['athlete_id'] ??
              row['user_id'] ??
              row['id'],
        );
        if (id > 0) out['$id'] = row;
      }
    }

    return out;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final playersResponse = await http.get(
        Uri.parse('${widget.apiBase}/get_players_by_team.php?team_id=${widget.teamId}'),
      );
      final playersData = jsonDecode(playersResponse.body);
      final dynamic rawPlayers = playersData is Map
          ? (playersData['players'] ?? playersData['data'] ?? playersData['items'] ?? const [])
          : playersData;
      final playerList = rawPlayers is List ? rawPlayers : const <dynamic>[];
      players = playerList
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((player) => _id(player['id'] ?? player['player_id'] ?? player['playerId']) > 0)
          .toList();

      final attendanceResponse = await http.get(
        Uri.parse('${widget.apiBase}/get_team_attendance.php?event_id=${widget.eventId}'),
      );
      final attendanceData = jsonDecode(attendanceResponse.body);
      final items = _normalizeAttendanceItems(attendanceData);

      status.clear();
      for (final player in players) {
        final playerId = _id(player['id'] ?? player['player_id'] ?? player['playerId']);
        final row = items['$playerId'];
        final rawStatus = '${row?['status'] ?? 'unset'}'.trim();
        status[playerId] = rawStatus.isEmpty || rawStatus == 'null' ? 'unset' : rawStatus;
      }

      final lifecycleApi = TrainingLifecycleApi(
        apiBase: widget.apiBase,
        clubId: widget.clubId,
        teamId: widget.teamId,
        eventId: widget.eventId,
      );
      lifecycle = await lifecycleApi.load();
      final currentUserId = await PrefUtils.getUserId() ?? 0;
      if (currentUserId > 0) {
        try {
          lifecycle = await lifecycleApi.recordAttendanceOpened(
            userId: currentUserId,
          );
        } catch (_) {}
      }
      lifecycleLoading = false;
    } catch (e) {
      error = '$e';
      lifecycleLoading = false;
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _setStatus(int playerId, String selectedStatus) async {
    if (playerId <= 0 || savingPlayers.contains(playerId)) return;
    final previousStatus = status[playerId] ?? 'unset';
    final nextStatus = previousStatus == selectedStatus ? 'unset' : selectedStatus;

    setState(() {
      status[playerId] = nextStatus;
      savingPlayers.add(playerId);
      saving = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${widget.apiBase}/set_team_attendance.php'),
        body: {
          'team_id': '${widget.teamId}',
          'event_id': '${widget.eventId}',
          'player_id': '$playerId',
          'status': nextStatus == 'unset' ? '' : nextStatus,
          'note': '',
        },
      );
      final data = jsonDecode(response.body);
      if (data is Map && data['success'] != true && data['status'] != 'success') {
        throw Exception(data['message'] ?? 'Ошибка сохранения');
      }

      if (_count('unset') == 0 && players.isNotEmpty) {
        final userId = await PrefUtils.getUserId() ?? 0;
        if (userId > 0) {
          try {
            lifecycle = await TrainingLifecycleApi(
              apiBase: widget.apiBase,
              clubId: widget.clubId,
              teamId: widget.teamId,
              eventId: widget.eventId,
            ).recordAttendanceReady(
              userId: userId,
              attendancePresent: _count('present'),
              attendanceTotal: players.length,
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => status[playerId] = previousStatus);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          savingPlayers.remove(playerId);
          saving = savingPlayers.isNotEmpty;
        });
      }
    }
  }

  Future<void> _startTraining() async {
    if (lifecycleSaving || lifecycle.started || lifecycle.finished) return;
    final unset = _count('unset');
    if (unset > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сначала отметьте посещаемость всех игроков. Не отмечено: $unset')),
      );
      return;
    }
    final userId = await PrefUtils.getUserId() ?? 0;
    if (userId <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось определить тренера')),
        );
      }
      return;
    }
    setState(() => lifecycleSaving = true);
    try {
      final next = await TrainingLifecycleApi(
        apiBase: widget.apiBase,
        clubId: widget.clubId,
        teamId: widget.teamId,
        eventId: widget.eventId,
      ).start(
        userId: userId,
        attendancePresent: _count('present'),
        attendanceTotal: players.length,
      );
      if (!mounted) return;
      setState(() => lifecycle = next);
      widget.onLifecycleChanged?.call(next);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тренировка началась.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось начать тренировку: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => lifecycleSaving = false);
    }
  }

  int _count(String value) => status.values.where((item) => item == value).length;

  void _setChromeExpanded(bool expanded) {
    if (_chromeExpanded == expanded || !mounted) return;
    setState(() => _chromeExpanded = expanded);
    widget.onChromeExpandedChanged?.call(expanded);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    final pixels = notification.metrics.pixels;
    if (notification is ScrollStartNotification) {
      _lastScrollPixels = pixels;
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? (pixels - _lastScrollPixels);
      _lastScrollPixels = pixels;

      if (delta > 3.5 && pixels > 36) {
        _setChromeExpanded(false);
      }

      // Аналогично мобильному журналу: движение вверх само по себе не должно
      // сразу возвращать большую шапку. Раскрываем её возле первых 1–2 игроков.
      if (delta < -3.0 && pixels <= 135) {
        _setChromeExpanded(true);
      }
    }

    if (pixels <= 4 && !_chromeExpanded) {
      _setChromeExpanded(true);
    }

    return false;
  }

  Widget _buildCollapsedChrome() {
    final present = _count('present');
    final unset = _count('unset');
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _setChromeExpanded(true),
        child: SizedBox(
          height: 42,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const _AttendanceBrandDots(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Журнал · присутствуют $present/${players.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.formLabel(color: _text),
                  ),
                ),
                if (unset > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Не отмечено $unset',
                      style: AppTypography.captionMedium(color: _muted),
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: _muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: _green, strokeWidth: 2));
    if (error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(error!, textAlign: TextAlign.center),
        ),
      );
    }

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 210),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _chromeExpanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSummary(),
                    const SizedBox(height: 8),
                    _buildLegend(),
                    const SizedBox(height: 8),
                  ],
                )
              : _buildCollapsedChrome(),
        ),
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: ListView.builder(
                padding: EdgeInsets.only(top: _chromeExpanded ? 0 : 2, bottom: 18),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: players.length,
                itemBuilder: (_, index) => _buildPlayerRow(players[index], index),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _timeOf(DateTime? value) {
    if (value == null) return '—';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildLifecycleAction() {
    final unset = _count('unset');
    final finished = lifecycle.finished;
    final started = lifecycle.started && !finished;
    final enabled = !lifecycleLoading && !lifecycleSaving && !started && !finished && unset == 0 && players.isNotEmpty;

    final title = finished
        ? 'Тренировка окончена'
        : started
            ? 'Тренировка идёт'
            : 'Готово к началу тренировки';
    final subtitle = finished
        ? '${lifecycle.finishedByLabel} завершил тренировку в ${_timeOf(lifecycle.finishedAt)}. Оценки: ${lifecycle.ratingsCount}.'
        : started
            ? '${lifecycle.startedByLabel} начал тренировку в ${_timeOf(lifecycle.startedAt)} · присутствуют ${lifecycle.attendancePresent}/${lifecycle.attendanceTotal}. После тренировки сохраните оценки.'
            : (unset > 0
                ? 'Отметьте всех игроков в журнале. Не отмечено: $unset.'
                : 'Посещаемость заполнена. После старта push получит клубный администратор, участникам уйдёт уведомление «Тренировка началась».');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
              ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final info = Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  finished ? Icons.check_rounded : (started ? Icons.play_arrow_rounded : Icons.fact_check_outlined),
                  color: _green,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.itemTitle(color: _text)),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _muted)),
                  ],
                ),
              ),
            ],
          );
          final button = SizedBox(
            height: 42,
            child: FilledButton.icon(
              onPressed: finished
                  ? null
                  : started
                      ? widget.onOpenRatings
                      : (enabled ? _startTraining : null),
              style: FilledButton.styleFrom(
                backgroundColor: started ? const Color(0xFF315447) : _green,
                disabledBackgroundColor: _line,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: lifecycleSaving
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white))
                  : Icon(
                      finished
                          ? Icons.check_rounded
                          : started
                              ? Icons.arrow_forward_rounded
                              : Icons.play_arrow_rounded,
                      size: 17,
                    ),
              label: Text(
                finished
                    ? 'Окончена'
                    : started
                        ? 'Перейти к оценкам'
                        : 'Начать тренировку',
              ),
            ),
          );
          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 9), button]);
          }
          return Row(children: [Expanded(child: info), const SizedBox(width: 12), button]);
        },
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(14),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _AttendanceBrandDots(),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Журнал посещаемости',
                  style: AppTypography.subsectionTitle(color: _text),
                ),
              ),
              if (saving)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _green, strokeWidth: 1.8)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _SummaryItem(title: 'Игроков', value: '${players.length}', style: _style)),
              Container(width: 1, height: 30, color: _line),
              const SizedBox(width: 12),
              Expanded(child: _SummaryItem(title: 'Присутствуют', value: '${_count('present')}', style: _style)),
              Container(width: 1, height: 30, color: _line),
              const SizedBox(width: 12),
              Expanded(child: _SummaryItem(title: 'Не отмечено', value: '${_count('unset')}', style: _style)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final item = _statuses[index];
          return Container(
            padding: const EdgeInsets.only(left: 4, right: 8),
            decoration: BoxDecoration(
              color: Color.alphaBlend(item.color.withOpacity(.045), Colors.white),
              borderRadius: BorderRadius.circular(10),
                          ),
            child: Row(
              children: [
                _StatusCircle(item: item, active: true, size: 25),
                const SizedBox(width: 5),
                Text(item.label, style: AppTypography.captionMedium(color: _muted)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerRow(Map<String, dynamic> player, int index) {
    final playerId = _id(player['id'] ?? player['player_id']);
    final name = _name(player);
    final photo = _photo(player);
    final position = _position(player);
    final number = _number(player);
    final currentStatus = status[playerId] ?? 'unset';
    final isSaving = savingPlayers.contains(playerId);
    _AttendanceStatus? activeStatus;
    for (final item in _statuses) {
      if (item.code == currentStatus) {
        activeStatus = item;
        break;
      }
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: currentStatus == 'unset'
            ? Colors.white
            : Color.alphaBlend((activeStatus?.color ?? _green).withOpacity(.045), Colors.white),
              ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 500;
          final playerInfo = Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 3,
                height: 48,
                decoration: BoxDecoration(
                  color: activeStatus?.color ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 9),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(12)),
                    child: photo == null
                        ? Center(child: Text(_initials(name), style: _style(15.5, weight: FontWeight.w600)))
                        : Image.network(
                            photo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(child: Text(_initials(name), style: _style(15.5, weight: FontWeight.w600))),
                          ),
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 19,
                      height: 19,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(number.isEmpty ? '•' : number, style: _style(number.length > 1 ? 8.5 : 9.5, weight: FontWeight.w600, color: _muted)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: _text)),
                    const SizedBox(height: 5),
                    Text(
                      position.isEmpty ? 'Без амплуа' : position,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.secondary(color: _muted),
                    ),
                  ],
                ),
              ),
              if (isSaving) const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: _green, strokeWidth: 1.8)),
            ],
          );

          final buttons = Wrap(
            spacing: 5,
            runSpacing: 5,
            alignment: WrapAlignment.end,
            children: _statuses.map((item) {
              final active = currentStatus == item.code;
              return Tooltip(
                message: item.label,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: isSaving ? null : () => _setStatus(playerId, item.code),
                    child: _StatusCircle(item: item, active: active, size: 30),
                  ),
                ),
              );
            }).toList(),
          );

          if (compact) {
            return Column(
              children: [
                playerInfo,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: buttons),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: playerInfo),
              const SizedBox(width: 10),
              Expanded(flex: 5, child: Align(alignment: Alignment.centerRight, child: buttons)),
            ],
          );
        },
      ),
    );
  }
}

class _AttendanceBrandDot extends StatelessWidget {
  final double size;
  final double opacity;

  const _AttendanceBrandDot({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF14915D),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _AttendanceBrandDots extends StatelessWidget {
  const _AttendanceBrandDots();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AttendanceBrandDot(size: 3.5, opacity: .28),
        SizedBox(width: 3),
        _AttendanceBrandDot(size: 4.5, opacity: .48),
        SizedBox(width: 3),
        _AttendanceBrandDot(size: 5.5, opacity: .72),
        SizedBox(width: 3),
        _AttendanceBrandDot(size: 6.5, opacity: 1),
      ],
    );
  }
}

class _AttendanceStatus {
  final String code;
  final String label;
  final String symbol;
  final Color color;
  const _AttendanceStatus(this.code, this.label, this.symbol, this.color);
}

class _StatusCircle extends StatelessWidget {
  final _AttendanceStatus item;
  final bool active;
  final double size;
  const _StatusCircle({required this.item, required this.active, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? item.color.withOpacity(.105) : const Color(0xFFF2F5F3),
        shape: BoxShape.circle,
      ),
      child: Text(
        item.symbol,
        style: TextStyle(fontSize: size * .37, fontWeight: FontWeight.w600, color: active ? item.color : const Color(0xFF8A9099), height: 1),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final TextStyle Function(double, {FontWeight weight, Color color}) style;
  const _SummaryItem({required this.title, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: style(15, weight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: style(10.2, weight: FontWeight.w500, color: const Color(0xFF8A9099))),
      ],
    );
  }
}

