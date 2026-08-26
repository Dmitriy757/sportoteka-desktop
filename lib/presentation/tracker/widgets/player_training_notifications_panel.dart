import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/theme/app_typography.dart';

import '../models/tracker_pro_models.dart';
import '../models/tracker_pitch_projection.dart';
import 'tracker_2gis_map_layer.dart';
import 'player_training_calendar_panel.dart';


DateTime? _trackerParseServerInstant(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty || raw == 'null') return null;
  final normalized = raw.replaceFirst(' ', 'T');
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
      .hasMatch(normalized);
  if (hasZone) return DateTime.tryParse(normalized)?.toUtc();

  final naive = DateTime.tryParse(normalized);
  if (naive == null) return null;
  // Серверные MySQL-строки без timezone считаем UTC.
  return DateTime.utc(
    naive.year,
    naive.month,
    naive.day,
    naive.hour,
    naive.minute,
    naive.second,
    naive.millisecond,
    naive.microsecond,
  );
}

DateTime? _trackerMoscowDateTime(dynamic value) {
  final instant = _trackerParseServerInstant(value);
  if (instant == null) return null;
  final moscow = instant.add(const Duration(hours: 3));
  // Возвращаем wall-clock Moscow без зависимости от timezone устройства.
  return DateTime(
    moscow.year,
    moscow.month,
    moscow.day,
    moscow.hour,
    moscow.minute,
    moscow.second,
    moscow.millisecond,
    moscow.microsecond,
  );
}

DateTime _trackerMoscowFromEpochMs(int millisecondsSinceEpoch) {
  final moscow = DateTime.fromMillisecondsSinceEpoch(
    millisecondsSinceEpoch,
    isUtc: true,
  ).add(const Duration(hours: 3));
  return DateTime(
    moscow.year,
    moscow.month,
    moscow.day,
    moscow.hour,
    moscow.minute,
    moscow.second,
    moscow.millisecond,
    moscow.microsecond,
  );
}


enum _CoachPersonalView { overview, live, journal, comparison, calendar }

class PlayerTrainingNotificationsPanel extends StatefulWidget {
  const PlayerTrainingNotificationsPanel({
    super.key,
    required this.teamId,
    this.teamName = 'Команда',
    this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker',
    this.onOpenAnalytics,
    this.onOpenReport,
    this.onSelectPlayer,
    this.onExitWorkspace,
    this.selectedField,
    this.cmrEmbedded = false,
    this.externalViewIndex = 0,
    this.externalViewSignal = 0,
    this.startInLive = false,
    this.onPersonalLiveFullscreenChanged,
    this.playerDirectory = const <int, Map<String, String>>{},
  });

  final int teamId;
  final String teamName;
  final String apiBaseUrl;
  final ValueChanged<Map<String, dynamic>>? onOpenAnalytics;
  final ValueChanged<Map<String, dynamic>>? onOpenReport;
  /// V204: полноэкранный тренерский центр имеет собственный выход обратно
  /// в основной Tracker workspace. Внутри выбранной сессии стрелка «назад»
  /// возвращает к списку личных тренировок и не закрывает весь экран.
  final VoidCallback? onExitWorkspace;
  final TrackerFieldModel? selectedField;

  /// V207: обычный Personal-раздел использует общий CMR shell как Аналитика.
  final bool cmrEmbedded;

  /// 0 Сессии · 1 Live · 2 События · 3 Календарь · 4 Сравнение.
  final int externalViewIndex;
  final int externalViewSignal;

  /// Полный экран нужен только активному Personal Live.
  final bool startInLive;
  final ValueChanged<bool>? onPersonalLiveFullscreenChanged;

  /// V166: синхронизирует выбор игрока с правой CMR-панелью родительского workspace.
  final ValueChanged<int?>? onSelectPlayer;
  /// Справочник состава: playerId -> {name, avatar}. Используется, когда API
  /// возвращает техническое имя вроде «Игрок 181».
  final Map<int, Map<String, String>> playerDirectory;

  @override
  State<PlayerTrainingNotificationsPanel> createState() => _PlayerTrainingNotificationsPanelState();
}

class _PlayerTrainingNotificationsPanelState extends State<PlayerTrainingNotificationsPanel> {
  static const _green = Color(0xFF00A750);
  static const _greenSoft = Color(0xFFF3FAF6);
  static const _text = Color(0xFF171B18);
  static const _muted = Color(0xFF66716A);
  static const _line = Color(0xFFE9ECEA);
  static const _soft = Color(0xFFF7F8F7);
  static const _red = Color(0xFFDC2626);
  static const _blue = Color(0xFF2563EB);
  static const _orange = Color(0xFFF59E0B);

  // V206: exact visual palette of TrackerLivePanel (_OF). Personal Live
  // intentionally uses the same surfaces, graphite and secondary text.
  static const _liveText = Color(0xFF0B0F14);
  static const _liveMuted = Color(0xFF5F6670);
  static const _liveMuted2 = Color(0xFF8A9099);
  static const _liveGraphite = Color(0xFF111827);
  static const _liveLineStrong = Color(0xFFE1E5E2);
  static const _liveGreenBorder = Color(0xFFD7F0E2);

