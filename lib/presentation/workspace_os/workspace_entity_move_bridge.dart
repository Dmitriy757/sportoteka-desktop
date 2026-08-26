import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';

class WorkspaceMoveResult {
  const WorkspaceMoveResult({required this.handled, required this.success, this.message = ''});
  final bool handled;
  final bool success;
  final String message;
}

class WorkspaceEntityMoveBridge {
  const WorkspaceEntityMoveBridge({this.apiBase = 'https://sportotekaapp.ru/api'});
  final String apiBase;

  int _int(dynamic value) => int.tryParse('${value ?? ''}'.trim()) ?? 0;

  int _playerId(WorkspaceFinderNode node) {
    final p = node.payload ?? const <String, dynamic>{};
    return _int(p['player_id'] ?? p['id']);
  }

  int _teamId(WorkspaceFinderNode node) {
    final p = node.payload ?? const <String, dynamic>{};
    return _int(p['team_id'] ?? p['id']);
  }

  Future<WorkspaceMoveResult> move(WorkspaceFinderNode source, WorkspaceFinderNode target) async {
    if (source.kind == WorkspaceFinderNodeKind.player && target.kind == WorkspaceFinderNodeKind.team) {
      final playerId = _playerId(source);
      final teamId = _teamId(target);
      if (playerId <= 0 || teamId <= 0) {
        return const WorkspaceMoveResult(handled: true, success: false, message: 'Не удалось определить игрока или команду');
      }
      final response = await http.post(
        Uri.parse('$apiBase/update_player.php'),
        body: <String, String>{
          'id': '$playerId',
          'player_id': '$playerId',
          'team_id': '$teamId',
        },
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return WorkspaceMoveResult(handled: true, success: false, message: 'Сервер ${response.statusCode}');
      }
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final ok = decoded['success'] == true || decoded['ok'] == true || decoded['status'] == 'success';
          if (!ok) {
            return WorkspaceMoveResult(
              handled: true,
              success: false,
              message: '${decoded['message'] ?? decoded['error'] ?? 'Не удалось переместить игрока'}',
            );
          }
        }
      } catch (_) {
        // Старые API Sportoteka не всегда возвращают JSON: HTTP 2xx считаем успехом.
      }
      return const WorkspaceMoveResult(handled: true, success: true, message: 'Игрок переведён в команду');
    }

    return const WorkspaceMoveResult(handled: false, success: false);
  }
}
