import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

class VideoLessonsService {
  static const String baseUrl = 'https://sportotekaapp.ru/api';

  static const String _addLessonUrl = '$baseUrl/add_video_lesson.php';
  static const String _updateLessonUrl = '$baseUrl/update_video_lesson.php';
  static const String _deleteLessonUrl = '$baseUrl/delete_video_lesson.php';
  static const String _getLessonsUrl = '$baseUrl/get_video_lessons.php';

  static const String _uploadChunkUrl =
      '$baseUrl/upload_video_lesson_chunk.php';
  static const String _finalizeUploadUrl =
      '$baseUrl/finalize_video_lesson_upload.php';
  static const String _finalizeUpdateUrl =
      '$baseUrl/finalize_video_lesson_update.php';

  static Dio _dio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(minutes: 2),
        sendTimeout: const Duration(minutes: 30),
        receiveTimeout: const Duration(minutes: 30),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    final raw = data?.toString() ?? '';
    final firstBrace = raw.indexOf('{');
    if (firstBrace >= 0) {
      final cleaned = raw.substring(firstBrace);
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Некорректный JSON: $raw');
  }

  static String _fileNameFromPath(File file) {
    if (file.path.contains(Platform.pathSeparator)) {
      return file.path.split(Platform.pathSeparator).last;
    }
    return file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'video.mp4';
  }

  static Future<List<Map<String, dynamic>>> getLessons(int folderId) async {
    try {
      final response = await _dio().post(
        _getLessonsUrl,
        data: FormData.fromMap({
          'folder_id': folderId.toString(),
        }),
      );

      final data = _asMap(response.data);

      if (data['success'] == true && data['lessons'] is List) {
        return (data['lessons'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> addLesson({
    required int folderId,
    required int userId,
    required String title,
    required String description,
    required String videoUrl,
    required String duration,
  }) async {
    try {
      final response = await _dio().post(
        _addLessonUrl,
        data: FormData.fromMap({
          'folder_id': folderId.toString(),
          'user_id': userId.toString(),
          'title': title,
          'description': description,
          'video_url': videoUrl,
          'duration': duration,
        }),
      );

      final data = _asMap(response.data);
      return data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateLesson({
    required int id,
    required String title,
    required String description,
    required String videoUrl,
    required String duration,
  }) async {
    try {
      final response = await _dio().post(
        _updateLessonUrl,
        data: FormData.fromMap({
          'id': id.toString(),
          'title': title,
          'description': description,
          'video_url': videoUrl,
          'duration': duration,
        }),
      );

      final data = _asMap(response.data);
      return data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteLesson(int id) async {
    try {
      final response = await _dio().post(
        _deleteLessonUrl,
        data: FormData.fromMap({
          'id': id.toString(),
        }),
      );

      final data = _asMap(response.data);
      return data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> addLessonWithChunks({
    required int folderId,
    required int userId,
    required String title,
    required String description,
    required File videoFile,
    required String duration,
    required Function(double progress) onProgress,
  }) async {
    final dio = _dio();

    final fileSize = await videoFile.length();
    final fileName = _fileNameFromPath(videoFile);

    const int chunkSize = 8 * 1024 * 1024; // 8 MB
    final int totalChunks = (fileSize / chunkSize).ceil();

    final String uploadId = md5
        .convert(
          utf8.encode(
            '${DateTime.now().millisecondsSinceEpoch}_${videoFile.path}_$fileSize',
          ),
        )
        .toString();

    final raf = videoFile.openSync(mode: FileMode.read);

    try {
      onProgress(0.0);

      for (int index = 0; index < totalChunks; index++) {
        final int start = index * chunkSize;
        final int end =
            (start + chunkSize > fileSize) ? fileSize : start + chunkSize;
        final int currentChunkSize = end - start;

        raf.setPositionSync(start);
        final bytes = raf.readSync(currentChunkSize);

        final formData = FormData.fromMap({
          'upload_id': uploadId,
          'file_name': fileName,
          'chunk_index': index.toString(),
          'total_chunks': totalChunks.toString(),
          'video_chunk': MultipartFile.fromBytes(
            bytes,
            filename: 'chunk_$index.part',
          ),
        });

        final response = await dio.post(
          _uploadChunkUrl,
          data: formData,
        );

        final data = _asMap(response.data);
        if (data['success'] != true) {
          return false;
        }

        final double progress = ((index + 1) / totalChunks) * 0.95;
        onProgress(progress);
      }

      final finalizeResponse = await dio.post(
        _finalizeUploadUrl,
        data: FormData.fromMap({
          'folder_id': folderId.toString(),
          'user_id': userId.toString(),
          'title': title,
          'description': description,
          'duration': duration,
          'upload_id': uploadId,
          'file_name': fileName,
          'total_chunks': totalChunks.toString(),
        }),
      );

      final finalizeData = _asMap(finalizeResponse.data);
      final ok = finalizeData['success'] == true;

      onProgress(ok ? 1.0 : 0.0);
      return ok;
    } catch (_) {
      return false;
    } finally {
      raf.closeSync();
    }
  }

  static Future<bool> updateLessonWithChunks({
    required int id,
    required String title,
    required String description,
    required String duration,
    required File videoFile,
    required Function(double progress) onProgress,
  }) async {
    final dio = _dio();

    final fileSize = await videoFile.length();
    final fileName = _fileNameFromPath(videoFile);

    const int chunkSize = 8 * 1024 * 1024; // 8 MB
    final int totalChunks = (fileSize / chunkSize).ceil();

    final String uploadId = md5
        .convert(
          utf8.encode(
            '${DateTime.now().millisecondsSinceEpoch}_${videoFile.path}_$fileSize',
          ),
        )
        .toString();

    final raf = videoFile.openSync(mode: FileMode.read);

    try {
      onProgress(0.0);

      for (int index = 0; index < totalChunks; index++) {
        final int start = index * chunkSize;
        final int end =
            (start + chunkSize > fileSize) ? fileSize : start + chunkSize;
        final int currentChunkSize = end - start;

        raf.setPositionSync(start);
        final bytes = raf.readSync(currentChunkSize);

        final formData = FormData.fromMap({
          'upload_id': uploadId,
          'file_name': fileName,
          'chunk_index': index.toString(),
          'total_chunks': totalChunks.toString(),
          'video_chunk': MultipartFile.fromBytes(
            bytes,
            filename: 'chunk_$index.part',
          ),
        });

        final response = await dio.post(
          _uploadChunkUrl,
          data: formData,
        );

        final data = _asMap(response.data);
        if (data['success'] != true) {
          return false;
        }

        final double progress = ((index + 1) / totalChunks) * 0.95;
        onProgress(progress);
      }

      final finalizeResponse = await dio.post(
        _finalizeUpdateUrl,
        data: FormData.fromMap({
          'id': id.toString(),
          'title': title,
          'description': description,
          'duration': duration,
          'upload_id': uploadId,
          'file_name': fileName,
          'total_chunks': totalChunks.toString(),
        }),
      );

      final finalizeData = _asMap(finalizeResponse.data);
      final ok = finalizeData['success'] == true;

      onProgress(ok ? 1.0 : 0.0);
      return ok;
    } catch (_) {
      return false;
    } finally {
      raf.closeSync();
    }
  }
}