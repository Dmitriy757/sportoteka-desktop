import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'cmr_ui.dart';

class TeamMatchesWorkspacePanel extends StatefulWidget {
  final int teamId;
  final String teamName;
  final VoidCallback? onOpenFullModule;

  const TeamMatchesWorkspacePanel({
    super.key,
    required this.teamId,
    required this.teamName,
    this.onOpenFullModule,
  });

  @override
  State<TeamMatchesWorkspacePanel> createState() => _TeamMatchesWorkspacePanelState();
}

class _TeamMatchesWorkspacePanelState extends State<TeamMatchesWorkspacePanel> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getUrl = '$apiBase/get_team_matches.php';
  static const String addUrl = '$apiBase/add_team_match.php';

  bool loading = true;
  List<Map<String, dynamic>> matches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TeamMatchesWorkspacePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final uri = Uri.parse(getUrl).replace(queryParameters: {'team_id': widget.teamId.toString()});
      final r = await http.get(uri);
      final data = _decode(r.body);
      final list = _list(data, const ['matches', 'data', 'items']);
      if (!mounted) return;
      setState(() {
        matches = list;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        matches = [];
        loading = false;
      });
    }
  }

  Future<void> _quickAddMatch() async {
    final opponentCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 1));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) {
        return StatefulBuilder(builder: (context, setSB) {
          return Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: CmrColors.border, borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Добавить матч', style: TextStyle(color: CmrColors.text, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  TextField(controller: opponentCtrl, decoration: const InputDecoration(labelText: 'Соперник', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: placeCtrl, decoration: const InputDecoration(labelText: 'Место проведения', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) setSB(() => date = picked);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(border: Border.all(color: CmrColors.border), borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [const Icon(Icons.calendar_month_rounded, color: CmrColors.blue), const SizedBox(width: 10), Text('${date.year}-${_two(date.month)}-${_two(date.day)}', style: const TextStyle(fontWeight: FontWeight.w900))]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: CmrPrimaryButton(
                      label: 'Создать матч',
                      icon: Icons.add_rounded,
                      onPressed: () async {
                        if (opponentCtrl.text.trim().isEmpty) {
                          Get.snackbar('Ошибка', 'Введите соперника');
                          return;
                        }
                        Navigator.pop(context);
                        await _createMatch(opponentCtrl.text.trim(), placeCtrl.text.trim(), date);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _createMatch(String opponent, String place, DateTime date) async {
    try {
      final r = await http.post(Uri.parse(addUrl), body: {
        'team_id': widget.teamId.toString(),
        'team_name': widget.teamName,
        'opponent': opponent,
        'opponent_name': opponent,
        'location': place,
        'place': place,
        'match_date': '${date.year}-${_two(date.month)}-${_two(date.day)}',
        'date': '${date.year}-${_two(date.month)}-${_two(date.day)}',
      });
      final data = _decode(r.body);
      if (data is Map && data['success'] == true) {
        Get.snackbar('Готово', 'Матч добавлен');
        await _load();
      } else {
        Get.snackbar('Ошибка', cmrStr(data is Map ? data['message'] : null, 'Не удалось добавить матч'));
      }
    } catch (e) {
      Get.snackbar('Сеть', 'Ошибка соединения: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
          child: CmrSectionTitle(
            title: 'Матчи',
            subtitle: 'Быстрый список матчей ${widget.teamName} внутри рабочего кабинета.',
            trailing: Wrap(
              spacing: 10,
              children: [
                CmrGhostButton(label: 'Обновить', icon: Icons.refresh_rounded, onPressed: _load),
                CmrGhostButton(label: 'Полный модуль', icon: Icons.open_in_new_rounded, onPressed: widget.onOpenFullModule),
                CmrPrimaryButton(label: 'Добавить матч', icon: Icons.add_rounded, onPressed: _quickAddMatch),
              ],
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : matches.isEmpty
                  ? CmrEmptyState(
                      icon: Icons.sports_soccer_rounded,
                      title: 'Матчи пока не добавлены',
                      subtitle: 'Создайте первый матч команды или откройте полный модуль матчей.',
                      action: CmrPrimaryButton(label: 'Добавить матч', icon: Icons.add_rounded, onPressed: _quickAddMatch),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                        itemCount: matches.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final m = matches[i];
                          final opponent = cmrStr(m['opponent'] ?? m['opponent_name'] ?? m['title'], 'Соперник');
                          final date = cmrStr(m['match_date'] ?? m['date'] ?? m['start_date'], 'Дата не указана');
                          final place = cmrStr(m['location'] ?? m['place'] ?? m['stadium'], 'Место не указано');
                          final score = cmrStr(m['score'] ?? m['result']);
                          final status = cmrStr(m['status'], score.isEmpty ? 'Запланирован' : 'Завершён');
                          return CmrCard(
                            padding: const EdgeInsets.all(15),
                            radius: 20,
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(color: CmrColors.blue.withOpacity(0.10), borderRadius: BorderRadius.circular(17)),
                                  child: const Icon(Icons.sports_soccer_rounded, color: CmrColors.blue),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${widget.teamName} — $opponent', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CmrColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 7),
                                      Wrap(spacing: 8, runSpacing: 6, children: [
                                        _Badge(icon: Icons.calendar_today_rounded, text: date),
                                        _Badge(icon: Icons.location_on_outlined, text: place),
                                        _Badge(icon: Icons.info_outline_rounded, text: status),
                                      ]),
                                    ],
                                  ),
                                ),
                                if (score.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Text(score, style: const TextStyle(color: CmrColors.text, fontSize: 22, fontWeight: FontWeight.w900)),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  dynamic _decode(String body) {
    final start = body.indexOf('{');
    final arr = body.indexOf('[');
    int idx;
    if (start == -1) {
      idx = arr;
    } else if (arr == -1) {
      idx = start;
    } else {
      idx = start < arr ? start : arr;
    }
    final clean = idx > 0 ? body.substring(idx) : body;
    return jsonDecode(clean);
  }

  List<Map<String, dynamic>> _list(dynamic data, List<String> keys) {
    if (data is List) return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (data is Map) {
      for (final k in keys) {
        final v = data[k];
        if (v is List) return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Badge({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: CmrColors.bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: CmrColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: CmrColors.muted), const SizedBox(width: 5), Text(text, style: const TextStyle(color: CmrColors.text, fontSize: 11, fontWeight: FontWeight.w800))]),
    );
  }
}