  TextStyle _liveTitle(double size, {Color color = _liveText}) {
    final base = size >= 17
        ? AppTypography.screenTitle(color: color)
        : size >= 14.5
            ? AppTypography.sectionTitle(color: color)
            : AppTypography.subsectionTitle(color: color);
    return base.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  TextStyle _liveBody(
    double size, {
    Color color = _liveText,
    FontWeight weight = FontWeight.w400,
    double height = 1.22,
  }) {
    final base = size < 10.8
        ? AppTypography.caption(color: color)
        : size < 12
            ? AppTypography.secondary(color: color)
            : AppTypography.body(color: color);
    return base.copyWith(fontWeight: weight, height: height);
  }

  Timer? _timer;
  Timer? _clockTimer;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _live = const [];
  List<Map<String, dynamic>> _events = const [];
  List<Map<String, dynamic>> _liveMoments = const [];
  final ValueNotifier<String?> _selectedPersonalLiveMomentId = ValueNotifier<String?>(null);
  Map<int, Map<String, String>> _resolvedDirectory = const <int, Map<String, String>>{};
  // Общая Live-история не сбрасывается при выходе из раздела и возврате.
  static final Map<String, List<_HrPoint>> _liveHrHistory = <String, List<_HrPoint>>{};
  static final Map<String, List<_LoadPoint>> _liveLoadHistory = <String, List<_LoadPoint>>{};
  static final Map<String, List<_GpsPoint>> _liveGpsHistory = <String, List<_GpsPoint>>{};
  final Map<String, GlobalKey> _liveCardKeys = <String, GlobalKey>{};
  int _eventDayOffset = 0;
  _CoachPersonalView _coachView = _CoachPersonalView.overview;
  int? _coachPlayerId;
  bool? _lastPersonalLiveFullscreenRequest;

  // V204 PERSONAL COACH FULLSCREEN:
  // Список сессий и подробный разбор живут в одном workspace, как «Карта».
  // Выбор сессии не открывает ещё одну модалку поверх интерфейса: правая
  // рабочая область заменяется полноценным экраном с метриками, GPS/Polar,
  // журналом и боковым инспектором. Стрелка назад возвращает именно к сессиям.
  Map<String, dynamic>? _coachWorkspaceSession;
  bool _coachWorkspaceSessionRunning = false;
  bool _coachWorkspaceSessionLoading = false;
  int _coachWorkspaceSessionToken = 0;

  // Личный Live повторяет компоновку командного Live:
  // слева одно рабочее окно (карта/пульс), справа данные/журнал.
  bool _personalLiveShowPulse = false;
  bool _personalLiveSideJournal = false;
  TrackerGeoBaseLayer _personalLiveGeoLayer = TrackerGeoBaseLayer.pitch;
  bool _personalLivePerspective3d = true;
  double? _personalLiveRotationDeg;
  String _personalLiveInspectorMode = 'journal'; // journal / speed / cardio
  bool _personalLiveShowTrace = true;
  bool _personalLiveShowHeat = false;
  bool _personalLiveShowEvents = true;
  bool _personalLiveShowHud = true;
  bool _personalLiveShowPlayerOnField = true;
  bool _loadInFlight = false;
  int _loadGeneration = 0;

  _CoachPersonalView _coachViewForExternalIndex(int index) {
    switch (index) {
      case 1:
        return _CoachPersonalView.live;
      case 2:
        return _CoachPersonalView.journal;
      case 3:
        return _CoachPersonalView.calendar;
      case 4:
        return _CoachPersonalView.comparison;
      case 0:
      default:
        return _CoachPersonalView.overview;
    }
  }

  void _queuePersonalLiveFullscreenSync() {
    final callback = widget.onPersonalLiveFullscreenChanged;
    if (callback == null) return;

    if (widget.startInLive && _loading && _live.isEmpty) {
      return;
    }

    final shouldFullscreen =
        _coachView == _CoachPersonalView.live && _live.isNotEmpty;
    if (_lastPersonalLiveFullscreenRequest == shouldFullscreen) return;
    _lastPersonalLiveFullscreenRequest = shouldFullscreen;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback(shouldFullscreen);
    });
  }

  @override
  void initState() {
    super.initState();
    _coachView = widget.startInLive
        ? _CoachPersonalView.live
        : _coachViewForExternalIndex(widget.externalViewIndex);
    _resolvedDirectory = Map<int, Map<String, String>>.from(widget.playerDirectory);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _load(silent: true));
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _live.isNotEmpty) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant PlayerTrainingNotificationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerDirectory != widget.playerDirectory) {
      _resolvedDirectory = <int, Map<String, String>>{
        ..._resolvedDirectory,
        ...widget.playerDirectory,
      };
    }

    final externalViewChanged =
        oldWidget.externalViewIndex != widget.externalViewIndex ||
        oldWidget.externalViewSignal != widget.externalViewSignal ||
        oldWidget.startInLive != widget.startInLive;
    if (externalViewChanged) {
      final next = widget.startInLive
          ? _CoachPersonalView.live
          : _coachViewForExternalIndex(widget.externalViewIndex);
      if (_coachView != next) {
        _coachView = next;
        _coachWorkspaceSession = null;
        _coachWorkspaceSessionRunning = false;
        _coachWorkspaceSessionLoading = false;
        _selectedPersonalLiveMomentId.value = null;
      }
      _lastPersonalLiveFullscreenRequest = null;
    }

    if (oldWidget.teamId != widget.teamId ||
        oldWidget.apiBaseUrl != widget.apiBaseUrl) {
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockTimer?.cancel();
    _selectedPersonalLiveMomentId.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (widget.teamId <= 0) return;
    // Не запускаем второй тяжёлый poll, пока первый ещё дочитывает HR/GPS.
    // Иначе старый ответ мог прийти позже нового и визуально перекидывать экран
    // между игроками, а также временно возвращать пустые Live-метрики.
    if (_loadInFlight) return;
    _loadInFlight = true;
    final generation = ++_loadGeneration;
    if (!silent && mounted) setState(() { _loading = true; _error = null; });

    try {
      final liveUri = Uri.parse('${widget.apiBaseUrl}/player_get_live_state.php').replace(queryParameters: {
        'team_id': '${widget.teamId}', 'personal_session': '1', 'active_only': '1', 'limit': '50',
      });
      final eventsUri = Uri.parse('${widget.apiBaseUrl}/player_get_training_notifications.php').replace(queryParameters: {
        'team_id': '${widget.teamId}', 'limit': '100', 'days': '7',
      });
      final playersUri = Uri.parse('${widget.apiBaseUrl}/get_tracker_players.php').replace(queryParameters: {
        'team_id': '${widget.teamId}',
      });
      final momentsUri = Uri.parse('${widget.apiBaseUrl}/get_tracker_live_events.php').replace(queryParameters: {
        'team_id': '${widget.teamId}',
        'limit': '700',
        '_ts': '${DateTime.now().millisecondsSinceEpoch}',
      });

      // Live — главный запрос. Ошибки вспомогательных endpoint больше не
      // уничтожают весь экран и не выводят красную ClientException сверху.
      final liveResponse = await http.get(liveUri).timeout(const Duration(seconds: 10));
      final liveJson = _decode(liveResponse.body);
      if (liveResponse.statusCode < 200 || liveResponse.statusCode >= 300 || liveJson['success'] == false) {
        throw Exception(liveJson['message'] ?? 'Ошибка Live API');
      }

      Map<String, dynamic> eventJson = const <String, dynamic>{};
      Map<String, dynamic> playersJson = const <String, dynamic>{};
      List<Map<String, dynamic>>? liveMoments;
      try {
        final response = await http.get(eventsUri).timeout(const Duration(seconds: 7));
        if (response.statusCode >= 200 && response.statusCode < 300) eventJson = _decode(response.body);
      } catch (_) {
        // Сохраняем уже показанные уведомления при временном обрыве соединения.
      }
      try {
        final response = await http.get(playersUri).timeout(const Duration(seconds: 7));
        if (response.statusCode >= 200 && response.statusCode < 300) playersJson = _decode(response.body);
      } catch (_) {
        // Имена и аватары остаются из предыдущего успешного обновления.
      }
      try {
        final response = await http.get(
          momentsUri,
          headers: const {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final json = _decode(response.body);
          if (json['success'] != false) {
            final raw = json['events'] as List? ?? const <dynamic>[];
            liveMoments = raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false);
          }
        }
      } catch (_) {
        // Live-моменты — дополнительный слой. При временной ошибке endpoint
        // оставляем предыдущий журнал и не мешаем основному Personal Live.
      }

      final directory = <int, Map<String, String>>{..._resolvedDirectory, ...widget.playerDirectory};
      final playersRaw = playersJson['players'] as List? ?? playersJson['items'] as List? ?? const [];
      for (final raw in playersRaw.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final id = _parsePositiveInt(item['id'] ?? item['player_id']);
        final userId = _parsePositiveInt(item['user_id'] ?? item['owner_user_id']);
        final name = _readText(item, const ['player_name', 'full_name', 'name'], fallback: '');
        final first = _readText(item, const ['first_name', 'player_first_name'], fallback: '');
        final last = _readText(item, const ['last_name', 'surname', 'player_last_name'], fallback: '');
        final resolvedName = (last.isNotEmpty || first.isNotEmpty) ? '$last $first'.trim() : name;
        final avatar = _readText(item, const ['avatar_url', 'avatar', 'photo_url', 'user_photo', 'photo'], fallback: '');
        final value = <String, String>{'name': resolvedName, 'avatar': avatar};
        if (id != null) directory[id] = value;
        if (userId != null) directory[userId] = value;
      }

      final liveRaw = liveJson['sessions'] as List? ??
          liveJson['live_sessions'] as List? ??
          liveJson['active_sessions'] as List? ??
          liveJson['items'] as List? ?? const [];
      final eventsRaw = eventJson['notifications'] as List? ?? eventJson['items'] as List? ?? const [];
      final baseLive = liveRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where(_isActivePersonalLive).toList();
      final live = await Future.wait(baseLive.map((source) async {
        final row = await _enrichLiveRow(source);
        await _enrichGpsRow(row);
        _rememberLiveTelemetry(row);
        return row;
      }));
      final events = eventsRaw.isEmpty
          ? _events
          : eventsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      if (!mounted || generation != _loadGeneration) return;

      // Сервер не обязан возвращать активные сессии в одном порядке.
      // Сохраняем уже показанный порядок карточек, новых игроков добавляем в конец.
      final previousOrder = <String, int>{
        for (var i = 0; i < _live.length; i++) _playerStableKey(_live[i]): i,
      };
      live.sort((a, b) {
        final ai = previousOrder[_playerStableKey(a)];
        final bi = previousOrder[_playerStableKey(b)];
        if (ai != null && bi != null) return ai.compareTo(bi);
        if (ai != null) return -1;
        if (bi != null) return 1;
        return _playerName(a).compareTo(_playerName(b));
      });

      setState(() {
        _resolvedDirectory = directory;
        _live = live;
        _events = events;
        if (liveMoments != null) _liveMoments = liveMoments!;
        final selectedMomentId = _selectedPersonalLiveMomentId.value;
        if (selectedMomentId != null &&
            !_liveMoments.any((event) => _liveMomentId(event) == selectedMomentId)) {
          _selectedPersonalLiveMomentId.value = null;
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      // Фоновое обновление не должно мигать ошибкой и убирать уже загруженные данные.
      if (silent) return;
      setState(() { _loading = false; _error = 'Не удалось обновить Live. Проверьте соединение.'; });
    } finally {
      if (generation == _loadGeneration) _loadInFlight = false;
    }
  }



  Map<String, dynamic> _flattenLivePayload(Map<String, dynamic> source) {
    final row = Map<String, dynamic>.from(source);

    void mergeDynamic(dynamic raw) {
      if (raw == null) return;
      dynamic value = raw;
      if (value is String && value.trim().isNotEmpty) {
        try {
          value = jsonDecode(value);
        } catch (_) {
          return;
        }
      }
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        for (final entry in map.entries) {
          final current = row[entry.key];
          if (current == null || '$current'.trim().isEmpty || '$current' == '0') {
            row[entry.key] = entry.value;
          }
        }
        for (final nestedKey in const ['snapshot', 'metrics', 'heart_rate', 'polar', 'latest', 'live']) {
          mergeDynamic(map[nestedKey]);
        }
      }
    }

    for (final key in const [
      'snapshot',
      'snapshot_json',
      'analysis',
      'analysis_json',
      'metrics',
      'metrics_json',
      'live_data',
      'latest_data',
    ]) {
      mergeDynamic(row[key]);
    }

    // Серверные версии используют разные названия текущего HR.
    row['last_heart_rate_bpm'] ??= row['current_hr'];
    row['last_heart_rate_bpm'] ??= row['heart_rate'];
    row['last_heart_rate_bpm'] ??= row['last_hr'];
    row['last_heart_rate_bpm'] ??= row['polar_bpm'];
    row['heart_rate_samples'] ??= row['hr_history'];
    row['heart_rate_samples'] ??= row['polar_history'];
    row['heart_rate_samples'] ??= row['samples'];

    return row;
  }

  Future<Map<String, dynamic>> _enrichLiveRow(Map<String, dynamic> source) async {
    final row = _flattenLivePayload(source);
    final existing = _heartRateSamples(row);
    final currentHr = _int(row, const [
      'last_heart_rate_bpm',
      'heart_rate_bpm',
      'bpm',
      'current_bpm',
      'latest_bpm',
      'hr',
    ]);

    final liveId = _int(row, const ['live_session_id', 'id', 'tracker_live_session_id']);
    final sessionId = _int(row, const ['session_id', 'final_session_id', 'tracker_session_id']);

    // Для завершённой сессии уже загруженной истории достаточно. Для активного Live
    // обязательно перечитываем online endpoint на каждом poll: иначе после первой
    // точки код возвращался здесь и график Polar больше не обновлялся до Stop.
    if (liveId <= 0 && existing.isNotEmpty && currentHr > 0) return row;
    if (liveId <= 0 && sessionId <= 0) return row;

    try {
      final query = <String, String>{
        'team_id': '${widget.teamId}',
        if (liveId > 0) 'live_session_id': '$liveId',
        if (sessionId > 0) 'session_id': '$sessionId',
        // Не кэшировать Live-график CDN/браузером.
        '_ts': '${DateTime.now().millisecondsSinceEpoch}',
      };
      final uri = Uri.parse('${widget.apiBaseUrl}/player_get_session_heart_rate.php')
          .replace(queryParameters: query);
      final response = await http.get(
        uri,
        headers: const {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return row;

      final json = _decode(response.body);
      if (json['success'] == false) return row;

      final samples = json['samples'] ??
          json['heart_rate_samples'] ??
          json['hr_samples'] ??
          json['points'] ??
          (json['data'] is Map ? (json['data'] as Map)['samples'] : null);
      if (samples is List && samples.isNotEmpty) {
        row['heart_rate_samples'] = samples;
      }

      final summary = json['summary'] is Map
          ? Map<String, dynamic>.from(json['summary'] as Map)
          : <String, dynamic>{};
      // Текущий пульс нельзя подменять максимальным значением сессии.
      // Некоторые API не возвращают last_bpm, но всегда возвращают max_bpm —
      // из-за старого fallback слева постоянно показывался максимум (например 146).
      final latest = json['last_bpm'] ??
          json['current_bpm'] ??
          json['latest_bpm'] ??
          summary['last_bpm'] ??
          summary['current_bpm'] ??
          summary['latest_bpm'];
      if (_parsePositiveInt(latest) != null) {
        row['last_heart_rate_bpm'] = latest;
      } else if (samples is List && samples.isNotEmpty) {
        final last = samples.last;
        if (last is Map) {
          row['last_heart_rate_bpm'] =
              last['bpm'] ?? last['heart_rate_bpm'] ?? last['value'];
        }
      }

      row['avg_heart_rate_bpm'] =
          json['avg_bpm'] ?? summary['avg_bpm'] ?? row['avg_heart_rate_bpm'];
      row['max_heart_rate_bpm'] =
          json['max_bpm'] ?? summary['max_bpm'] ?? row['max_heart_rate_bpm'];
      row['min_heart_rate_bpm'] =
          json['min_bpm'] ?? summary['min_bpm'] ?? row['min_heart_rate_bpm'];
      row['heart_rate_samples_count'] =
          json['samples_count'] ?? summary['samples_count'] ?? (samples is List ? samples.length : 0);

      // Во время активного Live основной session endpoint может отдавать только
      // последний сохранённый snapshot. Всегда дочитываем специальный live endpoint,
      // чтобы получить свежий bpm и новые точки Polar до завершения сессии.
      if (liveId > 0) {
        await _tryLiveHeartRateFallback(row, liveId);
      }
      return row;
    } catch (_) {
      if (liveId > 0) {
        await _tryLiveHeartRateFallback(row, liveId);
      }
      // Live-карточка всё равно должна остаться видимой, даже если endpoint
      // истории Polar временно недоступен.
      return row;
    }
  }

  Future<void> _tryLiveHeartRateFallback(Map<String, dynamic> row, int liveId) async {
    for (final endpoint in const [
      'player_check_session_heart_rate.php',
      'player_get_live_heart_rate.php',
    ]) {
      try {
        final uri = Uri.parse('${widget.apiBaseUrl}/$endpoint').replace(
          queryParameters: {
            'live_session_id': '$liveId',
            'team_id': '${widget.teamId}',
            '_ts': '${DateTime.now().millisecondsSinceEpoch}',
          },
        );
        final response = await http.get(
          uri,
          headers: const {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final json = _decode(response.body);
        final hr = json['heart_rate'] is Map
            ? Map<String, dynamic>.from(json['heart_rate'] as Map)
            : <String, dynamic>{};
        final samples = json['samples'] ?? json['points'] ?? hr['samples'];
        if (samples is List && samples.isNotEmpty) {
          row['heart_rate_samples'] = samples;
        }
        // max_bpm — это статистика, а не текущий показатель Polar.
        final latest = json['last_bpm'] ??
            json['current_bpm'] ??
            json['latest_bpm'] ??
            hr['last_bpm'] ??
            hr['current_bpm'] ??
            hr['latest_bpm'];
        if (_parsePositiveInt(latest) != null) {
          // Не используем ??=: старое значение из первого snapshot блокировало
          // все последующие online bpm.
          row['last_heart_rate_bpm'] = latest;
        }
        row['avg_heart_rate_bpm'] =
            json['avg_bpm'] ?? hr['avg_bpm'] ?? row['avg_heart_rate_bpm'];
        row['max_heart_rate_bpm'] =
            json['max_bpm'] ?? hr['max_bpm'] ?? row['max_heart_rate_bpm'];
        row['heart_rate_samples_count'] =
            json['samples_count'] ?? hr['samples_count'] ?? row['heart_rate_samples_count'];
        if (_int(row, const ['last_heart_rate_bpm', 'current_bpm', 'bpm']) > 0 ||
            _heartRateSamples(row).isNotEmpty) {
          return;
        }
      } catch (_) {}
    }
  }


  String _playerStableKey(Map<String, dynamic> row) {
    final playerId = _int(row, const ['player_id', 'owner_user_id', 'user_id']);
    if (playerId > 0) return 'player:$playerId';
    return _liveKey(row);
  }

  String _liveKey(Map<String, dynamic> row) {
    final liveId = _int(row, const ['live_session_id', 'id', 'tracker_live_session_id']);
    if (liveId > 0) return 'live:$liveId';
    final sessionId = _int(row, const ['session_id', 'final_session_id', 'tracker_session_id']);
    if (sessionId > 0) return 'session:$sessionId';
    final playerId = _int(row, const ['player_id', 'owner_user_id', 'user_id']);
    return 'player:$playerId';
  }

  void _rememberLiveTelemetry(Map<String, dynamic> row) {
    final key = _liveKey(row);
    final incomingHr = _heartRateSamples(row);
    final history = _liveHrHistory.putIfAbsent(key, () => <_HrPoint>[]);
    final isRunning = _isRowRunning(row);

    // Во время прямого эфира серверные samples могут быть агрегированными:
    // первая точка + последняя точка с большой временной дырой. Их объединение
    // давало одну длинную диагональ и резкий вертикальный скачок справа.
    // Для активной сессии строим непрерывную локальную историю из current BPM.
    // Полную серверную историю используем после завершения сессии.
    if (!isRunning) {
      for (final point in incomingHr) {
        final duplicate = history.any((old) =>
            (old.sec - point.sec).abs() < .2 && (old.bpm - point.bpm).abs() < .1);
        if (!duplicate) history.add(point);
      }
    }
    final current = _int(row, const [
      'last_heart_rate_bpm', 'heart_rate_bpm', 'bpm', 'current_bpm', 'latest_bpm', 'hr',
    ]);
    if (current > 0) {
      // Для Live-графика используем локальную шкалу истории, а не полную
      // длительность сессии. Иначе при подключении к уже идущей тренировке
      // первая точка была на 0 сек, а следующая сразу на 3+ часах — линия
      // визуально замирала у правого края.
      final sec = history.isEmpty ? 0.0 : history.last.sec + 2.0;
      final last = history.isEmpty ? null : history.last;
      if (last == null || (last.bpm - current).abs() > .1 || sec - last.sec >= .8) {
        history.add(_HrPoint(sec: sec, bpm: current.toDouble()));
      }
    }
    history.sort((a, b) => a.sec.compareTo(b.sec));
    if (history.length > 7200) history.removeRange(0, history.length - 7200);
    if (history.isNotEmpty) {
      row['heart_rate_samples'] = history
          .map((p) => <String, dynamic>{'elapsed_sec': p.sec, 'bpm': p.bpm})
          .toList(growable: false);
    }

    final loadValue = _num(row, const ['player_load', 'load', 'total_load', 'mechanical_load']);
    if (loadValue > 0) {
      final loadHistory = _liveLoadHistory.putIfAbsent(key, () => <_LoadPoint>[]);
      final sec = history.isNotEmpty ? history.last.sec : _sessionDuration(row).toDouble();
      final lastLoad = loadHistory.isEmpty ? null : loadHistory.last;
      if (lastLoad == null || (lastLoad.value - loadValue).abs() >= 0.5) {
        loadHistory.add(_LoadPoint(sec: sec, value: loadValue));
      }
      if (loadHistory.length > 2000) loadHistory.removeRange(0, loadHistory.length - 2000);
      row['load_samples'] = loadHistory
          .map((e) => <String, dynamic>{'sec': e.sec, 'value': e.value})
          .toList(growable: false);
    }

    var gps = _gpsSamples(row);
    // Некоторые live endpoint во время записи возвращают не массив points, а
    // только последнюю координату в самой строке сессии. Превращаем её в точку,
    // чтобы маршрут рисовался сразу, а не только после финализации сессии.
    if (gps.isEmpty) {
      final lat = _num(row, const ['latitude', 'lat', 'last_latitude', 'gps_latitude']);
      final lon = _num(row, const ['longitude', 'lng', 'lon', 'last_longitude', 'gps_longitude']);
      if (lat.abs() > .000001 && lon.abs() > .000001) {
        gps = <_GpsPoint>[
          _GpsPoint(
            lat: lat,
            lon: lon,
            speedKmh: _num(row, const ['speed_kmh', 'current_speed_kmh', 'speed']),
            elapsedSec: _sessionDuration(row).toDouble(),
          ),
        ];
      }
    }
    if (gps.isNotEmpty) {
      final gpsHistory = _liveGpsHistory.putIfAbsent(key, () => <_GpsPoint>[]);
      for (final point in gps) {
        final duplicate = gpsHistory.any((old) =>
            (old.lat - point.lat).abs() < 0.0000001 &&
            (old.lon - point.lon).abs() < 0.0000001);
        if (!duplicate) gpsHistory.add(point);
      }
      if (gpsHistory.length > 3000) gpsHistory.removeRange(0, gpsHistory.length - 3000);
      final accumulated = gpsHistory
          .map((p) => <String, dynamic>{
                'latitude': p.lat,
                'longitude': p.lon,
                'speed_kmh': p.speedKmh,
                'elapsed_sec': p.elapsedSec,
                'time_ms': p.timeMs,
                'distance_delta_m': p.distanceDeltaM,
              })
          .toList(growable: false);
      row['gps_points'] = accumulated;
      // Online endpoint часто отдаёт по одной новой точке. Аналитику считаем по
      // накопленному маршруту — тогда Спринты/Бег/Ходьба обновляются до Stop.
      _applyMovementAnalyticsFromPoints(row, accumulated);
    }
  }

  Future<void> _enrichArchivedAnalytics(Map<String, dynamic> row) async {
    final sessionId = _int(row, const ['session_id', 'final_session_id', 'tracker_session_id', 'id']);
    final playerId = _int(row, const ['player_id', 'owner_user_id', 'user_id']);
    if (sessionId <= 0 && playerId <= 0) return;
    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/player_get_sessions.php').replace(
        queryParameters: <String, String>{
          'team_id': '${widget.teamId}',
          if (playerId > 0) 'player_id': '$playerId',
          if (playerId > 0) 'owner_user_id': '$playerId',
          if (sessionId > 0) 'session_id': '$sessionId',
          'limit': '200',
          '_ts': '${DateTime.now().millisecondsSinceEpoch}',
        },
      );
      final response = await http.get(uri, headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final json = _decode(response.body);
      dynamic raw = json['sessions'] ?? json['items'] ?? json['data'];
      if (raw is Map) raw = raw['sessions'] ?? raw['items'] ?? raw['data'];
      if (raw is! List) return;
      Map<String, dynamic>? match;
      for (final item in raw.whereType<Map>()) {
        final candidate = Map<String, dynamic>.from(item);
        final candidateId = _int(candidate, const ['session_id', 'id', 'tracker_session_id']);
        if (sessionId > 0 && candidateId == sessionId) {
          match = candidate;
          break;
        }
      }
      match ??= raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).cast<Map<String, dynamic>?>().firstWhere(
        (e) => e != null,
        orElse: () => null,
      );
      if (match == null) return;
      final flattened = _flattenLivePayload(match);
      for (final entry in flattened.entries) {
        final current = row[entry.key];
        if (current == null || '$current'.trim().isEmpty || '$current' == '0' || '$current' == '0.0') {
          row[entry.key] = entry.value;
        }
      }
    } catch (_) {
      // Окно последнего события остаётся доступным даже при временной ошибке API.
    }
  }

  Future<void> _enrichGpsRow(Map<String, dynamic> row) async {
    final liveId = _int(row, const ['live_session_id', 'id', 'tracker_live_session_id']);
    final sessionId = _int(row, const ['session_id', 'final_session_id', 'tracker_session_id']);
    final playerId = _int(row, const ['player_id', 'owner_user_id', 'user_id']);
    if (liveId <= 0 && sessionId <= 0 && playerId <= 0) return;
    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/player_get_session_points.php').replace(
        queryParameters: <String, String>{
          'team_id': '${widget.teamId}',
          if (liveId > 0) 'live_session_id': '$liveId',
          if (sessionId > 0) 'session_id': '$sessionId',
          if (playerId > 0) 'player_id': '$playerId',
          if (playerId > 0) 'owner_user_id': '$playerId',
          'limit': '3000',
          '_ts': '${DateTime.now().millisecondsSinceEpoch}',
        },
      );
      final response = await http.get(
        uri,
        headers: const {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 7));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final json = _decode(response.body);
      final points = json['points'] ?? json['gps_points'] ?? json['items'] ??
          (json['data'] is Map ? (json['data'] as Map)['points'] : null);
      if (points is List && points.isNotEmpty) {
        row['gps_points'] = points;
        _applyMovementAnalyticsFromPoints(row, points);
      }
      for (final source in <dynamic>[json['summary'], json['metrics'], json['analytics'], json['data']]) {
        if (source is! Map) continue;
        final flat = _flattenLivePayload(Map<String, dynamic>.from(source));
        for (final entry in flat.entries) {
          final current = row[entry.key];
          if (current == null || '$current'.trim().isEmpty || '$current' == '0' || '$current' == '0.0') {
            row[entry.key] = entry.value;
          }
        }
      }
    } catch (_) {
      // Карточка Live продолжает работать даже при временной ошибке GPS endpoint.
    }
  }

  void _applyMovementAnalyticsFromPoints(Map<String, dynamic> row, List<dynamic> rawPoints) {
    const runThresholdKmh = 7.0;
    const sprintThresholdKmh = 18.0;
    final fallbackSpeed = _num(row, const [
      'speed_kmh',
      'current_speed_kmh',
      'last_speed_kmh',
      'avg_speed_kmh',
      'average_speed_kmh',
    ]);
    if (rawPoints.length < 2) {
      final knownDistance = _num(
        row,
        const ['total_distance_m', 'distance_m', 'distance'],
      );
      final knownDuration = _sessionDuration(row);
      if (knownDistance <= 0 || fallbackSpeed <= 0) return;
      final running = fallbackSpeed >= runThresholdKmh;
      row['walk_distance_m'] = running ? 0.0 : knownDistance;
      row['walk_duration_sec'] = running ? 0 : knownDuration;
      row['run_distance_m'] = running ? knownDistance : 0.0;
      row['run_duration_sec'] = running ? knownDuration : 0;
      row['walk_percent'] = running ? 0.0 : 100.0;
      row['run_percent'] = running ? 100.0 : 0.0;
      row['sprint_distance_m'] =
          fallbackSpeed >= sprintThresholdKmh ? knownDistance : 0.0;
      row['sprint_duration_sec'] =
          fallbackSpeed >= sprintThresholdKmh ? knownDuration : 0;
      row['sprint_count'] =
          fallbackSpeed >= sprintThresholdKmh ? 1 : 0;
      return;
    }
    var walkDistance = 0.0;
    var runDistance = 0.0;
    var sprintDistance = 0.0;
    var walkSec = 0.0;
    var runSec = 0.0;
    var sprintSec = 0.0;
    var sprintCount = 0;
    var inSprint = false;
    var totalDistance = 0.0;
    var maxSegmentSpeed = 0.0;
    var lastSegmentSpeed = 0.0;

    double value(Map m, List<String> keys) {
      for (final key in keys) {
        final raw = m[key];
        final parsed = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
        if (parsed != null && parsed.isFinite) return parsed;
      }
      return 0;
    }

    double timeSeconds(Map m) {
      for (final key in const [
        'time_ms',
        'timestamp_ms',
        'measured_at_ms',
        'elapsed_ms',
      ]) {
        final parsed = double.tryParse('${m[key] ?? ''}');
        if (parsed != null && parsed.isFinite && parsed > 0) {
          return parsed / 1000.0;
        }
      }
      for (final key in const [
        'elapsed_sec',
        'elapsed_seconds',
        'session_elapsed_sec',
        'time_sec',
      ]) {
        final parsed = double.tryParse('${m[key] ?? ''}');
        if (parsed != null && parsed.isFinite && parsed >= 0) return parsed;
      }
      for (final key in const [
        'measured_at',
        'recorded_at',
        'created_at',
        'timestamp',
      ]) {
        final parsed = DateTime.tryParse('${m[key] ?? ''}'.replaceFirst(' ', 'T'));
        if (parsed != null) {
          return parsed.millisecondsSinceEpoch / 1000.0;
        }
      }
      return 0;
    }

    double haversine(double lat1, double lon1, double lat2, double lon2) {
      const earth = 6371000.0;
      final p1 = lat1 * math.pi / 180;
      final p2 = lat2 * math.pi / 180;
      final dp = (lat2 - lat1) * math.pi / 180;
      final dl = (lon2 - lon1) * math.pi / 180;
      final a = math.sin(dp / 2) * math.sin(dp / 2) +
          math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
      return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    }

    Map<String, dynamic>? previous;
    for (final raw in rawPoints) {
      if (raw is! Map) continue;
      final point = Map<String, dynamic>.from(raw);
      final lat = value(point, const ['latitude', 'lat']);
      final lon = value(point, const ['longitude', 'lng', 'lon']);
      final reportedSpeed = value(
        point,
        const ['speed_kmh', 'current_speed_kmh', 'speed'],
      );
      var delta = value(point, const ['distance_delta_m', 'delta_distance_m', 'segment_distance_m']);
      var dt = value(point, const ['delta_time_sec', 'duration_sec']);
      if (previous != null) {
        if (delta <= 0 && lat.abs() > .000001 && lon.abs() > .000001) {
          final prevLat = value(previous, const ['latitude', 'lat']);
          final prevLon = value(previous, const ['longitude', 'lng', 'lon']);
          if (prevLat.abs() > .000001 && prevLon.abs() > .000001) {
            delta = haversine(prevLat, prevLon, lat, lon)
                .clamp(0, 2000)
                .toDouble();
          }
        }
        if (dt <= 0) {
          final elapsed = timeSeconds(point);
          final previousElapsed = timeSeconds(previous);
          if (elapsed > previousElapsed && previousElapsed >= 0) {
            dt = (elapsed - previousElapsed).clamp(.2, 300).toDouble();
          }
        }
      }
      var speed = reportedSpeed;
      if (speed <= .1 && dt > 0 && delta > 0) {
        speed = delta / dt * 3.6;
      }
      if (speed <= .1 && fallbackSpeed > 0) {
        speed = fallbackSpeed;
      }
      if (!speed.isFinite || speed < 0) speed = 0;
      speed = (!speed.isFinite || speed < 1.5 || speed > 36.0) ? 0.0 : speed;
      if (dt <= 0 && speed > 0 && delta > 0) {
        dt = delta / (speed / 3.6);
      }
      dt = dt.clamp(0, 300).toDouble();
      totalDistance += delta;
      maxSegmentSpeed = math.max(maxSegmentSpeed, speed);
      lastSegmentSpeed = speed;
      if (speed >= sprintThresholdKmh) {
        sprintDistance += delta;
        sprintSec += dt;
        if (!inSprint) sprintCount++;
        inSprint = true;
      } else if (speed >= runThresholdKmh) {
        runDistance += delta;
        runSec += dt;
        if (speed < sprintThresholdKmh * .88) inSprint = false;
      } else {
        walkDistance += delta;
        walkSec += dt;
        inSprint = false;
      }
      previous = point;
    }
    final totalSec = walkSec + runSec + sprintSec;
    if (_num(row, const ['total_distance_m', 'distance_m', 'distance']) <= 0 && totalDistance > 0) {
      row['total_distance_m'] = totalDistance;
    }
    // GPS-маршрут является источником истины для live-метрик движения.
    // Перезаписываем значения при каждом опросе, иначе карточки замирают после
    // первого ненулевого результата и обновляются только после Stop.
    row['walk_distance_m'] = walkDistance;
    row['walk_duration_sec'] = walkSec.round();
    row['run_distance_m'] = runDistance + sprintDistance;
    row['run_duration_sec'] = (runSec + sprintSec).round();
    row['sprint_distance_m'] = sprintDistance;
    row['sprint_duration_sec'] = sprintSec.round();
    row['sprint_count'] = sprintCount;
    if (totalSec > 0) {
      row['walk_percent'] = walkSec / totalSec * 100;
      row['run_percent'] = (runSec + sprintSec) / totalSec * 100;
    } else if (walkDistance + runDistance + sprintDistance > 0) {
      final movementDistance =
          walkDistance + runDistance + sprintDistance;
      row['walk_percent'] = walkDistance / movementDistance * 100;
      row['run_percent'] =
          (runDistance + sprintDistance) / movementDistance * 100;
    } else {
      row['walk_percent'] = 0.0;
      row['run_percent'] = 0.0;
    }
    if (lastSegmentSpeed > 0) row['speed_kmh'] = lastSegmentSpeed;
    if (maxSegmentSpeed > _num(row, const ['max_speed_kmh', 'max_speed'])) {
      row['max_speed_kmh'] = maxSegmentSpeed;
    }
  }

  List<_LoadPoint> _loadSamples(Map<String, dynamic> row) {
    final raw = row['load_samples'];
    if (raw is! List) return const <_LoadPoint>[];
    final result = <_LoadPoint>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final sec = double.tryParse('${m['sec'] ?? m['time_sec'] ?? 0}') ?? 0;
      final value = double.tryParse('${m['value'] ?? m['load'] ?? 0}') ?? 0;
      if (value > 0) result.add(_LoadPoint(sec: sec, value: value));
    }
    result.sort((a, b) => a.sec.compareTo(b.sec));
    return result;
  }

  String _deviceBattery(Map<String, dynamic> row, List<String> keys) {
    final value = _int(row, keys);
    return value > 0 ? '$value%' : '—';
  }

  String _deviceSignal(Map<String, dynamic> row, List<String> keys) {
    final value = _int(row, keys);
    if (value == 0) return '—';
    if (value > 0 && value <= 4) return List.filled(value, '▮').join();
    return '$value dBm';
  }

  List<_GpsPoint> _gpsSamples(Map<String, dynamic> row) {
    dynamic raw = row['gps_points'] ?? row['route_points'] ?? row['track_points'] ?? row['points'];
    if (raw is String && raw.trim().isNotEmpty) {
      try { raw = jsonDecode(raw); } catch (_) {}
    }
    if (raw is Map) raw = raw['points'] ?? raw['items'] ?? raw['data'];
    final out = <_GpsPoint>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final lat = double.tryParse('${item['latitude'] ?? item['lat'] ?? item['field_y_m'] ?? item['y_m'] ?? item['y'] ?? ''}');
        final lon = double.tryParse('${item['longitude'] ?? item['lng'] ?? item['lon'] ?? item['field_x_m'] ?? item['x_m'] ?? item['x'] ?? ''}');
        if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) continue;
        if (lat.abs() < .000001 || lon.abs() < .000001) continue;
        final elapsedSec = double.tryParse(
              '${item['elapsed_sec'] ?? item['elapsed_seconds'] ?? item['time_sec'] ?? 0}',
            ) ??
            0;
        final rawTimeMs = double.tryParse(
              '${item['time_ms'] ?? item['timestamp_ms'] ?? item['measured_at_ms'] ?? 0}',
            ) ??
            0;
        out.add(_GpsPoint(
          lat: lat,
          lon: lon,
          speedKmh: double.tryParse('${item['speed_kmh'] ?? item['speed'] ?? 0}') ?? 0,
          elapsedSec: elapsedSec,
          timeMs: rawTimeMs > 0
              ? rawTimeMs.round()
              : (elapsedSec * 1000).round(),
          distanceDeltaM: double.tryParse(
                '${item['distance_delta_m'] ?? item['delta_distance_m'] ?? item['segment_distance_m'] ?? 0}',
              ) ??
              0,
        ));
      }
    }
    if (out.isEmpty) return out;

    final fallbackSpeed = _num(row, const [
      'speed_kmh',
      'current_speed_kmh',
      'last_speed_kmh',
      'avg_speed_kmh',
    ]);
    double distanceM(_GpsPoint a, _GpsPoint b) {
      const earth = 6371000.0;
      final dLat = (b.lat - a.lat) * math.pi / 180;
      final dLon = (b.lon - a.lon) * math.pi / 180;
      final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(a.lat * math.pi / 180) *
              math.cos(b.lat * math.pi / 180) *
              math.sin(dLon / 2) *
              math.sin(dLon / 2);
      return earth * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
    }

    final resolved = <_GpsPoint>[];
    for (var i = 0; i < out.length; i++) {
      final point = out[i];
      var speed = point.speedKmh;
      var delta = point.distanceDeltaM;
      if (i > 0) {
        final previous = out[i - 1];
        var dt = point.timeMs > 0 && previous.timeMs > 0
            ? (point.timeMs - previous.timeMs).abs() / 1000.0
            : (point.elapsedSec - previous.elapsedSec).abs();
        if (!dt.isFinite || dt <= 0 || dt > 300) dt = 0;
        if (delta <= 0) {
          final maxDistance = dt > 0
              ? math.max(120.0, dt * 36.0 / 3.6)
              : 2000.0;
          delta = distanceM(previous, point)
              .clamp(0, maxDistance)
              .toDouble();
        }
        if (speed <= .1 && dt > 0 && delta > 0) {
          speed = delta / dt * 3.6;
        }
      }
      if (speed <= .1 && fallbackSpeed > 0) speed = fallbackSpeed;
      resolved.add(
        _GpsPoint(
          lat: point.lat,
          lon: point.lon,
          speedKmh: (!speed.isFinite || speed < 1.5 || speed > 36.0) ? 0.0 : speed,
          elapsedSec: point.elapsedSec,
          timeMs: point.timeMs,
          distanceDeltaM: delta,
        ),
      );
    }
    return resolved;
  }

  Widget _coachCmrEmbeddedBody() {
    final calendar = _coachView == _CoachPersonalView.calendar;
    final liveView = _coachView == _CoachPersonalView.live;

    final body = liveView && _live.isNotEmpty
        ? _coachInlineLiveLauncher()
        : _coachBody();

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const LinearProgressIndicator(color: _green, minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: _errorBox(_error!),
            ),
          Container(
            height: 66,
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _line, width: .7)),
            ),
            child: _coachPlayerSelector(),
          ),
          Expanded(
            child: calendar
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: body,
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 9, 10, 14),
                    child: body,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _coachInlineLiveLauncher() {
    final rows = _coachFilteredLive();
    if (rows.isEmpty) {
      return _coachEmptyCard(
        'Сейчас Live нет',
        'Когда игрок начнёт личную тренировку, Live откроется здесь в полноэкранном режиме.',
        Icons.sensors_off_rounded,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: _greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sensors_rounded, color: _green, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rows.length} ${rows.length == 1 ? 'игрок в Live' : 'игроков в Live'}',
                  style: const TextStyle(
                    color: _text,
                    fontSize: AppTypography.secondarySize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Открываю полноэкранный режим как командный Live…',
                  style: TextStyle(
                    color: _muted,
                    fontSize: AppTypography.menuGroupSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _green),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _queuePersonalLiveFullscreenSync();
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 960;
        final selectedSession = _coachWorkspaceResolvedSession();

        if (selectedSession != null || _coachWorkspaceSessionLoading) {
          return _coachSessionWorkspace(
            selectedSession,
            loading: _coachWorkspaceSessionLoading,
            desktop: desktop,
          );
        }

        if (desktop &&
            !widget.cmrEmbedded &&
            _coachView == _CoachPersonalView.live &&
            _live.isNotEmpty) {
          return _personalLiveFullscreenWorkspace();
        }

        if (desktop && widget.cmrEmbedded) {
          return _coachCmrEmbeddedBody();
        }

        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const LinearProgressIndicator(color: _green, minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _errorBox(_error!),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(desktop ? 12 : 8, 7, desktop ? 12 : 8, 0),
              child: _coachHeader(),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: desktop ? 12 : 8),
              child: _coachPlayerSelector(),
            ),
            if (!desktop) ...[
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _coachTabs(),
              ),
            ],
            const SizedBox(height: 7),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 12 : 8,
                  0,
                  desktop ? 12 : 8,
                  desktop ? 10 : 8,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _coachBody(),
                ),
              ),
            ),
          ],
        );

        if (!desktop) {
          return ColoredBox(color: Colors.white, child: main);
        }

        // V204: тот же принцип, что у полноэкранной «Карты»:
        // собственный левый инструментальный блок + большая рабочая область.
        return ColoredBox(
          color: Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 238, child: _coachWorkspaceSidebar()),
              Container(width: 1, color: _line),
              Expanded(child: main),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _coachWorkspaceResolvedSession() {
    final selected = _coachWorkspaceSession;
    if (selected == null) return null;
    if (!_coachWorkspaceSessionRunning) return selected;

    final selectedPlayerId = _rowPlayerId(selected);
    final selectedSessionId = _int(
      selected,
      const [
        'tracker_session_id',
        'session_id',
        'live_session_id',
        'personal_session_id',
      ],
    );

    for (final liveRow in _live) {
      final livePlayerId = _rowPlayerId(liveRow);
      final liveSessionId = _int(
        liveRow,
        const [
          'tracker_session_id',
          'session_id',
          'live_session_id',
          'personal_session_id',
        ],
      );
      final samePlayer = selectedPlayerId != null &&
          livePlayerId != null &&
          selectedPlayerId == livePlayerId;
      final sameSession = selectedSessionId > 0 &&
          liveSessionId > 0 &&
          selectedSessionId == liveSessionId;
      if (sameSession || (selectedSessionId <= 0 && samePlayer)) {
        return <String, dynamic>{...selected, ...liveRow};
      }
    }
    return selected;
  }

  Future<void> _openCoachSessionWorkspace(
    Map<String, dynamic> source, {
    bool? running,
  }) async {
    final token = ++_coachWorkspaceSessionToken;
    final isRunning = running ?? _isRowRunning(source);
    if (mounted) {
      setState(() {
        _coachWorkspaceSessionLoading = true;
        _coachWorkspaceSessionRunning = isRunning;
      });
    }

    try {
      Map<String, dynamic> row;
      if (isRunning) {
        row = await _loadLatestDetailRow(Map<String, dynamic>.from(source));
      } else {
        row = await _enrichLiveRow(Map<String, dynamic>.from(source));
        await _enrichArchivedAnalytics(row);
        await _enrichGpsRow(row);
      }
      if (!mounted || token != _coachWorkspaceSessionToken) return;
      final playerId = _rowPlayerId(row);
      setState(() {
        _coachWorkspaceSession = row;
        _coachWorkspaceSessionRunning = isRunning;
        _coachWorkspaceSessionLoading = false;
        if (playerId != null && playerId > 0) _coachPlayerId = playerId;
      });
      if (playerId != null && playerId > 0) {
        widget.onSelectPlayer?.call(playerId);
      }
    } catch (error) {
      if (!mounted || token != _coachWorkspaceSessionToken) return;
      setState(() {
        _coachWorkspaceSessionLoading = false;
        _error = 'Не удалось открыть сессию: $error';
      });
    }
  }

  void _backToCoachSessions() {
    _coachWorkspaceSessionToken++;
    setState(() {
      _coachWorkspaceSession = null;
      _coachWorkspaceSessionRunning = false;
      _coachWorkspaceSessionLoading = false;
      _coachView = _CoachPersonalView.overview;
    });
  }

  Widget _coachWorkspaceSidebar() {
    const tabs = <_CoachPersonalView, (IconData, String, String)>{
      _CoachPersonalView.overview: (
        Icons.history_rounded,
        'Сессии',
        'архив личных тренировок',
      ),
      _CoachPersonalView.live: (
        Icons.sensors_rounded,
        'Live',
        'кто тренируется сейчас',
      ),
      _CoachPersonalView.journal: (
        Icons.view_timeline_outlined,
        'События',
        'журнал стартов и завершений',
      ),
      _CoachPersonalView.comparison: (
        Icons.compare_arrows_rounded,
        'Сравнение',
        'динамика игроков и нагрузка',
      ),
      _CoachPersonalView.calendar: (
        Icons.calendar_month_outlined,
        'Календарь',
        'личные тренировки по датам',
      ),
    };

    final liveWithGps = _live.where((row) =>
        _gpsSamples(row).isNotEmpty ||
        _num(row, const ['total_distance_m', 'distance_m', 'distance']) > 0).length;
    final liveWithHr = _live.where((row) => _int(row, const [
          'last_heart_rate_bpm',
          'heart_rate_bpm',
          'bpm',
          'current_bpm',
        ]) > 0).length;

    return ColoredBox(
      color: const Color(0xFFFBFCFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _greenSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sports_rounded, color: _green, size: 18),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Личные тренировки',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w900,
                          fontSize: AppTypography.itemTitleSize,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'тренерский контроль',
                        style: TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w600,
                          fontSize: AppTypography.badgeSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: _line),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(9, 10, 9, 10),
              children: [
                for (final entry in tabs.entries) ...[
                  _coachWorkspaceNavItem(
                    icon: entry.value.$1,
                    label: entry.value.$2,
                    subtitle: entry.value.$3,
                    selected: entry.key == _coachView,
                    onTap: () => setState(() => _coachView = entry.key),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          Container(height: 1, color: _line),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
            child: Column(
              children: [
                _coachWorkspaceStatus('Live', '${_live.length}', _live.isNotEmpty),
                const SizedBox(height: 6),
                _coachWorkspaceStatus('GPS', '$liveWithGps', liveWithGps > 0),
                const SizedBox(height: 6),
                _coachWorkspaceStatus('Polar', '$liveWithHr', liveWithHr > 0),
                if (widget.onExitWorkspace != null) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: widget.onExitWorkspace,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back_rounded, color: _muted, size: 17),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'К Tracker',
                              style: TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w800,
                                fontSize: AppTypography.captionSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coachWorkspaceNavItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(10, 9, 9, 9),
        decoration: BoxDecoration(
          color: selected ? _greenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                width: selected ? 7 : 5,
                height: selected ? 7 : 5,
                decoration: BoxDecoration(
                  color: selected ? _green : _muted,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? _green : _text,
                      fontSize: AppTypography.secondarySize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 8.1,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personalArchiveSessionFullscreenWorkspace(
    Map<String, dynamic> row, {
    required bool loading,
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        final compactHeight = c.maxHeight < 680;
        final compactWidth = c.maxWidth < 1180;
        final compact = compactHeight || compactWidth;
        final sidebarWidth = _personalLiveSidebarWidth(c.maxWidth);

        return ColoredBox(
          color: Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: sidebarWidth,
                child: _personalArchiveSidebar(row, compact: compact),
              ),
              Container(width: 1, color: _line),
              Expanded(
                child: Column(
                  children: [
                    _personalArchiveControlHeader(row, compact: compact),
                    if (loading)
                      const LinearProgressIndicator(color: _green, minHeight: 2),
                    Container(height: 1, color: _line),
                    SizedBox(
                      height: compactHeight ? 112 : 124,
                      child: _personalArchivePlayerHeader(row, compact: compact),
                    ),
                    Container(height: 1, color: _line),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 62,
                            child: Column(
                              children: [
                                Expanded(
                                  child: _personalLiveMainWindow(
                                    row,
                                    dense: compactHeight,
                                  ),
                                ),
                                _personalLiveTimelineBar(
                                  row,
                                  dense: compactHeight,
                                ),
                                SizedBox(
                                  height: compactHeight ? 48 : 50,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: _personalLiveBottomMetricStrip(
                                      row,
                                      dense: compactHeight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, color: _line),
                          Expanded(
                            flex: 38,
                            child: _personalLiveRightPanel(
                              row,
                              dense: compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _personalArchiveControlHeader(
    Map<String, dynamic> row, {
    required bool compact,
  }) {
    final gpsReady = _gpsSamples(row).isNotEmpty;
    final hr = _int(row, const [
      'last_heart_rate_bpm',
      'heart_rate_bpm',
      'bpm',
      'current_bpm',
    ]);
    return Container(
      height: 38,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 5, 7, 5),
      child: Row(
        children: [
          const Icon(Icons.sports_soccer_rounded, color: _green, size: 15),
          const SizedBox(width: 7),
          Flexible(
            flex: 2,
            child: Text(
              '${widget.teamName} · ЛИЧНАЯ СЕССИЯ · ${_duration(_sessionDuration(row))}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _liveTitle(compact ? 9.7 : 10.4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  _personalLiveStatusChip(
                    Icons.person_rounded,
                    _playerFullName(row),
                    true,
                    compact: compact,
                  ),
                  const SizedBox(width: 5),
                  _personalLiveStatusChip(
                    Icons.gps_fixed_rounded,
                    gpsReady ? 'GPS ${_gpsSamples(row).length}' : 'GPS —',
                    gpsReady,
                    compact: compact,
                  ),
                  const SizedBox(width: 5),
                  _personalLiveStatusChip(
                    Icons.favorite_rounded,
                    hr > 0 ? 'Polar $hr' : 'Polar —',
                    hr > 0,
                    compact: compact,
                  ),
                  const SizedBox(width: 5),
                  _personalLiveStatusChip(
                    Icons.check_circle_rounded,
                    'Завершено',
                    true,
                    compact: compact,
                  ),
                  if (widget.onOpenAnalytics != null) ...[
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 28,
                      child: TextButton.icon(
                        onPressed: () => widget.onOpenAnalytics!.call(row),
                        style: TextButton.styleFrom(
                          foregroundColor: _green,
                          backgroundColor: _greenSoft,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.analytics_outlined, size: 13),
                        label: Text(
                          'Аналитика',
                          style: _liveBody(
                            9.0,
                            color: _green,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Назад к выбору сессии',
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _backToCoachSessions,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: _liveMuted2,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalArchivePlayerHeader(
    Map<String, dynamic> row, {
    required bool compact,
  }) {
    final gpsCount = _gpsSamples(row).length;
    final hr = _int(row, const [
      'last_heart_rate_bpm',
      'heart_rate_bpm',
      'bpm',
      'current_bpm',
    ]);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        compact ? 6 : 8,
        compact ? 6 : 7,
        compact ? 6 : 8,
        compact ? 6 : 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: compact ? 150 : 166,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 11,
              vertical: compact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: _greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: compact ? 34 : 38,
                  height: compact ? 34 : 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.92),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: _green,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Личная сессия',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _liveTitle(
                          compact ? 9.6 : 10.2,
                          color: _green,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_activityLabel(row)} · ${_duration(_sessionDuration(row))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _liveBody(
                          compact ? 7.8 : 8.4,
                          color: _green,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'GPS $gpsCount · Polar ${hr > 0 ? 1 : 0}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _liveBody(
                          compact ? 7.5 : 8,
                          color: _liveMuted2,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: compact ? 176 : 198,
            child: _personalLivePlayerCard(
              row,
              0,
              compact: compact,
              focused: true,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: _green, size: 16),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Полный повтор: карта, скорость, Polar и журнал выбранной личной тренировки.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _liveBody(
                        compact ? 7.8 : 8.4,
                        color: _liveMuted,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalArchiveSidebar(
    Map<String, dynamic> row, {
    required bool compact,
  }) {
    final moments = _personalLiveMomentsForRow(row);
    final redEvents = moments.where((event) =>
        '${event['severity'] ?? ''}'.trim().toLowerCase() == 'red').length;

    Widget section(String label) => Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 8 : 10,
            compact ? 11 : 14,
            compact ? 8 : 10,
            compact ? 6 : 7,
          ),
          child: Text(
            label,
            style: _liveBody(
              compact ? 8.8 : 9.5,
              color: _liveMuted2,
              weight: FontWeight.w600,
            ),
          ),
        );

    Widget item({
      required String label,
      required String subtitle,
      required IconData icon,
      required bool active,
      required VoidCallback onTap,
      int? badge,
      bool danger = false,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: BoxConstraints(minHeight: compact ? 46 : 48),
          padding: EdgeInsets.fromLTRB(
            compact ? 8 : 10,
            compact ? 6 : 7,
            compact ? 7 : 8,
            compact ? 6 : 7,
          ),
          decoration: BoxDecoration(
            color: active ? _greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: active ? _green : _liveMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _liveBody(
                        compact ? 9.7 : 10.6,
                        color: active ? _green : _liveText,
                        weight: active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _liveBody(
                        compact ? 8.7 : 9.5,
                        color: active ? _green.withOpacity(.72) : _liveMuted,
                        weight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null && badge > 0) ...[
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: danger ? _red : (active ? _green : _soft),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: _liveBody(
                      compact ? 7.8 : 8.2,
                      color: danger || active ? Colors.white : _liveMuted,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                compact ? 8 : 10,
                9,
                compact ? 8 : 10,
                12,
              ),
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 9 : 10,
                    vertical: compact ? 7 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'СЕССИЯ · ЗАВЕРШЕНА',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _liveBody(
                                compact ? 9.7 : 10.6,
                                color: _green,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_playerFullName(row)} · ${_duration(_sessionDuration(row))}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _liveBody(
                                compact ? 8.8 : 9.5,
                                color: _liveMuted,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                item(
                  label: 'Карта сессии',
                  subtitle: 'полный повтор выбранной тренировки',
                  icon: Icons.sports_soccer_rounded,
                  active: _personalLiveInspectorMode != 'journal',
                  onTap: () => setState(() {
                    if (_personalLiveInspectorMode == 'journal') {
                      _personalLiveInspectorMode = 'speed';
                    }
                  }),
                ),
                const SizedBox(height: 4),
                item(
                  label: 'Журнал',
                  subtitle: '${moments.length} событий тренировки',
                  icon: Icons.timeline_rounded,
                  active: _personalLiveInspectorMode == 'journal',
                  badge: moments.length,
                  danger: redEvents > 0,
                  onTap: () => setState(() {
                    _personalLiveInspectorMode = 'journal';
                  }),
                ),
                section('ВИД И СОБЫТИЯ'),
                item(
                  label: _personalLivePerspective3d ? '3D PRO' : '2D',
                  subtitle: _personalLivePerspective3d
                      ? 'объёмный вид поля и карты'
                      : 'плоский вид поля и карты',
                  icon: _personalLivePerspective3d
                      ? Icons.view_in_ar_rounded
                      : Icons.grid_view_rounded,
                  active: _personalLivePerspective3d,
                  onTap: () => setState(() {
                    _personalLivePerspective3d = !_personalLivePerspective3d;
                  }),
                ),
                const SizedBox(height: 4),
                item(
                  label: 'Метки',
                  subtitle: 'события сессии на поле',
                  icon: Icons.place_rounded,
                  active: _personalLiveShowEvents,
                  onTap: () => setState(() {
                    _personalLiveShowEvents = !_personalLiveShowEvents;
                  }),
                ),
                const SizedBox(height: 4),
                item(
                  label: 'HUD',
                  subtitle: 'метрики рядом с игроком',
                  icon: Icons.dashboard_customize_rounded,
                  active: _personalLiveShowHud,
                  onTap: () => setState(() {
                    _personalLiveShowHud = !_personalLiveShowHud;
                  }),
                ),
                section('СЛОИ КАРТЫ'),
                item(
                  label: 'Маршрут',
                  subtitle: 'трек движения игрока',
                  icon: Icons.timeline_rounded,
                  active: _personalLiveShowTrace,
                  onTap: () => setState(() {
                    _personalLiveShowTrace = !_personalLiveShowTrace;
                  }),
                ),
                const SizedBox(height: 4),
                item(
                  label: 'Тепло',
                  subtitle: 'тепловая карта активности',
                  icon: Icons.local_fire_department_rounded,
                  active: _personalLiveShowHeat,
                  onTap: () => setState(() {
                    _personalLiveShowHeat = !_personalLiveShowHeat;
                  }),
                ),
                const SizedBox(height: 4),
                item(
                  label: 'Игрок на поле',
                  subtitle: 'аватар и положение на маршруте',
                  icon: Icons.account_circle_rounded,
                  active: _personalLiveShowPlayerOnField,
                  onTap: () => setState(() {
                    _personalLiveShowPlayerOnField =
                        !_personalLiveShowPlayerOnField;
                  }),
                ),
                section('ПОДЛОЖКА'),
                for (final layer in TrackerGeoBaseLayer.values) ...[
                  item(
                    label: layer.label,
                    subtitle: layer == TrackerGeoBaseLayer.pitch
                        ? 'откалиброванное футбольное поле'
                        : (layer == TrackerGeoBaseLayer.dgis
                            ? 'обычная географическая подложка'
                            : 'спутниковая географическая подложка'),
                    icon: layer.icon,
                    active: _personalLiveGeoLayer == layer,
                    onTap: () => setState(() {
                      _personalLiveGeoLayer = layer;
                    }),
                  ),
                  if (layer != TrackerGeoBaseLayer.values.last)
                    const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          Container(height: 1, color: _line),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 8 : 10,
              7,
              compact ? 8 : 10,
              8,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _backToCoachSessions,
              child: Container(
                constraints: BoxConstraints(minHeight: compact ? 62 : 68),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 9 : 10,
                ),
                decoration: BoxDecoration(
                  color: _soft.withOpacity(.82),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _greenSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 14,
                        color: _green,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'К выбору сессий',
                            style: _liveTitle(compact ? 9.4 : 10),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'архив личных тренировок',
                            style: _liveBody(
                              compact ? 7.5 : 8,
                              color: _liveMuted2,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: _liveMuted2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coachWorkspaceStatus(String label, String value, bool active) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? _green : _muted.withOpacity(.45),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: AppTypography.menuGroupSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: active ? _green : _text,
            fontSize: AppTypography.menuGroupSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _coachSessionWorkspace(
    Map<String, dynamic>? row, {
    required bool loading,
    required bool desktop,
  }) {
    final current = row ?? _coachWorkspaceSession ?? const <String, dynamic>{};
    final running = _coachWorkspaceSessionRunning || _isRowRunning(current);
    final playerName = current.isEmpty ? 'Личная тренировка' : _playerName(current);
    final sessionSubtitle = current.isEmpty
        ? 'загружаем данные выбранной сессии'
        : '${_activityLabel(current)} · ${_shortDate('${current['ended_at'] ?? current['started_at'] ?? current['created_at'] ?? ''}')}';

    Widget header() => Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _line)),
          ),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: _backToCoachSessions,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: _text,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (current.isNotEmpty) ...[
                _avatar(_avatarUrl(current), size: 36),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: AppTypography.itemTitleSize,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sessionSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: AppTypography.menuGroupSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (running)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    '● LIVE',
                    style: TextStyle(
                      color: _green,
                      fontSize: AppTypography.captionSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              if (current.isNotEmpty && widget.onOpenAnalytics != null)
                TextButton.icon(
                  onPressed: () => widget.onOpenAnalytics!.call(current),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text('Аналитика'),
                  style: TextButton.styleFrom(
                    foregroundColor: _green,
                    textStyle: const TextStyle(
                      fontSize: AppTypography.captionSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        );

    if (desktop && current.isNotEmpty) {
      if (running && _live.isNotEmpty) {
        return _personalLiveFullscreenWorkspace();
      }
      return _personalArchiveSessionFullscreenWorkspace(
        current,
        loading: loading,
      );
    }

    if (loading && current.isEmpty) {
      return ColoredBox(
        color: Colors.white,
        child: Column(
          children: [
            header(),
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: _green),
              ),
            ),
          ],
        ),
      );
    }

    final alerts = _coachAlerts(
      running ? <Map<String, dynamic>>[current] : const <Map<String, dynamic>>[],
      running ? const <Map<String, dynamic>>[] : <Map<String, dynamic>>[current],
    );
    final playerEvents = _coachFilteredEvents()
        .where((event) {
          final playerId = _rowPlayerId(current);
          return playerId == null || _rowPlayerId(event) == playerId;
        })
        .toList(growable: false);

    final mainData = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: _liveCard(current, archived: !running),
    );

    final inspector = ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      children: [
        _coachAttentionPanel(alerts),
        const SizedBox(height: 8),
        _coachDataQualityPanel(
          running ? <Map<String, dynamic>>[current] : const <Map<String, dynamic>>[],
          running ? const <Map<String, dynamic>>[] : <Map<String, dynamic>>[current],
        ),
        const SizedBox(height: 8),
        _coachRecentMiniPanel(playerEvents),
        const SizedBox(height: 8),
        Container(
          height: 360,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFCFB),
            borderRadius: BorderRadius.circular(13),
          ),
          clipBehavior: Clip.antiAlias,
          child: _personalLiveDetailJournal(current, dense: true),
        ),
      ],
    );

    return ColoredBox(
      color: const Color(0xFFF7FAF7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header(),
          if (loading)
            const LinearProgressIndicator(
              color: _green,
              minHeight: 2,
            ),
          Expanded(
            child: desktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: mainData),
                      Container(width: 1, color: _line),
                      Expanded(flex: 3, child: inspector),
                    ],
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      SizedBox(height: 760, child: mainData),
                      Container(height: 1, color: _line),
                      SizedBox(height: 760, child: inspector),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _coachFilteredLive() {
    final id = _coachPlayerId;
    if (id == null) return List<Map<String, dynamic>>.from(_live);
    return _live.where((row) => _rowPlayerId(row) == id).toList(growable: false);
  }

  List<Map<String, dynamic>> _coachFilteredEvents() {
    final id = _coachPlayerId;
    if (id == null) return List<Map<String, dynamic>>.from(_events);
    return _events.where((row) => _rowPlayerId(row) == id).toList(growable: false);
  }

  List<Map<String, dynamic>> _coachFinishedEvents([List<Map<String, dynamic>>? source]) {
    final candidates = List<Map<String, dynamic>>.from(source ?? _coachFilteredEvents())
        .where((row) {
          final type = '${row['event_type'] ?? row['type'] ?? row['status'] ?? ''}'.toLowerCase();
          return type.contains('finish') ||
              type.contains('complete') ||
              _parseDate(row['ended_at'] ?? row['stopped_at'] ?? row['finished_at']) != null;
        })
        .toList(growable: false);

    candidates.sort((a, b) {
      final ad = _parseDate(a['ended_at'] ?? a['stopped_at'] ?? a['created_at'] ?? a['event_at']) ?? DateTime(1970);
      final bd = _parseDate(b['ended_at'] ?? b['stopped_at'] ?? b['created_at'] ?? b['event_at']) ?? DateTime(1970);
      return bd.compareTo(ad);
    });

    // Notifications API может вернуть несколько служебных finish-событий
    // на одну физическую сессию. Для тренерского UI считаем именно сессии,
    // чтобы «сегодня», архив и сравнение не удваивали тренировки.
    final seen = <String>{};
    final rows = <Map<String, dynamic>>[];
    for (final row in candidates) {
      final sessionId = _int(row, const [
        'tracker_session_id',
        'session_id',
        'live_session_id',
        'personal_session_id',
      ]);
      final playerId = _rowPlayerId(row) ?? 0;
      final ended = _parseDate(
        row['ended_at'] ?? row['stopped_at'] ?? row['finished_at'] ?? row['created_at'] ?? row['event_at'],
      );
      final key = sessionId > 0
          ? 's:$sessionId'
          : 'p:$playerId:t:${ended?.millisecondsSinceEpoch ?? 0}';
      if (!seen.add(key)) continue;
      rows.add(row);
    }
    return rows;
  }

  Widget _coachHeader() {
    final now = DateTime.now();
    bool today(Map<String, dynamic> row) {
      final d = _parseDate(row['ended_at'] ?? row['stopped_at'] ?? row['created_at'] ?? row['event_at']);
      return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
    }

    final finishedToday = _coachFinishedEvents(_events).where(today).length;
    final alerts = _coachAlerts(_live, _coachFinishedEvents(_events));
    final onlineWithHr = _live.where((row) => _int(row, const [
          'last_heart_rate_bpm',
          'heart_rate_bpm',
          'bpm',
          'current_bpm',
        ]) > 0).length;
    final onlineWithGps = _live.where((row) =>
        _gpsSamples(row).isNotEmpty ||
        _num(row, const ['total_distance_m', 'distance_m', 'distance']) > 0).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 7, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final titleBlock = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_2_rounded, color: _green, size: 19),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Тренерский контроль',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: AppTypography.screenTitleSize,
                    letterSpacing: -.2,
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 11),
                Flexible(
                  child: Text(
                    '${widget.teamName} · Live · архив · события · сравнение игроков',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w500,
                      fontSize: AppTypography.menuGroupSize,
                    ),
                  ),
                ),
              ],
            ],
          );

          final stats = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _coachHeaderStat(Icons.sensors_rounded, '${_live.length}', 'онлайн', _green),
              const SizedBox(width: 4),
              _coachHeaderStat(Icons.task_alt_rounded, '$finishedToday', 'сегодня', const Color(0xFF1677D2)),
              const SizedBox(width: 4),
              _coachHeaderStat(Icons.favorite_rounded, '$onlineWithHr/${_live.length}', 'Polar', _red),
              const SizedBox(width: 4),
              _coachHeaderStat(Icons.location_on_rounded, '$onlineWithGps/${_live.length}', 'GPS', const Color(0xFF0EA5E9)),
              const SizedBox(width: 4),
              _coachHeaderStat(
                Icons.warning_amber_rounded,
                '${alerts.length}',
                'внимание',
                alerts.isEmpty ? _green : _orange,
              ),
            ],
          );

          return Row(
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: stats,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              IconButton(
                tooltip: 'Обновить',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                padding: EdgeInsets.zero,
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: _muted, size: 18),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _coachHeaderStat(
    IconData icon,
    String value,
    String label,
    Color accent,
  ) {
    return Container(
      constraints: const BoxConstraints(minWidth: 66),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9F7),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: accent),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.captionSize, height: 1)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: 7.2, height: 1)),
            ],
          ),
        ],
      ),
    );
  }

  void _selectCoachPlayer(int? id) {
    if (_coachPlayerId == id) return;
    setState(() => _coachPlayerId = id);
    widget.onSelectPlayer?.call(id);
  }

  Widget _coachPlayerSelector() {
    final directory = _resolvedDirectory.isNotEmpty ? _resolvedDirectory : widget.playerDirectory;
    final entries = directory.entries.toList()
      ..sort((a, b) =>
          _shortSurnameFirst((a.value['name'] ?? '').trim(), assumeFirstNameFirst: true)
              .compareTo(_shortSurnameFirst((b.value['name'] ?? '').trim(), assumeFirstNameFirst: true)));

    Widget chip({
      required int? id,
      required String name,
      required String avatar,
    }) {
      final selected = _coachPlayerId == id;
      final online = id == null
          ? _live.isNotEmpty
          : _live.any((row) => _rowPlayerId(row) == id);
      final finishedCount = id == null
          ? _coachFinishedEvents(_events).length
          : _coachFinishedEvents(_events.where((row) => _rowPlayerId(row) == id).toList()).length;
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectCoachPlayer(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: id == null ? 108 : 134,
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? _greenSoft : const Color(0xFFF7F9F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (id == null)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: selected ? Colors.white : _greenSoft, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.groups_2_rounded, color: _green, size: 18),
                )
              else
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _avatar(avatar, size: 32),
                    if (online)
                      const Positioned(
                        right: -2,
                        bottom: -2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _green,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                          ),
                          child: SizedBox(width: 10, height: 10),
                        ),
                      ),
                  ],
                ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? _darkTextForGreen() : _text,
                        fontWeight: FontWeight.w800,
                        fontSize: AppTypography.captionSize,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      online ? 'LIVE сейчас' : '$finishedCount сесс.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: online ? _green : _muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 8.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: entries.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            return chip(id: null, name: 'Вся команда', avatar: '');
          }
          final entry = entries[index - 1];
          return chip(
            id: entry.key,
            name: _shortSurnameFirst((entry.value['name'] ?? 'Игрок ${entry.key}').trim(), assumeFirstNameFirst: true),
            avatar: (entry.value['avatar'] ?? '').trim(),
          );
        },
      ),
    );
  }

  Color _darkTextForGreen() => const Color(0xFF075D36);

  Widget _coachTabs() {
    const tabs = <_CoachPersonalView, (IconData, String)>{
      _CoachPersonalView.overview: (Icons.history_rounded, 'Сессии'),
      _CoachPersonalView.live: (Icons.sensors_rounded, 'Live'),
      _CoachPersonalView.journal: (Icons.view_timeline_outlined, 'События'),
      _CoachPersonalView.comparison: (Icons.compare_arrows_rounded, 'Сравнение'),
      _CoachPersonalView.calendar: (Icons.calendar_month_outlined, 'Календарь'),
    };

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final entry = tabs.entries.elementAt(index);
          final selected = entry.key == _coachView;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _coachView = entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected ? _greenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: selected ? 6.5 : 5.0,
                    height: selected ? 6.5 : 5.0,
                    decoration: BoxDecoration(
                      color: selected ? _green : _muted,
                      shape: BoxShape.circle,
                      boxShadow: selected
                          ? <BoxShadow>[
                              BoxShadow(
                                color: _green.withOpacity(.16),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    entry.value.$2,
                    style: TextStyle(
                      color: selected ? _green : _text,
                      fontWeight: FontWeight.w800,
                      fontSize: AppTypography.captionSize,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _coachBody() {
    switch (_coachView) {
      case _CoachPersonalView.live:
        return _coachLiveBody();
      case _CoachPersonalView.journal:
        return _coachJournalBody();
      case _CoachPersonalView.comparison:
        return _coachComparisonBody();
      case _CoachPersonalView.calendar:
        return _coachCalendarBody();
      case _CoachPersonalView.overview:
        return _coachOverviewBody();
    }
  }

  Widget _coachOverviewBody() {
    final live = _coachFilteredLive();
    final events = _coachFilteredEvents();
    final finished = _coachFinishedEvents(events);
    final alerts = _coachAlerts(live, finished);

    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 1120;
        final cards = finished.take(18).toList(growable: false);

        final archive = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _coachSectionTitle(
              'Выбор сессии',
              _coachPlayerId == null
                  ? '${finished.length} завершённых личных тренировок · выберите сессию для полного просмотра'
                  : '${finished.length} сесс. выбранного игрока · откроются все GPS / Polar / нагрузка / события',
              Icons.history_rounded,
              accent: const Color(0xFF1677D2),
            ),
            if (live.isNotEmpty) ...[
              const SizedBox(height: 8),
              _coachOverviewLiveSummary(live),
            ],
            const SizedBox(height: 8),
            if (cards.isEmpty)
              _coachEmptyCard(
                'Архив пока пуст',
                _coachPlayerId == null
                    ? 'После завершения личных тренировок здесь появятся сессии игроков.'
                    : 'У выбранного игрока пока нет завершённых личных тренировок.',
                Icons.history_rounded,
              )
            else
              LayoutBuilder(
                builder: (context, grid) {
                  final columns = grid.maxWidth >= 1220
                      ? 2
                      : 1;
                  const gap = 8.0;
                  final cardWidth =
                      (grid.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final row in cards)
                        SizedBox(
                          width: cardWidth,
                          child: _coachCompletedFocusCard(row),
                        ),
                    ],
                  );
                },
              ),
          ],
        );

        if (!split) return archive;

        final side = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _coachAttentionPanel(alerts),
            const SizedBox(height: 8),
            _coachDataQualityPanel(live, finished),
            const SizedBox(height: 8),
            _coachRecentMiniPanel(events),
          ],
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: archive),
            const SizedBox(width: 9),
            Expanded(flex: 3, child: side),
          ],
        );
      },
    );
  }

  Widget _coachOverviewLiveSummary(List<Map<String, dynamic>> rows) {
    final selected = rows.isNotEmpty ? rows.first : null;
    final allTeam = _coachPlayerId == null;
    final title = allTeam
        ? '${rows.length} ${rows.length == 1 ? 'игрок тренируется' : 'игроков в личном Live'}'
        : (selected == null ? 'Личный Live' : _playerFullName(selected));
    final subtitle = allTeam
        ? 'Текущие данные не дублируются в Обзоре — откройте вкладку Live для карты, пульса и журнала.'
        : 'Тренировка идёт сейчас · карта, пульс, данные и журнал находятся во вкладке Live.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _greenSoft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          if (!allTeam && selected != null) ...[
            Stack(
              clipBehavior: Clip.none,
              children: [
                _avatar(_avatarUrl(selected), size: 38),
                const Positioned(
                  right: -2,
                  bottom: -2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                    ),
                    child: SizedBox(width: 10, height: 10),
                  ),
                ),
              ],
            ),
          ] else
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.sensors_rounded, color: _green, size: 20),
            ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.secondarySize),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _liveDot(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: AppTypography.badgeSize, height: 1.2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => setState(() => _coachView = _CoachPersonalView.live),
            style: TextButton.styleFrom(
              foregroundColor: _green,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              minimumSize: const Size(0, 32),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
            label: const Text('Открыть Live', style: TextStyle(fontSize: AppTypography.badgeSize, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  double _personalLiveSidebarWidth(double width) {
    if (width >= 1500) return 236.0;
    if (width >= 1180) return 220.0;
    if (width >= 980) return 200.0;
    if (width >= 820) return 184.0;
    return 168.0;
  }

  Map<String, dynamic> _personalLiveSelectedRow() {
    if (_live.isEmpty) return const <String, dynamic>{};
    final selectedId = _coachPlayerId;
    if (selectedId != null) {
      for (final row in _live) {
        if (_rowPlayerId(row) == selectedId) return row;
      }
    }
    return _live.first;
  }

  int _personalLiveGpsOnlineCount() => _live.where((row) {
        final points = _gpsSamples(row);
        return points.isNotEmpty ||
            _num(row, const ['total_distance_m', 'distance_m', 'distance']) > 0;
      }).length;

  int _personalLivePolarOnlineCount() => _live.where((row) {
        return _int(row, const [
              'last_heart_rate_bpm',
              'heart_rate_bpm',
              'bpm',
              'current_bpm',
            ]) >
            0;
      }).length;

  Widget _personalLiveFullscreenWorkspace() {
    return LayoutBuilder(
      builder: (context, c) {
        final selected = _personalLiveSelectedRow();
        if (selected.isEmpty) {
          return _coachEmptyCard(
            'Сейчас Live нет',
            'Ни один игрок команды сейчас не ведёт личную тренировку.',
            Icons.sensors_off_rounded,
          );
        }
        final compactHeight = c.maxHeight < 680;
        final compactWidth = c.maxWidth < 1180;
        final compact = compactHeight || compactWidth;
        final sidebarWidth = _personalLiveSidebarWidth(c.maxWidth);

        return ColoredBox(
          color: Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: sidebarWidth,
                child: _personalLiveDesktopSidebar(
                  selected,
                  compact: compact,
                ),
              ),
              Container(width: 1, color: _line),
              Expanded(
                child: Column(
                  children: [
                    _personalLiveControlHeader(selected, compact: compact),
                    Container(height: 1, color: _line),
                    SizedBox(
                      height: compactHeight ? 112 : 124,
                      child: _personalLivePlayersHeader(compact: compact),
                    ),
                    Container(height: 1, color: _line),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 62,
                            child: Column(
                              children: [
                                Expanded(
                                  child: _personalLiveMainWindow(
                                    selected,
                                    dense: compactHeight,
                                  ),
                                ),
                                _personalLiveTimelineBar(
                                  selected,
                                  dense: compactHeight,
                                ),
                                SizedBox(
                                  height: compactHeight ? 48 : 50,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: _personalLiveBottomMetricStrip(
                                      selected,
                                      dense: compactHeight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, color: _line),
                          Expanded(
                            flex: 38,
                            child: _personalLiveRightPanel(
                              selected,
                              dense: compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _personalLiveStatusChip(
    IconData icon,
    String text,
    bool active, {
    required bool compact,
  }) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: active ? _greenSoft : _soft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: active ? _green : _liveMuted2),
          const SizedBox(width: 4),
          Text(
            text,
            style: _liveBody(
              compact ? 8.5 : 9.1,
              color: active ? _liveText : _liveMuted2,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalLiveControlHeader(
    Map<String, dynamic> row, {
    required bool compact,
  }) {
    final gpsReady = _gpsSamples(row).isNotEmpty;
    final hr = _int(row, const [
      'last_heart_rate_bpm',
      'heart_rate_bpm',
      'bpm',
      'current_bpm',
    ]);
    final duration = _duration(_sessionDuration(row));

    return Container(
      height: 38,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 5, 7, 5),
      child: Row(
        children: [
          const Icon(Icons.sports_soccer_rounded, color: _green, size: 15),
          const SizedBox(width: 7),
          Flexible(
            flex: 2,
            child: Text(
              '${widget.teamName} · ЛИЧНЫЙ LIVE · $duration',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _liveTitle(compact ? 9.7 : 10.4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  _personalLiveStatusChip(
                    Icons.person_rounded,
                    _playerFullName(row),
                    true,
                    compact: compact,
                  ),
                  const SizedBox(width: 5),
                  _personalLiveStatusChip(
                    Icons.groups_rounded,
                    '${_live.length} Live',
                    _live.isNotEmpty,
                    compact: compact,
                  ),
                  const SizedBox(width: 5),
                  _personalLiveStatusChip(
                    Icons.gps_fixed_rounded,
                    gpsReady ? 'GPS online' : 'GPS —',
                    gpsReady,
                    compact: compact,
                  ),
                  const SizedBox(width: 5),
                  _personalLiveStatusChip(
                    Icons.favorite_rounded,
                    hr > 0 ? 'Polar $hr' : 'Polar —',
                    hr > 0,
                    compact: compact,
                  ),
                  const SizedBox(width: 5),
                  _personalLiveStatusChip(
                    Icons.directions_run_rounded,
                    _activityLabel(row),
                    true,
                    compact: compact,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Вернуться к выбору личной сессии',
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                setState(() {
                  _coachView = _CoachPersonalView.overview;
                  _personalLiveInspectorMode = 'journal';
                });
                _lastPersonalLiveFullscreenRequest = null;
                _queuePersonalLiveFullscreenSync();
              },
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: _liveMuted2,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalLivePlayersHeader({required bool compact}) {
    final rows = List<Map<String, dynamic>>.from(_live)
      ..sort((a, b) => _playerFullName(a).compareTo(_playerFullName(b)));
    final selectedId = _rowPlayerId(_personalLiveSelectedRow());
    final gpsCount = _personalLiveGpsOnlineCount();
    final polarCount = _personalLivePolarOnlineCount();

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        compact ? 6 : 8,
        compact ? 6 : 7,
        compact ? 6 : 8,
        compact ? 6 : 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: compact ? 150 : 166,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 11,
              vertical: compact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: _greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: compact ? 34 : 38,
                  height: compact ? 34 : 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.92),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sensors_rounded,
                    color: _green,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Личные Live',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _liveTitle(
                          compact ? 9.6 : 10.2,
                          color: _green,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${rows.length} онлайн · выберите игрока',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _liveBody(
                          compact ? 7.8 : 8.4,
                          color: _green,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'GPS $gpsCount · Polar $polarCount',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _liveBody(
                          compact ? 7.5 : 8,
                          color: _liveMuted2,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: compact ? 176 : 198,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: rows.length,
              itemBuilder: (_, index) => _personalLivePlayerCard(
                rows[index],
                index,
                compact: compact,
                focused: _rowPlayerId(rows[index]) == selectedId,
              ),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: compact ? 76 : 88,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.touch_app_rounded, color: _green, size: 16),
                  const SizedBox(height: 3),
                  Text(
                    'Выбор',
                    style: _liveBody(
                      compact ? 7.6 : 8.2,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalLivePlayerCard(
    Map<String, dynamic> row,
    int index, {
    required bool compact,
    required bool focused,
  }) {
    final gps = _gpsSamples(row);
    final distance = _num(row, const [
      'total_distance_m',
      'distance_m',
      'distance',
      'session_distance_m',
    ]);
    final speed = _num(row, const [
      'speed_kmh',
      'last_speed_kmh',
      'current_speed_kmh',
    ]);
    final maxSpeed = _num(row, const [
      'max_speed_kmh',
      'top_speed_kmh',
      'max_speed',
    ]);
    final hr = _int(row, const [
      'last_heart_rate_bpm',
      'heart_rate_bpm',
      'bpm',
      'current_bpm',
    ]);
    final sprints = _int(row, const ['sprint_count', 'sprints', 'spr']);
    final load = _num(row, const ['load_score', 'player_load', 'load']);
    final number = '${row['number'] ?? row['player_number'] ?? index + 1}';
    final id = _rowPlayerId(row);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: id == null
            ? null
            : () {
                setState(() {
                  _coachPlayerId = id;
                  _personalLiveInspectorMode = 'journal';
                  _selectedPersonalLiveMomentId.value = null;
                });
                widget.onSelectPlayer?.call(id);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 8,
            vertical: compact ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: focused ? _greenSoft : _soft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _avatar(_avatarUrl(row), size: compact ? 28 : 30),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: focused ? _green : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        number,
                        maxLines: 1,
                        style: _liveBody(
                          7.1,
                          color: focused ? Colors.white : _liveText,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _playerFullName(row),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _liveTitle(
                              compact ? 8.8 : 9.4,
                              color: focused ? _green : _liveText,
                            ),
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: gps.isNotEmpty ? _green : _orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'GPS · ${distance >= 1000 ? '${(distance / 1000).toStringAsFixed(2)} км' : '${distance.toStringAsFixed(0)} м'} · ${speed.toStringAsFixed(1)}/${math.max(speed, maxSpeed).toStringAsFixed(1)} км/ч',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _liveBody(
                        compact ? 7.4 : 8,
                        color: _liveMuted,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '♥ ${hr > 0 ? hr : '—'} · S $sprints · нагрузка ${load > 0 ? load.toStringAsFixed(0) : '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _liveBody(
                        compact ? 7.2 : 7.8,
                        color: hr > 0 ? _liveText : _liveMuted2,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _personalLiveDesktopSidebar(
    Map<String, dynamic> selected, {
    required bool compact,
  }) {
    final moments = _personalLiveMomentsForRow(selected);
    final redEvents = moments.where((event) =>
        '${event['severity'] ?? ''}'.trim().toLowerCase() == 'red').length;

    Widget section(String label) => Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 8 : 10,
            compact ? 11 : 14,
            compact ? 8 : 10,
            compact ? 6 : 7,
          ),
          child: Text(
            label,
            style: _liveBody(
              compact ? 8.8 : 9.5,
              color: _liveMuted2,
              weight: FontWeight.w600,
            ),
          ),
        );

    Widget item({
      required String label,
      required String subtitle,
      required IconData icon,
      required bool active,
      required VoidCallback onTap,
      int? badge,
      bool danger = false,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: BoxConstraints(minHeight: compact ? 46 : 48),
          padding: EdgeInsets.fromLTRB(
            compact ? 8 : 10,
            compact ? 6 : 7,
            compact ? 7 : 8,
            compact ? 6 : 7,
          ),
          decoration: BoxDecoration(
            color: active ? _greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: active ? _green : _liveMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _liveBody(
                        compact ? 9.7 : 10.6,
                        color: active ? _green : _liveText,
                        weight: active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _liveBody(
                        compact ? 8.7 : 9.5,
                        color: active ? _green.withOpacity(.72) : _liveMuted,
                        weight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null && badge > 0) ...[
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: danger ? _red : (active ? _green : _soft),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: _liveBody(
                      compact ? 7.8 : 8.2,
                      color: danger || active ? Colors.white : _liveMuted,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                compact ? 8 : 10,
                9,
                compact ? 8 : 10,
                12,
              ),
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 9 : 10,
                    vertical: compact ? 7 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ЛИЧНЫЙ LIVE · ИДЁТ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _liveBody(
                                compact ? 9.7 : 10.6,
                                color: _green,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_live.length} онлайн · ${_duration(_sessionDuration(selected))}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _liveBody(
                                compact ? 8.8 : 9.5,
                                color: _liveMuted,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                item(
                  label: 'Поле Live',
                  subtitle: 'карта выбранного игрока',
                  icon: Icons.sports_soccer_rounded,
                  active: _personalLiveInspectorMode != 'journal',
                  onTap: () => setState(() {
                    if (_personalLiveInspectorMode == 'journal') {
                      _personalLiveInspectorMode = 'speed';
                    }
                  }),
                ),
                const SizedBox(height: 4),
                item(
                  label: 'Журнал',
                  subtitle: redEvents > 0
                      ? '${moments.length} событий · $redEvents предупреждений'
                      : '${moments.length} событий Live',
                  icon: Icons.timeline_rounded,
                  active: _personalLiveInspectorMode == 'journal',
                  badge: moments.length,
                  danger: redEvents > 0,
                  onTap: () => setState(() {
                    _personalLiveInspectorMode = 'journal';
                  }),
                ),
                section('ВИД И СОБЫТИЯ'),
                item(
                  label: _personalLivePerspective3d ? '3D PRO' : '2D',
                  subtitle: _personalLivePerspective3d
                      ? 'объёмный вид поля и карты'
                      : 'плоский вид поля и карты',
                  icon: _personalLivePerspective3d
                      ? Icons.view_in_ar_rounded
                      : Icons.grid_view_rounded,
                  active: _personalLivePerspective3d,
                  onTap: () => setState(() {
                    _personalLivePerspective3d = !_personalLivePerspective3d;
                  }),
                ),
                const SizedBox(height: 4),
                item(
                  label: 'Метки',
                  subtitle: 'события Live прямо на поле',
                  icon: Icons.place_rounded,
                  active: _personalLiveShowEvents,
                  onTap: () => setState(() {
                    _personalLiveShowEvents = !_personalLiveShowEvents;
                  }),
                ),
                const SizedBox(height: 4),
                item(
                  label: 'HUD',
                  subtitle: 'метрики выбранного игрока',
                  icon: Icons.dashboard_customize_rounded,
                  active: _personalLiveShowHud,
                  onTap: () => setState(() {
                    _personalLiveShowHud = !_personalLiveShowHud;
                  }),
                ),
                section('СЛОИ КАРТЫ'),
                item(
                  label: 'Маршрут',
                  subtitle: 'трек движения игрока',
                  icon: Icons.timeline_rounded,
                  active: _personalLiveShowTrace,
                  onTap: () => setState(() {
                    _personalLiveShowTrace = !_personalLiveShowTrace;
                  }),
                ),
                const SizedBox(height: 4),
                item(
                  label: 'Тепло',
                  subtitle: 'тепловая карта активности',
                  icon: Icons.local_fire_department_rounded,
                  active: _personalLiveShowHeat,
                  onTap: () => setState(() {
                    _personalLiveShowHeat = !_personalLiveShowHeat;
                  }),
                ),
                const SizedBox(height: 4),
                item(
                  label: 'Игрок на поле',
                  subtitle: 'аватар и текущая позиция',
                  icon: Icons.account_circle_rounded,
                  active: _personalLiveShowPlayerOnField,
                  onTap: () => setState(() {
                    _personalLiveShowPlayerOnField =
                        !_personalLiveShowPlayerOnField;
                  }),
                ),
                section('ПОДЛОЖКА'),
                for (final layer in TrackerGeoBaseLayer.values) ...[
                  item(
                    label: layer.label,
                    subtitle: layer == TrackerGeoBaseLayer.pitch
                        ? 'откалиброванное футбольное поле'
                        : (layer == TrackerGeoBaseLayer.dgis
                            ? 'обычная географическая подложка'
                            : 'спутниковая географическая подложка'),
                    icon: layer.icon,
                    active: _personalLiveGeoLayer == layer,
                    onTap: () => setState(() {
                      _personalLiveGeoLayer = layer;
                    }),
                  ),
                  if (layer != TrackerGeoBaseLayer.values.last)
                    const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          Container(height: 1, color: _line),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 8 : 10,
              7,
              compact ? 8 : 10,
              8,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _coachView = _CoachPersonalView.overview;
                  _personalLiveInspectorMode = 'journal';
                });
                _lastPersonalLiveFullscreenRequest = null;
                _queuePersonalLiveFullscreenSync();
              },
              child: Container(
                constraints: BoxConstraints(minHeight: compact ? 62 : 68),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 9 : 10,
                ),
                decoration: BoxDecoration(
                  color: _soft.withOpacity(.82),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _greenSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 14,
                        color: _green,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'К выбору сессий',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _liveTitle(compact ? 9.4 : 10),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'архив и личные тренировки',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _liveBody(
                              compact ? 7.5 : 8,
                              color: _liveMuted2,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: _liveMuted2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compatibility entry point for mobile/non-fullscreen callers.
  Widget _coachLiveBody() => _personalLiveFullscreenWorkspace();

  Widget _personalLiveMainWindow(
    Map<String, dynamic> row, {
    required bool dense,
  }) {
    final gpsPoints = _gpsSamples(row);
    final runningMode = _activityLabel(row) == 'Бег';
    final distance = _num(row, const [
      'total_distance_m',
      'distance_m',
      'distance',
      'session_distance_m',
    ]);
    final speed = _num(row, const [
      'speed_kmh',
      'last_speed_kmh',
      'current_speed_kmh',
    ]);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _personalLiveMapWorkspace(
          row,
          points: gpsPoints,
          runningMode: runningMode,
          distanceM: distance,
          currentSpeedKmh: speed,
          dense: dense,
        ),
      ),
    );
  }

  Widget _personalLiveTimelineBar(
    Map<String, dynamic> row, {
    required bool dense,
  }) {
    final sessionRunning = _isRowRunning(row);
    final moments = _personalLiveMomentsForRow(row)
        .where((event) => _liveMomentTimeMs(event) > 0)
        .toList(growable: false)
      ..sort((a, b) =>
          _liveMomentTimeMs(a).compareTo(_liveMomentTimeMs(b)));
    final gps = _gpsSamples(row);
    final startMs = gps.isNotEmpty && gps.first.timeMs > 0
        ? gps.first.timeMs
        : (_parseDate(row['started_at'] ?? row['start_time'] ?? row['created_at'])
                ?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch);
    final endMs = gps.isNotEmpty && gps.last.timeMs > startMs
        ? gps.last.timeMs
        : math.max(
            startMs + 1,
            DateTime.now().millisecondsSinceEpoch,
          ).toInt();
    final span = math.max(1, endMs - startMs);

    return ValueListenableBuilder<String?>(
      valueListenable: _selectedPersonalLiveMomentId,
      builder: (context, selectedId, _) {
        Map<String, dynamic>? selected;
        if (selectedId != null) {
          for (final event in moments) {
            if (_liveMomentId(event) == selectedId) {
              selected = event;
              break;
            }
          }
        }
        final reviewing = selected != null;
        final reviewMs = reviewing ? _liveMomentTimeMs(selected!) : endMs;
        final cursorRatio =
            ((reviewMs - startMs) / span).clamp(0.0, 1.0).toDouble();

        return Container(
          height: dense ? 46 : 48,
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 7 : 9,
            vertical: 4,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _line)),
          ),
          child: Row(
            children: [
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: reviewing
                      ? _orange.withOpacity(.08)
                      : _greenSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: reviewing ? _orange : _green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reviewing ? 'ПРОСМОТР МОМЕНТА' : (sessionRunning ? 'ПРЯМОЙ ЭФИР' : 'ПОВТОР СЕССИИ'),
                          style: TextStyle(
                            color: reviewing ? _orange : _green,
                            fontSize: dense ? 7.8 : 8.3,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          reviewing
                              ? _liveMomentClockLabel(selected!)
                              : '${_playerFullName(row)} · ${sessionRunning ? 'личный Live идёт' : 'завершённая тренировка'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _liveMuted2,
                            fontSize: dense ? 7.0 : 7.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final width = math.max(1.0, box.maxWidth);
                    double xFor(int timeMs) =>
                        (((timeMs - startMs) / span)
                                    .clamp(0.0, 1.0)
                                    .toDouble() *
                                math.max(1.0, width - 10))
                            .toDouble();
                    return SizedBox(
                      height: 24,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 10,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: _liveLineStrong,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 10,
                            child: Container(
                              width: math.max(3.0, (width - 10) * cursorRatio),
                              height: 3,
                              decoration: BoxDecoration(
                                color: reviewing ? _orange : _green,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          for (final event in moments.take(80))
                            Positioned(
                              left: xFor(_liveMomentTimeMs(event)),
                              top: 6,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(99),
                                onTap: () =>
                                    _selectedPersonalLiveMomentId.value =
                                        _liveMomentId(event),
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: '${event['severity'] ?? ''}'
                                                .trim()
                                                .toLowerCase() ==
                                            'red'
                                        ? _red
                                        : _orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: math.max(0.0, (width - 10) * cursorRatio - 4),
                            top: 5,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: reviewing ? _orange : _green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              if (reviewing)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _selectedPersonalLiveMomentId.value = null,
                  child: Container(
                    height: 27,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.skip_next_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          sessionRunning ? 'В LIVE' : 'К КОНЦУ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.0,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  height: 27,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _greenSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: _green,
                      fontSize: 8.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _personalLiveBottomMetricStrip(
    Map<String, dynamic> row, {
    required bool dense,
  }) {
    final distance = _num(row, const [
      'total_distance_m',
      'distance_m',
      'distance',
      'session_distance_m',
    ]);
    final speed = _num(row, const [
      'speed_kmh',
      'last_speed_kmh',
      'current_speed_kmh',
    ]);
    final maxSpeed = _num(row, const [
      'max_speed_kmh',
      'top_speed_kmh',
      'max_speed',
    ]);
    final hr = _int(row, const [
      'last_heart_rate_bpm',
      'heart_rate_bpm',
      'bpm',
      'current_bpm',
    ]);
    final load = _num(row, const ['load_score', 'player_load', 'load']);
    final sprints = _int(row, const ['sprint_count', 'sprints', 'spr']);

    Widget tile(
      String label,
      String value,
      String unit, {
      Color? accent,
      IconData? icon,
    }) {
      return Container(
        padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
        decoration: BoxDecoration(
          color: _soft.withOpacity(.72),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 11.5, color: accent ?? _green),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _liveMuted2,
                      fontSize: 7.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent ?? _liveText,
                      fontSize: AppTypography.bodySize,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 1),
                    child: Text(
                      '',
                      style: TextStyle(fontSize: 1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      unit,
                      style: const TextStyle(
                        color: _liveMuted2,
                        fontSize: 6.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    final tiles = <Widget>[
      tile('Дистанция', (distance / 1000).toStringAsFixed(2), 'км',
          icon: Icons.route_rounded),
      tile('Скорость', speed.toStringAsFixed(1), 'км/ч',
          icon: Icons.speed_rounded),
      tile('Макс. скорость', math.max(speed, maxSpeed).toStringAsFixed(1), 'км/ч',
          icon: Icons.bolt_rounded),
      tile('Спринты', '$sprints', '', icon: Icons.directions_run_rounded),
      tile('ЧСС', hr <= 0 ? '—' : '$hr', hr <= 0 ? '' : 'уд/мин',
          accent: hr > 0 ? _red : null, icon: Icons.favorite_rounded),
      tile('Нагрузка', load > 0 ? load.toStringAsFixed(0) : '—', '',
          icon: Icons.stacked_line_chart_rounded),
    ];

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }

  Widget _personalLiveRightPanel(
    Map<String, dynamic> row, {
    required bool dense,
  }) {
    final moments = _personalLiveMomentsForRow(row);
    final redCount = moments.where((event) =>
        '${event['severity'] ?? ''}'.trim().toLowerCase() == 'red').length;
    final mode = _personalLiveInspectorMode;
    final sessionRunning = _isRowRunning(row);

    Widget tab({
      required String value,
      required IconData icon,
      required String label,
      int? badge,
      bool dangerBadge = false,
    }) {
      final active = mode == value;
      return InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() => _personalLiveInspectorMode = value),
        child: Container(
          height: 27,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? _greenSoft : _soft,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? _liveGreenBorder.withOpacity(.8) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: active ? _green : _liveMuted2),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? _green : _liveGraphite,
                  fontSize: AppTypography.menuGroupSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (badge != null && badge > 0) ...[
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(minWidth: 17),
                  height: 17,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dangerBadge ? _red : (active ? _green : _liveMuted2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final title = mode == 'journal'
        ? (sessionRunning ? 'Журнал Live' : 'Журнал сессии')
        : (mode == 'speed' ? 'Скорость' : 'Кардио');
    final subtitle = mode == 'journal'
        ? (moments.isEmpty
            ? 'моментов пока нет'
            : '${moments.length} · красных $redCount')
        : '${_playerFullName(row)} · ${sessionRunning ? 'online' : 'сессия'}';

    Widget content;
    if (mode == 'speed') {
      content = _personalLiveSpeedInspector(row, dense: dense);
    } else if (mode == 'cardio') {
      final hr = _int(row, const [
        'last_heart_rate_bpm',
        'heart_rate_bpm',
        'bpm',
        'current_bpm',
      ]);
      content = Padding(
        padding: const EdgeInsets.all(7),
        child: _pulseLivePanel(
          hr: hr,
          samples: _heartRateSamples(row),
          embedded: true,
        ),
      );
    } else {
      content = _personalLiveJournalInspector(row, moments, dense: dense);
    }

    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(color: Color(0xFFFAFBFA)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _liveTitle(11.7),
                  ),
                ),
                if (!dense)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 125),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _liveBody(
                          10.4,
                          color: _liveMuted2,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      tab(
                        value: 'journal',
                        icon: Icons.timeline_rounded,
                        label: 'Журнал',
                        badge: redCount > 0 ? redCount : null,
                        dangerBadge: redCount > 0,
                      ),
                      const SizedBox(width: 4),
                      tab(
                        value: 'speed',
                        icon: Icons.speed_rounded,
                        label: 'Скорость',
                      ),
                      const SizedBox(width: 4),
                      tab(
                        value: 'cardio',
                        icon: Icons.favorite_rounded,
                        label: 'Кардио',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _personalLiveJournalInspector(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> moments, {
    required bool dense,
  }) {
    final sessionRunning = _isRowRunning(row);
    return ValueListenableBuilder<String?>(
      valueListenable: _selectedPersonalLiveMomentId,
      builder: (context, selectedId, _) {
        final reviewing = selectedId != null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: dense ? 38 : 42,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: reviewing
                      ? _orange.withOpacity(.075)
                      : _greenSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: reviewing
                        ? _orange.withOpacity(.16)
                        : _liveGreenBorder.withOpacity(.55),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: reviewing ? _orange : _green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reviewing ? 'ПРОСМОТР МОМЕНТА' : (sessionRunning ? 'ПРЯМОЙ ЭФИР' : 'ПОВТОР СЕССИИ'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: reviewing ? _orange : _green,
                              fontSize: dense ? 8.0 : 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            reviewing
                                ? 'Карта выбранного игрока зафиксирована на моменте'
                                : (sessionRunning
                                    ? 'Выберите событие — личный Live продолжит обновляться'
                                    : 'Выберите событие — карта перейдёт к моменту тренировки'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _liveMuted2,
                              fontSize: 7.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (reviewing)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _selectedPersonalLiveMomentId.value = null,
                        child: Container(
                          height: 27,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sessionRunning ? 'В LIVE' : 'К КОНЦУ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: moments.isEmpty
                    ? Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _soft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Журнал заполнится во время личного Live: GPS-предупреждения, ускорения, торможения, спринты и другие моменты. Нажатие переносит карту к этому моменту.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _liveMuted2,
                            fontSize: AppTypography.badgeSize,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 70),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        itemCount: moments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 5),
                        itemBuilder: (_, index) =>
                            _personalLiveJournalEventRow(moments[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _personalLiveJournalEventRow(Map<String, dynamic> event) {
    final id = _liveMomentId(event);
    final selected = _selectedPersonalLiveMomentId.value == id;
    final isRed = '${event['severity'] ?? ''}'.trim().toLowerCase() == 'red';
    final color = isRed ? _red : _orange;
    final title = _readText(
      event,
      const ['title', 'label', 'event_name', 'message', 'type'],
      fallback: 'Событие Live',
    );
    final detail = _readText(
      event,
      const ['detail', 'subtitle', 'description', 'note'],
      fallback: '',
    );

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _selectedPersonalLiveMomentId.value = id,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(.07) : _soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRed ? Icons.warning_amber_rounded : Icons.bolt_rounded,
                size: 15,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _liveBody(
                            9.5,
                            color: _liveText,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _liveMomentClockLabel(event),
                        style: _liveBody(
                          8.2,
                          color: _liveMuted2,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _liveBody(
                        8.3,
                        color: _liveMuted,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personalLiveSpeedInspector(
    Map<String, dynamic> row, {
    required bool dense,
  }) {
    final points = _gpsSamples(row);
    final speed = _num(row, const [
      'speed_kmh',
      'last_speed_kmh',
      'current_speed_kmh',
    ]);
    final maxSpeed = math.max(
      speed,
      _num(row, const ['max_speed_kmh', 'top_speed_kmh', 'max_speed']),
    ).toDouble();
    final samples = points
        .map((p) => p.speedKmh)
        .where((v) => v.isFinite && v >= 0 && v <= 40)
        .toList(growable: false);
    final avg = samples.isEmpty
        ? speed
        : samples.fold<double>(0, (sum, value) => sum + value) / samples.length;

    return Padding(
      padding: const EdgeInsets.all(7),
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.speed_rounded, color: _green, size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _playerFullName(row),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _liveTitle(10.2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'макс. ${maxSpeed.toStringAsFixed(1)} км/ч · ср. ${avg.toStringAsFixed(1)} км/ч',
                        style: _liveBody(
                          8.5,
                          color: _liveMuted,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CustomPaint(
                painter: _PersonalLiveSpeedChartPainter(
                  samples: samples,
                  maxSpeedKmh: maxSpeed,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalLiveMapWorkspace(
    Map<String, dynamic> row, {
    required List<_GpsPoint> points,
    required bool runningMode,
    required double distanceM,
    required double currentSpeedKmh,
    required bool dense,
  }) {
    final playerId = _rowPlayerId(row) ?? 0;
    final sessionRunning = _isRowRunning(row);
    final validPoints = points.where((point) =>
        point.lat.isFinite &&
        point.lon.isFinite &&
        point.lat.abs() <= 90 &&
        point.lon.abs() <= 180 &&
        !(point.lat == 0 && point.lon == 0)).toList(growable: false);

    final geoTrack = TrackerGeoTrack(
      id: 'personal-live-$playerId',
      name: _playerFullName(row),
      avatar: _avatarUrl(row),
      selected: true,
      points: validPoints
          .map((point) => TrackerGeoPoint(
                latitude: point.lat,
                longitude: point.lon,
                timeMs: point.timeMs > 0
                    ? point.timeMs
                    : (point.elapsedSec * 1000).round(),
                speedKmh: point.speedKmh,
              ))
          .toList(growable: false),
    );

    final fieldLayer = _PersonalTeamLiveField(
      points: validPoints,
      field: widget.selectedField,
      avatarUrl: _avatarUrl(row),
      playerName: _playerFullName(row),
      showTrace: _personalLiveShowTrace,
      showHeat: _personalLiveShowHeat,
      showEvents: _personalLiveShowEvents,
      showHud: _personalLiveShowHud,
      showPlayer: _personalLiveShowPlayerOnField,
      selectedMoment: _personalLiveShowEvents
          ? _selectedPersonalMomentMarkerForRow(row)
          : null,
      currentSpeedKmh: currentSpeedKmh,
      distanceM: distanceM,
    );

    final baseLayer = _personalLiveGeoLayer == TrackerGeoBaseLayer.pitch
        ? fieldLayer
        : Tracker2GisMapLayer(
            key: ValueKey<String>(
              'personal-live-map-${_personalLiveGeoLayer.name}-$playerId',
            ),
            layer: _personalLiveGeoLayer,
            tracks: <TrackerGeoTrack>[geoTrack],
            cursorTimeMs:
                geoTrack.points.isEmpty ? null : geoTrack.points.last.timeMs,
            live: sessionRunning,
            followLatest: sessionRunning,
            interactive: true,
            perspective3d: _personalLivePerspective3d,
            field: widget.selectedField,
            rotationDeg: _personalLiveRotationDeg,
            showPlayers: _personalLiveShowPlayerOnField,
            showLabels: _personalLiveShowHud,
            showTrace: _personalLiveShowTrace,
            routeWindowMs: 60000,
          );

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: _PersonalLivePitchPerspective(
            enabled: _personalLiveGeoLayer == TrackerGeoBaseLayer.pitch &&
                _personalLivePerspective3d,
            child: baseLayer,
          ),
        ),
        if (validPoints.isEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: _personalLivePerspective3d ? 108 : 14,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.94),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  widget.selectedField?.hasCalibration == true
                      ? 'Ждём GPS от трекера'
                      : 'Ждём GPS выбранного игрока',
                  style: _liveBody(
                    9.0,
                    color: _liveText,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mapLivePanel({
    required Map<String, dynamic> current,
    required List<_GpsPoint> points,
    required bool runningMode,
    required double distanceM,
    required double currentSpeedKmh,
    bool embedded = false,
  }) {
    final map = ValueListenableBuilder<String?>(
      valueListenable: _selectedPersonalLiveMomentId,
      builder: (context, _, __) {
        return _PersonalGpsMap(
          points: points,
          runningMode: runningMode,
          showWaitingState: runningMode,
          moment: _selectedPersonalMomentMarkerForRow(current),
        );
      },
    );

    if (embedded) {
      return Container(
        color: runningMode ? const Color(0xFFF4FAF7) : const Color(0xFFF3F8F5),
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: map,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: runningMode ? const Color(0xFFF4FAF7) : const Color(0xFFF3F8F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                runningMode ? Icons.route_rounded : Icons.map_outlined,
                color: _green,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  runningMode ? 'Маршрут бега' : 'Карта активности',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w700,
                    fontSize: AppTypography.bodySize,
                  ),
                ),
              ),
              if (runningMode) ...[
                const SizedBox(width: 6),
                Text(
                  '${_meters(distanceM)} · ${currentSpeedKmh.toStringAsFixed(1)} км/ч',
                  maxLines: 1,
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 8.2,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Expanded(child: map),
        ],
      ),
    );
  }

  Widget _loadZonesCard(double low, double moderate, double high, double veryHigh) {
    final sum = low + moderate + high + veryHigh;
    final values = sum > 0 ? [low, moderate, high, veryHigh] : [0.0, 0.0, 0.0, 0.0];
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Зоны интенсивности'),
          content: const Text(
            'Показывают, какую долю тренировки игрок провёл при низкой, умеренной, высокой и очень высокой интенсивности. '
            'При наличии серверных зон используются они; иначе распределение рассчитывается по фактической истории пульса.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Понятно'),
            ),
          ],
        ),
      ),
      child: _bottomInfoCard(
      title: 'Зоны интенсивности',
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    flex: math.max(1, values[i].round()),
                    child: Container(height: 9, color: <Color>[const Color(0xFF22C55E), const Color(0xFF84CC16), const Color(0xFFFBBF24), const Color(0xFFEF4444)][i]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _zoneValue(values[0], 'Низкая', const Color(0xFF16A34A)),
              _zoneValue(values[1], 'Умеренная', const Color(0xFF65A30D)),
              _zoneValue(values[2], 'Высокая', const Color(0xFFF59E0B)),
              _zoneValue(values[3], 'Очень высокая', const Color(0xFFDC2626)),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _zoneValue(double value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value > 0 ? '${value.round()}%' : '—', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: AppTypography.bodySize)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 7.2, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sprintsCard(
    int count,
    int seconds,
    double distance,
    double maxSpeed,
    int totalDurationSec,
  ) {
    final sprintPercent = totalDurationSec > 0
        ? ((seconds / totalDurationSec) * 100).clamp(0.0, 100.0)
        : 0.0;
    const accent = Color(0xFF7C3AED);
    return _bottomInfoCard(
      title: 'Спринты',
      child: Column(
        children: [
          Row(
            children: [
              Text(
                count > 0 ? '$count' : '0',
                style: const TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'всего',
                style: TextStyle(
                  color: _muted,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _smallStat(distance > 0 ? _meters(distance) : '—', 'дистанция'),
              const SizedBox(width: 10),
              _smallStat(seconds > 0 ? _duration(seconds) : '—', 'время'),
              const SizedBox(width: 10),
              _smallStat(maxSpeed > 0 ? '${maxSpeed.toStringAsFixed(1)}' : '—', 'км/ч'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: sprintPercent / 100.0,
              backgroundColor: accent.withOpacity(.14),
              valueColor: const AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _movementCard(String title, double percent, double distance, int seconds, Color accent) {
    return _bottomInfoCard(
      title: title,
      child: Column(
        children: [
          Row(
            children: [
              Text(percent > 0 ? '${percent.round()}%' : '—', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 19)),
              const Spacer(),
              _smallStat(distance > 0 ? _meters(distance) : '—', 'дистанция'),
              const SizedBox(width: 10),
              _smallStat(seconds > 0 ? _duration(seconds) : '—', 'время'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (percent / 100).clamp(0, 1).toDouble(),
              backgroundColor: accent.withOpacity(.14),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomInfoCard({required String title, required Widget child}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _text,
              fontSize: AppTypography.menuGroupSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _smallStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.secondarySize)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _muted, fontSize: 7.5, fontWeight: FontWeight.w600)),
      ],
    );
  }


  Future<Map<String, dynamic>> _loadLatestDetailRow(
    Map<String, dynamic> source,
  ) async {
    final liveId = _int(
      source,
      const ['live_session_id', 'id', 'tracker_live_session_id'],
    );
    if (liveId <= 0) return source;

    try {
      final liveUri = Uri.parse(
        '${widget.apiBaseUrl}/player_get_live_state.php',
      ).replace(queryParameters: {
        'team_id': '${widget.teamId}',
        'live_session_id': '$liveId',
        'active_only': '0',
        'include_finished': '1',
        '_ts': '${DateTime.now().millisecondsSinceEpoch}',
      });
      final response = await http.get(
        liveUri,
        headers: const {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 6));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = _decode(response.body);
        final rows = json['sessions'] as List? ??
            json['items'] as List? ??
            const <dynamic>[];
        if (rows.isNotEmpty && rows.first is Map) {
          final merged = <String, dynamic>{
            ...source,
            ...Map<String, dynamic>.from(rows.first as Map),
          };
          final enriched = await _enrichLiveRow(merged);
          await _enrichGpsRow(enriched);
          _rememberLiveTelemetry(enriched);
          return enriched;
        }
      }
    } catch (_) {}

    final enriched = await _enrichLiveRow(source);
    await _enrichGpsRow(enriched);
    _rememberLiveTelemetry(enriched);
    final finalSessionId = _int(
      enriched,
      const ['final_session_id', 'session_id', 'tracker_session_id'],
    );
    if (finalSessionId > 0) {
      enriched['status'] = 'finished';
      enriched['is_live'] = false;
    }
    return enriched;
  }

  Future<void> _showPlayerDetails(Map<String, dynamic> row) async {
    final notifier = ValueNotifier<Map<String, dynamic>>(
      await _loadLatestDetailRow(row),
    );
    Timer? detailTimer;

    Future<void> refreshDetail() async {
      final latest = await _loadLatestDetailRow(notifier.value);
      if (notifier.value != latest) notifier.value = latest;
    }

    detailTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => refreshDetail(),
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return ValueListenableBuilder<Map<String, dynamic>>(
            valueListenable: notifier,
            builder: (context, current, _) {
              final running = _isRowRunning(current);
              final screen = MediaQuery.sizeOf(dialogContext);

              Widget actionButton({
                required IconData icon,
                required String label,
                required VoidCallback? onPressed,
                bool primary = false,
              }) {
                if (primary) {
                  return FilledButton.icon(
                    onPressed: onPressed,
                    icon: Icon(icon, size: 15),
                    label: Text(label),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      textStyle: const TextStyle(
                        fontSize: AppTypography.captionSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }
                return TextButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon, size: 15),
                  label: Text(label),
                  style: TextButton.styleFrom(
                    foregroundColor: _green,
                    backgroundColor: _greenSoft,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    textStyle: const TextStyle(
                      fontSize: AppTypography.captionSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }

              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.zero,
                child: Container(
                  width: screen.width,
                  height: screen.height,
                  color: const Color(0xFFF8FAF9),
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wideJournal = constraints.maxWidth >= 1180;
                        final dense = constraints.maxHeight <= 900;
                        final pad = dense ? 8.0 : 12.0;

                        final dashboard = SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                          child: _liveCard(current),
                        );
                        final journal = _personalLiveDetailJournal(
                          current,
                          dense: dense,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: dense ? 48 : 54,
                              padding: EdgeInsets.symmetric(horizontal: pad),
                              color: Colors.white,
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: running ? _greenSoft : _soft,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Icon(
                                      Icons.monitor_heart_outlined,
                                      size: 17,
                                      color: running ? _green : _muted,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Личная тренировка',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: _text,
                                            fontSize: AppTypography.bodySize,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          running
                                              ? 'данные обновляются в прямом эфире'
                                              : 'просмотр завершённой сессии',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: running ? _green : _muted,
                                            fontSize: AppTypography.menuGroupSize,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (constraints.maxWidth >= 760 && widget.onOpenReport != null) ...[
                                    actionButton(
                                      icon: Icons.description_outlined,
                                      label: 'Отчёт',
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop();
                                        widget.onOpenReport?.call(current);
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  if (constraints.maxWidth >= 700 && widget.onOpenAnalytics != null) ...[
                                    actionButton(
                                      icon: Icons.analytics_outlined,
                                      label: 'Аналитика',
                                      primary: true,
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop();
                                        widget.onOpenAnalytics?.call(current);
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  IconButton(
                                    tooltip: 'Обновить',
                                    onPressed: refreshDetail,
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                      color: _muted,
                                    ),
                                  ),
                                  const SizedBox(width: 1),
                                  IconButton(
                                    tooltip: 'Закрыть',
                                    onPressed: () => Navigator.of(dialogContext).pop(),
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                      color: _text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: dense ? 5 : 8),
                            Expanded(
                              child: wideJournal
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(child: dashboard),
                                        SizedBox(width: dense ? 4 : 7),
                                        SizedBox(
                                          width: dense ? 286 : 310,
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: pad,
                                              bottom: pad,
                                            ),
                                            child: journal,
                                          ),
                                        ),
                                      ],
                                    )
                                  : SingleChildScrollView(
                                      padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _liveCard(current),
                                          SizedBox(height: dense ? 6 : 9),
                                          SizedBox(
                                            height: dense ? 210 : 250,
                                            child: journal,
                                          ),
                                          if (constraints.maxWidth < 700) ...[
                                            const SizedBox(height: 7),
                                            Row(
                                              children: [
                                                if (widget.onOpenReport != null)
                                                  Expanded(
                                                    child: actionButton(
                                                      icon: Icons.description_outlined,
                                                      label: 'Отчёт',
                                                      onPressed: () {
                                                        Navigator.of(dialogContext).pop();
                                                        widget.onOpenReport?.call(current);
                                                      },
                                                    ),
                                                  ),
                                                if (widget.onOpenReport != null && widget.onOpenAnalytics != null)
                                                  const SizedBox(width: 6),
                                                if (widget.onOpenAnalytics != null)
                                                  Expanded(
                                                    child: actionButton(
                                                      icon: Icons.analytics_outlined,
                                                      label: 'Аналитика',
                                                      primary: true,
                                                      onPressed: () {
                                                        Navigator.of(dialogContext).pop();
                                                        widget.onOpenAnalytics?.call(current);
                                                      },
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      detailTimer.cancel();
      notifier.dispose();
    }
  }

  int _liveMomentTimeMs(Map<String, dynamic> event) {
    final direct = _int(event, const ['time_ms', 'timestamp_ms', 'ts_ms']);
    if (direct > 0) return direct;
    final parsed = _parseDate(
      event['event_at'] ?? event['created_at'] ?? event['started_at'],
    );
    return parsed?.millisecondsSinceEpoch ?? 0;
  }

  String _liveMomentClockLabel(Map<String, dynamic> event) =>
      _liveMomentClock(event);

  String _liveMomentId(Map<String, dynamic> event) {
    final explicit = '${event['event_id'] ?? ''}'.trim();
    if (explicit.isNotEmpty && explicit != 'null') return explicit;
    final pointId = _int(event, const ['point_id', 'source_id', 'id']);
    final type = '${event['type'] ?? 'moment'}'.trim();
    return '$pointId:$type';
  }

  List<Map<String, dynamic>> _personalLiveMomentsForRow(
    Map<String, dynamic> current,
  ) {
    final liveId = _int(
      current,
      const ['live_session_id', 'tracker_live_session_id', 'id'],
    );
    final playerId = _rowPlayerId(current) ?? 0;
    final rows = _liveMoments.where((event) {
      final eventLiveId = _int(event, const ['live_session_id']);
      if (liveId > 0) return eventLiveId == liveId;
      final eventPlayerId = _rowPlayerId(event) ??
          _parsePositiveInt(event['player_id']) ??
          0;
      return playerId > 0 && eventPlayerId == playerId;
    }).toList(growable: false)
      ..sort((a, b) {
        final at = _int(a, const ['time_ms']);
        final bt = _int(b, const ['time_ms']);
        if (at != bt) return bt.compareTo(at);
        return _int(b, const ['point_id', 'id'])
            .compareTo(_int(a, const ['point_id', 'id']));
      });
    return rows;
  }

  String _liveMomentClock(Map<String, dynamic> event) {
    final timeMs = _int(event, const ['time_ms']);
    if (timeMs > 0) {
      final value = _trackerMoscowFromEpochMs(timeMs);
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
    }
    final value = _parseDate(
      event['event_at'] ?? event['created_at'] ?? event['started_at'],
    );
    if (value == null) return '—';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
  }

  Color _liveMomentColor(Map<String, dynamic> event) {
    final severity = '${event['severity'] ?? ''}'.trim().toLowerCase();
    return severity == 'red' ? _red : _orange;
  }

  IconData _liveMomentIcon(Map<String, dynamic> event) {
    final type = '${event['type'] ?? ''}'.trim().toLowerCase();
    if (type.contains('gps')) return Icons.gps_off_rounded;
    if (type.contains('sprint')) return Icons.directions_run_rounded;
    if (type.contains('accel')) return Icons.trending_up_rounded;
    if (type.contains('decel') || type.contains('brak')) {
      return Icons.trending_down_rounded;
    }
    if (type.contains('speed')) return Icons.speed_rounded;
    return Icons.bolt_rounded;
  }

  String _liveMomentTitle(Map<String, dynamic> event) {
    final title = '${event['title'] ?? ''}'.trim();
    if (title.isNotEmpty && title != 'null') return title;
    final type = '${event['type'] ?? ''}'.trim().toLowerCase();
    if (type.contains('gps')) return 'GPS предупреждение';
    if (type.contains('sprint')) return 'Спринт';
    if (type.contains('accel')) return 'Ускорение';
    if (type.contains('decel')) return 'Торможение';
    if (type.contains('speed')) return 'Высокая скорость';
    return 'Live-момент';
  }

  _GpsMomentMarker? _selectedPersonalMomentMarkerForRow(
    Map<String, dynamic> current,
  ) {
    final selectedId = _selectedPersonalLiveMomentId.value;
    if (selectedId == null) return null;
    Map<String, dynamic>? selected;
    for (final event in _personalLiveMomentsForRow(current)) {
      if (_liveMomentId(event) == selectedId) {
        selected = event;
        break;
      }
    }
    if (selected == null) return null;
    final lat = _num(selected, const ['latitude', 'lat', 'raw_latitude']);
    final lon = _num(
      selected,
      const ['longitude', 'lng', 'lon', 'raw_longitude'],
    );
    if (lat == 0 || lon == 0) return null;
    return _GpsMomentMarker(
      lat: lat,
      lon: lon,
      color: _liveMomentColor(selected),
      label: '${_liveMomentClock(selected)} · ${_liveMomentTitle(selected)}',
    );
  }

  Widget _personalLiveDetailJournal(
    Map<String, dynamic> current, {
    required bool dense,
    bool embedded = false,
  }) {
    final rows = _personalLiveMomentsForRow(current);
    final redCount = rows
        .where((event) =>
            '${event['severity'] ?? ''}'.trim().toLowerCase() == 'red')
        .length;
    final gpsCount = rows
        .where((event) =>
            '${event['type'] ?? ''}'.trim().toLowerCase().contains('gps'))
        .length;
    final sprintEvents = rows
        .where((event) =>
            '${event['type'] ?? ''}'.trim().toLowerCase().contains('sprint'))
        .length;
    final accelEvents = rows
        .where((event) =>
            '${event['type'] ?? ''}'.trim().toLowerCase().contains('accel'))
        .length;
    final decelEvents = rows
        .where((event) =>
            '${event['type'] ?? ''}'.trim().toLowerCase().contains('decel'))
        .length;
    final highSpeedEvents = rows
        .where((event) =>
            '${event['type'] ?? ''}'.trim().toLowerCase().contains('speed'))
        .length;

    final load = _num(current, const ['load_score', 'player_load', 'load']);
    final distance = _num(current, const [
      'total_distance_m',
      'distance_m',
      'distance',
      'session_distance_m',
    ]);
    final currentSpeed = _num(current, const [
      'speed_kmh',
      'last_speed_kmh',
      'current_speed_kmh',
      'avg_speed_kmh',
    ]);
    final currentHr = _int(current, const [
      'last_heart_rate_bpm',
      'heart_rate_bpm',
      'bpm',
      'current_bpm',
    ]);

    Widget liveMetric(String label, String value) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 7 : 8,
          vertical: dense ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8F7),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _text,
                fontSize: AppTypography.captionSize,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _muted,
                fontSize: 7.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    Widget countChip(
      String label,
      int value, {
      Color color = _green,
      IconData? icon,
    }) {
      return Container(
        height: dense ? 25 : 27,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(.075),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11.5, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              '$label $value',
              style: TextStyle(
                color: color,
                fontSize: 7.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    final metrics = <Widget>[
      liveMetric('Дистанция', distance > 0 ? _meters(distance) : '—'),
      liveMetric(
        'Скорость',
        currentSpeed > 0 ? '${currentSpeed.toStringAsFixed(1)} км/ч' : '—',
      ),
      liveMetric('Пульс', currentHr > 0 ? '$currentHr уд/мин' : '—'),
      liveMetric('Нагрузка', load > 0 ? load.toStringAsFixed(0) : '—'),
    ];

    return ValueListenableBuilder<String?>(
      valueListenable: _selectedPersonalLiveMomentId,
      builder: (context, selectedId, _) {
        Map<String, dynamic>? selectedEvent;
        if (selectedId != null) {
          for (final event in rows) {
            if (_liveMomentId(event) == selectedId) {
              selectedEvent = event;
              break;
            }
          }
        }
        final reviewing = selectedEvent != null;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: embedded ? BorderRadius.zero : BorderRadius.circular(14),
          ),
          padding: embedded
              ? EdgeInsets.fromLTRB(8, dense ? 7 : 8, 8, 10)
              : EdgeInsets.all(dense ? 8 : 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!embedded) ...[
                Row(
                  children: [
                    const Icon(Icons.timeline_rounded, size: 17, color: _green),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'Журнал Live',
                        style: TextStyle(
                          color: _text,
                          fontSize: AppTypography.secondarySize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (redCount > 0)
                      Container(
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _red,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$redCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      '${rows.length}',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: AppTypography.badgeSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: dense ? 6 : 8),
              ],
              Container(
                height: dense ? 40 : 44,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: reviewing
                      ? _orange.withOpacity(.075)
                      : _greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: reviewing ? _orange : _green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reviewing ? 'ПРОСМОТР МОМЕНТА' : 'ПРЯМОЙ ЭФИР',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: reviewing ? _orange : _green,
                              fontSize: 8.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            reviewing
                                ? '${_liveMomentClock(selectedEvent!)} · точка выделена на маршруте'
                                : 'Нажмите событие — Live продолжит записываться',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 7.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (reviewing)
                      TextButton(
                        onPressed: () =>
                            _selectedPersonalLiveMomentId.value = null,
                        style: TextButton.styleFrom(
                          foregroundColor: _green,
                          backgroundColor: Colors.white,
                          minimumSize: const Size(0, 27),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 7.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        child: const Text('В LIVE'),
                      ),
                  ],
                ),
              ),
              SizedBox(height: dense ? 6 : 8),
              if (!embedded) ...[
                LayoutBuilder(
                  builder: (context, c) {
                    final width = (c.maxWidth - 6) / 2;
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: metrics
                          .map((item) => SizedBox(width: width, child: item))
                          .toList(growable: false),
                    );
                  },
                ),
                SizedBox(height: dense ? 6 : 8),
              ],
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  countChip('Все', rows.length),
                  countChip(
                    'Красные',
                    redCount,
                    color: _red,
                    icon: Icons.warning_amber_rounded,
                  ),
                  countChip('GPS', gpsCount, color: _red, icon: Icons.gps_off_rounded),
                  countChip('SPR', sprintEvents, color: const Color(0xFF7C3AED)),
                  countChip('ACC', accelEvents, icon: Icons.trending_up_rounded),
                  countChip('DEC', decelEvents, color: _orange, icon: Icons.trending_down_rounded),
                  if (highSpeedEvents > 0)
                    countChip('30+', highSpeedEvents, color: const Color(0xFF1677D2)),
                ],
              ),
              SizedBox(height: dense ? 6 : 8),
              const Divider(height: 1, color: Color(0xFFF0F3F1)),
              SizedBox(height: dense ? 4 : 6),
              Expanded(
                child: rows.isEmpty
                    ? Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAF9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Журнал заполнится во время личного Live: GPS-предупреждения, спринты, ускорения, торможения и высокоскоростные моменты.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            fontSize: AppTypography.badgeSize,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 5),
                        itemBuilder: (context, index) {
                          final event = rows[index];
                          final id = _liveMomentId(event);
                          final selected = selectedId == id;
                          final color = _liveMomentColor(event);
                          final title = _liveMomentTitle(event);
                          final detail = '${event['detail'] ?? ''}'.trim();
                          final speed = _num(event, const ['speed_kmh']);
                          final eventLoad = _num(event, const ['load_score']);
                          final hasPoint =
                              _num(event, const ['latitude', 'lat', 'raw_latitude']) != 0 &&
                              _num(event, const ['longitude', 'lng', 'lon', 'raw_longitude']) != 0;

                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              _selectedPersonalLiveMomentId.value = id;
                              if (_personalLiveShowPulse && mounted) {
                                setState(() => _personalLiveShowPulse = false);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              constraints: BoxConstraints(
                                minHeight: dense ? 50 : 56,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: dense ? 7 : 8,
                                vertical: dense ? 6 : 7,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? color.withOpacity(.09)
                                    : const Color(0xFFF7F9F8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: dense ? 26 : 28,
                                    height: dense ? 26 : 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(.10),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _liveMomentIcon(event),
                                      size: dense ? 13 : 14,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: selected
                                                      ? color
                                                      : _text,
                                                  fontSize: dense ? 8.9 : 9.4,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              _liveMomentClock(event),
                                              style: const TextStyle(
                                                color: _muted,
                                                fontSize: 7.4,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          detail.isNotEmpty
                                              ? detail
                                              : '${speed > 0 ? '${speed.toStringAsFixed(1)} км/ч' : 'скорость —'} · нагрузка ${eventLoad > 0 ? eventLoad.toStringAsFixed(0) : '—'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _muted,
                                            fontSize: 7.7,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: selected ? color : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      hasPoint
                                          ? Icons.my_location_rounded
                                          : Icons.schedule_rounded,
                                      size: 14,
                                      color: selected
                                          ? Colors.white
                                          : (hasPoint ? color : _muted),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _deviceStatusChip({
    required IconData icon,
    required String title,
    required bool connected,
    required String signal,
    required String battery,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFFF1FBF5) : const Color(0xFFF7F8F9),
        borderRadius: BorderRadius.circular(10),
        
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: connected ? _green : _muted),
        const SizedBox(width: 7),
        Text('$title ${connected ? 'подключён' : 'не подключён'}', style: TextStyle(color: connected ? _text : _muted, fontWeight: FontWeight.w800, fontSize: AppTypography.captionSize)),
        const SizedBox(width: 10),
        const Icon(Icons.signal_cellular_alt_rounded, size: 14, color: _muted),
        const SizedBox(width: 3),
        Text(signal, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: AppTypography.captionSize)),
        const SizedBox(width: 8),
        const Icon(Icons.battery_5_bar_rounded, size: 14, color: _muted),
        const SizedBox(width: 3),
        Text(battery, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: AppTypography.captionSize)),
      ]),
    );
  }

  Widget _recentEvents(List<Map<String, dynamic>> events) {
    final now = DateTime.now();

    DateTime dayForOffset(int offset) =>
        DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));

    bool sameDate(DateTime? a, DateTime b) =>
        a != null &&
        a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;

    DateTime? eventDate(Map<String, dynamic> event) => _parseDate(
          event['ended_at'] ??
              event['stopped_at'] ??
              event['created_at'] ??
              event['event_at'] ??
              event['started_at'],
        );

    final selectedDay = dayForOffset(_eventDayOffset);
    final filtered = events
        .where((event) => sameDate(eventDate(event), selectedDay))
        .toList()
      ..sort(
        (a, b) => (eventDate(b) ?? DateTime(1970))
            .compareTo(eventDate(a) ?? DateTime(1970)),
      );

    String dayLabel(int offset) {
      if (offset == 0) return 'Сегодня';
      if (offset == 1) return 'Вчера';

      final day = dayForOffset(offset);
      const months = [
        'янв',
        'фев',
        'мар',
        'апр',
        'мая',
        'июн',
        'июл',
        'авг',
        'сен',
        'окт',
        'ноя',
        'дек',
      ];
      return '${day.day} ${months[day.month - 1]}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Последние события',
                style: TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w700,
                  fontSize: AppTypography.bodySize,
                ),
              ),
            ),
            Text(
              '${filtered.length} за день',
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w500,
                fontSize: AppTypography.captionSize,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (_, offset) {
              final selected = offset == _eventDayOffset;
              final count = events
                  .where(
                    (event) =>
                        sameDate(eventDate(event), dayForOffset(offset)),
                  )
                  .length;

              return InkWell(
                onTap: () => setState(() => _eventDayOffset = offset),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? _green : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dayLabel(offset),
                        style: TextStyle(
                          color: selected ? _text : _muted,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: AppTypography.captionSize,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 5),
                        Text(
                          '$count',
                          style: TextStyle(
                            color: selected ? _green : _muted,
                            fontWeight: FontWeight.w700,
                            fontSize: AppTypography.menuGroupSize,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'За выбранный день личных тренировок нет.',
              style: TextStyle(
                color: _muted,
                fontWeight: FontWeight.w500,
                fontSize: AppTypography.secondarySize,
              ),
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < filtered.length; index++) ...[
                _recentEventRow(filtered[index]),
                if (index != filtered.length - 1)
                  const Divider(
                    height: 1,
                    thickness: .7,
                    color: _line,
                  ),
              ],
            ],
          ),
      ],
    );
  }

  Future<void> _showRecentEventDetails(Map<String, dynamic> event) async {
    final row = await _enrichLiveRow(Map<String, dynamic>.from(event));
    await _enrichArchivedAnalytics(row);
    await _enrichGpsRow(row);
    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть последнее событие',
      barrierColor: Colors.black.withOpacity(.34),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screen = MediaQuery.sizeOf(dialogContext);
        final phone = screen.width < 560;
        final horizontalMargin = phone ? 6.0 : 14.0;
        final verticalMargin = phone ? 6.0 : 18.0;
        final dialogWidth = math.min(
          screen.width - horizontalMargin * 2,
          1580.0,
        );
        final dialogHeight = math.min(
          screen.height - verticalMargin * 2,
          phone ? 940.0 : 980.0,
        );

        return SafeArea(
          minimum: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: verticalMargin,
          ),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: dialogWidth,
                height: dialogHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAF9),
                  borderRadius: BorderRadius.circular(phone ? 18 : 24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 34,
                      spreadRadius: 2,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        phone ? 14 : 20,
                        phone ? 10 : 12,
                        phone ? 8 : 12,
                        8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 5,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _green,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Последнее событие игрока',
                            style: TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w600,
                              fontSize: AppTypography.sectionTitleSize,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              widget.onOpenAnalytics?.call(row);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _green,
                              padding: EdgeInsets.symmetric(
                                horizontal: phone ? 8 : 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.analytics_outlined, size: 17),
                            label: Text(
                              phone ? 'Аналитика' : 'Подробнее в аналитике',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: AppTypography.secondarySize,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Закрыть',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded, color: _text),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: .7, color: _line),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          phone ? 6 : 12,
                          8,
                          phone ? 6 : 12,
                          phone ? 6 : 12,
                        ),
                        child: LayoutBuilder(
                          builder: (_, constraints) => Scrollbar(
                            thumbVisibility: phone,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              padding: const EdgeInsets.only(bottom: 20),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: _liveCard(row, archived: true),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .975, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _recentEventRow(Map<String, dynamic> event) {
    final finished = '${event['event_type'] ?? event['type'] ?? ''}'
        .toLowerCase()
        .contains('finish');

    final name = _playerName(event);
    final avatar = _avatarUrl(event);
    final duration = _sessionDuration(event);
    final distance = _num(
      event,
      const [
        'total_distance_m',
        'distance_m',
        'distance',
        'session_distance_m',
      ],
    );
    final avgHr = _int(
      event,
      const [
        'avg_heart_rate_bpm',
        'average_heart_rate_bpm',
        'avg_bpm',
        'heart_rate_avg',
      ],
    );
    final maxHr = _int(
      event,
      const [
        'max_heart_rate_bpm',
        'max_bpm',
        'heart_rate_max',
      ],
    );
    final speed = _num(
      event,
      const [
        'avg_speed_kmh',
        'speed_kmh',
        'average_speed_kmh',
      ],
    );

    final metrics = <String>[
      _duration(duration),
      if (distance > 0) _meters(distance),
      if (speed > 0) '${speed.toStringAsFixed(1)} км/ч',
      if (avgHr > 0) 'ср. $avgHr bpm',
      if (maxHr > 0) 'макс. $maxHr bpm',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showRecentEventDetails(event),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 38,
                decoration: BoxDecoration(
                  color: finished ? _green : _orange,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              _avatar(avatar, size: 34),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w700,
                        fontSize: AppTypography.secondarySize,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${finished ? 'Завершил' : 'Начал'} · ${_activityLabel(event)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w500,
                        fontSize: AppTypography.captionSize,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metrics.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w500,
                        fontSize: AppTypography.menuGroupSize,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _shortDate(
                      '${event['created_at'] ?? event['event_at'] ?? event['ended_at'] ?? ''}',
                    ),
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w500,
                      fontSize: AppTypography.menuGroupSize,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Открыть',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w700,
                      fontSize: AppTypography.captionSize,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventMetric(IconData icon, String value, {Color accent = _muted}) => Container(
    margin: const EdgeInsets.only(right: 5),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: accent, size: 12),
      const SizedBox(width: 4),
      Text(value, style: TextStyle(color: accent == _muted ? _text : accent, fontWeight: FontWeight.w900, fontSize: AppTypography.menuGroupSize)),
    ]),
  );

  Widget _compactMetric(String label, String value, {Color valueColor = _text}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: valueColor, fontSize: AppTypography.bodySize, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: _muted, fontSize: AppTypography.menuGroupSize, fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _detailMetric(String label, String value) => Container(
    width: 150, padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFF6F8F7), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: AppTypography.captionSize, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3), Text(value, style: const TextStyle(color: _text, fontSize: AppTypography.bodySize, fontWeight: FontWeight.w900)),
    ]),
  );

  String _lastUpdatedLabel() {
    final now = DateTime.now();
    return 'обновлено ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Widget _liveStatusText(int count) {
    final active = count > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? _green : _muted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          active ? 'LIVE $count' : 'OFFLINE',
          style: TextStyle(
            color: active ? _green : _muted,
            fontSize: AppTypography.captionSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _liveIcon(int count) => Container(width: 38, height: 38, decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(13)), child: Stack(clipBehavior: Clip.none, children: [
    const Center(child: Icon(Icons.notifications_active_rounded, color: _green, size: 20)),
    if (count > 0) Positioned(right: -4, top: -5, child: _smallBadge(count)),
  ]));

  Widget _countPill(int count) { final active = count > 0; return Container(height: 28, padding: const EdgeInsets.symmetric(horizontal: 9), alignment: Alignment.center, decoration: BoxDecoration(color: active ? _green : _soft, borderRadius: BorderRadius.circular(999)), child: Text('$count онлайн', style: TextStyle(color: active ? Colors.white : _muted, fontSize: AppTypography.secondarySize, fontWeight: FontWeight.w900))); }
  Widget _smallBadge(int count) => Container(constraints: const BoxConstraints(minWidth: 18, minHeight: 18), padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.center, decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white, width: 2)), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: AppTypography.menuGroupSize, fontWeight: FontWeight.w900)));
  Widget _liveDot() => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(999)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 6, color: _green), SizedBox(width: 4), Text('LIVE', style: TextStyle(color: _green, fontSize: AppTypography.menuGroupSize, fontWeight: FontWeight.w900))]));

  Widget _avatar(String url, {double size = 42}) {
    if (url.trim().isNotEmpty) return ClipRRect(borderRadius: BorderRadius.circular(size * .3), child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarFallback(size)));
    return _avatarFallback(size);
  }
  Widget _avatarFallback(double size) => Container(width: size, height: size, decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(size * .3)), child: Icon(Icons.person_rounded, color: _green, size: size * .52));
  Widget _errorBox(String error) => Text(
    error,
    style: const TextStyle(color: _red, fontWeight: FontWeight.w600, fontSize: AppTypography.secondarySize),
  );
  Widget _emptyState() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Text(
      'Сейчас никто из игроков не ведёт личную тренировку.',
      style: TextStyle(color: _muted, fontWeight: FontWeight.w500, fontSize: AppTypography.secondarySize),
    ),
  );

  List<_HrPoint> _heartRateSamples(Map<String, dynamic> row) {
    dynamic raw = row['heart_rate_samples'] ??
        row['hr_samples'] ??
        row['polar_samples'] ??
        row['bpm_history'] ??
        row['heart_rate_history'] ??
        row['points'];

    if (raw is Map) {
      raw = raw['samples'] ?? raw['points'] ?? raw['items'] ?? raw['data'];
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        raw = jsonDecode(raw);
        if (raw is Map) {
          raw = raw['samples'] ?? raw['points'] ?? raw['items'] ?? raw['data'];
        }
      } catch (_) {}
    }

    final out = <_HrPoint>[];
    DateTime? firstMeasured;
    if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];
        final bpmValue = item is Map
            ? (item['bpm'] ?? item['heart_rate_bpm'] ?? item['heart_rate'] ?? item['hr'] ?? item['value'])
            : item;
        final bpm = double.tryParse('$bpmValue');
        if (bpm == null || bpm <= 0 || bpm >= 260) continue;

        double sec = i.toDouble();
        if (item is Map) {
          final value = item['elapsed_sec'] ??
              item['offset_sec'] ??
              item['time_sec'] ??
              item['seconds_from_start'] ??
              item['elapsed_seconds'] ??
              item['relative_sec'];
          final parsed = double.tryParse('$value');
          if (parsed != null) {
            sec = parsed;
          } else {
            final measuredRaw = '${item['measured_at'] ?? item['created_at'] ?? item['timestamp'] ?? ''}'.trim();
            final measured = measuredRaw.isEmpty
                ? null
                : _parseServerDate(measuredRaw);
            if (measured != null) {
              firstMeasured ??= measured;
              sec = measured.difference(firstMeasured!).inMilliseconds / 1000.0;
            }
          }
        }
        out.add(_HrPoint(sec: sec < 0 ? 0 : sec, bpm: bpm));
      }
    }

    // Даже один текущий BPM должен быть виден в Live-карточке.
    if (out.isEmpty) {
      final current = _int(row, const [
        'last_heart_rate_bpm',
        'heart_rate_bpm',
        'bpm',
        'current_bpm',
        'latest_bpm',
        'hr',
      ]);
      if (current > 0) {
        out.add(_HrPoint(sec: 0, bpm: current.toDouble()));
      }
    }
    out.sort((a, b) => a.sec.compareTo(b.sec));
    return out;
  }

  Widget _summaryStrip() {
    final today = DateTime.now();
    bool sameDay(DateTime? d) => d != null && d.year == today.year && d.month == today.month && d.day == today.day;
    final completed = _events.where((e) => '${e['event_type'] ?? e['type'] ?? ''}'.toLowerCase().contains('finish')).toList();
    final todayCount = completed.where((e) => sameDay(_parseDate(e['ended_at'] ?? e['created_at'] ?? e['event_at']))).length;
    final weekCount = completed.where((e) { final d = _parseDate(e['ended_at'] ?? e['created_at'] ?? e['event_at']); return d != null && today.difference(d).inDays < 7; }).length;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _summaryMetric('Всего', '${completed.length}', Icons.fitness_center_rounded),
      _summaryMetric('Сегодня', '$todayCount', Icons.today_rounded),
      _summaryMetric('7 дней', '$weekCount', Icons.date_range_rounded),
      _summaryMetric('Онлайн', '${_live.length}', Icons.notifications_active_rounded),
    ]);
  }

  Widget _summaryMetric(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: AppTypography.screenTitleSize)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w500, fontSize: AppTypography.menuGroupSize)),
    ]),
  );

  String _activityLabel(Map<String, dynamic> row) {
    final raw = _readText(row, const ['activity_type', 'training_type', 'workout_type', 'mode'], fallback: '').toLowerCase();
    if (raw.contains('run') || raw.contains('бег')) return 'Бег';
    if (raw.contains('gym') || raw.contains('зал')) return 'Зал';
    if (raw.contains('strength') || raw.contains('сил')) return 'Силовая';
    if (raw.contains('field') || raw.contains('football') || raw.contains('поле')) return 'Поле';
    return 'Личная';
  }

  int _sessionDuration(Map<String, dynamic> row) {
    final direct = _int(row, const ['duration_sec', 'duration_seconds', 'elapsed_sec', 'live_duration_sec']);
    if (direct > 0) return direct;
    final a = _parseDate(row['started_at'] ?? row['start_time'] ?? row['created_at']);
    final b = _parseDate(row['ended_at'] ?? row['end_time'] ?? row['finished_at']) ?? DateTime.now();
    return a == null ? 0 : b.difference(a).inSeconds.clamp(0, 86400).toInt();
  }

  String _startTime(Map<String, dynamic> row) =>
      _formatTime(_parseServerDate(row['started_at'] ?? row['start_time'] ?? row['created_at']));

  String _endTime(Map<String, dynamic> row) {
    final d = _parseServerDate(
      row['stopped_at'] ??
          row['ended_at'] ??
          row['end_time'] ??
          row['finished_at'],
    );
    return d == null ? 'идёт сейчас' : _formatTime(d);
  }

  bool _isRowRunning(Map<String, dynamic> row) {
    // Наличие итоговой сессии однозначно означает, что Live уже завершён,
    // даже если старый API продолжает возвращать status=active.
    final finalSessionId = _int(
      row,
      const ['final_session_id', 'session_id', 'tracker_session_id'],
    );
    if (finalSessionId > 0) return false;

    final status = '${row['status'] ?? row['state'] ?? row['live_status'] ?? ''}'
        .trim()
        .toLowerCase();
    final explicitlyFinished = status.contains('finish') ||
        status.contains('stop') ||
        status.contains('closed') ||
        status.contains('cancel') ||
        status.contains('autosaved') ||
        status.contains('completed');
    if (explicitlyFinished) return false;

    final ended = row['stopped_at'] ??
        row['ended_at'] ??
        row['end_time'] ??
        row['finished_at'];
    if (_parseServerDate(ended) != null) return false;

    // Если heartbeat давно не обновлялся, такую строку нельзя показывать LIVE.
    final lastSeenInstant = _trackerParseServerInstant(
      row['last_seen_at'] ?? row['updated_at'] ?? row['heartbeat_at'],
    );
    if (lastSeenInstant != null &&
        DateTime.now().toUtc().difference(lastSeenInstant).abs() >
            const Duration(minutes: 2)) {
      return false;
    }

    return status.isEmpty ||
        status == 'active' ||
        status == 'online' ||
        status == 'live' ||
        status.contains('active');
  }

  String _formatTime(DateTime? d) => d == null
      ? '—'
      : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Серверные строки без timezone считаются UTC и отображаются
  /// строго по московскому времени (UTC+3), независимо от timezone устройства.
  DateTime? _parseServerDate(dynamic value) => _trackerMoscowDateTime(value);

  DateTime? _parseDate(dynamic value) => _parseServerDate(value);
  int _durationMinutes(int sec) => sec <= 0 ? 0 : (sec / 60).ceil();
  String _hrExtremesText(List<_HrPoint> values) {
    if (values.isEmpty) return 'Нет данных';
    final minP = values.reduce((a,b) => a.bpm <= b.bpm ? a : b);
    final maxP = values.reduce((a,b) => a.bpm >= b.bpm ? a : b);
    return '${minP.bpm.round()} (${(minP.sec/60).floor()} мин) / ${maxP.bpm.round()} (${(maxP.sec/60).floor()} мин)';
  }

  int? _parsePositiveInt(dynamic value) {
    final parsed = value is num ? value.toInt() : int.tryParse('${value ?? ''}');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  int? _rowPlayerId(Map<String, dynamic> row) {
    for (final key in const ['player_id', 'playerId', 'resolved_player_id', 'owner_user_id', 'user_id', 'userId', 'resolved_user_id', 'athlete_id']) {
      final value = row[key];
      final parsed = value is num ? value.toInt() : int.tryParse('${value ?? ''}');
      if (parsed != null && parsed > 0 && _resolvedDirectory.containsKey(parsed)) return parsed;
    }
    final direct = _readText(row, const ['player_name', 'full_name', 'name', 'athlete_name'], fallback: '');
    final technical = RegExp(r'^(?:Игрок|Player)\s*#?\s*(\d+)$', caseSensitive: false).firstMatch(direct);
    final parsed = technical == null ? null : int.tryParse(technical.group(1) ?? '');
    return parsed != null && _resolvedDirectory.containsKey(parsed) ? parsed : null;
  }

  String _playerName(Map<String, dynamic> row) {
    // Сначала используем раздельные поля — это единственный надёжный способ
    // гарантировать формат «Фамилия И.» независимо от порядка full_name.
    final first = _readText(
      row,
      const ['first_name', 'player_first_name', 'user_first_name'],
      fallback: '',
    );
    final last = _readText(
      row,
      const ['last_name', 'surname', 'player_last_name', 'user_last_name'],
      fallback: '',
    );
    if (last.isNotEmpty || first.isNotEmpty) {
      return _surnameWithInitial(last: last, first: first);
    }

    final directoryId = _rowPlayerId(row);
    final directoryName = directoryId == null
        ? ''
        : (_resolvedDirectory[directoryId]?['name'] ?? '').trim();
    if (directoryName.isNotEmpty) return _shortSurnameFirst(directoryName, assumeFirstNameFirst: true);

    final direct = _readText(
      row,
      const ['player_short_name', 'short_name', 'player_name', 'full_name', 'name', 'athlete_name'],
      fallback: '',
    );
    final technical = RegExp(
      r'^(?:Игрок|Player)\s*#?\s*\d+$',
      caseSensitive: false,
    ).hasMatch(direct);
    if (direct.isNotEmpty && !technical) {
      return _shortSurnameFirst(direct, assumeFirstNameFirst: true);
    }
    return directoryId == null ? 'Игрок' : 'Игрок #$directoryId';
  }

  String _playerFullName(Map<String, dynamic> row) {
    final first = _readText(
      row,
      const ['first_name', 'player_first_name', 'user_first_name'],
      fallback: '',
    );
    final last = _readText(
      row,
      const ['last_name', 'surname', 'player_last_name', 'user_last_name'],
      fallback: '',
    );
    if (last.isNotEmpty || first.isNotEmpty) {
      if (last.isEmpty) return first;
      if (first.isEmpty) return last;
      return '$last $first';
    }

    final directoryId = _rowPlayerId(row);
    final directoryName = directoryId == null
        ? ''
        : (_resolvedDirectory[directoryId]?['name'] ?? '').trim();
    if (directoryName.isNotEmpty) {
      return _fullSurnameFirst(directoryName, assumeFirstNameFirst: true);
    }

    final direct = _readText(
      row,
      const ['player_name', 'full_name', 'name', 'athlete_name'],
      fallback: '',
    );
    final technical = RegExp(
      r'^(?:Игрок|Player)\s*#?\s*\d+$',
      caseSensitive: false,
    ).hasMatch(direct);
    if (direct.isNotEmpty && !technical) {
      return _fullSurnameFirst(direct, assumeFirstNameFirst: true);
    }
    return directoryId == null ? 'Игрок' : 'Игрок #$directoryId';
  }

  String _fullSurnameFirst(
    String value, {
    bool assumeFirstNameFirst = false,
  }) {
    final cleaned = value.trim();
    final parts = cleaned
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length < 2) return cleaned;
    if (parts[1].endsWith('.') && parts[1].length <= 3) return cleaned;
    if (!assumeFirstNameFirst) return cleaned;
    final first = parts.first;
    final surname = parts.last;
    if (parts.length == 2) return '$surname $first';
    final middle = parts.sublist(1, parts.length - 1).join(' ');
    return '$surname $first${middle.isEmpty ? '' : ' $middle'}';
  }

  String _surnameWithInitial({required String last, required String first}) {
    final surname = last.trim();
    final given = first.trim();
    if (surname.isEmpty) return given;
    if (given.isEmpty) return surname;
    return '$surname ${given.substring(0, 1).toUpperCase()}.';
  }

  String _shortSurnameFirst(
    String value, {
    bool assumeFirstNameFirst = false,
  }) {
    final cleaned = value.trim();
    final parts = cleaned
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length < 2) return cleaned;

    // Если строка уже сокращена («Красновский С.»), оставляем как есть.
    if (parts[1].endsWith('.') && parts[1].length <= 3) {
      return '${parts.first} ${parts[1].substring(0, 1).toUpperCase()}.';
    }

    final surname = assumeFirstNameFirst ? parts.last : parts.first;
    final firstName = assumeFirstNameFirst ? parts.first : parts[1];
    return '$surname ${firstName.substring(0, 1).toUpperCase()}.';
  }
  String _avatarUrl(Map<String, dynamic> row) {
    final direct = _readText(row, const ['avatar_url', 'avatar', 'photo_url', 'photo', 'player_avatar'], fallback: '');
    if (direct.isNotEmpty) return direct;
    final id = _rowPlayerId(row);
    return id == null ? '' : (_resolvedDirectory[id]?['avatar'] ?? '').trim();
  }
  String _shortDate(String value) {
    final parsed = _parseServerDate(value);
    if (parsed == null) return value;
    return _formatTime(parsed);
  }
  IconData _iconFor(String type) => type.toLowerCase().contains('finish') ? Icons.check_circle_rounded : type.toLowerCase().contains('start') ? Icons.play_circle_fill_rounded : Icons.info_rounded;
  String _plural(int count) { final n10 = count % 10, n100 = count % 100; if (n10 == 1 && n100 != 11) return ''; if (n10 >= 2 && n10 <= 4 && (n100 < 12 || n100 > 14)) return 'а'; return 'ов'; }

  bool _isActivePersonalLive(Map<String, dynamic> s) {
    final status = '${s['status'] ?? s['state'] ?? s['live_status'] ?? 'active'}'.toLowerCase();
    if (status.contains('finish') || status.contains('stop') || status.contains('closed') || status.contains('cancel')) return false;
    final personalRaw = '${s['personal_session'] ?? s['is_personal'] ?? s['personal'] ?? ''}'.toLowerCase().trim();
    final kind = '${s['session_kind'] ?? s['source'] ?? s['started_by_role'] ?? ''}'.toLowerCase();
    return personalRaw == '1' || personalRaw == 'true' || kind.contains('personal') || kind.contains('player') || kind.contains('polar') || !s.containsKey('personal_session');
  }

  Map<String, dynamic> _decode(String body) { final text = body.trim(); final start = text.indexOf('{'); final decoded = jsonDecode(start >= 0 ? text.substring(start) : text); return decoded is Map ? Map<String, dynamic>.from(decoded) : {'success': false, 'message': 'Некорректный ответ API'}; }
  String _sourceLabel(Map<String, dynamic> row) { final source = _readText(row, const ['source', 'device_source', 'activity_source'], fallback: '').toLowerCase(); final device = _readText(row, const ['device_name', 'tracker_name'], fallback: '').toLowerCase(); final hasHr = _int(row, const ['last_heart_rate_bpm', 'heart_rate_bpm', 'bpm', 'avg_heart_rate_bpm']) > 0 || source.contains('polar') || device.contains('polar'); final hasGps = _num(row, const ['total_distance_m', 'distance_m', 'last_field_x_m', 'field_x_m', 'latitude', 'lat']) > 0 || source.contains('gps') || source.contains('tracker'); if (hasHr && hasGps) return 'Polar + GPS'; if (hasHr) return 'Polar'; if (hasGps) return 'GPS-трекер'; return 'личная сессия'; }
  String _readText(Map<String, dynamic> row, List<String> keys, {required String fallback}) { for (final key in keys) { final value = row[key]; if (value == null) continue; final text = '$value'.trim(); if (text.isNotEmpty && text != 'null') return text; } return fallback; }
  int _int(Map<String, dynamic> row, List<String> keys) { for (final key in keys) { final value = row[key]; if (value == null) continue; final parsed = int.tryParse('$value') ?? (value is num ? value.toInt() : null); if (parsed != null) return parsed; } return 0; }
  double _num(Map<String, dynamic> row, List<String> keys) { for (final key in keys) { final value = row[key]; if (value == null) continue; final parsed = double.tryParse('$value') ?? (value is num ? value.toDouble() : null); if (parsed != null && parsed.isFinite) return parsed; } return 0; }
  int _displayDurationSeconds(
    Map<String, dynamic> row, {
    required int serverDuration,
    required bool archived,
  }) {
    final safeServerDuration = math.max(0, serverDuration);
    if (archived) return safeServerDuration;

    final raw = _readText(
      row,
      const ['started_at', 'start_at', 'start_time_iso', 'live_started_at'],
      fallback: '',
    ).trim();
    if (raw.isEmpty) return safeServerDuration;

    final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    DateTime? started = DateTime.tryParse(normalized);
    if (started == null) return safeServerDuration;

    final hasExplicitTimezone =
        normalized.endsWith('Z') ||
        RegExp(r'[+-]\\d{2}:?\\d{2}$').hasMatch(normalized);

    if (hasExplicitTimezone) {
      started = started.toLocal();
    } else {
      // PHP/MySQL usually returns DATETIME without timezone.
      // Treat it as local wall-clock time instead of UTC.
      started = DateTime(
        started.year,
        started.month,
        started.day,
        started.hour,
        started.minute,
        started.second,
        started.millisecond,
        started.microsecond,
      );
    }

    final localElapsed = DateTime.now().difference(started).inSeconds;
    if (localElapsed < 0) return safeServerDuration;

    // A newly started session must never jump several hours because of
    // a timezone mismatch or a stale started_at value.
    if (safeServerDuration <= 5 * 60 && localElapsed > 30 * 60) {
      return safeServerDuration;
    }

    // Prefer the server duration whenever the two clocks differ materially.
    // The local calculation is used only to make the counter tick smoothly
    // between successful Live API refreshes.
    if ((localElapsed - safeServerDuration).abs() > 5 * 60) {
      return safeServerDuration;
    }

    return math.max(safeServerDuration, localElapsed);
  }

  String _duration(int sec) { if (sec <= 0) return '0:00'; final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60; return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '$m:${s.toString().padLeft(2, '0')}'; }
  String _meters(double value) => value >= 1000 ? '${(value / 1000).toStringAsFixed(2)} км' : '${value.toStringAsFixed(0)} м';


  // V206.2 BUILD FIX: helper-методы V205 восстановлены ВНУТРИ State-класса.
  // Новый Personal Live V206 сохранён без отката.


  Widget _personalLiveDataPanel(
    Map<String, dynamic> row, {
    required bool dense,
  }) {
    final hr = _int(row, const [
      'last_heart_rate_bpm',
      'heart_rate_bpm',
      'bpm',
      'current_bpm',
    ]);
    final duration = _displayDurationSeconds(
      row,
      serverDuration: _int(row, const [
        'duration_sec',
        'duration_seconds',
        'elapsed_sec',
        'live_duration_sec',
      ]),
      archived: false,
    );
    final distance = _num(row, const [
      'total_distance_m',
      'distance_m',
      'distance',
      'session_distance_m',
    ]);
    final speed = _num(row, const [
      'speed_kmh',
      'last_speed_kmh',
      'current_speed_kmh',
    ]);
    final maxSpeed = _num(row, const [
      'max_speed_kmh',
      'top_speed_kmh',
      'max_speed',
    ]);
    final load = _num(row, const ['load_score', 'player_load', 'load']);
    final sprintCount = _int(row, const ['sprint_count', 'sprints', 'spr']);
    final accelerationCount = _int(row, const [
      'acceleration_count',
      'accelerations',
      'hard_acceleration_count',
      'accel_count',
    ]);
    final decelerationCount = _int(row, const [
      'deceleration_count',
      'decelerations',
      'braking_count',
      'hard_deceleration_count',
      'decel_count',
    ]);
    final explosiveRaw = _int(row, const [
      'explosive_action_count',
      'explosive_actions',
      'explosive_count',
      'high_intensity_actions',
    ]);
    final explosive = explosiveRaw > 0
        ? explosiveRaw
        : sprintCount + accelerationCount + decelerationCount;
    final hsr = _num(row, const [
      'high_speed_distance_m',
      'hsr_distance_m',
      'high_intensity_distance_m',
    ]);
    final samples = _heartRateSamples(row);
    final averageHr = samples.isEmpty
        ? hr.toDouble()
        : samples.fold<double>(0, (sum, point) => sum + point.bpm) /
            samples.length;
    final aiRaw = _num(row, const ['ai_load', 'ai_load_score']);
    final ai = aiRaw > 0
        ? aiRaw.clamp(0, 100).toDouble()
        : _calculateAiLoadIndex(
            load: load,
            averageHr: averageHr,
            maxSpeed: math.max(speed, maxSpeed),
            sprintCount: sprintCount,
            durationSec: duration,
            distanceM: distance,
          );

    Widget metric(
      String label,
      String value, {
      IconData? icon,
      Color accent = _green,
    }) {
      return Container(
        constraints: BoxConstraints(minHeight: dense ? 52 : 57),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 9,
          vertical: dense ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: dense ? 25 : 28,
                height: dense ? 25 : 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 13, color: accent),
              ),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 7.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: AppTypography.captionSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final values = <Widget>[
      metric('Длительность', _duration(duration), icon: Icons.timer_outlined),
      metric('Дистанция', _meters(distance), icon: Icons.route_rounded),
      metric('Текущая скорость', '${speed.toStringAsFixed(1)} км/ч', icon: Icons.speed_rounded),
      metric('Макс. скорость', '${math.max(speed, maxSpeed).toStringAsFixed(1)} км/ч', icon: Icons.flash_on_rounded),
      metric('Пульс', hr > 0 ? '$hr уд/мин' : '—', icon: Icons.favorite_rounded, accent: _red),
      metric('Нагрузка', load > 0 ? '${load.toStringAsFixed(0)} · ${_loadLevel(load)}' : '—', icon: Icons.monitor_heart_outlined),
      metric('Спринты', '$sprintCount', icon: Icons.directions_run_rounded),
      metric('Ускорения', '$accelerationCount', icon: Icons.trending_up_rounded),
      metric('Торможения', '$decelerationCount', icon: Icons.trending_down_rounded, accent: _orange),
      metric('Взрывные действия', '$explosive', icon: Icons.bolt_rounded, accent: _orange),
      metric('HSR', hsr > 0 ? _meters(hsr) : '—', icon: Icons.double_arrow_rounded),
      metric('AI индекс', ai > 0 ? '${ai.round()} / 100' : '—', icon: Icons.psychology_alt_outlined),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(8, dense ? 7 : 8, 8, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final width = (c.maxWidth - 6) / 2;
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: values
                  .map((item) => SizedBox(width: width, child: item))
                  .toList(growable: false),
            ),
          );
        },
      ),
    );
  }


  Widget _coachJournalBody() {
    final events = _coachFilteredEvents();
    if (events.isEmpty) {
      return _coachEmptyCard(
        'Журнал пока пуст',
        _coachPlayerId == null
            ? 'Завершённые и стартовавшие личные тренировки команды появятся здесь.'
            : 'У выбранного игрока пока нет событий личных тренировок.',
        Icons.view_timeline_outlined,
      );
    }
    if (widget.cmrEmbedded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 1, 0, 8),
        child: _recentEvents(events),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: _recentEvents(events),
    );
  }


  Widget _coachCalendarBody() {
    final directory = _resolvedDirectory.isNotEmpty ? _resolvedDirectory : widget.playerDirectory;
    final players = directory.entries
        .map(
          (entry) => PlayerTrainingCalendarPlayer(
            id: entry.key,
            name: _fullSurnameFirst((entry.value['name'] ?? 'Игрок ${entry.key}').trim(), assumeFirstNameFirst: true),
            avatar: (entry.value['avatar'] ?? '').trim(),
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final calendarHeight = viewportHeight <= 1000 ? 560.0 : 680.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        height: calendarHeight,
        child: PlayerTrainingCalendarPanel(
          key: ValueKey<String>('coach_personal_calendar_${widget.teamId}_${_coachPlayerId ?? 0}'),
          teamId: widget.teamId,
          players: players,
          initialPlayerId: _coachPlayerId,
          allowAllPlayers: true,
          initialMode: PlayerTrainingCalendarMode.personal,
          showHeader: !widget.cmrEmbedded,
          showPlayerPicker: _coachPlayerId == null,
          showModeControls: false,
          splitWideLayout: true,
          cleanPersonalStyle: true,
          onClose: widget.cmrEmbedded
              ? null
              : () => setState(() => _coachView = _CoachPersonalView.overview),
          onSessionTap: (row) => widget.onOpenAnalytics?.call(row),
        ),
      ),
    );
  }


  Widget _coachComparisonBody() {
    final finished = _coachFinishedEvents(_events);
    if (finished.isEmpty) {
      return _coachEmptyCard(
        'Недостаточно данных для сравнения',
        'После завершения минимум двух личных тренировок появится динамика дистанции, скорости, нагрузки и пульса.',
        Icons.compare_arrows_rounded,
      );
    }

    if (_coachPlayerId != null) {
      final rows = finished.where((row) => _rowPlayerId(row) == _coachPlayerId).toList();
      if (rows.isEmpty) {
        return _coachEmptyCard(
          'Нет завершённых тренировок',
          'Для выбранного игрока пока нечего сравнивать.',
          Icons.compare_arrows_rounded,
        );
      }
      return _coachPlayerComparison(rows);
    }

    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final row in finished) {
      final id = _rowPlayerId(row);
      if (id == null) continue;
      grouped.putIfAbsent(id, () => <Map<String, dynamic>>[]).add(row);
    }
    for (final rows in grouped.values) {
      rows.sort((a, b) {
        final ad = _parseDate(a['ended_at'] ?? a['created_at']) ?? DateTime(1970);
        final bd = _parseDate(b['ended_at'] ?? b['created_at']) ?? DateTime(1970);
        return bd.compareTo(ad);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _coachSectionTitle(
          'Динамика игроков команды',
          'Последняя личная тренировка относительно предыдущей',
          Icons.compare_arrows_rounded,
          accent: const Color(0xFF7C3AED),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1180 ? 3 : (constraints.maxWidth >= 720 ? 2 : 1);
            const gap = 8.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            final ids = grouped.keys.toList()
              ..sort((a, b) => _coachPlayerName(a).compareTo(_coachPlayerName(b)));
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final id in ids)
                  SizedBox(
                    width: width,
                    child: _coachComparisonPlayerCard(id, grouped[id]!),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }


  Widget _coachPlayerComparison(List<Map<String, dynamic>> rows) {
    final latest = rows.first;
    final previous = rows.length > 1 ? rows[1] : null;
    final name = _playerName(latest);
    final avatar = _avatarUrl(latest);

    final metrics = <(String, String, double, double, IconData)>[
      ('Дистанция', _meters(_num(latest, const ['total_distance_m', 'distance_m', 'distance'])), _num(latest, const ['total_distance_m', 'distance_m', 'distance']), previous == null ? 0 : _num(previous, const ['total_distance_m', 'distance_m', 'distance']), Icons.route_rounded),
      ('Макс. скорость', '${_num(latest, const ['max_speed_kmh', 'top_speed_kmh', 'max_speed']).toStringAsFixed(1)} км/ч', _num(latest, const ['max_speed_kmh', 'top_speed_kmh', 'max_speed']), previous == null ? 0 : _num(previous, const ['max_speed_kmh', 'top_speed_kmh', 'max_speed']), Icons.speed_rounded),
      ('Нагрузка', _num(latest, const ['load_score', 'player_load', 'load']).toStringAsFixed(0), _num(latest, const ['load_score', 'player_load', 'load']), previous == null ? 0 : _num(previous, const ['load_score', 'player_load', 'load']), Icons.monitor_heart_outlined),
      ('Средний пульс', '${_int(latest, const ['avg_heart_rate_bpm', 'avg_bpm', 'heart_rate_avg']) > 0 ? _int(latest, const ['avg_heart_rate_bpm', 'avg_bpm', 'heart_rate_avg']) : '—'} bpm', _int(latest, const ['avg_heart_rate_bpm', 'avg_bpm', 'heart_rate_avg']).toDouble(), previous == null ? 0 : _int(previous, const ['avg_heart_rate_bpm', 'avg_bpm', 'heart_rate_avg']).toDouble(), Icons.favorite_rounded),
      ('Спринты', '${_int(latest, const ['sprint_count', 'sprints', 'spr'])}', _int(latest, const ['sprint_count', 'sprints', 'spr']).toDouble(), previous == null ? 0 : _int(previous, const ['sprint_count', 'sprints', 'spr']).toDouble(), Icons.bolt_rounded),
      ('Длительность', _duration(_sessionDuration(latest)), _sessionDuration(latest).toDouble(), previous == null ? 0 : _sessionDuration(previous).toDouble(), Icons.timer_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _avatar(avatar, size: 42),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.itemTitleSize)),
                    const SizedBox(height: 2),
                    Text(
                      previous == null ? 'Есть 1 завершённая тренировка' : 'Последняя ↔ предыдущая',
                      style: const TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: AppTypography.menuGroupSize),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _openCoachSessionWorkspace(latest, running: false),
                child: const Text('Открыть'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final two = constraints.maxWidth < 700;
            const gap = 8.0;
            final width = two ? (constraints.maxWidth - gap) / 2 : (constraints.maxWidth - gap * 2) / 3;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width: width,
                    child: _coachCompareMetric(
                      metric.$1,
                      metric.$2,
                      metric.$3,
                      metric.$4,
                      metric.$5,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }


  Widget _coachCompareMetric(
    String label,
    String value,
    double current,
    double previous,
    IconData icon,
  ) {
    final hasDelta = previous > 0 && current >= 0;
    final delta = hasDelta ? ((current - previous) / previous * 100) : 0.0;
    final accent = !hasDelta
        ? _muted
        : (delta.abs() < 3 ? _muted : (delta > 0 ? _green : _orange));
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 5),
              Expanded(child: Text(label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: AppTypography.badgeSize))),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.itemTitleSize)),
          const SizedBox(height: 3),
          Text(
            hasDelta ? '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% к предыдущей' : 'нужна предыдущая сессия',
            style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 8.3),
          ),
        ],
      ),
    );
  }


  Widget _coachComparisonPlayerCard(int id, List<Map<String, dynamic>> rows) {
    final latest = rows.first;
    final previous = rows.length > 1 ? rows[1] : null;
    final distance = _num(latest, const ['total_distance_m', 'distance_m', 'distance']);
    final prevDistance = previous == null ? 0.0 : _num(previous, const ['total_distance_m', 'distance_m', 'distance']);
    final maxSpeed = _num(latest, const ['max_speed_kmh', 'top_speed_kmh', 'max_speed']);
    final load = _num(latest, const ['load_score', 'player_load', 'load']);
    final delta = prevDistance > 0 ? ((distance - prevDistance) / prevDistance * 100) : 0.0;
    final dir = widget.playerDirectory[id] ?? const <String, String>{};
    final avatar = (dir['avatar'] ?? _avatarUrl(latest)).trim();
    final name = (dir['name'] ?? _playerName(latest)).trim();

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => _selectCoachPlayer(id),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _avatar(avatar, size: 36),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.secondarySize)),
                      const SizedBox(height: 2),
                      Text(_shortDate('${latest['ended_at'] ?? latest['created_at'] ?? ''}'), style: const TextStyle(color: _muted, fontSize: AppTypography.badgeSize, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (previous != null)
                  Text(
                    '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%',
                    style: TextStyle(color: delta >= 0 ? _green : _orange, fontWeight: FontWeight.w900, fontSize: AppTypography.captionSize),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(child: _coachTinyMetric('Дистанция', _meters(distance))),
                Expanded(child: _coachTinyMetric('Макс.', maxSpeed > 0 ? '${maxSpeed.toStringAsFixed(1)} км/ч' : '—')),
                Expanded(child: _coachTinyMetric('Нагрузка', load > 0 ? load.toStringAsFixed(0) : '—')),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _coachTinyMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.menuGroupSize)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: 7.7)),
      ],
    );
  }


  Widget _coachCompletedFocusCard(Map<String, dynamic> row) {
    final distance = _num(row, const ['total_distance_m', 'distance_m', 'distance']);
    final avgSpeed = _num(row, const ['avg_speed_kmh', 'average_speed_kmh', 'speed_kmh']);
    final maxSpeed = _num(row, const ['max_speed_kmh', 'top_speed_kmh', 'max_speed']);
    final load = _num(row, const ['load_score', 'player_load', 'load']);
    final avgHr = _int(row, const ['avg_heart_rate_bpm', 'avg_bpm', 'heart_rate_avg']);
    final maxHr = _int(row, const ['max_heart_rate_bpm', 'max_bpm', 'heart_rate_max']);
    final sprints = _int(row, const ['sprint_count', 'sprints', 'spr']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFB),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _avatar(_avatarUrl(row), size: 44),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_playerName(row), style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.itemTitleSize)),
                    const SizedBox(height: 2),
                    Text(
                      '${_activityLabel(row)} · ${_shortDate('${row['ended_at'] ?? row['created_at'] ?? ''}')}',
                      style: const TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: AppTypography.menuGroupSize),
                    ),
                  ],
                ),
              ),
              _archiveStatusChip(),
            ],
          ),
          const SizedBox(height: 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 740 ? 4 : 2;
              const gap = 7.0;
              final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
              final data = <(String, String, IconData)>[
                ('Длительность', _duration(_sessionDuration(row)), Icons.timer_outlined),
                ('Дистанция', _meters(distance), Icons.route_rounded),
                ('Средняя скорость', avgSpeed > 0 ? '${avgSpeed.toStringAsFixed(1)} км/ч' : '—', Icons.speed_rounded),
                ('Макс. скорость', maxSpeed > 0 ? '${maxSpeed.toStringAsFixed(1)} км/ч' : '—', Icons.bolt_rounded),
                ('Средний пульс', avgHr > 0 ? '$avgHr bpm' : '—', Icons.favorite_outline_rounded),
                ('Макс. пульс', maxHr > 0 ? '$maxHr bpm' : '—', Icons.favorite_rounded),
                ('Спринты', '$sprints', Icons.directions_run_rounded),
                ('Нагрузка', load > 0 ? load.toStringAsFixed(0) : '—', Icons.monitor_heart_outlined),
              ];
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in data)
                    SizedBox(
                      width: width,
                      child: _coachSimpleMetric(item.$1, item.$2, item.$3),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 9),
          _coachActionBar(row, running: false),
        ],
      ),
    );
  }


  Widget _coachSimpleMetric(String label, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _green),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontWeight: FontWeight.w800, fontSize: 7.2)),
                const SizedBox(height: 3),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.captionSize)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _coachActionBar(Map<String, dynamic> row, {required bool running}) {
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            onPressed: () => _openCoachSessionWorkspace(row, running: running),
            icon: Icon(running ? Icons.open_in_full_rounded : Icons.visibility_outlined, size: 15),
            label: Text(running ? 'Подробнее Live' : 'Открыть'),
            style: TextButton.styleFrom(
              foregroundColor: _green,
              backgroundColor: _greenSoft,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppTypography.captionSize),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FilledButton.icon(
            onPressed: widget.onOpenAnalytics == null ? null : () => widget.onOpenAnalytics!.call(row),
            icon: const Icon(Icons.analytics_outlined, size: 15),
            label: const Text('Аналитика'),
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppTypography.captionSize),
            ),
          ),
        ),
        if (!running && widget.onOpenReport != null) ...[
          const SizedBox(width: 3),
          IconButton(
            tooltip: 'Отчёт',
            onPressed: () => widget.onOpenReport!.call(row),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.description_outlined, color: _green, size: 18),
          ),
        ],
      ],
    );
  }


  List<Map<String, dynamic>> _coachAlerts(
    List<Map<String, dynamic>> live,
    List<Map<String, dynamic>> finished,
  ) {
    final out = <Map<String, dynamic>>[];
    void add(
      Map<String, dynamic> row,
      String title,
      String detail,
      IconData icon,
      Color color,
    ) {
      if (out.length >= 12) return;
      out.add(<String, dynamic>{
        'row': row,
        'title': title,
        'detail': detail,
        'icon': icon,
        'color': color,
      });
    }

    for (final row in live) {
      final name = _playerName(row);
      final hr = _int(row, const ['last_heart_rate_bpm', 'heart_rate_bpm', 'bpm', 'current_bpm']);
      final load = _num(row, const ['load_score', 'player_load', 'load']);
      final duration = _displayDurationSeconds(
        row,
        serverDuration: _int(row, const ['duration_sec', 'duration_seconds', 'elapsed_sec', 'live_duration_sec']),
        archived: false,
      );
      final distance = _num(row, const ['total_distance_m', 'distance_m', 'distance']);
      final source = _sourceLabel(row).toLowerCase();
      final ai = _calculateAiLoadIndex(
        load: load,
        averageHr: hr.toDouble(),
        maxSpeed: _num(row, const ['max_speed_kmh', 'speed_kmh', 'current_speed_kmh']),
        sprintCount: _int(row, const ['sprint_count', 'sprints']),
        durationSec: duration,
        distanceM: distance,
      );
      if (hr >= 180) {
        add(row, '$name · высокая интенсивность', 'Текущий пульс $hr bpm. Проверьте динамику и восстановление игрока.', Icons.favorite_rounded, _red);
      }
      if (load >= 160) {
        add(row, '$name · высокая нагрузка', 'Внешняя нагрузка ${load.toStringAsFixed(0)} уже в высокой зоне.', Icons.local_fire_department_rounded, _orange);
      }
      if (ai >= 85) {
        add(row, '$name · пиковая работа', 'AI-индекс интенсивности ${ai.toStringAsFixed(0)}/100.', Icons.bolt_rounded, const Color(0xFF7C3AED));
      }
      if (duration >= 5400) {
        add(row, '$name · длительная сессия', 'Личная работа продолжается ${_duration(duration)}.', Icons.timer_outlined, _orange);
      }
      if (duration >= 120 && source.contains('polar') && hr <= 0) {
        add(row, '$name · нет актуального Polar', 'Источник заявлен, но текущий пульс не поступает.', Icons.favorite_border_rounded, _orange);
      }
      if (duration >= 120 && source.contains('gps') && _gpsSamples(row).isEmpty && distance <= 0) {
        add(row, '$name · нет GPS-точек', 'Трекер указан, но координаты и дистанция пока не поступают.', Icons.gps_off_rounded, _orange);
      }
    }

    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final row in finished) {
      final id = _rowPlayerId(row);
      if (id == null) continue;
      grouped.putIfAbsent(id, () => <Map<String, dynamic>>[]).add(row);
    }
    for (final rows in grouped.values) {
      if (rows.length < 2) continue;
      rows.sort((a, b) {
        final ad = _parseDate(a['ended_at'] ?? a['created_at']) ?? DateTime(1970);
        final bd = _parseDate(b['ended_at'] ?? b['created_at']) ?? DateTime(1970);
        return bd.compareTo(ad);
      });
      final latest = rows[0];
      final previous = rows[1];
      final currentMax = _num(latest, const ['max_speed_kmh', 'top_speed_kmh', 'max_speed']);
      final prevMax = _num(previous, const ['max_speed_kmh', 'top_speed_kmh', 'max_speed']);
      if (currentMax > 0 && prevMax >= 10 && currentMax < prevMax * .85) {
        final drop = ((prevMax - currentMax) / prevMax * 100).round();
        add(
          latest,
          '${_playerName(latest)} · скорость ниже прошлой',
          'Максимальная скорость снизилась примерно на $drop% относительно предыдущей личной тренировки.',
          Icons.trending_down_rounded,
          _orange,
        );
      }
    }
    return out;
  }


  Widget _coachAttentionPanel(List<Map<String, dynamic>> alerts) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: alerts.isEmpty ? const Color(0xFFF3FAF6) : const Color(0xFFFFF8EA),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(alerts.isEmpty ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded, size: 17, color: alerts.isEmpty ? _green : _orange),
              const SizedBox(width: 6),
              const Expanded(child: Text('Внимание тренера', style: TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.secondarySize))),
              Text('${alerts.length}', style: TextStyle(color: alerts.isEmpty ? _green : _orange, fontWeight: FontWeight.w900, fontSize: AppTypography.captionSize)),
            ],
          ),
          const SizedBox(height: 7),
          if (alerts.isEmpty)
            const Text(
              'Критичных отклонений по доступным Live-данным сейчас не найдено.',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: AppTypography.badgeSize, height: 1.3),
            )
          else
            for (final alert in alerts.take(5)) ...[
              InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () {
                  final row = Map<String, dynamic>.from(alert['row'] as Map);
                  _openCoachSessionWorkspace(
                    row,
                    running: _isRowRunning(row),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(alert['icon'] as IconData, size: 14, color: alert['color'] as Color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${alert['title']}', style: const TextStyle(color: _text, fontWeight: FontWeight.w800, fontSize: AppTypography.menuGroupSize)),
                            const SizedBox(height: 2),
                            Text('${alert['detail']}', style: const TextStyle(color: _muted, fontWeight: FontWeight.w500, fontSize: 8.4, height: 1.25)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (alert != alerts.take(5).last)
                const Divider(height: 1, thickness: .6, color: Color(0xFFECE6D8)),
            ],
        ],
      ),
    );
  }


  Widget _coachDataQualityPanel(
    List<Map<String, dynamic>> live,
    List<Map<String, dynamic>> finished,
  ) {
    final rows = live.isNotEmpty ? live : finished.take(5).toList();
    final total = rows.length;
    final gps = rows.where((row) =>
        _gpsSamples(row).isNotEmpty ||
        _num(row, const ['total_distance_m', 'distance_m', 'distance']) > 0).length;
    final hr = rows.where((row) =>
        _int(row, const ['last_heart_rate_bpm', 'avg_heart_rate_bpm', 'heart_rate_bpm', 'avg_bpm']) > 0 ||
        _heartRateSamples(row).isNotEmpty).length;
    final completeness = total <= 0 ? 0 : (((gps + hr) / (total * 2)) * 100).round();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F7),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 16, color: Color(0xFF1677D2)),
              SizedBox(width: 6),
              Expanded(child: Text('Полнота данных', style: TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.secondarySize))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: (completeness / 100).clamp(0.0, 1.0).toDouble(),
              backgroundColor: const Color(0xFFE8EEF2),
              valueColor: AlwaysStoppedAnimation<Color>(completeness >= 80 ? _green : _orange),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _coachTinyMetric('GPS', total > 0 ? '$gps/$total' : '—')),
              Expanded(child: _coachTinyMetric('Polar', total > 0 ? '$hr/$total' : '—')),
              Expanded(child: _coachTinyMetric('Готовность', total > 0 ? '$completeness%' : '—')),
            ],
          ),
        ],
      ),
    );
  }


  Widget _coachRecentMiniPanel(List<Map<String, dynamic>> events) {
    final rows = List<Map<String, dynamic>>.from(events)
      ..sort((a, b) {
        final ad = _parseDate(a['ended_at'] ?? a['created_at'] ?? a['event_at']) ?? DateTime(1970);
        final bd = _parseDate(b['ended_at'] ?? b['created_at'] ?? b['event_at']) ?? DateTime(1970);
        return bd.compareTo(ad);
      });
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 16, color: _green),
              const SizedBox(width: 6),
              const Expanded(child: Text('Последние тренировки', style: TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.secondarySize))),
              TextButton(
                onPressed: () => setState(() => _coachView = _CoachPersonalView.journal),
                child: const Text('Все', style: TextStyle(fontSize: AppTypography.menuGroupSize, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Событий пока нет.', style: TextStyle(color: _muted, fontSize: AppTypography.badgeSize, fontWeight: FontWeight.w600)),
            )
          else
            for (final row in rows.take(5))
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openCoachSessionWorkspace(row, running: false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      _avatar(_avatarUrl(row), size: 28),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_playerName(row), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w800, fontSize: AppTypography.menuGroupSize)),
                            const SizedBox(height: 2),
                            Text(
                              '${_activityLabel(row)} · ${_duration(_sessionDuration(row))} · ${_meters(_num(row, const ['total_distance_m', 'distance_m', 'distance']))}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _muted, fontWeight: FontWeight.w500, fontSize: 8.1),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: _muted, size: 16),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }


  Widget _coachSectionTitle(
    String title,
    String subtitle,
    IconData icon, {
    Color accent = _green,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: accent.withOpacity(.09), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.secondarySize)),
              const SizedBox(height: 1),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontWeight: FontWeight.w500, fontSize: AppTypography.badgeSize)),
            ],
          ),
        ),
      ],
    );
  }


  Widget _coachEmptyCard(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: _green, size: 24),
          ),
          const SizedBox(height: 9),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: AppTypography.bodySize)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontWeight: FontWeight.w500, fontSize: AppTypography.menuGroupSize, height: 1.35)),
        ],
      ),
    );
  }


  String _coachPlayerName(int id) {
    final dir = _resolvedDirectory[id] ?? widget.playerDirectory[id];
    final name = (dir?['name'] ?? '').trim();
    return name.isNotEmpty
        ? _shortSurnameFirst(name, assumeFirstNameFirst: true)
        : 'Игрок $id';
  }


  Widget _liveStrip(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      _liveCardKeys.putIfAbsent(_playerStableKey(row), () => GlobalKey());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 66,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final row = rows[index];
              final name = _playerName(row);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final target = _liveCardKeys[_playerStableKey(row)]?.currentContext;
                  if (target != null) {
                    Scrollable.ensureVisible(
                      target,
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      alignment: .05,
                    );
                  }
                },
                child: Container(
                  width: 94,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    color: _greenSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _avatar(_avatarUrl(row), size: 34),
                          const Positioned(
                            right: -1,
                            bottom: -1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: _green, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2))),
                              child: SizedBox(width: 10, height: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: AppTypography.menuGroupSize),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 18, thickness: 1, color: _line),
          itemBuilder: (context, index) {
            final row = rows[index];
            return KeyedSubtree(
              key: _liveCardKeys[_playerStableKey(row)],
              child: SizedBox(
                width: double.infinity,
                child: _liveCard(row),
              ),
            );
          },
        ),
      ],
    );
  }



  Widget _trackerMiniInfo({
    required IconData icon,
    required String value,
    required String tooltip,
  }) {
    final hasValue = value.trim().isNotEmpty && value.trim() != '—';
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.86),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: hasValue ? _green : _muted),
            const SizedBox(width: 3),
            Text(
              hasValue ? value : '—',
              style: TextStyle(
                color: hasValue ? _text : _muted,
                fontWeight: FontWeight.w800,
                fontSize: AppTypography.badgeSize,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _liveCard(Map<String, dynamic> row, {bool archived = false}) {
    final name = _playerName(row);
    final avatar = _avatarUrl(row);
    final hr = _int(row, const [
      'last_heart_rate_bpm',
      'heart_rate_bpm',
      'bpm',
      'current_bpm',
    ]);
    final serverDuration = _int(row, const [
      'duration_sec',
      'duration_seconds',
      'elapsed_sec',
      'live_duration_sec',
    ]);
    final duration = _displayDurationSeconds(
      row,
      serverDuration: serverDuration,
      archived: archived,
    );
    final distance = _num(row, const [
      'total_distance_m',
      'distance_m',
      'distance',
      'session_distance_m',
    ]);
    final speed = _num(row, const [
      'speed_kmh',
      'last_speed_kmh',
      'current_speed_kmh',
    ]);
    final maxSpeed = _num(row, const [
      'max_speed_kmh',
      'top_speed_kmh',
      'max_speed',
    ]);
    final load = _num(row, const ['load_score', 'player_load', 'load']);
    final aiLoad = _num(row, const ['ai_load', 'ai_load_score']);
    final samples = _heartRateSamples(row);
    final sprintCount = _int(row, const ['sprint_count', 'sprints', 'spr']);
    final accelerationCount = _int(row, const [
      'acceleration_count',
      'accelerations',
      'hard_acceleration_count',
      'accel_count',
    ]);
    final decelerationCount = _int(row, const [
      'deceleration_count',
      'decelerations',
      'braking_count',
      'hard_deceleration_count',
      'decel_count',
    ]);
    final explosiveCountRaw = _int(row, const [
      'explosive_action_count',
      'explosive_actions',
      'explosive_count',
      'high_intensity_actions',
    ]);
    final explosiveCount = explosiveCountRaw > 0
        ? explosiveCountRaw
        : accelerationCount + decelerationCount + sprintCount;
    final highSpeedDistance = _num(row, const [
      'high_speed_distance_m',
      'hsr_distance_m',
      'high_intensity_distance_m',
    ]);
    final gpsPoints = _gpsSamples(row);
    final runningMode = _activityLabel(row) == 'Бег';
    final hasGps = gpsPoints.isNotEmpty ||
        _sourceLabel(row).toLowerCase().contains('gps') ||
        distance > 0;
    final trackerSignal = _deviceSignal(
      row,
      const ['gps_rssi', 'tracker_rssi', 'signal_dbm', 'rssi'],
    );
    final trackerBattery = _deviceBattery(
      row,
      const ['gps_battery', 'tracker_battery', 'battery_percent', 'battery'],
    );

    final averageHr = samples.isEmpty
        ? hr.toDouble()
        : samples.fold<double>(0, (sum, point) => sum + point.bpm) / samples.length;
    final calculatedAiLoad = _calculateAiLoadIndex(
      load: load,
      averageHr: averageHr,
      maxSpeed: math.max(speed, maxSpeed),
      sprintCount: sprintCount,
      durationSec: duration,
      distanceM: distance,
    );
    final displayAiLoad = aiLoad > 0
        ? aiLoad.clamp(0, 100).toDouble()
        : calculatedAiLoad;
    final locationLabel = _readText(
      row,
      const ['location_name', 'venue_name', 'field_name', 'place_name', 'city'],
      fallback: '',
    );
    final airTemperature = _num(
      row,
      const ['air_temperature_c', 'temperature_c', 'weather_temperature_c', 'temperature'],
    );

    final loadLow = _percentage(row, const ['load_low_percent', 'load_zone_1_percent', 'low_load_percent']);
    final loadModerate = _percentage(row, const ['load_moderate_percent', 'load_zone_2_percent', 'moderate_load_percent']);
    final loadHigh = _percentage(row, const ['load_high_percent', 'load_zone_3_percent', 'high_load_percent']);
    var loadVeryHigh = _percentage(row, const ['load_very_high_percent', 'load_zone_4_percent', 'very_high_load_percent']);
    var resolvedLoadLow = loadLow;
    var resolvedLoadModerate = loadModerate;
    var resolvedLoadHigh = loadHigh;
    var resolvedLoadVeryHigh = loadVeryHigh;
    if (resolvedLoadLow + resolvedLoadModerate + resolvedLoadHigh + resolvedLoadVeryHigh <= 0 && samples.isNotEmpty) {
      final zones = _deriveIntensityZones(samples);
      resolvedLoadLow = zones[0];
      resolvedLoadModerate = zones[1];
      resolvedLoadHigh = zones[2];
      resolvedLoadVeryHigh = zones[3];
    }

    final sprintDistance = _num(row, const ['sprint_distance_m', 'sprints_distance_m']);
    final sprintDuration = _int(row, const ['sprint_duration_sec', 'sprint_time_sec']);
    final runPercent = _percentage(row, const ['run_percent', 'running_percent']);
    final runDistance = _num(row, const ['run_distance_m', 'running_distance_m']);
    final runDuration = _int(row, const ['run_duration_sec', 'running_time_sec']);
    final walkPercent = _percentage(row, const ['walk_percent', 'walking_percent']);
    final walkDistance = _num(row, const ['walk_distance_m', 'walking_distance_m']);
    final walkDuration = _int(row, const ['walk_duration_sec', 'walking_time_sec']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide = constraints.maxWidth >= 360;
          final compact = constraints.maxWidth < 560;
          final viewportHeight = MediaQuery.sizeOf(context).height;
          final tabletDense = constraints.maxWidth >= 860 && viewportHeight <= 1050;
          final denseMetrics = compact || tabletDense;
          final metricColumns = constraints.maxWidth >= 900 ? 7 : (constraints.maxWidth >= 560 ? 4 : 3);
          final metricWidth = (constraints.maxWidth - ((metricColumns - 1) * 8)) / metricColumns;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compact)
                Row(
                  children: [
                    _avatar(avatar, size: 48),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppTypography.screenTitleSize,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            archived ? _archiveStatusChip() : _liveDot(),
                            const SizedBox(width: 8),
                            Flexible(
                              child: _headerMetaChip(
                                Icons.place_outlined,
                                locationLabel.isNotEmpty ? locationLabel : 'Место определяется',
                              ),
                            ),
                            const SizedBox(width: 6),
                            _headerMetaChip(
                              Icons.device_thermostat_rounded,
                              airTemperature != 0
                                  ? '${airTemperature.toStringAsFixed(airTemperature == airTemperature.roundToDouble() ? 0 : 1)} °C'
                                  : 'Погода —',
                            ),

                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_activityLabel(row)} · ${_sourceLabel(row)}',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: AppTypography.captionSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasGps)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1FBF5),
                        borderRadius: BorderRadius.circular(11),
                        
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sensors_rounded, size: 17, color: _green),
                          const SizedBox(width: 6),
                          Text(archived ? 'Трекер подключался' : 'Трекер онлайн', style: const TextStyle(color: _green, fontWeight: FontWeight.w600, fontSize: AppTypography.secondarySize)),
                          const SizedBox(width: 12),
                          _trackerMiniInfo(icon: Icons.network_cell_rounded, value: trackerSignal, tooltip: 'Сигнал трекера'),
                          const SizedBox(width: 6),
                          _trackerMiniInfo(icon: Icons.battery_5_bar_rounded, value: trackerBattery, tooltip: 'Заряд трекера'),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _avatar(avatar, size: 42),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w600, fontSize: AppTypography.sectionTitleSize)),
                                  ),
                                  const SizedBox(width: 6),
                                  archived ? _archiveStatusChip() : _liveDot(),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_activityLabel(row)} · ${_sourceLabel(row)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: _muted, fontSize: AppTypography.menuGroupSize, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _headerMetaChip(
                                    Icons.place_outlined,
                                    locationLabel.isNotEmpty ? locationLabel : 'Место определяется',
                                    compact: true,
                                  ),
                                  _headerMetaChip(
                                    Icons.device_thermostat_rounded,
                                    airTemperature != 0
                                        ? '${airTemperature.toStringAsFixed(airTemperature == airTemperature.roundToDouble() ? 0 : 1)} °C'
                                        : 'Погода —',
                                    compact: true,
                                  ),

                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (hasGps) ...[
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFF1FBF5), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.sensors_rounded, size: 15, color: _green),
                            const SizedBox(width: 5),
                            Expanded(child: Text(archived ? 'Трекер подключался' : 'Трекер онлайн', style: const TextStyle(color: _green, fontWeight: FontWeight.w600, fontSize: AppTypography.captionSize))),
                            _trackerMiniInfo(icon: Icons.network_cell_rounded, value: trackerSignal, tooltip: 'Сигнал трекера'),
                            const SizedBox(width: 5),
                            _trackerMiniInfo(icon: Icons.battery_5_bar_rounded, value: trackerBattery, tooltip: 'Заряд трекера'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _topMetricCard('Начало', _startTime(row), Icons.schedule_rounded, width: metricWidth, compact: denseMetrics),
                  _topMetricCard('Длительность', _duration(duration), Icons.timer_outlined, width: metricWidth, compact: denseMetrics),
                  _topMetricCard('Дистанция', _meters(distance), Icons.location_on_outlined, width: metricWidth, compact: denseMetrics),
                  _topMetricCard('Скорость', '${speed.toStringAsFixed(1)} км/ч', Icons.speed_rounded, width: metricWidth, compact: denseMetrics),
                  _topMetricCard('Макс. скорость', '${math.max(speed, maxSpeed).toStringAsFixed(1)} км/ч', Icons.speed_rounded, width: metricWidth, compact: denseMetrics),
                  _topMetricCard('Пульс', hr > 0 ? '$hr bpm' : '—', Icons.favorite_rounded, width: metricWidth, compact: denseMetrics),
                  _topMetricCard('Спринты', '$sprintCount', Icons.directions_run_rounded, width: metricWidth, compact: denseMetrics),
                  _topMetricCard('Ускорения', '$accelerationCount', Icons.trending_up_rounded, width: metricWidth, compact: denseMetrics),
                  _topMetricCard('Торможения', '$decelerationCount', Icons.trending_down_rounded, width: metricWidth, compact: denseMetrics),
                  _topMetricCard('Взрывные', '$explosiveCount', Icons.bolt_rounded, width: metricWidth, compact: denseMetrics),
                  _topMetricCard('HSR', highSpeedDistance > 0 ? _meters(highSpeedDistance) : '—', Icons.double_arrow_rounded, width: metricWidth, compact: denseMetrics),
                  _loadMetricCard(
                    title: 'Нагрузка',
                    value: load,
                    width: metricWidth,
                    compact: denseMetrics,
                    description: 'Суммарная внешняя нагрузка трекера. Используется для сравнения тренировок одного игрока между собой.',
                  ),
                  _loadMetricCard(
                    title: 'AI индекс',
                    value: displayAiLoad,
                    width: metricWidth,
                    compact: denseMetrics,
                    isAi: true,
                    description: 'Индекс 0–100 рассчитан по фактическим данным: длительности, дистанции, скорости, пульсу, спринтам и нагрузке трекера. Это спортивный ориентир, а не медицинская оценка.',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: sideBySide
                    ? (tabletDense ? 238 : (compact ? 245 : 320))
                    : (compact ? 500 : 620),
                child: sideBySide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _pulseLivePanel(hr: hr, samples: samples)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _mapLivePanel(
                              current: row,
                              points: gpsPoints,
                              runningMode: runningMode,
                              distanceM: distance,
                              currentSpeedKmh: speed,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: _pulseLivePanel(hr: hr, samples: samples)),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _mapLivePanel(
                              current: row,
                              points: gpsPoints,
                              runningMode: runningMode,
                              distanceM: distance,
                              currentSpeedKmh: speed,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, bottomConstraints) {
                  final twoColumns = bottomConstraints.maxWidth < 720;
                  const gap = 8.0;
                  final cardWidth = twoColumns
                      ? (bottomConstraints.maxWidth - gap) / 2
                      : (bottomConstraints.maxWidth - gap * 3) / 4;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _loadZonesCard(
                          resolvedLoadLow,
                          resolvedLoadModerate,
                          resolvedLoadHigh,
                          resolvedLoadVeryHigh,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _sprintsCard(
                          sprintCount,
                          sprintDuration,
                          sprintDistance,
                          math.max(speed, maxSpeed),
                          duration,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _movementCard(
                          'Бег',
                          runPercent,
                          runDistance,
                          runDuration,
                          const Color(0xFF1677D2),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _movementCard(
                          'Ходьба',
                          walkPercent,
                          walkDistance,
                          walkDuration,
                          const Color(0xFF7B8794),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _archiveStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 11, color: _green),
          SizedBox(width: 4),
          Text('Завершено', style: TextStyle(color: _green, fontWeight: FontWeight.w900, fontSize: AppTypography.menuGroupSize)),
        ],
      ),
    );
  }


  double _percentage(Map<String, dynamic> row, List<String> keys) {
    final value = _num(row, keys);
    if (!value.isFinite || value <= 0) return 0;
    return value.clamp(0, 100).toDouble();
  }



  double _calculateAiLoadIndex({
    required double load,
    required double averageHr,
    required double maxSpeed,
    required int sprintCount,
    required int durationSec,
    required double distanceM,
  }) {
    final safeLoad = load.isFinite ? math.max(0.0, load) : 0.0;
    final safeHr = averageHr.isFinite ? math.max(0.0, averageHr) : 0.0;
    final safeSpeed = maxSpeed.isFinite ? math.max(0.0, maxSpeed) : 0.0;
    final safeDistance = distanceM.isFinite ? math.max(0.0, distanceM) : 0.0;
    final safeSprints = math.max(0, sprintCount);
    final safeDuration = math.max(0, durationSec);
    if (safeLoad <= 0 && safeHr <= 0 && safeSpeed <= 0 && safeDistance <= 0) return 0;
    final durationMinutes = math.max(1.0, safeDuration / 60.0);
    final intensityMPerMin = safeDistance / durationMinutes;
    final loadPart = (safeLoad / 180.0).clamp(0.0, 1.0).toDouble() * 30.0;
    final hrPart = ((safeHr - 70.0) / 110.0).clamp(0.0, 1.0).toDouble() * 25.0;
    final speedPart = (safeSpeed / 30.0).clamp(0.0, 1.0).toDouble() * 15.0;
    final sprintPart = (safeSprints / 12.0).clamp(0.0, 1.0).toDouble() * 15.0;
    final densityPart = (intensityMPerMin / 130.0).clamp(0.0, 1.0).toDouble() * 15.0;
    final result = loadPart + hrPart + speedPart + sprintPart + densityPart;
    return result.isFinite ? result.clamp(0.0, 100.0).toDouble() : 0.0;
  }


  List<double> _deriveIntensityZones(List<_HrPoint> samples) {
    if (samples.isEmpty) return const [0, 0, 0, 0];
    final maxObserved = samples.map((e) => e.bpm).reduce(math.max);
    if (maxObserved <= 0) return const [0, 0, 0, 0];
    final counts = <int>[0, 0, 0, 0];
    for (final point in samples) {
      final ratio = point.bpm / maxObserved;
      if (ratio < .65) {
        counts[0]++;
      } else if (ratio < .78) {
        counts[1]++;
      } else if (ratio < .90) {
        counts[2]++;
      } else {
        counts[3]++;
      }
    }
    final total = math.max(1, counts.fold<int>(0, (a, b) => a + b));
    return counts.map((e) => e * 100.0 / total).toList();
  }


  String _loadLevel(double value) {
    if (value <= 0) return 'Нет данных';
    if (value < 40) return 'Низкая';
    if (value < 100) return 'Умеренная';
    if (value < 160) return 'Высокая';
    return 'Очень высокая';
  }


  Color _loadLevelColor(double value) {
    if (value <= 0) return const Color(0xFF98A2B3);
    if (value < 40) return const Color(0xFF22C55E);
    if (value < 100) return const Color(0xFF84CC16);
    if (value < 160) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }


  Widget _sessionMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _green),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: _muted,
            fontSize: AppTypography.captionSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }


  Widget _headerMetaChip(
    IconData icon,
    String text, {
    bool compact = false,
  }) {
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 210 : 260),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1FBF5),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 12, color: _green),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _green,
                fontSize: compact ? 8.8 : 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _loadMetricCard({
    required String title,
    required double value,
    required double width,
    required bool compact,
    required String description,
    bool isAi = false,
  }) {
    final level = isAi
        ? (value <= 0 ? 'Нет данных' : value < 35 ? 'Низкий' : value < 65 ? 'Рабочий' : value < 85 ? 'Высокий' : 'Пиковый')
        : _loadLevel(value);
    final accent = isAi
        ? (value <= 0 ? const Color(0xFF98A2B3) : value < 65 ? const Color(0xFF22C55E) : value < 85 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))
        : _loadLevelColor(value);
    final progress = isAi
        ? (value / 100.0).clamp(0.0, 1.0)
        : (value / 200.0).clamp(0.0, 1.0);
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Понятно'),
            ),
          ],
        ),
      ),
      child: Container(
        width: width,
        height: compact ? 50 : 60,
        padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 6 : 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFA),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isAi ? Icons.psychology_alt_outlined : Icons.monitor_heart_outlined, size: compact ? 14 : 17, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _muted, fontSize: compact ? 6.8 : 7.8, fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.info_outline_rounded, size: 11, color: Color(0xFF98A2B3)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value > 0 ? (isAi ? '${value.round()} / 100' : '${value.toStringAsFixed(0)} · $level') : '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _text, fontSize: compact ? 9.5 : 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: progress.toDouble(),
                backgroundColor: accent.withOpacity(.13),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _topMetricCard(String title, String value, IconData icon, {double? width, bool compact = false}) {
    return Container(
      width: width ?? 138,
      height: compact ? 46 : 60,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFA),
        borderRadius: BorderRadius.circular(9),
      ),
      child: compact
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 6.9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: AppTypography.captionSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Icon(icon, size: 17, color: _green),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 7.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _text,
                          fontSize: AppTypography.secondarySize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }


  Widget _pulseLivePanel({
    required int hr,
    required List<_HrPoint> samples,
    bool embedded = false,
  }) {
    final sortedSamples = List<_HrPoint>.from(samples)
      ..sort((a, b) => a.sec.compareTo(b.sec));
    final firstSec = sortedSamples.isEmpty ? 0.0 : sortedSamples.first.sec;
    final chartSamples = firstSec > 0
        ? sortedSamples
            .map((e) => _HrPoint(sec: math.max(0.0, e.sec - firstSec), bpm: e.bpm))
            .toList()
        : sortedSamples;
    final avg = chartSamples.isEmpty
        ? 0
        : (chartSamples.fold<double>(0, (s, e) => s + e.bpm) /
                chartSamples.length)
            .round();
    final maxHr = chartSamples.isEmpty
        ? 0
        : chartSamples.map((e) => e.bpm).reduce(math.max).round();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: embedded ? 34 : 38,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Row(
            children: [
              const Icon(Icons.favorite_rounded, color: _red, size: 16),
              const SizedBox(width: 6),
              Text(
                hr > 0 ? '$hr уд/мин' : 'Пульс —',
                style: const TextStyle(
                  color: _red,
                  fontWeight: FontWeight.w800,
                  fontSize: AppTypography.captionSize,
                ),
              ),
              const Spacer(),
              Text(
                'Средний ${avg > 0 ? avg : '—'} · Макс. ${maxHr > 0 ? maxHr : '—'}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 8.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              embedded ? 7 : 12,
              0,
              embedded ? 7 : 12,
              embedded ? 5 : 8,
            ),
            child: _HrChart(values: chartSamples, compact: true),
          ),
        ),
      ],
    );

    if (embedded) {
      return Container(color: const Color(0xFFFFF8F8), child: content);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: content,
    );
  }

}



