import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/manager_match_list_model.dart';
import '../services/manager_mode_service.dart';
import 'manager_match_report_screen.dart';

class ManagerMatchesScreen extends StatefulWidget {
  final int teamId;
  final String teamName;

  const ManagerMatchesScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<ManagerMatchesScreen> createState() => _ManagerMatchesScreenState();
}

class _ManagerMatchesScreenState extends State<ManagerMatchesScreen> {
  late Future<List<ManagerMatchListItem>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ManagerMatchListItem>> _load() {
    return ManagerModeService.getMatches(
      teamId: widget.teamId,
      filter: _filter,
    );
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Color _resultColor(String result) {
    if (result == 'W') return const Color(0xFF16A34A);
    if (result == 'L') return const Color(0xFFDC2626);
    return const Color(0xFFF59E0B);
  }

  String _resultText(String result) {
    if (result == 'W') return 'Победа';
    if (result == 'L') return 'Поражение';
    return 'Ничья';
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _filter = value;
          _future = _load();
        });
      },
    );
  }

  Widget _matchCard(ManagerMatchListItem match) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ManagerMatchReportScreen(
              matchId: match.id,
              teamName: widget.teamName,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.teamName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _resultColor(match.resultLabel).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _resultText(match.resultLabel),
                    style: TextStyle(
                      color: _resultColor(match.resultLabel),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  Text(
                    '${match.homeScore} : ${match.awayScore}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    match.opponentName,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaChip(_formatDate(match.matchDate)),
                _metaChip(match.formationUsed.isEmpty ? '4-3-3' : match.formationUsed),
                _metaChip(match.playStyle.isEmpty ? 'balanced' : match.playStyle),
                _metaChip('Удары ${match.shotsHome}:${match.shotsAway}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Матчи сезона'),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterChip('all', 'Все'),
                _filterChip('wins', 'Победы'),
                _filterChip('draws', 'Ничьи'),
                _filterChip('losses', 'Поражения'),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<ManagerMatchListItem>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('Ошибка: ${snapshot.error}'),
                    ),
                  );
                }

                final matches = snapshot.data ?? [];
                if (matches.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('Матчей пока нет'),
                    ),
                  );
                }

                return Column(
                  children: matches.map(_matchCard).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}