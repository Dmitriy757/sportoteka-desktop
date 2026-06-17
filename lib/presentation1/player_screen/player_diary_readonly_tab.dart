import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/player_screen/player_id_resolver.dart';
import 'package:sportoteka/presentation/player_screen/player_self_assessment_screen.dart';

class PlayerDiaryReadonlyTab extends StatefulWidget {
  final int teamId;
  final int userId; // ✅ user_id игрока

  const PlayerDiaryReadonlyTab({
    super.key,
    required this.teamId,
    required this.userId,
  });

  @override
  State<PlayerDiaryReadonlyTab> createState() => _PlayerDiaryReadonlyTabState();
}

class _PlayerDiaryReadonlyTabState extends State<PlayerDiaryReadonlyTab> {
  static const apiBase = "https://sportotekaapp.ru/api";

  bool loading = true;
  String? error;
  int playerId = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      if (widget.teamId <= 0 || widget.userId <= 0) {
        throw "Нет данных teamId/userId";
      }

      final pid = await PlayerIdResolver.resolvePlayerId(
        apiBase: apiBase,
        userId: widget.userId,
      );

      if (!mounted) return;

      if (pid <= 0) throw "Не удалось определить player_id";
      setState(() {
        playerId = pid;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Text(error!, style: const TextStyle(color: Colors.red)));

    return PlayerSelfAssessmentScreen(
      teamId: widget.teamId,
      userId: widget.userId,
      playerId: playerId,
      readOnly: true, // ✅ тренер только смотрит
    );
  }
}
