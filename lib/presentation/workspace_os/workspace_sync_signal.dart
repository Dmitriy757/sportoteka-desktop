import 'package:flutter/foundation.dart';

/// Lightweight in-process signal used to keep Calendar and Sportoteka OS in sync.
///
/// Calendar still remains the source of truth on the server. This notifier only
/// tells an already mounted Workspace panel that it should re-read the real
/// calendar/training records immediately instead of waiting for a manual refresh.
class WorkspaceSyncSignal {
  WorkspaceSyncSignal._();

  static final ValueNotifier<int> calendarRevision = ValueNotifier<int>(0);
  static final ValueNotifier<int> trackerRevision = ValueNotifier<int>(0);
  static int _lastCalendarTeamId = 0;
  static int _lastTrackerTeamId = 0;
  static List<int> _lastTrackerSessionIds = const <int>[];

  static int get lastCalendarTeamId => _lastCalendarTeamId;
  static int get lastTrackerTeamId => _lastTrackerTeamId;
  static List<int> get lastTrackerSessionIds => _lastTrackerSessionIds;

  static void calendarChanged({int teamId = 0}) {
    _lastCalendarTeamId = teamId;
    calendarRevision.value = calendarRevision.value + 1;
  }

  static void trackerChanged({int teamId = 0, Iterable<int> sessionIds = const <int>[]}) {
    _lastTrackerTeamId = teamId;
    _lastTrackerSessionIds = sessionIds.where((id) => id > 0).toSet().toList(growable: false);
    trackerRevision.value = trackerRevision.value + 1;
  }
}