class _PersonalTeamLiveField extends StatelessWidget {
  const _PersonalTeamLiveField({
    required this.points,
    required this.field,
    required this.avatarUrl,
    required this.playerName,
    required this.showTrace,
    required this.showHeat,
    required this.showEvents,
    required this.showHud,
    required this.showPlayer,
    required this.selectedMoment,
    required this.currentSpeedKmh,
    required this.distanceM,
  });

  final List<_GpsPoint> points;
  final TrackerFieldModel? field;
  final String avatarUrl;
  final String playerName;
  final bool showTrace;
  final bool showHeat;
  final bool showEvents;
  final bool showHud;
  final bool showPlayer;
  final _GpsMomentMarker? selectedMoment;
  final double currentSpeedKmh;
  final double distanceM;

  Offset _project(_GpsPoint point, Size size) {
    final pitch = Rect.fromLTWH(
      10,
      10,
      math.max(1.0, size.width - 20),
      math.max(1.0, size.height - 20),
    );
    final projected = TrackerPitchProjector.projectGps(
      field,
      latitude: point.lat,
      longitude: point.lon,
    );
    if (projected != null && projected.isInside) {
      return Offset(
        pitch.left + projected.clampedNx * pitch.width,
        pitch.bottom - projected.clampedNy * pitch.height,
      );
    }
    if (points.isEmpty) return pitch.center;
    var minLat = points.first.lat;
    var maxLat = points.first.lat;
    var minLon = points.first.lon;
    var maxLon = points.first.lon;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLon = math.min(minLon, p.lon);
      maxLon = math.max(maxLon, p.lon);
    }
    final lonRange = (maxLon - minLon).abs();
    final latRange = (maxLat - minLat).abs();
    final nx = lonRange < .000001
        ? .5
        : ((point.lon - minLon) / lonRange).clamp(.035, .965).toDouble();
    final ny = latRange < .000001
        ? .5
        : ((point.lat - minLat) / latRange).clamp(.035, .965).toDouble();
    return Offset(
      pitch.left + nx * pitch.width,
      pitch.bottom - ny * pitch.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(
          math.max(1.0, c.maxWidth),
          math.max(1.0, c.maxHeight),
        );
        final latest = points.isEmpty ? null : points.last;
        final pos = latest == null ? null : _project(latest, size);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PersonalTeamLiveFieldPainter(
                  points: points,
                  field: field,
                  showTrace: showTrace,
                  showHeat: showHeat,
                  showEvents: showEvents,
                  selectedMoment: selectedMoment,
                ),
              ),
            ),
            if (showPlayer && pos != null)
              Positioned(
                left: (pos.dx - 25)
                    .clamp(0.0, math.max(0.0, size.width - 50))
                    .toDouble(),
                top: (pos.dy - 25)
                    .clamp(0.0, math.max(0.0, size.height - 58))
                    .toDouble(),
                width: showHud ? 118 : 50,
                child: IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.13),
                              blurRadius: 9,
                              spreadRadius: -3,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: avatarUrl.trim().isEmpty
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF00A750),
                                  size: 24,
                                )
                              : Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    color: Color(0xFF00A750),
                                    size: 24,
                                  ),
                                ),
                        ),
                      ),
                      if (showHud) ...[
                        const SizedBox(height: 2),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 118),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.94),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            '$playerName · ${currentSpeedKmh.toStringAsFixed(1)} км/ч · ${distanceM >= 1000 ? '${(distanceM / 1000).toStringAsFixed(2)} км' : '${distanceM.toStringAsFixed(0)} м'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF0B0F14),
                              fontSize: 7.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PersonalTeamLiveFieldPainter extends CustomPainter {
  const _PersonalTeamLiveFieldPainter({
    required this.points,
    required this.field,
    required this.showTrace,
    required this.showHeat,
    required this.showEvents,
    required this.selectedMoment,
  });

  final List<_GpsPoint> points;
  final TrackerFieldModel? field;
  final bool showTrace;
  final bool showHeat;
  final bool showEvents;
  final _GpsMomentMarker? selectedMoment;

  Rect _pitch(Size size) => Rect.fromLTWH(
        10,
        10,
        math.max(1.0, size.width - 20),
        math.max(1.0, size.height - 20),
      );

  Offset _project(_GpsPoint point, Rect pitch) {
    final projected = TrackerPitchProjector.projectGps(
      field,
      latitude: point.lat,
      longitude: point.lon,
    );
    if (projected != null && projected.isInside) {
      return Offset(
        pitch.left + projected.clampedNx * pitch.width,
        pitch.bottom - projected.clampedNy * pitch.height,
      );
    }
    if (points.isEmpty) return pitch.center;
    var minLat = points.first.lat;
    var maxLat = points.first.lat;
    var minLon = points.first.lon;
    var maxLon = points.first.lon;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLon = math.min(minLon, p.lon);
      maxLon = math.max(maxLon, p.lon);
    }
    final lonRange = (maxLon - minLon).abs();
    final latRange = (maxLat - minLat).abs();
    final nx = lonRange < .000001
        ? .5
        : ((point.lon - minLon) / lonRange).clamp(.035, .965).toDouble();
    final ny = latRange < .000001
        ? .5
        : ((point.lat - minLat) / latRange).clamp(.035, .965).toDouble();
    return Offset(
      pitch.left + nx * pitch.width,
      pitch.bottom - ny * pitch.height,
    );
  }

  void _drawPitch(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final border = RRect.fromRectAndRadius(full, const Radius.circular(16));
    canvas.drawRRect(border, Paint()..color = const Color(0xFF76947B));

    final clip = Path()..addRRect(border.deflate(8));
    canvas.save();
    canvas.clipPath(clip);
    final stripeW = math.max(36.0, size.width / 12);
    for (var i = 0; i < 14; i++) {
      final color =
          i.isEven ? const Color(0xFF719078) : const Color(0xFF819E86);
      canvas.drawRect(
        Rect.fromLTWH(
          8 + i * stripeW,
          8,
          stripeW,
          math.max(1.0, size.height - 16),
        ),
        Paint()..color = color,
      );
    }
    canvas.restore();

    final line = Paint()
      ..color = Colors.white.withOpacity(.78)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final inner = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(12)),
      line,
    );
    canvas.drawLine(
      Offset(size.width / 2, 10),
      Offset(size.width / 2, size.height - 10),
      line,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      math.min(size.width, size.height) * .12,
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(10, size.height * .28, size.width * .17, size.height * .44),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(10, size.height * .38, size.width * .08, size.height * .24),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width - 10 - size.width * .17,
        size.height * .28,
        size.width * .17,
        size.height * .44,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width - 10 - size.width * .08,
        size.height * .38,
        size.width * .08,
        size.height * .24,
      ),
      line,
    );
    canvas.drawCircle(
      Offset(size.width * .13, size.height / 2),
      3,
      Paint()..color = Colors.white.withOpacity(.75),
    );
    canvas.drawCircle(
      Offset(size.width * .87, size.height / 2),
      3,
      Paint()..color = Colors.white.withOpacity(.75),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawPitch(canvas, size);
    final pitch = _pitch(size);

    if (points.isEmpty) {
      final text = field?.hasCalibration == true
          ? 'Ждём GPS от трекера'
          : 'Откалибруйте поле по 4 углам';
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 32);
      tp.paint(
        canvas,
        Offset(
          (size.width - tp.width) / 2,
          (size.height - tp.height) / 2,
        ),
      );
      return;
    }

    if (showHeat) {
      final stride = math.max(1, points.length ~/ 180);
      for (var i = 0; i < points.length; i += stride) {
        final p = points[i];
        final pos = _project(p, pitch);
        final intensity = (p.speedKmh / 24.0).clamp(.15, 1.0).toDouble();
        final color = p.speedKmh >= 18
            ? const Color(0xFFDC2626)
            : (p.speedKmh >= 12
                ? const Color(0xFFF59E0B)
                : const Color(0xFF00A750));
        final radius = 10 + 18 * intensity;
        canvas.drawCircle(
          pos,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                color.withOpacity(.16 * intensity),
                color.withOpacity(.04 * intensity),
                Colors.transparent,
              ],
            ).createShader(Rect.fromCircle(center: pos, radius: radius)),
        );
      }
    }

    if (showTrace && points.length >= 2) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final pos = _project(points[i], pitch);
        if (i == 0) {
          path.moveTo(pos.dx, pos.dy);
        } else {
          path.lineTo(pos.dx, pos.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withOpacity(.08)
          ..strokeWidth = 5.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF00A750).withOpacity(.92)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (showEvents && selectedMoment != null) {
      final markerPoint = _GpsPoint(
        lat: selectedMoment!.lat,
        lon: selectedMoment!.lon,
        speedKmh: 0,
      );
      final pos = _project(markerPoint, pitch);
      canvas.drawCircle(
        pos,
        10,
        Paint()..color = Colors.white.withOpacity(.92),
      );
      canvas.drawCircle(
        pos,
        6.5,
        Paint()..color = selectedMoment!.color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PersonalTeamLiveFieldPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.field != field ||
      oldDelegate.showTrace != showTrace ||
      oldDelegate.showHeat != showHeat ||
      oldDelegate.showEvents != showEvents ||
      oldDelegate.selectedMoment != selectedMoment;
}

class _PersonalLivePitchPerspective extends StatefulWidget {
  const _PersonalLivePitchPerspective({
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<_PersonalLivePitchPerspective> createState() =>
      _PersonalLivePitchPerspectiveState();
}

class _PersonalLivePitchPerspectiveState
    extends State<_PersonalLivePitchPerspective> {
  double _yawDeg = 0.0;
  double _tiltRad = -.34;
  double _zoom = .96;

  void _orbit(Offset delta) {
    if (!widget.enabled) return;
    setState(() {
      _yawDeg = (_yawDeg + delta.dx * .48) % 360.0;
      _tiltRad =
          (_tiltRad - delta.dy * .0065).clamp(-.70, -.10).toDouble();
    });
  }

  void _zoomBy(double delta) {
    if (!widget.enabled) return;
    setState(() {
      _zoom = (_zoom + delta).clamp(.96, 1.38).toDouble();
    });
  }

  void _reset() {
    if (!widget.enabled) return;
    setState(() {
      _yawDeg = 0.0;
      _tiltRad = -.34;
      _zoom = .96;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final yaw = _yawDeg * math.pi / 180.0;
    final transform = Matrix4.identity()
      ..setEntry(3, 2, .00135)
      ..rotateX(_tiltRad.clamp(-.70, -.10).toDouble())
      ..rotateZ(yaw)
      ..scale(_zoom.clamp(.96, 1.38).toDouble());

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFDDE7E1), Color(0xFFF6F8F7)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          IgnorePointer(
            child: Transform.translate(
              offset: const Offset(0, 8),
              child: Transform(
                alignment: Alignment.center,
                transform: transform,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF284B38),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.20),
                        blurRadius: 18,
                        spreadRadius: -6,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -5),
            child: Transform(
              alignment: Alignment.center,
              transform: transform,
              transformHitTests: true,
              child: RepaintBoundary(child: widget.child),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: _PersonalLiveCameraControl(
              onOrbitDelta: _orbit,
              onZoomIn: () => _zoomBy(.08),
              onZoomOut: () => _zoomBy(-.08),
              onReset: _reset,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalLiveCameraControl extends StatelessWidget {
  const _PersonalLiveCameraControl({
    required this.onOrbitDelta,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final ValueChanged<Offset> onOrbitDelta;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PersonalLiveCameraButton(
              icon: Icons.add_rounded,
              onTap: onZoomIn,
            ),
            const SizedBox(height: 5),
            _PersonalLiveCameraButton(
              icon: Icons.remove_rounded,
              onTap: onZoomOut,
            ),
            const SizedBox(height: 5),
            _PersonalLiveCameraButton(
              icon: Icons.center_focus_strong_rounded,
              onTap: onReset,
              compact: true,
            ),
          ],
        ),
        const SizedBox(width: 7),
        _PersonalLiveOrbitPad(
          onOrbitDelta: onOrbitDelta,
          onReset: onReset,
        ),
      ],
    );
  }
}

class _PersonalLiveCameraButton extends StatelessWidget {
  const _PersonalLiveCameraButton({
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final side = compact ? 27.0 : 31.0;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.94),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE9ECEA), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.09),
              blurRadius: 8,
              spreadRadius: -3,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: compact ? 13 : 16,
          color: const Color(0xFF0B0F14),
        ),
      ),
    );
  }
}

class _PersonalLiveOrbitPad extends StatefulWidget {
  const _PersonalLiveOrbitPad({
    required this.onOrbitDelta,
    required this.onReset,
  });

  final ValueChanged<Offset> onOrbitDelta;
  final VoidCallback onReset;

  @override
  State<_PersonalLiveOrbitPad> createState() => _PersonalLiveOrbitPadState();
}

class _PersonalLiveOrbitPadState extends State<_PersonalLiveOrbitPad> {
  Offset _thumb = Offset.zero;

  void _updateThumb(Offset local) {
    const size = 78.0;
    const center = Offset(size / 2, size / 2);
    var delta = local - center;
    const maxRadius = 20.0;
    if (delta.distance > maxRadius) {
      delta = Offset.fromDirection(delta.direction, maxRadius);
    }
    setState(() => _thumb = delta);
  }

  @override
  Widget build(BuildContext context) {
    const size = 78.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.onReset,
      onPanStart: (details) => _updateThumb(details.localPosition),
      onPanUpdate: (details) {
        _updateThumb(details.localPosition);
        widget.onOrbitDelta(details.delta);
      },
      onPanEnd: (_) => setState(() => _thumb = Offset.zero),
      onPanCancel: () => setState(() => _thumb = Offset.zero),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.94),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE9ECEA), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.12),
              blurRadius: 12,
              spreadRadius: -4,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              top: 6,
              child: Icon(Icons.keyboard_arrow_up_rounded,
                  size: 17, color: Color(0xFF5F6670)),
            ),
            const Positioned(
              bottom: 6,
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 17, color: Color(0xFF5F6670)),
            ),
            const Positioned(
              left: 6,
              child: Icon(Icons.keyboard_arrow_left_rounded,
                  size: 17, color: Color(0xFF5F6670)),
            ),
            const Positioned(
              right: 6,
              child: Icon(Icons.keyboard_arrow_right_rounded,
                  size: 17, color: Color(0xFF5F6670)),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 70),
              transform: Matrix4.translationValues(_thumb.dx, _thumb.dy, 0),
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF00A750),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A750).withOpacity(.24),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.open_with_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalLiveSpeedChartPainter extends CustomPainter {
  const _PersonalLiveSpeedChartPainter({
    required this.samples,
    required this.maxSpeedKmh,
  });

  final List<double> samples;
  final double maxSpeedKmh;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.drawRRect(bg, Paint()..color = Colors.white);

    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0xFFE9ECEA).withOpacity(.65)
          ..strokeWidth = 1,
      );
    }

    if (samples.length < 2) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Ждём GPS скорость',
          style: TextStyle(
            color: Color(0xFF8A9099),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
      );
      return;
    }

    final observed = samples.fold<double>(0, math.max);
    final maxV = math.max(12.0, math.max(maxSpeedKmh, observed) * 1.18)
        .clamp(12.0, 38.0)
        .toDouble();
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = i / (samples.length - 1) * size.width;
      final y = size.height -
          8 -
          (samples[i] / maxV).clamp(0.0, 1.0) * (size.height - 16);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00A750).withOpacity(.10)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00A750)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PersonalLiveSpeedChartPainter oldDelegate) =>
      oldDelegate.samples != samples || oldDelegate.maxSpeedKmh != maxSpeedKmh;
}

