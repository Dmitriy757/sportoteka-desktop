import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/presentation/workspace_os/workspace_entity_data_bridge.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_server_storage.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_sync_signal.dart';

import '../reports/tracker_training_report_api.dart';
import '../reports/tracker_training_report_models.dart';


class TrackerAiAnalysisDocument {
  const TrackerAiAnalysisDocument({
    required this.documentKey,
    required this.title,
    required this.body,
    required this.entityId,
    required this.sessionIds,
    required this.personal,
    this.updatedAt,
  });

  final String documentKey;
  final String title;
  final String body;
  final int entityId;
  final List<int> sessionIds;
  final bool personal;
  final DateTime? updatedAt;
}

/// Автоматически превращает завершённую Tracker-сессию в документ Sportoteka OS.
///
/// Важно: цифры для ИИ берутся только из TrackerTrainingReportApi. ИИ получает
/// их как verified_report и не должен придумывать отсутствующие показатели.
class TrackerWorkspaceAiArchiveService {
  TrackerWorkspaceAiArchiveService({
    TrackerTrainingReportApi? reportApi,
    WorkspaceEntityDataBridge? entityBridge,
    this.aiUrl = 'https://sportotekaapp.ru/api/ai/v1/assistant/chat',
  })  : _reportApi = reportApi ?? TrackerTrainingReportApi(),
        _entityBridge = entityBridge ?? WorkspaceEntityDataBridge();

  final TrackerTrainingReportApi _reportApi;
  final WorkspaceEntityDataBridge _entityBridge;
  final String aiUrl;

