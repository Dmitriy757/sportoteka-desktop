import 'dart:convert';

class AiJobStatus {
  final String jobId;
  final String status;
  final int progress;
  final String message;

  const AiJobStatus({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.message,
  });

  factory AiJobStatus.fromJson(Map<String, dynamic> json) {
    return AiJobStatus(
      jobId: (json['job_id'] ?? '').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      progress: int.tryParse((json['progress'] ?? 0).toString()) ?? 0,
      message: (json['message'] ?? '').toString(),
    );
  }
}

class AiCreateJobResponse {
  final bool success;
  final String jobId;
  final String status;
  final Map<String, dynamic> job;

  const AiCreateJobResponse({
    required this.success,
    required this.jobId,
    required this.status,
    required this.job,
  });

  factory AiCreateJobResponse.fromJson(Map<String, dynamic> json) {
    return AiCreateJobResponse(
      success: json['success'] == true,
      jobId: (json['job_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      job: Map<String, dynamic>.from(json['job'] ?? const {}),
    );
  }
}

class AiUploadVideoResponse {
  final bool success;
  final String jobId;
  final String filename;
  final String videoPath;
  final int sizeBytes;

  const AiUploadVideoResponse({
    required this.success,
    required this.jobId,
    required this.filename,
    required this.videoPath,
    required this.sizeBytes,
  });

  factory AiUploadVideoResponse.fromJson(Map<String, dynamic> json) {
    return AiUploadVideoResponse(
      success: json['success'] == true,
      jobId: (json['job_id'] ?? '').toString(),
      filename: (json['filename'] ?? '').toString(),
      videoPath: (json['video_path'] ?? '').toString(),
      sizeBytes: int.tryParse((json['size_bytes'] ?? 0).toString()) ?? 0,
    );
  }
}

class AiRunAnalysisResponse {
  final bool success;
  final String jobId;
  final String status;
  final int trackingFrames;
  final int eventsCount;
  final int autoTtdCount;
  final Map<String, dynamic> summary;

  const AiRunAnalysisResponse({
    required this.success,
    required this.jobId,
    required this.status,
    required this.trackingFrames,
    required this.eventsCount,
    required this.autoTtdCount,
    required this.summary,
  });

  factory AiRunAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return AiRunAnalysisResponse(
      success: json['success'] == true,
      jobId: (json['job_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      trackingFrames:
          int.tryParse((json['tracking_frames'] ?? 0).toString()) ?? 0,
      eventsCount: int.tryParse((json['events_count'] ?? 0).toString()) ?? 0,
      autoTtdCount: int.tryParse((json['auto_ttd_count'] ?? 0).toString()) ?? 0,
      summary: Map<String, dynamic>.from(json['summary'] ?? const {}),
    );
  }
}

class AiMatchEvent {
  final String id;
  final String type;
  final String? team;
  final int? playerId;
  final int? targetPlayerId;
  final int? trackId;
  final int? targetTrackId;
  final int startMs;
  final int endMs;
  final bool? success;
  final double confidence;
  final String? title;
  final String? description;
  final List<AiEventParticipant> participants;
  final Map<String, dynamic> meta;

  const AiMatchEvent({
    required this.id,
    required this.type,
    required this.team,
    required this.playerId,
    required this.targetPlayerId,
    required this.trackId,
    required this.targetTrackId,
    required this.startMs,
    required this.endMs,
    required this.success,
    required this.confidence,
    required this.title,
    required this.description,
    required this.participants,
    required this.meta,
  });

  factory AiMatchEvent.fromJson(Map<String, dynamic> json) {
    final rawParticipants = (json['participants'] as List?) ?? const [];
    return AiMatchEvent(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      team: json['team']?.toString(),
      playerId: int.tryParse((json['player_id'] ?? '').toString()),
      targetPlayerId:
          int.tryParse((json['target_player_id'] ?? '').toString()),
      trackId: int.tryParse((json['track_id'] ?? '').toString()),
      targetTrackId:
          int.tryParse((json['target_track_id'] ?? '').toString()),
      startMs: int.tryParse((json['start_ms'] ?? 0).toString()) ?? 0,
      endMs: int.tryParse((json['end_ms'] ?? 0).toString()) ?? 0,
      success: json['success'] == null ? null : json['success'] == true,
      confidence:
          double.tryParse((json['confidence'] ?? 0).toString()) ?? 0.0,
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      participants: rawParticipants
          .map((e) => AiEventParticipant.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      meta: Map<String, dynamic>.from(json['meta'] ?? const {}),
    );
  }
}

class AiEventParticipant {
  final int? trackId;
  final int? playerId;
  final String? team;
  final String? role;
  final String? name;

  const AiEventParticipant({
    required this.trackId,
    required this.playerId,
    required this.team,
    required this.role,
    required this.name,
  });

  factory AiEventParticipant.fromJson(Map<String, dynamic> json) {
    return AiEventParticipant(
      trackId: int.tryParse((json['track_id'] ?? '').toString()),
      playerId: int.tryParse((json['player_id'] ?? '').toString()),
      team: json['team']?.toString(),
      role: json['role']?.toString(),
      name: json['name']?.toString(),
    );
  }
}

class AiEventsResponse {
  final String jobId;
  final int total;
  final List<AiMatchEvent> events;

  const AiEventsResponse({
    required this.jobId,
    required this.total,
    required this.events,
  });

  factory AiEventsResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['events'] as List?) ?? const [];
    return AiEventsResponse(
      jobId: (json['job_id'] ?? '').toString(),
      total: int.tryParse((json['total'] ?? 0).toString()) ?? 0,
      events: raw
          .map((e) => AiMatchEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class AiAutoTtdItem {
  final String id;
  final String? sourceEventId;
  final String source;
  final String? team;
  final int? playerId;
  final int? trackId;
  final String eventType;
  final String? eventTitle;
  final int isPositive;
  final int startMs;
  final int endMs;
  final double confidence;
  final String? note;
  final Map<String, dynamic> meta;

  const AiAutoTtdItem({
    required this.id,
    required this.sourceEventId,
    required this.source,
    required this.team,
    required this.playerId,
    required this.trackId,
    required this.eventType,
    required this.eventTitle,
    required this.isPositive,
    required this.startMs,
    required this.endMs,
    required this.confidence,
    required this.note,
    required this.meta,
  });

  factory AiAutoTtdItem.fromJson(Map<String, dynamic> json) {
    return AiAutoTtdItem(
      id: (json['id'] ?? '').toString(),
      sourceEventId: json['source_event_id']?.toString(),
      source: (json['source'] ?? 'ai').toString(),
      team: json['team']?.toString(),
      playerId: int.tryParse((json['player_id'] ?? '').toString()),
      trackId: int.tryParse((json['track_id'] ?? '').toString()),
      eventType: (json['event_type'] ?? '').toString(),
      eventTitle: json['event_title']?.toString(),
      isPositive: int.tryParse((json['is_positive'] ?? 0).toString()) ?? 0,
      startMs: int.tryParse((json['start_ms'] ?? 0).toString()) ?? 0,
      endMs: int.tryParse((json['end_ms'] ?? 0).toString()) ?? 0,
      confidence:
          double.tryParse((json['confidence'] ?? 0).toString()) ?? 0.0,
      note: json['note']?.toString(),
      meta: Map<String, dynamic>.from(json['meta'] ?? const {}),
    );
  }
}

class AiAutoTtdResponse {
  final String jobId;
  final int total;
  final List<AiAutoTtdItem> items;

  const AiAutoTtdResponse({
    required this.jobId,
    required this.total,
    required this.items,
  });

  factory AiAutoTtdResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['items'] as List?) ?? const [];
    return AiAutoTtdResponse(
      jobId: (json['job_id'] ?? '').toString(),
      total: int.tryParse((json['total'] ?? 0).toString()) ?? 0,
      items: raw
          .map((e) =>
              AiAutoTtdItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class AiTeamMatchStats {
  final int goals;
  final int shots;
  final int shotsOnGoal;
  final int freekicks;
  final int corners;
  final double possessionPercent;
  final double possessionMinutes;
  final int possessionWon;
  final int passesCompleted;
  final int passesTotal;
  final int interceptions;
  final int recoveries;
  final int duelsWon;
  final int throwIns;
  final int saves;
  final int conceded;

  const AiTeamMatchStats({
    required this.goals,
    required this.shots,
    required this.shotsOnGoal,
    required this.freekicks,
    required this.corners,
    required this.possessionPercent,
    required this.possessionMinutes,
    required this.possessionWon,
    required this.passesCompleted,
    required this.passesTotal,
    required this.interceptions,
    required this.recoveries,
    required this.duelsWon,
    required this.throwIns,
    required this.saves,
    required this.conceded,
  });

  factory AiTeamMatchStats.empty() {
    return const AiTeamMatchStats(
      goals: 0,
      shots: 0,
      shotsOnGoal: 0,
      freekicks: 0,
      corners: 0,
      possessionPercent: 0,
      possessionMinutes: 0,
      possessionWon: 0,
      passesCompleted: 0,
      passesTotal: 0,
      interceptions: 0,
      recoveries: 0,
      duelsWon: 0,
      throwIns: 0,
      saves: 0,
      conceded: 0,
    );
  }

  factory AiTeamMatchStats.fromJson(Map<String, dynamic> json) {
    return AiTeamMatchStats(
      goals: int.tryParse((json['goals'] ?? 0).toString()) ?? 0,
      shots: int.tryParse((json['shots'] ?? 0).toString()) ?? 0,
      shotsOnGoal: int.tryParse((json['shots_on_goal'] ?? 0).toString()) ?? 0,
      freekicks: int.tryParse((json['freekicks'] ?? 0).toString()) ?? 0,
      corners: int.tryParse((json['corners'] ?? 0).toString()) ?? 0,
      possessionPercent:
          double.tryParse((json['possession_percent'] ?? 0).toString()) ?? 0.0,
      possessionMinutes:
          double.tryParse((json['possession_minutes'] ?? 0).toString()) ?? 0.0,
      possessionWon:
          int.tryParse((json['possession_won'] ?? 0).toString()) ?? 0,
      passesCompleted:
          int.tryParse((json['passes_completed'] ?? 0).toString()) ?? 0,
      passesTotal: int.tryParse((json['passes_total'] ?? 0).toString()) ?? 0,
      interceptions:
          int.tryParse((json['interceptions'] ?? 0).toString()) ?? 0,
      recoveries: int.tryParse((json['recoveries'] ?? 0).toString()) ?? 0,
      duelsWon: int.tryParse((json['duels_won'] ?? 0).toString()) ?? 0,
      throwIns: int.tryParse((json['throw_ins'] ?? 0).toString()) ?? 0,
      saves: int.tryParse((json['saves'] ?? 0).toString()) ?? 0,
      conceded: int.tryParse((json['conceded'] ?? 0).toString()) ?? 0,
    );
  }
}

class AiMatchStatsResponse {
  final String jobId;
  final AiTeamMatchStats home;
  final AiTeamMatchStats away;
  final int eventsCount;
  final String generatedAt;
  final Map<String, dynamic> extra;

  const AiMatchStatsResponse({
    required this.jobId,
    required this.home,
    required this.away,
    required this.eventsCount,
    required this.generatedAt,
    required this.extra,
  });

  factory AiMatchStatsResponse.fromJson(Map<String, dynamic> json) {
    return AiMatchStatsResponse(
      jobId: (json['job_id'] ?? '').toString(),
      home: AiTeamMatchStats.fromJson(
        Map<String, dynamic>.from(json['home'] ?? const {}),
      ),
      away: AiTeamMatchStats.fromJson(
        Map<String, dynamic>.from(json['away'] ?? const {}),
      ),
      eventsCount: int.tryParse((json['events_count'] ?? 0).toString()) ?? 0,
      generatedAt: (json['generated_at'] ?? '').toString(),
      extra: Map<String, dynamic>.from(json['extra'] ?? const {}),
    );
  }
}

class AiPlayerAutoStats {
  final int? playerId;
  final int? trackId;
  final String playerName;
  final String? team;
  final int passesCompleted;
  final int passesTotal;
  final int shots;
  final int interceptions;
  final int recoveries;
  final int duelsWon;
  final int involvement;
  final double confidence;

  const AiPlayerAutoStats({
    required this.playerId,
    required this.trackId,
    required this.playerName,
    required this.team,
    required this.passesCompleted,
    required this.passesTotal,
    required this.shots,
    required this.interceptions,
    required this.recoveries,
    required this.duelsWon,
    required this.involvement,
    required this.confidence,
  });

  factory AiPlayerAutoStats.fromJson(Map<String, dynamic> json) {
    return AiPlayerAutoStats(
      playerId: int.tryParse((json['player_id'] ?? '').toString()),
      trackId: int.tryParse((json['track_id'] ?? '').toString()),
      playerName: (json['player_name'] ?? 'Игрок').toString(),
      team: json['team']?.toString(),
      passesCompleted:
          int.tryParse((json['passes_completed'] ?? 0).toString()) ?? 0,
      passesTotal: int.tryParse((json['passes_total'] ?? 0).toString()) ?? 0,
      shots: int.tryParse((json['shots'] ?? 0).toString()) ?? 0,
      interceptions:
          int.tryParse((json['interceptions'] ?? 0).toString()) ?? 0,
      recoveries: int.tryParse((json['recoveries'] ?? 0).toString()) ?? 0,
      duelsWon: int.tryParse((json['duels_won'] ?? 0).toString()) ?? 0,
      involvement: int.tryParse((json['involvement'] ?? 0).toString()) ?? 0,
      confidence:
          double.tryParse((json['confidence'] ?? 0).toString()) ?? 0.0,
    );
  }
}

class AiSummaryResponse {
  final String jobId;
  final Map<String, dynamic> video;
  final Map<String, dynamic> tracking;
  final int eventsCount;
  final int autoTtdCount;
  final AiMatchStatsResponse? matchStats;
  final List<AiPlayerAutoStats> playersAutoStats;

  const AiSummaryResponse({
    required this.jobId,
    required this.video,
    required this.tracking,
    required this.eventsCount,
    required this.autoTtdCount,
    required this.matchStats,
    required this.playersAutoStats,
  });

  factory AiSummaryResponse.fromJson(Map<String, dynamic> json) {
    final rawPlayers = (json['players_auto_stats'] as List?) ?? const [];
    final rawMatchStats = json['match_stats'];

    return AiSummaryResponse(
      jobId: (json['job_id'] ?? '').toString(),
      video: Map<String, dynamic>.from(json['video'] ?? const {}),
      tracking: Map<String, dynamic>.from(json['tracking'] ?? const {}),
      eventsCount: int.tryParse((json['events_count'] ?? 0).toString()) ?? 0,
      autoTtdCount:
          int.tryParse((json['auto_ttd_count'] ?? 0).toString()) ?? 0,
      matchStats: rawMatchStats is Map<String, dynamic>
          ? AiMatchStatsResponse.fromJson(rawMatchStats)
          : rawMatchStats is Map
              ? AiMatchStatsResponse.fromJson(
                  Map<String, dynamic>.from(rawMatchStats))
              : null,
      playersAutoStats: rawPlayers
          .map((e) =>
              AiPlayerAutoStats.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  static AiSummaryResponse fromRawString(String source) {
    final Map<String, dynamic> jsonMap =
        json.decode(source) as Map<String, dynamic>;
    return AiSummaryResponse.fromJson(jsonMap);
  }
}