class _GpsPoint {
  const _GpsPoint({
    required this.lat,
    required this.lon,
    this.speedKmh = 0,
    this.elapsedSec = 0,
    this.timeMs = 0,
    this.distanceDeltaM = 0,
  });

  final double lat;
  final double lon;
  final double speedKmh;
  final double elapsedSec;
  final int timeMs;
  final double distanceDeltaM;
}


class _GpsMomentMarker {
  const _GpsMomentMarker({
    required this.lat,
    required this.lon,
    required this.color,
    required this.label,
  });

  final double lat;
  final double lon;
  final Color color;
  final String label;
}

class _PersonalGpsMap extends StatelessWidget {
  const _PersonalGpsMap({
    required this.points,
    required this.runningMode,
    this.showWaitingState = false,
    this.moment,
  });

  final List<_GpsPoint> points;
  final bool runningMode;
  final bool showWaitingState;
  final _GpsMomentMarker? moment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _PersonalGpsMapPainter(
              points,
              runningMode: runningMode,
              moment: moment,
            ),
            size: Size.infinite,
          ),
          if (showWaitingState && points.isEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.94),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.10),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Color(0xFF12B85A),
                        ),
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Определяем старт маршрута',
                        style: TextStyle(
                          color: Color(0xFF171B18),
                          fontWeight: FontWeight.w700,
                          fontSize: AppTypography.menuGroupSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PersonalGpsMapPainter extends CustomPainter {
  const _PersonalGpsMapPainter(
    this.points, {
    required this.runningMode,
    this.moment,
  });

  final List<_GpsPoint> points;
  final bool runningMode;
  final _GpsMomentMarker? moment;

  @override
  void paint(Canvas canvas, Size size) {
    final area = (Offset.zero & size).deflate(8);
    final surface = runningMode ? area : _fitPitch(area);
    if (runningMode) {
      _drawRunningMap(canvas, surface);
    } else {
      _drawAnalyticsPitch(canvas, surface);
    }

    if (points.isEmpty) return;

    final positions = runningMode
        ? _runningPositions(surface.deflate(18))
        : _fieldPositions(surface.deflate(14));

    if (positions.length >= 2) {
      final shadow = Paint()
        ..color = runningMode
            ? const Color(0xFF087846).withOpacity(.18)
            : Colors.black.withOpacity(.12)
        ..strokeWidth = runningMode ? 7 : 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (var i = 1; i < positions.length; i++) {
        canvas.drawLine(positions[i - 1], positions[i], shadow);
      }

      for (var i = 1; i < positions.length; i++) {
        final speed = points[i].speedKmh;
        final color = runningMode
            ? (speed >= 18
                ? const Color(0xFFF97316)
                : speed >= 7
                    ? const Color(0xFF12B85A)
                    : const Color(0xFF4F8FCC))
            : Colors.white.withOpacity(.95);
        canvas.drawLine(
          positions[i - 1],
          positions[i],
          Paint()
            ..color = color
            ..strokeWidth = runningMode ? 3.8 : 2.4
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }

    final start = positions.first;
    canvas.drawCircle(start, 6, Paint()..color = Colors.white);
    canvas.drawCircle(start, 3.5, Paint()..color = const Color(0xFF087846));

    final current = positions.last;
    canvas.drawCircle(
      current,
      runningMode ? 13 : 10,
      Paint()..color = const Color(0xFF12B85A).withOpacity(.18),
    );
    canvas.drawCircle(current, 7.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      current,
      5,
      Paint()..color = runningMode
          ? const Color(0xFF12B85A)
          : const Color(0xFFFFD84D),
    );

    final selectedMoment = moment;
    if (selectedMoment != null && positions.isNotEmpty) {
      var bestIndex = 0;
      var bestDistance = double.infinity;
      for (var i = 0; i < points.length; i++) {
        final dx = points[i].lat - selectedMoment.lat;
        final dy = points[i].lon - selectedMoment.lon;
        final distance = dx * dx + dy * dy;
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = i;
        }
      }
      final selectedPosition = positions[bestIndex.clamp(0, positions.length - 1)];
      canvas.drawCircle(
        selectedPosition,
        15,
        Paint()..color = selectedMoment.color.withOpacity(.18),
      );
      canvas.drawCircle(
        selectedPosition,
        9,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        selectedPosition,
        6,
        Paint()..color = selectedMoment.color,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: selectedMoment.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.min(170.0, size.width * .55));
      final bubbleWidth = textPainter.width + 14;
      final bubbleHeight = textPainter.height + 9;
      var left = selectedPosition.dx - bubbleWidth / 2;
      left = left.clamp(6.0, math.max(6.0, size.width - bubbleWidth - 6));
      var top = selectedPosition.dy - bubbleHeight - 18;
      if (top < 6) top = selectedPosition.dy + 18;
      final bubble = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, bubbleWidth, bubbleHeight),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        bubble,
        Paint()..color = selectedMoment.color.withOpacity(.94),
      );
      textPainter.paint(
        canvas,
        Offset(left + 7, top + (bubbleHeight - textPainter.height) / 2),
      );
    }
  }

  List<Offset> _fieldPositions(Rect routeArea) {
    var minLat = points.first.lat;
    var maxLat = points.first.lat;
    var minLon = points.first.lon;
    var maxLon = points.first.lon;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLon = math.min(minLon, p.lon);
      maxLon = math.max(maxLon, p.lon);
    }
    final latSpan = math.max(0.000001, maxLat - minLat);
    final lonSpan = math.max(0.000001, maxLon - minLon);
    return points
        .map(
          (p) => Offset(
            routeArea.left + ((p.lon - minLon) / lonSpan) * routeArea.width,
            routeArea.bottom - ((p.lat - minLat) / latSpan) * routeArea.height,
          ),
        )
        .toList(growable: false);
  }

  List<Offset> _runningPositions(Rect routeArea) {
    final meanLat =
        points.fold<double>(0, (sum, p) => sum + p.lat) /
            math.max(1, points.length);
    final lonScale = 111320.0 *
        math.cos(meanLat * math.pi / 180).abs().clamp(.2, 1.0).toDouble();
    const latScale = 111320.0;
    final origin = points.first;
    final projected = points
        .map(
          (p) => Offset(
            (p.lon - origin.lon) * lonScale,
            (p.lat - origin.lat) * latScale,
          ),
        )
        .toList(growable: false);

    var minX = projected.first.dx;
    var maxX = projected.first.dx;
    var minY = projected.first.dy;
    var maxY = projected.first.dy;
    for (final p in projected) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final spanX = math.max(55.0, maxX - minX);
    final spanY = math.max(55.0, maxY - minY);
    final scale = math.min(
      routeArea.width / spanX,
      routeArea.height / spanY,
    );
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    return projected
        .map(
          (p) => Offset(
            routeArea.center.dx + (p.dx - centerX) * scale,
            routeArea.center.dy - (p.dy - centerY) * scale,
          ),
        )
        .toList(growable: false);
  }

  void _drawRunningMap(Canvas canvas, Rect area) {
    final rounded = RRect.fromRectAndRadius(area, const Radius.circular(13));
    canvas.drawRRect(
      rounded,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE9F7EF), Color(0xFFDDF1E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(area),
    );
    canvas.save();
    canvas.clipRRect(rounded);

    final grid = Paint()
      ..color = const Color(0xFF78B996).withOpacity(.16)
      ..strokeWidth = 1;
    for (var x = area.left; x <= area.right; x += 34) {
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), grid);
    }
    for (var y = area.top; y <= area.bottom; y += 34) {
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
    }

    final edge = Paint()
      ..color = const Color(0xFFB7DDC8).withOpacity(.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    final road = Paint()
      ..color = Colors.white.withOpacity(.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final roadA = Path()
      ..moveTo(area.left - 10, area.bottom - area.height * .12)
      ..cubicTo(
        area.left + area.width * .25,
        area.top + area.height * .72,
        area.left + area.width * .62,
        area.top + area.height * .28,
        area.right + 10,
        area.top + area.height * .18,
      );
    canvas.drawPath(roadA, edge);
    canvas.drawPath(roadA, road);

    final roadB = Path()
      ..moveTo(area.left + area.width * .16, area.top - 10)
      ..cubicTo(
        area.left + area.width * .27,
        area.top + area.height * .32,
        area.left + area.width * .72,
        area.top + area.height * .62,
        area.right - area.width * .08,
        area.bottom + 10,
      );
    canvas.drawPath(roadB, edge);
    canvas.drawPath(roadB, road);
    canvas.restore();
  }

  Rect _fitPitch(Rect area) {
    const aspectRatio = 105 / 68;
    var width = area.width;
    var height = width / aspectRatio;
    if (height > area.height) {
      height = area.height;
      width = height * aspectRatio;
    }
    return Rect.fromCenter(
      center: area.center,
      width: width,
      height: height,
    );
  }

  void _drawAnalyticsPitch(Canvas canvas, Rect pitch) {
    final roundedPitch = RRect.fromRectAndRadius(
      pitch,
      const Radius.circular(12),
    );
    canvas.drawRRect(
      roundedPitch,
      Paint()..color = const Color(0xFF78977F),
    );

    canvas.save();
    canvas.clipRRect(roundedPitch);
    const stripeCount = 12;
    for (var i = 0; i < stripeCount; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          pitch.left + pitch.width * i / stripeCount,
          pitch.top,
          pitch.width / stripeCount,
          pitch.height,
        ),
        Paint()
          ..color = i.isEven
              ? Colors.white.withOpacity(.055)
              : Colors.black.withOpacity(.045),
      );
    }
    canvas.restore();

    final inner = pitch.deflate(math.max(8.0, pitch.width * .016));
    final line = Paint()
      ..color = Colors.white.withOpacity(.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.15, pitch.width * .0024);

    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(8)),
      line,
    );
    canvas.drawLine(
      Offset(inner.center.dx, inner.top),
      Offset(inner.center.dx, inner.bottom),
      line,
    );
    canvas.drawCircle(
      inner.center,
      inner.height * .125,
      line,
    );

    final penaltyWidth = inner.width * .175;
    final penaltyHeight = inner.height * .46;
    final goalWidth = inner.width * .078;
    final goalHeight = inner.height * .23;

    canvas.drawRect(
      Rect.fromLTWH(
        inner.left,
        inner.center.dy - penaltyHeight / 2,
        penaltyWidth,
        penaltyHeight,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        inner.right - penaltyWidth,
        inner.center.dy - penaltyHeight / 2,
        penaltyWidth,
        penaltyHeight,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        inner.left,
        inner.center.dy - goalHeight / 2,
        goalWidth,
        goalHeight,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        inner.right - goalWidth,
        inner.center.dy - goalHeight / 2,
        goalWidth,
        goalHeight,
      ),
      line,
    );

    final spotPaint = Paint()..color = Colors.white.withOpacity(.82);
    canvas.drawCircle(
      Offset(inner.left + inner.width * .115, inner.center.dy),
      math.max(1.8, inner.width * .0045),
      spotPaint,
    );
    canvas.drawCircle(
      Offset(inner.right - inner.width * .115, inner.center.dy),
      math.max(1.8, inner.width * .0045),
      spotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PersonalGpsMapPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.runningMode != runningMode ||
      oldDelegate.moment != moment;
}

