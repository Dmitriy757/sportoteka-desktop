import 'dart:convert';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/theme/app_typography.dart';

class TrainingAttendancePanel extends StatefulWidget {
  final String apiBase;
  final int teamId;
  final int eventId;

  const TrainingAttendancePanel({
    super.key,
    required this.apiBase,
    required this.teamId,
    required this.eventId,
  });

  @override
  State<TrainingAttendancePanel> createState() => _TrainingAttendancePanelState();
}

class _TrainingAttendancePanelState extends State<TrainingAttendancePanel> {
  static const Color _green = Color(0xFF00A750);
  static const Color _greenSoft = Color(0xFFF8FEFA);
  static const Color _line = Color(0xFFE9ECEA);
  static const Color _soft = Color(0xFFF7F8F7);
  static const Color _text = Color(0xFF0B0F14);
  static const Color _muted = Color(0xFF5F6670);

  bool loading = true;
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> players = [];
  final Map<int, String> status = {};
  final Set<int> savingPlayers = {};

  static const _statuses = <_AttendanceStatus>[
    _AttendanceStatus('present', 'Присутствует', 'П', Color(0xFF22C55E)),
    _AttendanceStatus('absent', 'Отсутствует', 'Н', Color(0xFFEF4444)),
    _AttendanceStatus('late', 'Болен', 'Б', Color(0xFFF59E0B)),
    _AttendanceStatus('injured', 'Травма', 'Т', Color(0xFF8B5CF6)),
    _AttendanceStatus('individual', 'Индивидуально', 'И', Color(0xFF0EA5E9)),
    _AttendanceStatus('dayoff', 'Выходной', 'В', Color(0xFF94A3B8)),
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
      final list = (playersData['players'] ?? playersData['data'] ?? []) as List;
      players = list
          .map((item) => Map<String, dynamic>.from(item))
          .where((player) => _id(player['id'] ?? player['player_id']) > 0)
          .toList();

      final attendanceResponse = await http.get(
        Uri.parse('${widget.apiBase}/get_team_attendance.php?event_id=${widget.eventId}'),
      );
      final attendanceData = jsonDecode(attendanceResponse.body);
      final items = (attendanceData['items'] as Map?) ?? {};

      status.clear();
      for (final player in players) {
        final playerId = _id(player['id'] ?? player['player_id']);
        final row = items['$playerId'];
        final value = '${row is Map ? row['status'] : 'unset'}';
        status[playerId] = value.isEmpty ? 'unset' : value;
      }
    } catch (e) {
      error = '$e';
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

  int _count(String value) => status.values.where((item) => item == value).length;

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
        _buildSummary(),
        const SizedBox(height: 8),
        _buildLegend(),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: players.length,
              itemBuilder: (_, index) => _buildPlayerRow(players[index], index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _SummaryItem(title: 'Игроков', value: '${players.length}', style: _style)),
          Container(width: 1, height: 30, color: _line),
          const SizedBox(width: 12),
          Expanded(child: _SummaryItem(title: 'Присутствуют', value: '${_count('present')}', style: _style)),
          Container(width: 1, height: 30, color: _line),
          const SizedBox(width: 12),
          Expanded(child: _SummaryItem(title: 'Не отмечено', value: '${_count('unset')}', style: _style)),
          if (saving) ...[
            const SizedBox(width: 10),
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _green, strokeWidth: 1.8)),
          ],
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
              color: item.color.withOpacity(.065),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                _StatusCircle(item: item, active: true, size: 25),
                const SizedBox(width: 5),
                Text(item.label, style: _style(10.2, weight: FontWeight.w600, color: _muted)),
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
        color: currentStatus == 'unset' ? Colors.white : _greenSoft,
        border: index == players.length - 1 ? null : const Border(bottom: BorderSide(color: _line, width: .65)),
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
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _style(13.8, weight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Text(
                      position.isEmpty ? 'Без амплуа' : position,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _style(11.2, color: _muted),
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
        color: active ? item.color.withOpacity(.14) : const Color(0xFFF2F4F2),
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

