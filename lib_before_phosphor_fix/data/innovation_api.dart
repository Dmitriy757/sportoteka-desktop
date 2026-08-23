import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:sportoteka/core/utils/pref_utils.dart';

class InnovationApi {
  InnovationApi._();
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://sportotekaapp.ru/api/',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Connection':'keep-alive'},
  ));

static Future<String> _uid() async {
  final v = await PrefUtils.getUserId();
  if (v == null) return 'guest';
  return v.toString(); // гарантируем String
}

  // 1) AI session
  static Future<int> saveAiSession({
    required DateTime startedAt,
    required Duration duration,
    required int reps,
    required List<Map<String, dynamic>> samples,
  }) async {
    final res = await _dio.post('ai/save_session.php', data: {
      'user_id': await _uid(),
      'started_at': startedAt.toIso8601String(),
      'duration_sec': duration.inSeconds,
      'reps': reps,
      'samples': samples,
    });
    _assertOk(res);
    return int.parse(res.data['id'].toString());
  }

  // 2) AR overlay (multipart)
  static Future<int> saveArOverlay({
    required String overlayPath,
    String? compositePath,
    String? notes,
  }) async {
    final form = FormData.fromMap({
      'user_id': await _uid(),
      if (notes != null) 'notes': notes,
      'overlay': await MultipartFile.fromFile(overlayPath, filename: p.basename(overlayPath)),
      if (compositePath != null)
        'composite': await MultipartFile.fromFile(compositePath, filename: p.basename(compositePath)),
    });
    final res = await _dio.post('ar/save_overlay.php', data: form);
    _assertOk(res);
    return int.parse(res.data['id'].toString());
  }

  // 3) Training plan
  static Future<int> saveTrainingPlan({
    required String goal,
    required int sessionsPerWeek,
    required int weeks,
    required bool hasGym,
    required bool hasField,
    required String planText,
  }) async {
    final res = await _dio.post('training/save_plan.php', data: {
      'user_id': await _uid(),
      'goal': goal,
      'sessions_per_week': sessionsPerWeek,
      'weeks': weeks,
      'has_gym': hasGym,
      'has_field': hasField,
      'plan_text': planText,
    });
    _assertOk(res);
    return int.parse(res.data['id'].toString());
  }

  // 4) Quests day
  static Future<void> upsertQuestDay({
    required String dateKey, // YYYY-MM-DD
    required bool completed,
    required Map<String, bool> tasks,
  }) async {
    final res = await _dio.post('quests/upsert_day.php', data: {
      'user_id': await _uid(),
      'date_key': dateKey,
      'completed': completed,
      'tasks': tasks,
    });
    _assertOk(res);
  }

  // 5) Heatmap session
  static Future<int> saveHeatmapSession({
    required DateTime startedAt,
    required Duration duration,
    required double distanceKm,
    required String pace,
    String? gpx, // можно передавать длинной строкой
    Map<String, dynamic>? zones,
  }) async {
    final res = await _dio.post('heatmap/save_session.php', data: {
      'user_id': await _uid(),
      'started_at': startedAt.toIso8601String(),
      'duration_sec': duration.inSeconds,
      'distance_km': distanceKm,
      'pace': pace,
      'gpx': gpx,
      'zones': zones ?? {},
    });
    _assertOk(res);
    return int.parse(res.data['id'].toString());
  }

  static void _assertOk(Response res) {
    if (res.statusCode != 200 || res.data is! Map || res.data['status'] != 'success') {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        error: 'Bad API response: ${res.data}',
        type: DioExceptionType.badResponse,
      );
    }
  }
  
  
  // ===== Lists & Details =====

static Future<Map<String, dynamic>> _get(String path, Map<String, dynamic> q) async {
  final res = await _dio.get(path, queryParameters: q);
  _assertOk(res);
  return Map<String, dynamic>.from(res.data);
}

// AI
static Future<Map<String, dynamic>> listAiSessions({required String userId, int page=1, int pageSize=20}) async {
  final r = await _get('ai/list_sessions.php', {'user_id': userId, 'page': page, 'page_size': pageSize});
  return r; // contains items, page, total, has_more...
}
static Future<Map<String, dynamic>> getAiSession(int id) async {
  final r = await _get('ai/get_session.php', {'id': id});
  return r['item'] ?? {};
}

// AR
static Future<Map<String, dynamic>> listArOverlays({required String userId, int page=1, int pageSize=20}) async {
  return await _get('ar/list_overlays.php', {'user_id': userId, 'page': page, 'page_size': pageSize});
}
static Future<Map<String, dynamic>> getArOverlay(int id) async {
  final r = await _get('ar/get_overlay.php', {'id': id});
  return r['item'] ?? {};
}

// Training
static Future<Map<String, dynamic>> listTrainingPlans({required String userId, int page=1, int pageSize=20}) async {
  return await _get('training/list_plans.php', {'user_id': userId, 'page': page, 'page_size': pageSize});
}
static Future<Map<String, dynamic>> getTrainingPlan(int id) async {
  final r = await _get('training/get_plan.php', {'id': id});
  return r['item'] ?? {};
}

// Quests
static Future<Map<String, dynamic>?> getQuestDay({required String userId, required String dateKey}) async {
  final r = await _get('quests/get_day.php', {'user_id': userId, 'date_key': dateKey});
  return r['item']; // may be null
}

// Heatmap
static Future<Map<String, dynamic>> listHeatmapSessions({required String userId, int page=1, int pageSize=20}) async {
  return await _get('heatmap/list_sessions.php', {'user_id': userId, 'page': page, 'page_size': pageSize});
}
static Future<Map<String, dynamic>> getHeatmapSession(int id) async {
  final r = await _get('heatmap/get_session.php', {'id': id});
  return r['item'] ?? {};
}

  
}