class _LoadPoint {
  const _LoadPoint({required this.sec, required this.value});
  final double sec;
  final double value;
}

class _HrPoint {
  const _HrPoint({required this.sec, required this.bpm});
  final double sec;
  final double bpm;
}

class _HrChart extends StatefulWidget {
  const _HrChart({required this.values, required this.compact, this.loadPoints = const <_LoadPoint>[]});
  final List<_HrPoint> values;
  final bool compact;
  final List<_LoadPoint> loadPoints;
  @override
  State<_HrChart> createState() => _HrChartState();
}

class _HrChartState extends State<_HrChart> {
  int? selected;
  bool followLive = true;
  double windowSec = 180;
  double? viewEndSec;
  Offset _panDistance = Offset.zero;
  bool _horizontalPan = false;

  double get _maxSec => widget.values.isEmpty ? 1 : math.max(1.0, widget.values.last.sec);
  double get _endSec => followLive ? _maxSec : (viewEndSec ?? _maxSec).clamp(windowSec, _maxSec).toDouble();
  double get _startSec => math.max(0, _endSec - windowSec);

  void _shift(double seconds) {
    setState(() {
      followLive = false;
      viewEndSec = (_endSec + seconds).clamp(windowSec, _maxSec).toDouble();
    });
  }

  void _select(Offset p, Size size) {
    if (widget.values.isEmpty || size.width <= 0) return;
    final target = _startSec + (p.dx.clamp(0.0, size.width) / size.width) * math.max(1.0, _endSec - _startSec);
    var best = 0;
    var delta = double.infinity;
    for (var i=0;i<widget.values.length;i++) { final d=(widget.values[i].sec-target).abs(); if(d<delta){delta=d;best=i;} }
    setState(() => selected = best);
  }

