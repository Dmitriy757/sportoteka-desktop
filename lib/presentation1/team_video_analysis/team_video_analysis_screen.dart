import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_video_analysis/video_match_review_screen.dart';

enum TeamVideoCatalogView { list, grid }

class TeamVideoUploadDraft {
  final String uploadId;
  final String videoPath;
  final String? thumbnailPath;
  final int matchId;
  final int teamId;
  final int coachId;
  final String notes;
  final String fileName;
  final int fileSize;
  final int totalChunks;
  final int lastUploadedChunk;

  const TeamVideoUploadDraft({
    required this.uploadId,
    required this.videoPath,
    required this.thumbnailPath,
    required this.matchId,
    required this.teamId,
    required this.coachId,
    required this.notes,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
    required this.lastUploadedChunk,
  });

  Map<String, dynamic> toJson() => {
        'upload_id': uploadId,
        'video_path': videoPath,
        'thumbnail_path': thumbnailPath,
        'match_id': matchId,
        'team_id': teamId,
        'coach_id': coachId,
        'notes': notes,
        'file_name': fileName,
        'file_size': fileSize,
        'total_chunks': totalChunks,
        'last_uploaded_chunk': lastUploadedChunk,
      };

  factory TeamVideoUploadDraft.fromJson(Map<String, dynamic> json) {
    return TeamVideoUploadDraft(
      uploadId: (json['upload_id'] ?? '').toString(),
      videoPath: (json['video_path'] ?? '').toString(),
      thumbnailPath: json['thumbnail_path']?.toString(),
      matchId: int.tryParse('${json['match_id']}') ?? 0,
      teamId: int.tryParse('${json['team_id']}') ?? 0,
      coachId: int.tryParse('${json['coach_id']}') ?? 0,
      notes: (json['notes'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      fileSize: int.tryParse('${json['file_size']}') ?? 0,
      totalChunks: int.tryParse('${json['total_chunks']}') ?? 0,
      lastUploadedChunk: int.tryParse('${json['last_uploaded_chunk']}') ?? -1,
    );
  }
}

class ChunkUploadService {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String uploadChunkUrl =
      "$apiBase/upload_team_match_video_chunk.php";
  static const String completeUploadUrl =
      "$apiBase/complete_team_match_video_upload.php";
  static const String uploadStatusUrl =
      "$apiBase/get_team_match_upload_status.php";
  static const String cancelUploadUrl =
      "$apiBase/cancel_team_match_video_upload.php";

  static const String _draftKey = 'team_video_upload_draft_v1';

  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
      responseType: ResponseType.plain,
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  Future<Map<String, dynamic>> uploadVideoInChunks({
    required File videoFile,
    File? thumbnailFile,
    required int matchId,
    required int teamId,
    required int coachId,
    required String notes,
    required void Function(double progress, String text) onProgress,
    String? resumeUploadId,
  }) async {
    if (!await videoFile.exists()) {
      return {
        "success": false,
        "message": "Видео файл не найден",
      };
    }

    final fileLength = await videoFile.length();
    final fileName = videoFile.uri.pathSegments.last;
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'mp4';

    const int chunkSize = 1 * 1024 * 1024;
    final int totalChunks = (fileLength / chunkSize).ceil();

    final uploadId = resumeUploadId ??
        _buildUploadId(
          matchId: matchId,
          teamId: teamId,
          coachId: coachId,
          fileName: fileName,
          fileLength: fileLength,
        );

    final existingDraft = await loadDraft();
    if (existingDraft == null || existingDraft.uploadId != uploadId) {
      await _saveDraft(
        TeamVideoUploadDraft(
          uploadId: uploadId,
          videoPath: videoFile.path,
          thumbnailPath: thumbnailFile?.path,
          matchId: matchId,
          teamId: teamId,
          coachId: coachId,
          notes: notes,
          fileName: fileName,
          fileSize: fileLength,
          totalChunks: totalChunks,
          lastUploadedChunk: -1,
        ),
      );
    }

    final uploadedChunks = await fetchUploadedChunks(uploadId);
    final raf = videoFile.openSync(mode: FileMode.read);

    try {
      for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
        if (uploadedChunks.contains(chunkIndex)) {
          final progress = (chunkIndex + 1) / totalChunks;
          onProgress(
            progress.clamp(0.0, 0.97),
            "Пропуск чанка ${chunkIndex + 1}/$totalChunks",
          );
          await _updateDraftLastChunk(chunkIndex);
          continue;
        }

        final int start = chunkIndex * chunkSize;
        final int end = min(start + chunkSize, fileLength);
        final int currentSize = end - start;

        raf.setPositionSync(start);
        final chunkBytes = raf.readSync(currentSize);

        final formData = FormData.fromMap({
          "upload_id": uploadId,
          "match_id": matchId.toString(),
          "team_id": teamId.toString(),
          "coach_id": coachId.toString(),
          "file_name": fileName,
          "file_ext": ext,
          "file_size": fileLength.toString(),
          "chunk_index": chunkIndex.toString(),
          "total_chunks": totalChunks.toString(),
          "chunk_size": currentSize.toString(),
          "notes": notes,
          "chunk": MultipartFile.fromBytes(
            chunkBytes,
            filename: "chunk_$chunkIndex.part",
          ),
        });

        final response = await _postChunkWithRetry(formData);
        final decoded = _decodePlain(response.data);

        if (decoded["success"] != true) {
          return {
            "success": false,
            "message":
                decoded["message"] ?? "Ошибка загрузки чанка ${chunkIndex + 1}",
          };
        }

        await _updateDraftLastChunk(chunkIndex);

        final progress = (chunkIndex + 1) / totalChunks;
        onProgress(
          progress.clamp(0.0, 0.97),
          "Загружено ${chunkIndex + 1} из $totalChunks",
        );
      }
    } finally {
      raf.closeSync();
    }

    onProgress(0.98, "Сборка файла на сервере...");

    String? thumbnailBase64;
    String? thumbnailName;

    if (thumbnailFile != null && await thumbnailFile.exists()) {
      final bytes = await thumbnailFile.readAsBytes();
      thumbnailBase64 = base64Encode(bytes);
      thumbnailName = thumbnailFile.uri.pathSegments.last;
    }

    final completeResp = await dio.post(
      completeUploadUrl,
      data: FormData.fromMap({
        "upload_id": uploadId,
        "match_id": matchId.toString(),
        "team_id": teamId.toString(),
        "coach_id": coachId.toString(),
        "file_name": fileName,
        "file_ext": ext,
        "file_size": fileLength.toString(),
        "total_chunks": totalChunks.toString(),
        "notes": notes,
        if (thumbnailBase64 != null) "thumbnail_base64": thumbnailBase64,
        if (thumbnailName != null) "thumbnail_name": thumbnailName,
      }),
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    final result = _decodePlain(completeResp.data);

    if (result["success"] == true) {
      await clearDraft();
    }

    onProgress(1.0, "Загрузка завершена");
    return result;
  }

  Future<Response<dynamic>> _postChunkWithRetry(FormData formData) async {
    DioException? lastError;

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        return await dio.post(
          uploadChunkUrl,
          data: formData,
          options: Options(
            contentType: 'multipart/form-data',
          ),
        );
      } on DioException catch (e) {
        lastError = e;
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }

    throw lastError ??
        DioException(
          requestOptions: RequestOptions(path: uploadChunkUrl),
          error: "Не удалось загрузить чанк",
        );
  }

  Future<Set<int>> fetchUploadedChunks(String uploadId) async {
    try {
      final resp = await dio.post(
        uploadStatusUrl,
        data: FormData.fromMap({
          "upload_id": uploadId,
        }),
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      final decoded = _decodePlain(resp.data);
      if (decoded["success"] == true && decoded["uploaded_chunks"] is List) {
        return (decoded["uploaded_chunks"] as List)
            .map((e) => int.tryParse('$e') ?? -1)
            .where((e) => e >= 0)
            .toSet();
      }
    } catch (_) {}

    return <int>{};
  }

  Future<void> cancelUploadOnServer(String uploadId) async {
    try {
      await dio.post(
        cancelUploadUrl,
        data: FormData.fromMap({
          "upload_id": uploadId,
        }),
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
    } catch (_) {}
  }

  Future<void> _saveDraft(TeamVideoUploadDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft.toJson()));
  }

  Future<TeamVideoUploadDraft?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return TeamVideoUploadDraft.fromJson(map);
      }
      if (map is Map) {
        return TeamVideoUploadDraft.fromJson(Map<String, dynamic>.from(map));
      }
    } catch (_) {}

    return null;
  }

  Future<void> _updateDraftLastChunk(int chunkIndex) async {
    final draft = await loadDraft();
    if (draft == null) return;

    final updated = TeamVideoUploadDraft(
      uploadId: draft.uploadId,
      videoPath: draft.videoPath,
      thumbnailPath: draft.thumbnailPath,
      matchId: draft.matchId,
      teamId: draft.teamId,
      coachId: draft.coachId,
      notes: draft.notes,
      fileName: draft.fileName,
      fileSize: draft.fileSize,
      totalChunks: draft.totalChunks,
      lastUploadedChunk: chunkIndex,
    );

    await _saveDraft(updated);
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  String _buildUploadId({
    required int matchId,
    required int teamId,
    required int coachId,
    required String fileName,
    required int fileLength,
  }) {
    final raw =
        "$matchId|$teamId|$coachId|$fileName|$fileLength|resume-stable";
    return md5.convert(utf8.encode(raw)).toString();
  }

  Map<String, dynamic> _decodePlain(dynamic rawResponse) {
    try {
      final body = (rawResponse ?? "").toString().trim();
      final start = body.indexOf('{');
      if (start == -1) {
        return {
          "success": false,
          "message": "Некорректный ответ сервера",
        };
      }
      final clean = body.substring(start);
      final j = jsonDecode(clean);
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);
      return {"success": false, "message": "Пустой JSON"};
    } catch (e) {
      return {"success": false, "message": "Ошибка разбора ответа: $e"};
    }
  }
}