  Future<TrackerAiAnalysisDocument> archiveTraining({
    required int clubId,
    required int userId,
    required int teamId,
    required String teamName,
    required List<int> sessionIds,
    required bool personal,
    int? playerId,
    String playerName = '',
    DateTime? finishedAt,
  }) async {
    final ids = sessionIds.where((id) => id > 0).toSet().toList()..sort();
    if (clubId <= 0 || userId <= 0 || teamId <= 0 || ids.isEmpty) {
      debugPrint(
        '[TRACKER_AI_ARCHIVE] skip invalid context '
        'club=$clubId user=$userId team=$teamId sessions=$ids',
      );
      throw ArgumentError(
        'Некорректный контекст анализа: club=$clubId user=$userId team=$teamId sessions=$ids',
      );
    }

    final report = await _loadReportWithRetry(
      sessionIds: ids,
      teamId: teamId,
      userId: userId,
      teamName: teamName,
      personal: personal,
      playerId: playerId,
    );

    final effectiveTeamName = _firstNonEmpty(<String>[
      report.teamName,
      teamName,
      'Команда #$teamId',
    ]);
    final effectivePlayerName = personal
        ? _resolvePlayerName(report, playerId: playerId, fallback: playerName)
        : '';
    final effectiveDate = _reportDate(report) ?? finishedAt ?? DateTime.now();

    final calendarTraining = personal
        ? null
        : await _findCalendarTraining(
            teamId: teamId,
            target: finishedAt ?? effectiveDate,
          );
    final mappedTrainingId = calendarTraining == null ? null : _eventId(calendarTraining);
    final entityId = mappedTrainingId ??
        _syntheticTrainingEntityId(
          sessionId: ids.first,
          personal: personal,
        );

    final storage = WorkspaceServerStorage(clubId: clubId, userId: userId);

    // The canonical destination is now the Tracker session folder itself:
    // entity:tracker:<session_id>. Calendar training is kept only as extra
    // context for the AI and, when available, as an additional cross-link.

    final workspaceContext = await _loadWorkspaceTrainingContext(
      storage: storage,
      entityId: entityId,
      trackerSessionIds: ids,
      calendarTraining: calendarTraining,
    );

    final verifiedContext = _verifiedContext(
      report: report,
      sessionIds: ids,
      teamId: teamId,
      teamName: effectiveTeamName,
      personal: personal,
      playerId: playerId,
      playerName: effectivePlayerName,
      date: effectiveDate,
      workspaceContext: workspaceContext,
    );

    final aiAnswer = await _askAiWithRetry(
      clubId: clubId,
      userId: userId,
      teamId: teamId,
      sessionIds: ids,
      personal: personal,
      playerName: effectivePlayerName,
      teamName: effectiveTeamName,
      verifiedContext: verifiedContext,
    );

    final dateLabel = _dateLabel(effectiveDate);
    final subject = personal ? effectivePlayerName : effectiveTeamName;
    final safeSubject = subject.trim().isEmpty
        ? (personal ? 'Игрок' : 'Команда')
        : subject.trim();
    final existingNode = await _findExistingAnalysisNode(
      storage: storage,
      sessionIds: ids,
      teamId: teamId,
    );
    final sessionKey = ids.join('-');
    final documentKey = existingNode?.id ??
        'workspace-ai-tracker-${personal ? 'personal' : 'team'}-$sessionKey';
    final title = 'Анализ ИИ · $dateLabel · $safeSubject';
    final subtitle = personal
        ? 'Личная тренировка · $safeSubject · $effectiveTeamName'
        : 'Командная тренировка · $effectiveTeamName · ${report.players.length} игроков';

    final node = WorkspaceFinderNode(
      id: documentKey,
      title: title,
      subtitle: subtitle,
      kind: WorkspaceFinderNodeKind.note,
      parentId: 'entity:tracker:${ids.first}',
      payload: <String, dynamic>{
        'workspace_document': true,
        '_workspace_ai_training_analysis': true,
        '_workspace_entity_type': 'tracker',
        '_workspace_entity_id': '${ids.first}',
        'personal_session': personal,
        'session_ids': ids,
        'team_id': teamId,
        'team_name': effectiveTeamName,
        if ((playerId ?? 0) > 0) 'player_id': playerId,
        if (effectivePlayerName.isNotEmpty) 'player_name': effectivePlayerName,
        'training_date': effectiveDate.toIso8601String(),
        'calendar_training_id': mappedTrainingId,
        'source': 'tracker_auto_ai_analysis',
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final body = _buildDocumentBody(
      report: report,
      sessionIds: ids,
      personal: personal,
      teamName: effectiveTeamName,
      playerName: effectivePlayerName,
      date: effectiveDate,
      aiAnswer: aiAnswer,
    );

    // Один и тот же завершённый Tracker-сеанс имеет стабильный documentKey:
    // повторный Stop/retry обновляет анализ, а не плодит копии.
    await storage.syncNodeDocument(
      node: node,
      body: body,
      createHint: true,
    );
    // The same team analysis may contain several player session IDs. Link the
    // single AI document to every Tracker folder in that completed training.
    for (final sessionId in ids) {
      try {
        await storage.linkDocument(
          documentKey: documentKey,
          entityType: 'tracker',
          entityId: '$sessionId',
          sectionKey: 'documents',
          title: title,
        );
      } catch (e) {
        // Older Workspace backends may not yet accept tracker as an entity
        // link type. The document is still visible because its payload carries
        // session_ids and Sportoteka OS resolves that fallback locally.
        debugPrint('[TRACKER_AI_ARCHIVE] tracker link $sessionId skipped: $e');
      }
    }

    // Keep the Calendar/Training cross-link when a real training was matched.
    // This does not control the Tracker view; it simply makes the same report
    // available from both places without creating a duplicate document.
    if (mappedTrainingId != null) {
      await storage.linkDocument(
        documentKey: documentKey,
        entityType: 'training',
        entityId: '$mappedTrainingId',
        sectionKey: 'documents',
        title: title,
      );
    }

    WorkspaceSyncSignal.trackerChanged(teamId: teamId, sessionIds: ids);

    debugPrint(
      '[TRACKER_AI_ARCHIVE] saved entity=tracker:${ids.join(',')} '
      'calendarTraining=${mappedTrainingId ?? 0} personal=$personal title=$title',
    );

    return TrackerAiAnalysisDocument(
      documentKey: documentKey,
      title: title,
      body: body,
      entityId: ids.first,
      sessionIds: List<int>.unmodifiable(ids),
      personal: personal,
      updatedAt: DateTime.now(),
    );
  }

  /// Ищет уже созданный «Анализ ИИ» по любой Tracker session_id.
  /// Работает и для старых документов, привязанных к календарной тренировке,
  /// и для synthetic training folder, поэтому UI Tracker не обязан знать
  /// entity_id заранее.
  Future<TrackerAiAnalysisDocument?> findExistingAnalysis({
    required int clubId,
    required int userId,
    required int teamId,
    required int sessionId,
  }) async {
    if (clubId <= 0 || sessionId <= 0) return null;
    final storage = WorkspaceServerStorage(clubId: clubId, userId: userId);
    final snapshot = await storage.load();
    final candidates = snapshot.nodes.where((node) {
      final payload = node.payload ?? const <String, dynamic>{};
      if (payload['_workspace_ai_training_analysis'] != true) return false;
      final payloadTeamId = int.tryParse('${payload['team_id'] ?? 0}') ?? 0;
      if (teamId > 0 && payloadTeamId > 0 && payloadTeamId != teamId) {
        return false;
      }
      return _payloadSessionIds(payload['session_ids']).contains(sessionId);
    }).toList(growable: false)
      ..sort((a, b) {
        final ad = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

    if (candidates.isEmpty) return null;
    final node = candidates.first;
    var body = (snapshot.noteBodies[node.id] ?? '').trim();
    if (body.isEmpty) {
      try {
        final remote = await storage.loadDocument(clientUid: node.id);
        body = _documentBodyFromRemote(remote);
      } catch (e) {
        debugPrint('[TRACKER_AI_ARCHIVE] load existing body failed: $e');
      }
    }
    final payload = node.payload ?? const <String, dynamic>{};
    return TrackerAiAnalysisDocument(
      documentKey: node.id,
      title: node.title,
      body: body,
      entityId: _payloadSessionIds(payload['session_ids']).isNotEmpty
          ? _payloadSessionIds(payload['session_ids']).first
          : (int.tryParse('${payload['_workspace_entity_id'] ?? 0}') ?? 0),
      sessionIds: _payloadSessionIds(payload['session_ids']),
      personal: payload['personal_session'] == true ||
          '${payload['personal_session']}' == '1',
      updatedAt: node.updatedAt ?? node.createdAt,
    );
  }

  /// Один bootstrap вместо N запросов: используется массовым анализом архива,
  /// чтобы пропускать сессии, у которых документ уже существует.
  Future<Set<int>> existingAnalysisSessionIds({
    required int clubId,
    required int userId,
    required int teamId,
  }) async {
    if (clubId <= 0) return <int>{};
    final storage = WorkspaceServerStorage(clubId: clubId, userId: userId);
    final snapshot = await storage.load();
    final result = <int>{};
    for (final node in snapshot.nodes) {
      final payload = node.payload ?? const <String, dynamic>{};
      if (payload['_workspace_ai_training_analysis'] != true) continue;
      final payloadTeamId = int.tryParse('${payload['team_id'] ?? 0}') ?? 0;
      if (teamId > 0 && payloadTeamId > 0 && payloadTeamId != teamId) continue;
      result.addAll(_payloadSessionIds(payload['session_ids']));
    }
    return result;
  }

  Future<WorkspaceFinderNode?> _findExistingAnalysisNode({
    required WorkspaceServerStorage storage,
    required List<int> sessionIds,
    required int teamId,
  }) async {
    final wanted = sessionIds.where((id) => id > 0).toSet();
    if (wanted.isEmpty) return null;
    try {
      final snapshot = await storage.load();
      final candidates = snapshot.nodes.where((node) {
        final payload = node.payload ?? const <String, dynamic>{};
        if (payload['_workspace_ai_training_analysis'] != true) return false;
        final payloadTeamId = int.tryParse('${payload['team_id'] ?? 0}') ?? 0;
        if (teamId > 0 && payloadTeamId > 0 && payloadTeamId != teamId) {
          return false;
        }
        return _payloadSessionIds(payload['session_ids'])
            .any(wanted.contains);
      }).toList(growable: false)
        ..sort((a, b) {
          final ad = a.updatedAt ??
              a.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.updatedAt ??
              b.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
      return candidates.isEmpty ? null : candidates.first;
    } catch (e) {
      debugPrint('[TRACKER_AI_ARCHIVE] existing document lookup failed: $e');
      return null;
    }
  }

  List<int> _payloadSessionIds(dynamic raw) {
    final ids = <int>{};
    void add(dynamic value) {
      if (value == null) return;
      if (value is num) {
        if (value.toInt() > 0) ids.add(value.toInt());
        return;
      }
      if (value is List) {
        for (final item in value) add(item);
        return;
      }
      if (value is String) {
        final text = value.trim();
        if (text.isEmpty) return;
        try {
          add(jsonDecode(text));
          return;
        } catch (_) {}
        for (final part in text.split(RegExp(r'[,;\s]+'))) {
          final id = int.tryParse(part.trim());
          if (id != null && id > 0) ids.add(id);
        }
      }
    }
    add(raw);
    return ids.toList(growable: false)..sort();
  }

  String _documentBodyFromRemote(Map<String, dynamic>? remote) {
    if (remote == null) return '';
    for (final key in const <String>['body', 'text', 'content']) {
      final value = remote[key];
      final text = '${value ?? ''}'.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    final nested = remote['document'];
    if (nested is Map) {
      return _documentBodyFromRemote(Map<String, dynamic>.from(nested));
    }
    return '';
  }

  Future<TrackerTrainingReport> _loadReportWithRetry({
    required List<int> sessionIds,
    required int teamId,
    required int userId,
    required String teamName,
    required bool personal,
    int? playerId,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final report = personal
            ? await _reportApi.loadPersonalTrainingReport(
                sessionId: sessionIds.first,
                teamId: teamId,
                ownerUserId: userId,
                playerId: playerId,
                teamName: teamName,
              )
            : await _reportApi.loadTrainingReports(
                sessionId: sessionIds.first,
                sessionIds: sessionIds,
                teamId: teamId,
              );
        if (report.hasData || report.players.isNotEmpty || attempt == 3) {
          return report;
        }
      } catch (e) {
        lastError = e;
        if (attempt == 3) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 900 + attempt * 700));
    }
    throw Exception('Не удалось получить итоговый Tracker-отчёт: $lastError');
  }

  Future<Map<String, dynamic>?> _findCalendarTraining({
    required int teamId,
    required DateTime target,
  }) async {
    try {
      final rows = await _entityBridge.loadTeamEvents(teamId);
      Map<String, dynamic>? best;
      Duration? bestDelta;
      for (final raw in rows) {
        if (!_looksLikeTraining(raw)) continue;
        final id = _eventId(raw);
        final date = _eventDate(raw);
        if (id <= 0 || date == null || !_sameDay(date, target)) continue;
        final delta = date.difference(target).abs();
        if (best == null || bestDelta == null || delta < bestDelta) {
          best = raw;
          bestDelta = delta;
        }
      }
      return best;
    } catch (e) {
      debugPrint('[TRACKER_AI_ARCHIVE] calendar match skipped: $e');
      return null;
    }
  }

  Future<void> _ensureTrainingFolder({
    required WorkspaceServerStorage storage,
    required int entityId,
    required int teamId,
    required String teamName,
    required bool personal,
    required int? playerId,
    required String playerName,
    required DateTime date,
    required List<int> sessionIds,
  }) async {
    final dateText = _dateLabel(date);
    final subject = personal
        ? (playerName.trim().isEmpty ? 'Игрок' : playerName.trim())
        : teamName;
    final folder = WorkspaceFinderNode(
      id: 'tracker-training-folder-$entityId',
      title: personal
          ? 'Личная тренировка · $subject'
          : 'Командная тренировка · $teamName',
      subtitle: personal
          ? '$dateText · $teamName · $subject'
          : '$dateText · $teamName',
      kind: WorkspaceFinderNodeKind.training,
      parentId: 'trainings',
      moduleKey: 'calendar',
      payload: <String, dynamic>{
        '_workspace_entity_folder': true,
        '_workspace_real_record': true,
        '_workspace_entity_type': 'training',
        '_workspace_entity_id': '$entityId',
        '_workspace_entity_folder_parent': 'trainings',
        '_tracker_generated_training_folder': true,
        'type': 'training',
        'training_type': personal ? 'personal' : 'team',
        'event_id': entityId,
        'team_id': teamId,
        'team_name': teamName,
        if ((playerId ?? 0) > 0) 'player_id': playerId,
        if (playerName.isNotEmpty) 'player_name': playerName,
        'title': personal
            ? 'Личная тренировка · $subject'
            : 'Командная тренировка · $teamName',
        'training_date': date.toIso8601String(),
        'session_ids': sessionIds,
        'source': 'tracker_completed_training',
      },
      createdAt: date,
      updatedAt: DateTime.now(),
    );
    try {
      await storage.createNode(folder);
    } catch (_) {
      await storage.updateNode(folder);
    }
  }

  Future<Map<String, dynamic>> _loadWorkspaceTrainingContext({
    required WorkspaceServerStorage storage,
    required int entityId,
    required List<int> trackerSessionIds,
    Map<String, dynamic>? calendarTraining,
  }) async {
    final result = <String, dynamic>{
      if (calendarTraining != null) 'calendar_training': _calendarContext(calendarTraining),
    };
    try {
      final links = await storage.listEntityDocuments(
        entityType: 'training',
        entityId: '$entityId',
        sectionKey: 'documents',
      );
      final attachments = await storage.listAttachments(
        entityType: 'training',
        entityId: entityId,
        sectionKey: 'documents',
      );
      final snapshot = await storage.load();
      final documents = <Map<String, dynamic>>[];
      for (final link in links.take(6)) {
        final key = '${link['document_key'] ?? link['client_uid'] ?? ''}'.trim();
        if (key.isEmpty || key.startsWith('workspace-ai-training-')) continue;
        final body = (snapshot.noteBodies[key] ?? '').trim();
        documents.add(<String, dynamic>{
          'title': '${link['title'] ?? link['name'] ?? 'Документ'}'.trim(),
          'document_key': key,
          if (body.isNotEmpty) 'text': _limit(body, 4500),
        });
      }
      // Documents manually added inside Tracker session folders are also
      // valid AI context. This lets a re-analysis use coach notes/files placed
      // directly next to the previous AI report in Sportoteka OS.
      for (final sessionId in trackerSessionIds.where((id) => id > 0).take(12)) {
        try {
          final trackerLinks = await storage.listEntityDocuments(
            entityType: 'tracker',
            entityId: '$sessionId',
            sectionKey: 'documents',
          );
          for (final link in trackerLinks.take(6)) {
            final key = '${link['document_key'] ?? link['client_uid'] ?? ''}'.trim();
            if (key.isEmpty || key.startsWith('workspace-ai-')) continue;
            if (documents.any((item) => '${item['document_key'] ?? ''}' == key)) continue;
            final body = (snapshot.noteBodies[key] ?? '').trim();
            documents.add(<String, dynamic>{
              'title': '${link['title'] ?? link['name'] ?? 'Документ'}'.trim(),
              'document_key': key,
              if (body.isNotEmpty) 'text': _limit(body, 4500),
            });
          }
        } catch (_) {}
      }
      result['documents'] = documents;
      result['attachments'] = attachments.take(20).map((row) => <String, dynamic>{
            'name': '${row['original_name'] ?? row['title'] ?? row['file_name'] ?? 'Файл'}'.trim(),
            'type': '${row['mime_type'] ?? row['type'] ?? ''}'.trim(),
          }).toList(growable: false);
    } catch (e) {
      debugPrint('[TRACKER_AI_ARCHIVE] workspace context unavailable: $e');
    }
    return result;
  }

  Map<String, dynamic> _calendarContext(Map<String, dynamic> row) {
    dynamic pick(List<String> keys) {
      for (final key in keys) {
        final value = row[key];
        final text = '${value ?? ''}'.trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return value;
      }
      return '';
    }

    return <String, dynamic>{
      'id': _eventId(row),
      'title': pick(const <String>['title', 'event_title', 'name', 'training_title']),
      'type': pick(const <String>['type', 'event_type', 'kind', 'category']),
      'date': pick(const <String>['start_at', 'event_date', 'training_date', 'date']),
      'location': pick(const <String>['location', 'venue', 'place', 'address']),
      'description': pick(const <String>['description', 'note', 'notes', 'comment']),
      'team_name': pick(const <String>['team_name']),
    };
  }

  String _limit(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}…';
  }

  Future<String> _askAiWithRetry({
    required int clubId,
    required int userId,
    required int teamId,
    required List<int> sessionIds,
    required bool personal,
    required String playerName,
    required String teamName,
    required Map<String, dynamic> verifiedContext,
  }) async {
    final prompt = _analysisPrompt(
      personal: personal,
      playerName: playerName,
      teamName: teamName,
    );
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(aiUrl),
              headers: const <String, String>{
                'Content-Type': 'application/json; charset=utf-8',
                'Accept': 'application/json',
              },
              body: jsonEncode(<String, dynamic>{
                'club_id': clubId,
                'user_id': userId,
                'team_id': teamId,
                'conversation_id':
                    'tracker_auto_${personal ? 'personal' : 'team'}_${sessionIds.join('_')}',
                'q': prompt,
                'context': verifiedContext,
                'memory': const <String, dynamic>{},
              }),
            )
            .timeout(const Duration(seconds: 45));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('AI HTTP ${response.statusCode}: ${response.body}');
        }
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map) throw Exception('AI вернул некорректный JSON');
        final map = Map<String, dynamic>.from(decoded);
        final answer = '${map['answer'] ?? ''}'.trim();
        if (answer.isEmpty) {
          throw Exception('AI вернул пустой answer: ${map['error'] ?? map['message'] ?? ''}');
        }
        return answer;
      } catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(seconds: 1 + attempt));
        }
      }
    }
    throw Exception('SPORTOTEKA AI не создал анализ: $lastError');
  }

  Map<String, dynamic> _verifiedContext({
    required TrackerTrainingReport report,
    required List<int> sessionIds,
    required int teamId,
    required String teamName,
    required bool personal,
    required int? playerId,
    required String playerName,
    required DateTime date,
    required Map<String, dynamic> workspaceContext,
  }) {
    final s = report.summary;
    return <String, dynamic>{
      'source': 'tracker_auto_training_archive',
      'scope': personal ? 'personal_training_report' : 'team_training_report',
      'personal_session': personal,
      'session_id': report.sessionId,
      'session_ids': sessionIds,
      'team_id': teamId,
      'team_name': teamName,
      if ((playerId ?? 0) > 0) 'player_id': playerId,
      if (playerName.isNotEmpty) 'player_name': playerName,
      'report_title': report.title,
      'report_date': report.dateLabel,
      'archive_date': date.toIso8601String(),
      'verified_data': true,
      'sportoteka_workspace_context': workspaceContext,
      'verified_report_summary': <String, dynamic>{
        'duration': report.durationLabel,
        'players_count': report.players.length,
        'gps_points_count': report.routePoints.length,
        'heart_rate_samples_count': s.heartRateSamplesCount,
        'average_distance_m': s.averageDistanceM,
        'total_distance_m': s.totalDistanceM,
        'high_speed_distance_m': s.highSpeedDistanceM,
        'distance_per_min': s.distancePerMin,
        'max_speed_kmh': s.maxSpeedKmh,
        'avg_speed_kmh': s.avgSpeedKmh,
        'sprint_count': s.sprintCount,
        'sprint_distance_m': s.sprintDistanceM,
        'acceleration_count': s.accelerationCount,
        'deceleration_count': s.decelerationCount,
        'acc_dec_per_min': s.accDecPerMin,
        'explosive_actions': s.explosiveActions,
        'player_load': s.playerLoad,
        'heart_rate_avg_bpm': s.heartRateAvgBpm,
        'heart_rate_max_bpm': s.heartRateMaxBpm,
      },
      'verified_players': report.players
          .map((p) => <String, dynamic>{
                'player_id': p.playerId,
                'name': p.name,
                'number': p.number,
                'position': p.position,
                'duration': p.duration,
                'distance_m': p.distanceM,
                'meters_per_min': p.metersPerMin,
                'max_speed_kmh': p.maxSpeedKmh,
                'avg_speed_kmh': p.avgSpeedKmh,
                'accelerations': p.accelerations,
                'decelerations': p.decelerations,
                'acc_dec_per_min': p.accDecPerMin,
                'explosive_actions': p.explosiveActions,
                'sprint_count': p.sprintCount,
                'high_speed_work_m': p.highSpeedWorkM,
                'player_load': p.playerLoad,
                'heart_rate_avg_bpm': p.heartRateAvgBpm,
                'heart_rate_max_bpm': p.heartRateMaxBpm,
                'heart_rate_samples_count': p.heartRateSamplesCount,
                'gps_points_count': p.pointsCount,
              })
          .toList(growable: false),
    };
  }

  String _analysisPrompt({
    required bool personal,
    required String playerName,
    required String teamName,
  }) {
    if (personal) {
      final player = playerName.trim().isEmpty ? 'игрока' : playerName.trim();
      return 'Составь расширенный итоговый анализ завершённой ЛИЧНОЙ тренировки $player '
          'для автоматического документа Sportoteka OS. Используй verified_report_summary, verified_players '
          'и sportoteka_workspace_context из context. Планы/описания из Sportoteka OS можно использовать как '
          'контекст того, что планировалось или было записано, а числовые выводы делай только по проверенным Tracker-данным. '
          'Не придумывай цифры, упражнения, диагнозы или события. '
          'В начале явно укажи игрока, команду и дату. Затем последовательно раскрой: '
          '1) что фактически произошло на тренировке; 2) объём и интенсивность; '
          '3) скоростную и спринтерскую работу; 4) ускорения/торможения и механическую нагрузку; '
          '5) пульс и внутреннюю нагрузку, только если есть данные; 6) сильные стороны и сигналы внимания; '
          '7) восстановление; 8) конкретные советы игроку; 9) рекомендации к следующей личной тренировке. '
          'Если показателя нет, прямо напиши, что данных недостаточно. Пиши по-русски, профессионально, '
          'понятно игроку и тренеру, с подробными абзацами и короткими маркированными рекомендациями. '
          'Не используй общие фразы без опоры на данные.';
    }
    return 'Составь расширенный итоговый анализ завершённой КОМАНДНОЙ тренировки команды «$teamName» '
        'для автоматического документа Sportoteka OS. Используй verified_report_summary, verified_players и '
        'sportoteka_workspace_context из context. Сопоставь план/описание/документы тренировки с фактическими '
        'Tracker-показателями, но не утверждай, что упражнение выполнялось, если это есть только в плане. '
        'Не придумывай цифры, упражнения, диагнозы или события. '
        'В начале явно укажи команду и дату. Затем раскрой: 1) что фактически произошло; '
        '2) общий объём и интенсивность; 3) скоростную/спринтерскую работу; '
        '4) ускорения, торможения и механическую нагрузку; 5) пульс, если он измерялся; '
        '6) распределение нагрузки по игрокам с ФИО; 7) игроков с заметными отклонениями и почему это важно; '
        '8) восстановление и контроль нагрузки; 9) конкретные рекомендации тренеру; '
        '10) задачи и акценты для следующей командной тренировки. Если данных нет — так и напиши. '
        'Не делай медицинских диагнозов. Пиши по-русски, подробно, профессионально, с понятными выводами.';
  }

  String _buildDocumentBody({
    required TrackerTrainingReport report,
    required List<int> sessionIds,
    required bool personal,
    required String teamName,
    required String playerName,
    required DateTime date,
    required String aiAnswer,
  }) {
    final s = report.summary;
    final lines = <String>[
      'АНАЛИЗ ИИ',
      '',
      'Дата: ${_dateLabel(date)}',
      'Тип: ${personal ? 'Личная тренировка' : 'Командная тренировка'}',
      if (personal) 'Игрок: ${playerName.isEmpty ? 'не определён' : playerName}',
      'Команда: $teamName',
      'Tracker-сессии: ${sessionIds.map((id) => '#$id').join(', ')}',
      if (report.durationLabel.trim().isNotEmpty) 'Длительность: ${report.durationLabel}',
      if (!personal) 'Игроков в отчёте: ${report.players.length}',
      '',
      'ПРОВЕРЕННЫЕ ДАННЫЕ TRACKER',
      '• Дистанция: ${_meters(s.totalDistanceM)}',
      '• Средняя дистанция${personal ? '' : ' на игрока'}: ${_meters(s.averageDistanceM)}',
      '• Максимальная скорость: ${_number(s.maxSpeedKmh)} км/ч',
      '• Средняя скорость: ${_number(s.avgSpeedKmh)} км/ч',
      '• Спринты: ${s.sprintCount}',
      '• Спринтерская дистанция: ${_meters(s.sprintDistanceM)}',
      '• Ускорения / торможения: ${s.accelerationCount} / ${s.decelerationCount}',
      '• Взрывные действия: ${s.explosiveActions}',
      '• Player Load: ${_number(s.playerLoad)}',
      if (s.heartRateSamplesCount > 0)
        '• Пульс: средний ${_number(s.heartRateAvgBpm)} bpm · максимум ${_number(s.heartRateMaxBpm)} bpm · ${s.heartRateSamplesCount} измерений',
      '',
      if (!personal && report.players.isNotEmpty) ...<String>[
        'ИГРОКИ',
        for (final p in report.players)
          '• ${p.name.trim().isEmpty ? 'Игрок #${p.playerId ?? 0}' : p.name}: '
              '${_meters(p.distanceM)} · max ${_number(p.maxSpeedKmh)} км/ч · '
              '${p.sprintCount} спринтов · ${p.accelerations}/${p.decelerations} ускор./торм. · '
              'Load ${_number(p.playerLoad)}'
              '${p.heartRateSamplesCount > 0 ? ' · HR ${_number(p.heartRateAvgBpm)}/${_number(p.heartRateMaxBpm)}' : ''}',
        '',
      ],
      'РАЗБОР SPORTOTEKA AI',
      aiAnswer.trim(),
      '',
      'Источник данных: Tracker SPORTOTEKA · автоматический анализ SPORTOTEKA AI.',
      'ИИ использовал проверенные показатели завершённой тренировки; отсутствующие показатели не должны подменяться предположениями.',
    ];
    return lines.join('\n');
  }

  String _resolvePlayerName(
    TrackerTrainingReport report, {
    int? playerId,
    String fallback = '',
  }) {
    if ((playerId ?? 0) > 0) {
      for (final p in report.players) {
        if (p.playerId == playerId && p.name.trim().isNotEmpty) {
          return p.name.trim();
        }
      }
    }
    for (final p in report.players) {
      final name = p.name.trim();
      if (name.isNotEmpty && name.toLowerCase() != 'игрок') return name;
    }
    return fallback.trim();
  }

  DateTime? _reportDate(TrackerTrainingReport report) {
    final raw = report.dateLabel.trim();
    if (raw.isEmpty) return null;
    final direct = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (direct != null) return direct;
    final match = RegExp(r'^(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{4})').firstMatch(raw);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
  }

  int _syntheticTrainingEntityId({
    required int sessionId,
    required bool personal,
  }) {
    final normalized = sessionId.abs() % 400000000;
    return (personal ? 1500000000 : 1100000000) + normalized;
  }

  int _eventId(Map<String, dynamic> row) => int.tryParse(
        '${row['event_id'] ?? row['training_id'] ?? row['calendar_event_id'] ?? row['id'] ?? 0}',
      ) ?? 0;

  DateTime? _eventDate(Map<String, dynamic> row) {
    for (final key in const <String>[
      'start_at',
      'event_date',
      'training_date',
      'date',
      'created_at',
    ]) {
      final raw = '${row[key] ?? ''}'.trim();
      if (raw.isEmpty || raw == 'null') continue;
      final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool _looksLikeTraining(Map<String, dynamic> row) {
    final type = '${row['type'] ?? row['event_type'] ?? row['kind'] ?? row['category'] ?? ''}'
        .toLowerCase();
    if (type.contains('training') ||
        type.contains('трен') ||
        type == 'gym' ||
        type.contains('ofp') ||
        type.contains('офп') ||
        type.contains('зал')) {
      return true;
    }
    final title = '${row['title'] ?? row['event_title'] ?? row['name'] ?? ''}'.toLowerCase();
    return title.contains('трениров');
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d.$m.${date.year}';
  }

  String _meters(double value) {
    if (!value.isFinite || value <= 0) return 'нет данных';
    if (value >= 1000) return '${_number(value / 1000)} км';
    return '${value.round()} м';
  }

  String _number(double value) {
    if (!value.isFinite || value <= 0) return 'нет данных';
    final rounded = value.toStringAsFixed(1);
    return rounded.endsWith('.0') ? rounded.substring(0, rounded.length - 2) : rounded;
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final clean = value.trim();
      if (clean.isNotEmpty && clean.toLowerCase() != 'null') return clean;
    }
    return '';
  }
}