  @override
  Widget build(BuildContext context) {
    final chart = LayoutBuilder(builder: (_, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _select(d.localPosition, size),
        onPanStart: (_) {
          _panDistance = Offset.zero;
          _horizontalPan = false;
        },
        onPanUpdate: (d) {
          _panDistance += d.delta;
          // Не выключаем прямой эфир при обычной вертикальной прокрутке страницы.
          // Режим истории включается только после явного горизонтального свайпа.
          if (!_horizontalPan &&
              _panDistance.dx.abs() > 10 &&
              _panDistance.dx.abs() > _panDistance.dy.abs() * 1.25) {
            _horizontalPan = true;
            if (widget.values.length > 1) {
              setState(() => followLive = false);
            }
          }
          if (_horizontalPan) {
            _shift(-d.delta.dx / math.max(1.0, size.width) * windowSec);
          }
        },
        onPanEnd: (_) {
          _panDistance = Offset.zero;
          _horizontalPan = false;
        },
        onPanCancel: () {
          _panDistance = Offset.zero;
          _horizontalPan = false;
        },
        child: CustomPaint(
          painter: _HrChartPainter(widget.values, detailed: !widget.compact, selected: selected, minSec: widget.compact ? 0 : _startSec, maxSec: widget.compact ? _maxSec : _endSec, loadPoints: widget.loadPoints),
          size: Size.infinite,
        ),
      );
    });
    if (widget.compact) {
      final historyAvailable = _maxSec > windowSec + 5;
      final progress = !historyAvailable
          ? 1.0
          : ((_endSec - windowSec) / math.max(1.0, _maxSec - windowSec))
              .clamp(0.0, 1.0)
              .toDouble();
      return Column(
        children: [
          Expanded(child: chart),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (_, c) {
              final thumbWidth = historyAvailable
                  ? math.max(34.0, c.maxWidth * .24)
                  : c.maxWidth;
              final left = (c.maxWidth - thumbWidth) * progress;
              return SizedBox(
                height: 7,
                child: Stack(
                  children: [
                    Positioned.fill(
                      top: 2.5,
                      bottom: 2.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE1E1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Positioned(
                      left: left,
                      top: 0,
                      width: thumbWidth,
                      height: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: historyAvailable
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFFCA5A5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(
                Icons.swipe_rounded,
                size: 13,
                color: Color(0xFF98A2B3),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  historyAvailable
                      ? 'Листайте график влево и вправо'
                      : 'История пульса накапливается',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: AppTypography.badgeSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  minimumSize: const Size(0, 26),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: followLive
                    ? null
                    : () => setState(() {
                          followLive = true;
                          viewEndSec = null;
                        }),
                icon: Icon(
                  Icons.radio_button_checked_rounded,
                  size: 13,
                  color: followLive
                      ? const Color(0xFF12B85A)
                      : const Color(0xFFDC2626),
                ),
                label: Text(
                  followLive ? 'Прямой эфир' : 'Продолжить эфир',
                  style: TextStyle(
                    color: followLive
                        ? const Color(0xFF12B85A)
                        : const Color(0xFFDC2626),
                    fontWeight: FontWeight.w900,
                    fontSize: AppTypography.badgeSize,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Column(children: [
      Expanded(child: chart),
      const SizedBox(height: 4),
      Row(children: [
        IconButton(onPressed: () => _shift(-windowSec * .65), icon: const Icon(Icons.chevron_left_rounded, size: 19), tooltip: 'Раньше'),
        Expanded(child: Text('Интервал ${(_startSec/60).floor()}–${(_endSec/60).ceil()} мин', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF98A2B3), fontSize: AppTypography.menuGroupSize, fontWeight: FontWeight.w700))),
        IconButton(onPressed: () => _shift(windowSec * .65), icon: const Icon(Icons.chevron_right_rounded, size: 19), tooltip: 'Позже'),
        TextButton.icon(
          onPressed: () => setState(() { followLive = true; viewEndSec = null; }),
          icon: Icon(Icons.radio_button_checked_rounded, size: 15, color: followLive ? const Color(0xFF12B85A) : const Color(0xFF98A2B3)),
          label: Text(followLive ? 'В прямом эфире' : 'Продолжить прямой эфир'),
        ),
      ]),
    ]);
  }
}

class _HrChartPainter extends CustomPainter {
  const _HrChartPainter(this.values, {this.detailed = false, this.selected, this.minSec = 0, this.maxSec, this.loadPoints = const <_LoadPoint>[]});
  final List<_HrPoint> values;
  final bool detailed;
  final int? selected;
  final double minSec;
  final double? maxSec;
  final List<_LoadPoint> loadPoints;
  @override
  void paint(Canvas canvas, Size size) {
    final labelHeight = 15.0;
    final chartHeight = math.max(24.0, size.height - labelHeight);
    final grid = Paint()
      ..color = const Color(0xFFFFE4E4)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Нет данных Polar',
          style: TextStyle(
            color: Color(0xFF98A2B3),
            fontSize: 11.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, (chartHeight - tp.height) / 2),
      );
      return;
    }

    final endSec = maxSec ?? values.last.sec;
    final visible =
        values.where((p) => p.sec >= minSec && p.sec <= endSec).toList();
    final plotValues = visible.isEmpty ? values : visible;
    final rangeSec = math.max(1.0, endSec - minSec);

    void drawTimeLabels() {
      for (var i = 0; i <= 4; i++) {
        final sec = minSec + rangeSec * i / 4;
        final totalSeconds = sec.round();
        final minutes = totalSeconds ~/ 60;
        final seconds = totalSeconds % 60;
        final label = seconds == 0
            ? '$minutes мин'
            : '$minutes:${seconds.toString().padLeft(2, '0')}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Color(0xFF98A2B3),
              fontSize: 8.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            (size.width * i / 4 - tp.width / 2)
                .clamp(0.0, size.width - tp.width),
            chartHeight + 2,
          ),
        );
      }
    }

    if (plotValues.length == 1) {
      final p = plotValues.first;
      final y = chartHeight * .5;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0xFFDC2626).withOpacity(.35)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        Offset(size.width * .5, y),
        5,
        Paint()..color = const Color(0xFFDC2626),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${p.bpm.round()} bpm',
          style: const TextStyle(
            color: Color(0xFFDC2626),
            fontSize: 11.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, math.max(0, y - 22)),
      );
      drawTimeLabels();
      return;
    }

    final minPoint =
        plotValues.reduce((a, b) => a.bpm <= b.bpm ? a : b);
    final maxPoint =
        plotValues.reduce((a, b) => a.bpm >= b.bpm ? a : b);
    final minV = math.max(40.0, minPoint.bpm - 10);
    final maxV = math.min(220.0, maxPoint.bpm + 10);
    final span = math.max(1.0, maxV - minV);

    Offset pos(_HrPoint p) => Offset(
          size.width *
              ((p.sec - minSec) / rangeSec).clamp(0.0, 1.0),
          chartHeight -
              ((p.bpm - minV) / span).clamp(0.0, 1.0) * chartHeight,
        );

    final path = Path();
    final first = pos(plotValues.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < plotValues.length; i++) {
      final previous = pos(plotValues[i - 1]);
      final current = pos(plotValues[i]);
      final mid = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(previous.dx, previous.dy, mid.dx, mid.dy);
      if (i == plotValues.length - 1) {
        path.quadraticBezierTo(
          current.dx,
          current.dy,
          current.dx,
          current.dy,
        );
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFDC2626)
        ..strokeWidth = detailed ? 2.4 : 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    void marker(_HrPoint p, Color color, String text) {
      final o = pos(p);
      canvas.drawCircle(o, detailed ? 4 : 3, Paint()..color = color);
      if (detailed) {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: 10.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            (o.dx - tp.width / 2).clamp(0.0, size.width - tp.width),
            (o.dy - 18).clamp(0.0, chartHeight - tp.height),
          ),
        );
      }
    }

    marker(
      minPoint,
      const Color(0xFF2563EB),
      'мин ${minPoint.bpm.round()} · ${(minPoint.sec / 60).floor()} мин',
    );
    marker(
      maxPoint,
      const Color(0xFFDC2626),
      'макс ${maxPoint.bpm.round()} · ${(maxPoint.sec / 60).floor()} мин',
    );

    if (detailed && loadPoints.isNotEmpty) {
      final loadPaint = Paint()..color = const Color(0xFF12B85A);
      for (final lp
          in loadPoints.where((p) => p.sec >= minSec && p.sec <= endSec)) {
        final x = size.width *
            ((lp.sec - minSec) / rangeSec).clamp(0.0, 1.0);
        canvas.drawCircle(Offset(x, chartHeight - 8), 3.2, loadPaint);
      }
    }

    if (selected != null &&
        selected! >= 0 &&
        selected! < values.length) {
      final point = values[selected!];
      final o = pos(point);
      canvas.drawLine(
        Offset(o.dx, 0),
        Offset(o.dx, chartHeight),
        Paint()
          ..color = const Color(0xFF66716A)
          ..strokeWidth = 1,
      );
      marker(
        point,
        const Color(0xFF171B18),
        '${point.bpm.round()} · ${(point.sec / 60).floor()}:${((point.sec % 60).round()).toString().padLeft(2, '0')}',
      );
    }
    drawTimeLabels();
  }
  @override
  bool shouldRepaint(covariant _HrChartPainter oldDelegate)=>oldDelegate.values!=values||oldDelegate.detailed!=detailed||oldDelegate.selected!=selected||oldDelegate.minSec!=minSec||oldDelegate.maxSec!=maxSec||oldDelegate.loadPoints!=loadPoints;
}

class PlayerTrainingOnlineBadge extends StatefulWidget {
  const PlayerTrainingOnlineBadge({
    super.key,
    required this.teamId,
    this.compact = true,
    this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker',
  });

  final int teamId;
  final bool compact;
  final String apiBaseUrl;

  @override
  State<PlayerTrainingOnlineBadge> createState() => _PlayerTrainingOnlineBadgeState();
}

class _PlayerTrainingOnlineBadgeState extends State<PlayerTrainingOnlineBadge> {
  Timer? _timer;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void didUpdateWidget(covariant PlayerTrainingOnlineBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId || oldWidget.apiBaseUrl != widget.apiBaseUrl) {
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.teamId <= 0) return;
    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/player_get_live_state.php').replace(
        queryParameters: <String, String>{
          'team_id': '${widget.teamId}',
          'personal_session': '1',
          'active_only': '1',
          'limit': '50',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final text = response.body.trim();
      final start = text.indexOf('{');
      final decoded = jsonDecode(start >= 0 ? text.substring(start) : text);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      final raw = data['sessions'] as List? ?? data['items'] as List? ?? const [];
      final count = raw.whereType<Map>().where((item) {
        final row = Map<String, dynamic>.from(item);
        final status = '${row['status'] ?? row['state'] ?? row['live_status'] ?? 'active'}'.toLowerCase();
        return !status.contains('finish') &&
            !status.contains('stop') &&
            !status.contains('closed') &&
            !status.contains('cancel');
      }).length;
      if (mounted && count != _count) setState(() => _count = count);
    } catch (_) {
      // Бейдж не должен ломать навигацию при временной ошибке сети.
    }
  }


  @override
  Widget build(BuildContext context) {
    final active = _count > 0;
    final size = widget.compact ? 20.0 : 24.0;
    return Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 5 : 7, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF12B85A) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? const Color(0xFF12B85A) : const Color(0xFFE4E7EC)),
      ),
      alignment: Alignment.center,
      child: Text(
        '$_count',
        style: TextStyle(
          color: active ? Colors.white : const Color(0xFF66716A),
          fontSize: widget.compact ? 9 : 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
