import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'screens/tracker_match_workspace_screen.dart';

class SportotekaTrackerProScreen extends StatelessWidget {
  const SportotekaTrackerProScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teamId,
    required this.teamName,
    required this.userId,
    this.initialPlayers = const [],
  });

  final int clubId;
  final String clubName;
  final int teamId;
  final String teamName;
  final int userId;
  final List<Map<String, dynamic>> initialPlayers;

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final map = args is Map ? args : const <String, dynamic>{};

    // Важно: конструктор — главный источник актуальной команды.
    // Get.arguments используем только как fallback, иначе старые arguments
    // могут перезатирать новую выбранную команду из панели клуба.
    final argClubId = _asInt(map['club_id'] ?? map['clubId']);
    final argTeamId = _asInt(map['team_id'] ?? map['teamId']);
    final argUserId = _asInt(map['user_id'] ?? map['userId']);

    final effectiveClubId = clubId > 0 ? clubId : argClubId;
    final effectiveTeamId = teamId > 0 ? teamId : argTeamId;
    final effectiveUserId = userId > 0 ? userId : argUserId;

    final argClubName = _asString(map['club_name'] ?? map['clubName']);
    final argTeamName = _asString(map['team_name'] ?? map['teamName']);

    final effectiveClubName = clubName.trim().isNotEmpty ? clubName : (argClubName ?? 'Клуб');
    final effectiveTeamName = teamName.trim().isNotEmpty ? teamName : (argTeamName ?? 'Команда');

    return TrackerMatchWorkspaceScreen(
      key: ValueKey('tracker_workspace_${effectiveClubId}_$effectiveTeamId'),
      clubId: effectiveClubId,
      clubName: effectiveClubName,
      teamId: effectiveTeamId,
      teamName: effectiveTeamName,
      userId: effectiveUserId,
      initialPlayers: initialPlayers,
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  String? _asString(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }
}
