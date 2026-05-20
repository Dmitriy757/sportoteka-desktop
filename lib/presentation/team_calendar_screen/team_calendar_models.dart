import 'package:flutter/material.dart';

enum TeamEventType {
  training,       // зелёный
  leagueMatch,    // красный (чемпионат)
  friendlyMatch,  // голубой
  theory,         // жёлтый
  gym,            // фиолетовый
  dayOff,         // серый
}

Color eventTypeColor(TeamEventType t) {
  switch (t) {
    case TeamEventType.training:
      return const Color(0xFF16A34A);
    case TeamEventType.leagueMatch:
      return const Color(0xFFEF4444);
    case TeamEventType.friendlyMatch:
      return const Color(0xFF0EA5E9);
    case TeamEventType.theory:
      return const Color(0xFFF59E0B);
    case TeamEventType.gym:
      return const Color(0xFF7C3AED);
    case TeamEventType.dayOff:
      return const Color(0xFF9CA3AF);
  }
}

/// Из БД -> enum
TeamEventType parseEventType(String raw) {
  final t = raw.trim().toLowerCase();

  if (t == 'dayoff' || t == 'day_off' || t == 'off' || t == 'выходной') {
    return TeamEventType.dayOff;
  }
  if (t == 'theory' || t == 'lecture' || t == 'class' || t == 'теория') {
    return TeamEventType.theory;
  }
  if (t == 'gym' || t == 'ofp' || t == 'офп' || t == 'зал' || t == 'training_gym') {
    return TeamEventType.gym;
  }
  if (t == 'league' || t == 'league_match' || t == 'championship' || t == 'official' || t == 'чемпионат') {
    return TeamEventType.leagueMatch;
  }
  if (t == 'friendly' || t == 'friendly_match' || t == 'товарищеский' || t == 'товарищ.') {
    return TeamEventType.friendlyMatch;
  }

  // fallback для старых значений
  if (t == 'match') return TeamEventType.leagueMatch;

  return TeamEventType.training;
}

/// enum -> в БД (важно!)
String eventTypeToDb(TeamEventType t) {
  switch (t) {
    case TeamEventType.training:
      return 'training';
    case TeamEventType.leagueMatch:
      return 'league';
    case TeamEventType.friendlyMatch:
      return 'friendly';
    case TeamEventType.theory:
      return 'theory';
    case TeamEventType.gym:
      return 'gym';
    case TeamEventType.dayOff:
      return 'day_off';
  }
}

String eventTypeLabel(TeamEventType t) {
  switch (t) {
    case TeamEventType.training:
      return "Тренировка";
    case TeamEventType.leagueMatch:
      return "Игра (чемпионат)";
    case TeamEventType.friendlyMatch:
      return "Товарищеская";
    case TeamEventType.theory:
      return "Теория";
    case TeamEventType.gym:
      return "ОФП / Зал";
    case TeamEventType.dayOff:
      return "Выходной";
  }
}

class TeamEvent {
  final int id;
  final int teamId;
  final int clubId;
  final TeamEventType type;

  final String title;
  final DateTime startAt;
  final DateTime? endAt;

  final String location;
  final String notes;

  TeamEvent({
    required this.id,
    required this.teamId,
    required this.clubId,
    required this.type,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.location,
    required this.notes,
  });

  factory TeamEvent.fromJson(Map<String, dynamic> j) {
    final startRaw = (j['start_at'] ?? '').toString().replaceFirst(' ', 'T');
    final endRaw = (j['end_at'] ?? '').toString().trim();

    final start = DateTime.tryParse(startRaw) ?? DateTime.now();
    DateTime? end;
    if (endRaw.isNotEmpty && endRaw.toLowerCase() != 'null') {
      end = DateTime.tryParse(endRaw.replaceFirst(' ', 'T'));
    }

    return TeamEvent(
      id: int.tryParse((j['id'] ?? 0).toString()) ?? 0,
      teamId: int.tryParse((j['team_id'] ?? 0).toString()) ?? 0,
      clubId: int.tryParse((j['club_id'] ?? 0).toString()) ?? 0,
      type: parseEventType((j['type'] ?? 'training').toString()),
      title: (j['title'] ?? '').toString(),
      startAt: start,
      endAt: end,
      location: (j['location'] ?? '').toString(),
      notes: (j['notes'] ?? '').toString(),
    );
  }

  TeamEvent copyWith({
    int? id,
    int? teamId,
    int? clubId,
    TeamEventType? type,
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    String? location,
    String? notes,
  }) {
    return TeamEvent(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      clubId: clubId ?? this.clubId,
      type: type ?? this.type,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      location: location ?? this.location,
      notes: notes ?? this.notes,
    );
  }
}

// ===== helpers =====
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
DateTime lastDayOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

DateTime startOfWeekMonday(DateTime d) {
  final base = DateTime(d.year, d.month, d.day);
  final diff = base.weekday - DateTime.monday;
  return base.subtract(Duration(days: diff));
}

String formatDateSql(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return "${d.year}-$mm-$dd";
}

String formatSqlDateTime(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  final ss = d.second.toString().padLeft(2, '0');
  return "${d.year}-$mm-$dd $hh:$mi:$ss";
}

String hhmm(DateTime d) =>
    "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