class TeamVideoAnalysisScreen extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;
  final bool embedded;

  const TeamVideoAnalysisScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.clubId,
    required this.clubName,
    this.embedded = false,
  });

  @override
  State<TeamVideoAnalysisScreen> createState() =>
      _TeamVideoAnalysisScreenState();
}

class _TeamVideoAnalysisScreenState extends State<TeamVideoAnalysisScreen>
    with SingleTickerProviderStateMixin {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getMatchesUrl = "$apiBase/get_team_matches.php";
  static const String getTeamProfileUrl = "$apiBase/get_team_profile.php";
  static const String deleteVideoUrl = "$apiBase/delete_team_match_video.php";
  static const String deleteMatchUrl = "$apiBase/delete_team_match.php";

  final TextEditingController _searchCtrl = TextEditingController();
  final ChunkUploadService _chunkUploadService = ChunkUploadService();

  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _filteredMatches = [];

  bool _loading = true;
  int _coachId = 0;

  late AnimationController _animationController;

  TeamVideoCatalogView _view = TeamVideoCatalogView.list;
  String _actualTeamName = "";

  String? _selectedUploadVideoPath;
  String? _selectedUploadVideoName;
  int? _selectedUploadVideoSize;

  String? _selectedUploadThumbPath;
  String? _selectedUploadThumbName;
  int? _selectedUploadThumbSize;

  String get _displayTeamName {
    bool isFakeName(String s) {
      final v = s.trim();
      if (v.isEmpty) return true;
      return RegExp(r'^Команда\s+\d+$').hasMatch(v);
    }

    final local = _actualTeamName.trim();
    if (!isFakeName(local)) return local;

    final passed = widget.teamName.trim();
    if (!isFakeName(passed)) return passed;

    return "Команда";
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();

    _init();
    _searchCtrl.addListener(_applySearch);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _coachId = await PrefUtils.getUserId() ?? 0;
    await _loadTeamProfile();
    await _loadMatches();
    await _checkPendingUpload();
  }

  Future<void> _checkPendingUpload() async {
    final draft = await _chunkUploadService.loadDraft();
    if (draft == null) return;
    if (!mounted) return;

    final videoFile = File(draft.videoPath);
    final exists = await videoFile.exists();
    if (!exists) {
      await _chunkUploadService.clearDraft();
      return;
    }

    await Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text("Незавершённая загрузка"),
        content: Text(
          "Найдена незавершённая загрузка видео.\n\n"
          "Файл: ${draft.fileName}\n"
          "Загружено чанков: ${draft.lastUploadedChunk + 1} из ${draft.totalChunks}",
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _chunkUploadService.cancelUploadOnServer(draft.uploadId);
              await _chunkUploadService.clearDraft();
              if (Get.isDialogOpen ?? false) {
                Get.back();
              }
              Get.snackbar("Удалено", "Черновик загрузки удалён");
            },
            child: const Text("Удалить"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (Get.isDialogOpen ?? false) {
                Get.back();
              }
              await _resumePendingUpload(draft);
            },
            child: const Text("Продолжить"),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _resumePendingUpload(TeamVideoUploadDraft draft) async {
    final videoFile = File(draft.videoPath);
    final thumbFile =
        (draft.thumbnailPath != null && draft.thumbnailPath!.isNotEmpty)
            ? File(draft.thumbnailPath!)
            : null;

    final progressNotifier = ValueNotifier<double>(0.0);
    final textNotifier = ValueNotifier<String>("Возобновление загрузки...");

    _showUploadingDialog(
      progressNotifier: progressNotifier,
      textNotifier: textNotifier,
    );

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final result = await _chunkUploadService.uploadVideoInChunks(
        videoFile: videoFile,
        thumbnailFile: thumbFile,
        matchId: draft.matchId,
        teamId: draft.teamId,
        coachId: draft.coachId,
        notes: draft.notes,
        resumeUploadId: draft.uploadId,
        onProgress: (progress, text) {
          progressNotifier.value = progress.clamp(0.0, 1.0);
          textNotifier.value = text;
        },
      );

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (result["success"] == true) {
        Get.snackbar("Готово", "Видео успешно догружено");
        await _loadMatches();
      } else {
        Get.snackbar(
          "Ошибка",
          _s(result["message"]).isNotEmpty
              ? _s(result["message"])
              : "Не удалось продолжить загрузку",
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      Get.snackbar("Ошибка", "Сбой при возобновлении загрузки: $e");
    } finally {
      progressNotifier.dispose();
      textNotifier.dispose();
    }
  }

  Future<void> _loadTeamProfile() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final resp = await dio.post(
        getTeamProfileUrl,
        data: {
          "team_id": widget.teamId.toString(),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final data = _decodePlain(resp.data);
      final ok = (data["success"] == true) || (data["status"] == "success");

      if (ok && data["team"] is Map) {
        final team = Map<String, dynamic>.from(data["team"]);
        final serverName = _s(team["name"]);

        if (serverName.isNotEmpty && mounted) {
          setState(() {
            _actualTeamName = serverName;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadMatches() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 25),
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final resp = await dio.post(
        getMatchesUrl,
        data: jsonEncode({
          "team_id": widget.teamId,
        }),
        options: Options(
          headers: const {
            "Content-Type": "application/json; charset=utf-8",
          },
        ),
      );

      final data = _decodePlain(resp.data);

      if (data["success"] == true && data["matches"] is List) {
        _matches = List<Map<String, dynamic>>.from(data["matches"]);
      } else {
        _matches = [];
      }
    } catch (_) {
      _matches = [];
    }

    _applySearch();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showUploadingDialog({
    required ValueNotifier<double> progressNotifier,
    required ValueNotifier<String> textNotifier,
  }) {
    return Get.dialog(
      PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: ValueListenableBuilder<double>(
            valueListenable: progressNotifier,
            builder: (_, progress, __) {
              return ValueListenableBuilder<String>(
                valueListenable: textNotifier,
                builder: (_, text, __) {
                  return SizedBox(
                    width: 320,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: FeedPalette.greenGradient,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Загрузка видео",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: FeedPalette.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Пожалуйста, не закрывай приложение",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: FeedPalette.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress <= 0 ? null : progress,
                            minHeight: 10,
                            backgroundColor: FeedPalette.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              FeedPalette.primaryGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          text,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: FeedPalette.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _uploadVideoWithDialog({
    required int matchId,
    required String notes,
    required File video,
    File? thumbnail,
  }) async {
    if (matchId <= 0) {
      Get.snackbar("Ошибка", "Некорректный match_id");
      return;
    }

    final progressNotifier = ValueNotifier<double>(0.0);
    final textNotifier = ValueNotifier<String>("Подготовка...");

    _showUploadingDialog(
      progressNotifier: progressNotifier,
      textNotifier: textNotifier,
    );

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final result = await _chunkUploadService.uploadVideoInChunks(
        videoFile: video,
        thumbnailFile: thumbnail,
        matchId: matchId,
        teamId: widget.teamId,
        coachId: _coachId,
        notes: notes,
        onProgress: (progress, text) {
          progressNotifier.value = progress.clamp(0.0, 1.0);
          textNotifier.value = text;
        },
      );

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (result["success"] == true) {
        Get.snackbar("Готово", "Видео прикреплено к матчу");
        await _loadMatches();
      } else {
        Get.snackbar(
          "Ошибка",
          _s(result["message"]).isNotEmpty
              ? _s(result["message"])
              : "Не удалось загрузить видео",
        );
      }
    } catch (e) {
      debugPrint("CHUNK UPLOAD ERROR: $e");
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      Get.snackbar("Ошибка", "Ошибка загрузки видео: $e");
    } finally {
      progressNotifier.dispose();
      textNotifier.dispose();
    }
  }

  Future<void> _deleteMatchVideo(Map<String, dynamic> item) async {
    final matchId = int.tryParse(_s(item["id"])) ?? 0;
    final videoUrl = _normalizeUrl(_s(item["video_url"])) ?? "";

    if (matchId <= 0) {
      Get.snackbar("Ошибка", "Некорректный match_id");
      return;
    }

    if (videoUrl.isEmpty) {
      Get.snackbar("Внимание", "У этого матча нет загруженного видео");
      return;
    }

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text("Удалить видео?"),
        content: Text(
          "Видео у матча\n\n${_buildMatchTitle(item)}\n\nбудет удалено безвозвратно.",
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 25),
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final resp = await dio.post(
        deleteVideoUrl,
        data: FormData.fromMap({
          "match_id": matchId.toString(),
          "team_id": widget.teamId.toString(),
          "coach_id": _coachId.toString(),
        }),
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      final data = _decodePlain(resp.data);

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (data["success"] == true) {
        Get.snackbar("Готово", "Видео удалено");
        await _loadMatches();
      } else {
        Get.snackbar(
          "Ошибка",
          _s(data["message"]).isNotEmpty
              ? _s(data["message"])
              : "Не удалось удалить видео",
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      Get.snackbar("Ошибка", "Ошибка удаления видео: $e");
    }
  }

 Future<void> _deleteMatch(Map<String, dynamic> item) async {
  final matchId = int.tryParse(_s(item["id"])) ?? 0;

  if (matchId <= 0) {
    Get.snackbar("Ошибка", "Некорректный id матча");
    return;
  }

  final confirmed = await Get.dialog<bool>(
    AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      title: const Text("Удалить матч?"),
      content: Text(
        "Матч\n\n${_buildMatchTitle(item)}\n\nбудет удалён из раздела полностью.",
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text("Отмена"),
        ),
        ElevatedButton(
          onPressed: () => Get.back(result: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text("Удалить"),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  Get.dialog(
    const Center(child: CircularProgressIndicator()),
    barrierDismissible: false,
  );

  try {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 25),
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final resp = await dio.post(
      deleteMatchUrl,
      data: jsonEncode({
        "id": matchId,
        "team_id": widget.teamId,
      }),
      options: Options(
        headers: const {
          "Content-Type": "application/json; charset=utf-8",
        },
      ),
    );

    final data = _decodePlain(resp.data);

    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    if (data["success"] == true) {
      Get.snackbar("Готово", "Матч удалён");
      await _loadMatches();
    } else {
      Get.snackbar(
        "Ошибка",
        _s(data["message"]).isNotEmpty
            ? _s(data["message"])
            : "Не удалось удалить матч",
      );
    }
  } catch (e) {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
    Get.snackbar("Ошибка", "Ошибка удаления матча: $e");
  }
}
  Future<void> _showMatchActionsSheet(Map<String, dynamic> item) async {
    final hasVideo = (_normalizeUrl(_s(item["video_url"])) ?? "").isNotEmpty;

    await showModalBottomSheet(
      context: context,
      backgroundColor: FeedPalette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: FeedPalette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                if (hasVideo)
                  ListTile(
                    leading: const Icon(
                      Icons.play_circle_outline,
                      color: FeedPalette.text,
                    ),
                    title: const Text("Открыть разбор"),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _openReview(item);
                    },
                  ),
                ListTile(
                  leading: Icon(
                    hasVideo
                        ? Icons.edit_outlined
                        : Icons.cloud_upload_outlined,
                    color: FeedPalette.text,
                  ),
                  title: Text(hasVideo ? "Обновить видео" : "Загрузить видео"),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showUploadVideoSheet(item);
                  },
                ),
                if (hasVideo)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      "Удалить видео",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _deleteMatchVideo(item);
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Colors.red,
                  ),
                  title: const Text(
                    "Удалить матч",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _deleteMatch(item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _decodePlain(dynamic rawResponse) {
    try {
      final body = (rawResponse ?? "").toString().trim();
      final start = body.indexOf('{');
      if (start == -1) {
        return {
          "success": false,
          "message": "Некорректный ответ сервера",
        };
      }
      final clean = body.substring(start);
      final j = jsonDecode(clean);
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);
      return {"success": false, "message": "Пустой JSON"};
    } catch (_) {
      return {"success": false, "message": "Ошибка разбора ответа"};
    }
  }

  String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    return "https://sportotekaapp.ru${s.startsWith('/') ? s : '/$s'}";
  }

  String _s(dynamic v) => (v ?? "").toString().trim();

  String _eventTypeLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'championship':
        return 'Чемпионат';
      case 'friendly':
        return 'Товарищеский';
      case 'tournament':
        return 'Турнир';
      default:
        return raw.isEmpty ? 'Матч' : raw;
    }
  }

  String _buildMatchTitle(Map<String, dynamic> item) {
    final readyTitle = _s(item["title"]);
    if (readyTitle.isNotEmpty) return readyTitle;

    final opponent = _s(item["opponent"]);
    final ourScore =
        _s(item["our_score"]).isEmpty ? "0" : _s(item["our_score"]);
    final oppScore =
        _s(item["opponent_score"]).isEmpty ? "0" : _s(item["opponent_score"]);

    if (opponent.isNotEmpty) {
      return "$_displayTeamName $ourScore:$oppScore $opponent";
    }

    return _displayTeamName;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 Б";
    const suffixes = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
    double size = bytes.toDouble();
    int i = 0;
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    final digits = size >= 100 ? 0 : (size >= 10 ? 1 : 2);
    return "${size.toStringAsFixed(digits)} ${suffixes[i]}";
  }

  void _applySearch() {
    final query = _searchCtrl.text.trim().toLowerCase();

    if (query.isEmpty) {
      _filteredMatches = List<Map<String, dynamic>>.from(_matches);
    } else {
      _filteredMatches = _matches.where((item) {
        final title = _buildMatchTitle(item).toLowerCase();
        final opponent = _s(item["opponent"]).toLowerCase();
        final competition = _s(item["competition_name"]).toLowerCase();
        final eventType =
            _eventTypeLabel(_s(item["event_type"])).toLowerCase();
        final date = _s(item["match_date"]).toLowerCase();

        return title.contains(query) ||
            opponent.contains(query) ||
            competition.contains(query) ||
            eventType.contains(query) ||
            date.contains(query);
      }).toList();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showUploadVideoSheet(Map<String, dynamic> match) async {
    final notesCtrl = TextEditingController(text: _s(match["notes"]));

    _selectedUploadVideoPath = null;
    _selectedUploadVideoName = null;
    _selectedUploadVideoSize = null;

    _selectedUploadThumbPath = null;
    _selectedUploadThumbName = null;
    _selectedUploadThumbSize = null;

    bool localSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FeedPalette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSB) {
            Future<void> pickVideo() async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.video,
                  allowMultiple: false,
                  withData: false,
                );

                if (result == null || result.files.isEmpty) {
                  return;
                }

                final picked = result.files.first;

                if (picked.path == null || picked.path!.isEmpty) {
                  Get.snackbar("Ошибка", "Не удалось получить путь к видео");
                  return;
                }

                final path = picked.path!;
                final file = File(path);

                if (!await file.exists()) {
                  Get.snackbar("Ошибка", "Файл не найден");
                  return;
                }

                _selectedUploadVideoPath = path;
                _selectedUploadVideoName = picked.name;
                _selectedUploadVideoSize = await file.length();

                if (ctx.mounted) {
                  setSB(() {});
                }
              } catch (e) {
                debugPrint("Ошибка выбора видео: $e");
                Get.snackbar("Ошибка", "Не удалось выбрать видео: $e");
              }
            }

            Future<void> pickThumb() async {
              final x = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: 1400,
              );

              if (x != null) {
                final file = File(x.path);
                final size = await file.length();

                _selectedUploadThumbPath = x.path;
                _selectedUploadThumbName = x.name;
                _selectedUploadThumbSize = size;

                if (ctx.mounted) {
                  setSB(() {});
                }
              }
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: FeedPalette.greenGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.video_library_outlined,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Загрузить видео матча",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: FeedPalette.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _buildMatchTitle(match),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FeedPalette.textMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Комментарий к видео",
                          hintStyle: const TextStyle(
                            color: FeedPalette.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          filled: true,
                          fillColor: FeedPalette.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: FeedPalette.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: FeedPalette.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: FeedPalette.primaryGreen,
                              width: 1.4,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: localSaving ? null : pickVideo,
                              icon: const Icon(Icons.video_library_outlined),
                              label: Text(
                                _selectedUploadVideoPath == null
                                    ? "Выбрать видео"
                                    : "Видео выбрано",
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: FeedPalette.text,
                                side: const BorderSide(
                                  color: FeedPalette.border,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          if (_selectedUploadVideoPath != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: FeedPalette.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: FeedPalette.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedUploadVideoName ?? "Видео",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: FeedPalette.text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Размер: ${_formatFileSize(_selectedUploadVideoSize ?? 0)}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: FeedPalette.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: localSaving ? null : pickThumb,
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                _selectedUploadThumbPath == null
                                    ? "Выбрать превью"
                                    : "Превью выбрано",
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: FeedPalette.text,
                                side: const BorderSide(
                                  color: FeedPalette.border,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          if (_selectedUploadThumbPath != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: FeedPalette.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: FeedPalette.border),
                              ),
                              child: Text(
                                "${_selectedUploadThumbName ?? "Превью"} • ${_formatFileSize(_selectedUploadThumbSize ?? 0)}",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: FeedPalette.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: FeedPalette.greenGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  FeedPalette.primaryGreen.withOpacity(0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: localSaving
                              ? null
                              : () async {
                                  if (_selectedUploadVideoPath == null ||
                                      _selectedUploadVideoPath!.isEmpty) {
                                    Get.snackbar(
                                      "Ошибка",
                                      "Сначала выберите видео матча",
                                    );
                                    return;
                                  }

                                  final matchId =
                                      int.tryParse(_s(match["id"])) ?? 0;
                                  if (matchId <= 0) {
                                    Get.snackbar(
                                      "Ошибка",
                                      "Некорректный match_id",
                                    );
                                    return;
                                  }

                                  final videoFile =
                                      File(_selectedUploadVideoPath!);
                                  final videoExists = await videoFile.exists();
                                  if (!videoExists) {
                                    Get.snackbar(
                                      "Ошибка",
                                      "Выбранный видеофайл не найден",
                                    );
                                    return;
                                  }

                                  final videoBytes = await videoFile.length();
                                  if (videoBytes <= 0) {
                                    Get.snackbar(
                                      "Ошибка",
                                      "Не удалось прочитать файл видео",
                                    );
                                    return;
                                  }

                                  setSB(() {
                                    localSaving = true;
                                  });

                                  if (Navigator.of(ctx).canPop()) {
                                    Navigator.of(ctx).pop();
                                  }

                                  await _uploadVideoWithDialog(
                                    matchId: matchId,
                                    notes: notesCtrl.text.trim(),
                                    video: videoFile,
                                    thumbnail: _selectedUploadThumbPath != null
                                        ? File(_selectedUploadThumbPath!)
                                        : null,
                                  );
                                },
                          icon: localSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.cloud_upload_outlined),
                          label: Text(
                            localSaving ? "Подготовка..." : "Сохранить видео",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    notesCtrl.dispose();
  }

  void _openReview(Map<String, dynamic> item) {
    final matchId = int.tryParse(_s(item["id"])) ?? 0;
    final title = _buildMatchTitle(item);
    final videoUrl = _normalizeUrl(_s(item["video_url"])) ?? "";
    final videoId = matchId;

    if (videoUrl.isEmpty) {
      Get.snackbar("Внимание", "Сначала загрузите видео матча");
      return;
    }

    if (videoId <= 0) {
      Get.snackbar("Внимание", "Не найден id матча");
      return;
    }

    Get.to(
      () => VideoMatchReviewScreen(
        matchId: matchId,
        teamId: widget.teamId,
        teamName: _displayTeamName,
        coachId: _coachId,
        matchTitle: title,
        videoUrl: videoUrl,
        videoId: videoId,
      ),
    );
  }

  Widget _searchAndToolbar() {
    return Container(
      color: FeedPalette.background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        children: [
          _MatteSurface(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: FeedPalette.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Поиск по матчу, сопернику, турниру',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applySearch(),
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: FeedPalette.textMuted,
                    ),
                    onPressed: () {
                      _searchCtrl.clear();
                      _applySearch();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "$_displayTeamName • ${_filteredMatches.length} матчей",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: FeedPalette.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              _viewSwitch(
                icon: Icons.view_list_rounded,
                selected: _view == TeamVideoCatalogView.list,
                onTap: () {
                  setState(() => _view = TeamVideoCatalogView.list);
                },
              ),
              const SizedBox(width: 8),
              _viewSwitch(
                icon: Icons.grid_view_rounded,
                selected: _view == TeamVideoCatalogView.grid,
                onTap: () {
                  setState(() => _view = TeamVideoCatalogView.grid);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _viewSwitch({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? FeedPalette.superLightGreen : FeedPalette.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? FeedPalette.primaryGreen.withOpacity(0.35)
                : FeedPalette.border,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected ? FeedPalette.primaryGreen : FeedPalette.textMuted,
        ),
      ),
    );
  }

  Widget _sectionLabel() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Text(
        "МАТЧИ КОМАНДЫ",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: FeedPalette.textMuted,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _matchMoreButton(Map<String, dynamic> item) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showMatchActionsSheet(item),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: FeedPalette.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FeedPalette.border),
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: FeedPalette.textMuted,
        ),
      ),
    );
  }

  Widget _matchTile(Map<String, dynamic> item) {
    final title = _buildMatchTitle(item);
    final opponent = _s(item["opponent"]);
    final competition = _s(item["competition_name"]);
    final date = _s(item["match_date"]);
    final eventType = _eventTypeLabel(_s(item["event_type"]));
    final thumb = _normalizeUrl(_s(item["thumbnail_url"]));
    final videoUrl = _normalizeUrl(_s(item["video_url"])) ?? "";
    final hasVideo = videoUrl.isNotEmpty;

    final score =
        "${_s(item["our_score"]).isEmpty ? "0" : _s(item["our_score"])}:"
        "${_s(item["opponent_score"]).isEmpty ? "0" : _s(item["opponent_score"])}";

    return _MatteSurface(
      onTap: hasVideo ? () => _openReview(item) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MatchThumb(
            thumb: thumb,
            hasVideo: hasVideo,
            width: 108,
            height: 92,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: FeedPalette.text,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _matchMoreButton(item),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$eventType • Счёт $score",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FeedPalette.textMuted,
                    ),
                  ),
                  if (competition.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      competition,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: FeedPalette.textMuted,
                      ),
                    ),
                  ],
                  if (opponent.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      "Соперник: $opponent",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: FeedPalette.textMuted,
                      ),
                    ),
                  ],
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A94A6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasVideo)
                        _smallActionButton(
                          label: "Разбор",
                          icon: Icons.play_circle_outline,
                          filled: true,
                          onTap: () => _openReview(item),
                        ),
                      if (!hasVideo)
                        _smallActionButton(
                          label: "Загрузить",
                          icon: Icons.cloud_upload_outlined,
                          filled: false,
                          onTap: () => _showUploadVideoSheet(item),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallActionButton({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    if (filled) {
      return Container(
        decoration: BoxDecoration(
          gradient: FeedPalette.greenGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: FeedPalette.text,
        side: const BorderSide(color: FeedPalette.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _matchGridCard(Map<String, dynamic> item) {
    final title = _buildMatchTitle(item);
    final opponent = _s(item["opponent"]);
    final competition = _s(item["competition_name"]);
    final date = _s(item["match_date"]);
    final eventType = _eventTypeLabel(_s(item["event_type"]));
    final thumb = _normalizeUrl(_s(item["thumbnail_url"]));
    final videoUrl = _normalizeUrl(_s(item["video_url"])) ?? "";
    final hasVideo = videoUrl.isNotEmpty;

    final score =
        "${_s(item["our_score"]).isEmpty ? "0" : _s(item["our_score"])}:"
        "${_s(item["opponent_score"]).isEmpty ? "0" : _s(item["opponent_score"])}";

    return _MatteSurface(
      padding: EdgeInsets.zero,
      onTap: hasVideo ? () => _openReview(item) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MatchThumb(
            thumb: thumb,
            hasVideo: hasVideo,
            width: double.infinity,
            height: 140,
            radius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: FeedPalette.text,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _matchMoreButton(item),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$eventType • $score",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: FeedPalette.textMuted,
                    ),
                  ),
                  if (competition.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      competition,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: FeedPalette.textMuted,
                      ),
                    ),
                  ],
                  if (opponent.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      opponent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: FeedPalette.textMuted,
                      ),
                    ),
                  ],
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A94A6),
                      ),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: hasVideo
                        ? Container(
                            decoration: BoxDecoration(
                              gradient: FeedPalette.greenGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _openReview(item),
                              icon: const Icon(Icons.play_circle_outline),
                              label: const Text("Открыть"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => _showUploadVideoSheet(item),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text("Загрузить"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: FeedPalette.text,
                              side:
                                  const BorderSide(color: FeedPalette.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
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

  Widget _buildEmpty() {
    final isSearching = _searchCtrl.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: FeedPalette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FeedPalette.border),
        ),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: FeedPalette.superLightGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.video_library_outlined,
                size: 32,
                color: FeedPalette.primaryGreen,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isSearching ? "Ничего не найдено" : "Пока нет добавленных матчей",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: FeedPalette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? "Попробуй изменить поисковый запрос"
                  : "Сначала добавь матчи команды в разделе «Матчи», после этого здесь можно будет прикрепить видео и открыть разбор.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: FeedPalette.textMuted,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listBody() {
    return ListView.separated(
      itemCount: _filteredMatches.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _matchTile(_filteredMatches[i]),
    );
  }

  Widget _gridBody(bool isTablet) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: GridView.builder(
        itemCount: _filteredMatches.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTablet ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isTablet ? 0.82 : 0.76,
        ),
        itemBuilder: (_, i) => _matchGridCard(_filteredMatches[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 900;

    final content = FadeTransition(
  opacity: _animationController,
  child: _loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: () async {
            await _loadTeamProfile();
            await _loadMatches();
            await _checkPendingUpload();
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              _searchAndToolbar(),
              _sectionLabel(),
              if (_filteredMatches.isEmpty)
                _buildEmpty()
              else if (_view == TeamVideoCatalogView.grid)
                _gridBody(isTablet)
              else
                _listBody(),
            ],
          ),
        ),
);
    if (widget.embedded) {
      return ColoredBox(
        color: FeedPalette.background,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: FeedPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: FeedPalette.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Видеоанализ',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: FeedPalette.text,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Обновить",
            onPressed: () async {
              await _loadTeamProfile();
              await _loadMatches();
              await _checkPendingUpload();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: content,
    );
  }
}

class _MatteSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const _MatteSurface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: FeedPalette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FeedPalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}

class _MatchThumb extends StatelessWidget {
  final String? thumb;
  final bool hasVideo;
  final double width;
  final double height;
  final BorderRadius? radius;

  const _MatchThumb({
    required this.thumb,
    required this.hasVideo,
    required this.width,
    required this.height,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(14),
      child: Stack(
        children: [
          SizedBox(
            width: width,
            height: height,
            child: thumb != null && thumb!.isNotEmpty
                ? Image.network(
                    thumb!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF111827),
                      child: const Center(
                        child: Icon(
                          Icons.sports_soccer_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFF111827),
                    child: const Center(
                      child: Icon(
                        Icons.sports_soccer_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: hasVideo
                    ? Colors.green.withOpacity(0.92)
                    : Colors.orange.withOpacity(0.92),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                hasVideo ? "Видео" : "Нет видео",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FeedPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);

  static const lightGreen = Color(0xFFE8F5E9);
  static const superLightGreen = Color(0xFFF2FFF5);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);
  static const background = Color(0xFFF8F9FA);
  static const border = Color(0xFFE5E7EB);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
}
