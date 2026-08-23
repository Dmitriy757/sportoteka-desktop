import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/video_folder_model.dart';
import '../models/video_lesson_author_model.dart';
import '../models/video_lesson_comment_model.dart';
import '../models/video_lesson_model.dart';
import '../models/video_lesson_preview_data.dart';

class VideoLessonsService {
  static const String baseUrl = 'https://sportotekaapp.ru/api/video_lessons';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(minutes: 30),
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  static Map<String, dynamic> _parseDioMap(dynamic data) {
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
    final path = file.path;
    if (path.contains(Platform.pathSeparator)) {
      return path.split(Platform.pathSeparator).last;
    }
    return file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'video.mp4';
  }

  static String _buildUploadId(File file, int fileSize) {
    return md5
        .convert(
          utf8.encode(
            '${DateTime.now().millisecondsSinceEpoch}_${file.path}_$fileSize',
          ),
        )
        .toString();
  }

  static Future<List<VideoFolderModel>> getFolders({
    int? ownerId,
    int? parentId,
  }) async {
    final query = <String, String>{
      'parent_id': parentId?.toString() ?? 'null',
    };

    if (ownerId != null) {
      query['owner_id'] = ownerId.toString();
    }

    final uri = Uri.parse(
      '$baseUrl/get_video_folders.php',
    ).replace(queryParameters: query);

    final response = await http.get(uri);

    try {
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (data['folders'] as List)
            .map((e) => VideoFolderModel.fromJson(e))
            .toList();
      } else {
        throw Exception(data['message'] ?? 'Ошибка загрузки папок');
      }
    } catch (e) {
      throw Exception('Некорректный ответ getFolders: ${response.body}');
    }
  }

  static Future<List<VideoLessonAuthorModel>> getAuthors({
    String query = '',
    String hashtag = '',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/get_video_lesson_authors.php?query=${Uri.encodeComponent(query)}&hashtag=${Uri.encodeComponent(hashtag)}',
    );

    final response = await http.get(uri);
    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      return (data['authors'] as List)
          .map((e) => VideoLessonAuthorModel.fromJson(e))
          .toList();
    }
    return [];
  }

  static Future<List<String>> getHashtags() async {
    final uri = Uri.parse('$baseUrl/get_video_lesson_hashtags.php');
    final response = await http.get(uri);

    try {
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return (data['hashtags'] as List)
            .map((e) => e.toString())
            .toList();
      } else {
        throw Exception(data['message'] ?? 'Ошибка загрузки хештегов');
      }
    } catch (e) {
      throw Exception('Некорректный ответ getHashtags: ${response.body}');
    }
  }

  static Future<bool> createFolder({
    required int userId,
    int? parentId,
    required String title,
    required String color,
    String? banner,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/create_video_folder.php'),
      body: {
        'user_id': userId.toString(),
        'parent_id': parentId?.toString() ?? '',
        'title': title,
        'color': color,
        'banner': banner ?? '',
      },
    );

    final data = jsonDecode(response.body);
    return data['success'] == true;
  }

  static Future<bool> updateFolder({
    required int id,
    required String title,
    required String color,
    String? banner,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update_video_folder.php'),
      body: {
        'id': id.toString(),
        'title': title,
        'color': color,
        'banner': banner ?? '',
      },
    );

    final data = jsonDecode(response.body);
    return data['success'] == true;
  }

  static Future<bool> deleteFolder(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/delete_video_folder.php'),
      body: {'id': id.toString()},
    );

    final data = jsonDecode(response.body);
    return data['success'] == true;
  }

  static Future<List<VideoLessonModel>> getLessons({
    required int folderId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_video_lessons.php?folder_id=$folderId'),
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      return (data['lessons'] as List)
          .map((e) => VideoLessonModel.fromJson(e))
          .toList();
    }
    return [];
  }

  static Future<VideoLessonModel?> getLessonDetail({
    required int lessonId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_video_lesson_detail.php?id=$lessonId'),
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true && data['lesson'] != null) {
      return VideoLessonModel.fromJson(data['lesson']);
    }
    return null;
  }

  static Future<bool> addLesson({
    required int folderId,
    required int userId,
    required String title,
    required String description,
    required String videoUrl,
    String thumbnail = '',
    String duration = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/add_video_lesson.php'),
      body: {
        'folder_id': folderId.toString(),
        'user_id': userId.toString(),
        'title': title,
        'description': description,
        'video_url': videoUrl,
        'thumbnail': thumbnail,
        'duration': duration,
      },
    );

    final data = jsonDecode(response.body);
    return data['success'] == true;
  }

  static Future<bool> addLessonWithChunks({
    required int folderId,
    required int userId,
    required String title,
    required String description,
    required File videoFile,
    String duration = '',
    ValueChanged<double>? onProgress,
  }) async {
    try {
      final fileSize = await videoFile.length();
      final fileName = _fileNameFromPath(videoFile);
      const int chunkSize = 8 * 1024 * 1024;
      final int totalChunks = (fileSize / chunkSize).ceil();
      final String uploadId = _buildUploadId(videoFile, fileSize);

      final raf = videoFile.openSync(mode: FileMode.read);

      try {
        onProgress?.call(0.0);

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

          final response = await _dio.post(
            '$baseUrl/upload_video_lesson_chunk.php',
            data: formData,
          );

          final data = _parseDioMap(response.data);
          if (data['success'] != true) {
            debugPrint('addLessonWithChunks chunk error: $data');
            return false;
          }

          onProgress?.call(((index + 1) / totalChunks) * 0.95);
        }

        final finalizeResponse = await _dio.post(
          '$baseUrl/finalize_video_lesson_upload.php',
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

        final finalizeData = _parseDioMap(finalizeResponse.data);
        final ok = finalizeData['success'] == true;
        onProgress?.call(ok ? 1.0 : 0.0);
        return ok;
      } finally {
        raf.closeSync();
      }
    } catch (e) {
      debugPrint('addLessonWithChunks error: $e');
      return false;
    }
  }

  static Future<bool> addLessonWithFile({
    required int folderId,
    required int userId,
    required String title,
    required String description,
    required File videoFile,
    String thumbnail = '',
    String duration = '',
    ValueChanged<double>? onProgress,
  }) async {
    return addLessonWithChunks(
      folderId: folderId,
      userId: userId,
      title: title,
      description: description,
      videoFile: videoFile,
      duration: duration,
      onProgress: onProgress,
    );
  }

  static Future<bool> updateLesson({
    required int id,
    required String title,
    required String description,
    required String videoUrl,
    required String duration,
    String thumbnail = '',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/update_video_lesson.php');

      final response = await http.post(
        uri,
        body: {
          'id': id.toString(),
          'title': title,
          'description': description,
          'video_url': videoUrl,
          'duration': duration,
          'thumbnail': thumbnail,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      debugPrint('updateLesson error: $e');
      return false;
    }
  }

  static Future<bool> updateLessonWithChunks({
    required int id,
    required String title,
    required String description,
    required String duration,
    required File videoFile,
    ValueChanged<double>? onProgress,
  }) async {
    try {
      final fileSize = await videoFile.length();
      final fileName = _fileNameFromPath(videoFile);
      const int chunkSize = 8 * 1024 * 1024;
      final int totalChunks = (fileSize / chunkSize).ceil();
      final String uploadId = _buildUploadId(videoFile, fileSize);

      final raf = videoFile.openSync(mode: FileMode.read);

      try {
        onProgress?.call(0.0);

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

          final response = await _dio.post(
            '$baseUrl/upload_video_lesson_chunk.php',
            data: formData,
          );

          final data = _parseDioMap(response.data);
          if (data['success'] != true) {
            debugPrint('updateLessonWithChunks chunk error: $data');
            return false;
          }

          onProgress?.call(((index + 1) / totalChunks) * 0.95);
        }

        final finalizeResponse = await _dio.post(
          '$baseUrl/finalize_video_lesson_update.php',
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

        final finalizeData = _parseDioMap(finalizeResponse.data);
        final ok = finalizeData['success'] == true;
        onProgress?.call(ok ? 1.0 : 0.0);
        return ok;
      } finally {
        raf.closeSync();
      }
    } catch (e) {
      debugPrint('updateLessonWithChunks error: $e');
      return false;
    }
  }

  static Future<bool> updateLessonWithOptionalFile({
    required int id,
    required String title,
    required String description,
    required String thumbnail,
    required String duration,
    String videoUrl = '',
    File? videoFile,
    ValueChanged<double>? onProgress,
  }) async {
    if (videoFile == null) {
      return updateLesson(
        id: id,
        title: title,
        description: description,
        videoUrl: videoUrl,
        thumbnail: thumbnail,
        duration: duration,
      );
    }

    return updateLessonWithChunks(
      id: id,
      title: title,
      description: description,
      duration: duration,
      videoFile: videoFile,
      onProgress: onProgress,
    );
  }

  static Future<bool> deleteLesson(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/delete_video_lesson.php'),
      body: {'id': id.toString()},
    );

    final data = jsonDecode(response.body);
    return data['success'] == true;
  }

  static Future<List<VideoLessonCommentModel>> getComments({
    required int lessonId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_video_lesson_comments.php?lesson_id=$lessonId'),
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      return (data['comments'] as List)
          .map((e) => VideoLessonCommentModel.fromJson(e))
          .toList();
    }
    return [];
  }

  static Future<bool> addComment({
    required int lessonId,
    required int userId,
    required String comment,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/add_video_lesson_comment.php'),
      body: {
        'lesson_id': lessonId.toString(),
        'user_id': userId.toString(),
        'comment': comment,
      },
    );

    final data = jsonDecode(response.body);
    return data['success'] == true;
  }

  static Future<List<VideoFolderModel>> getAllFoldersRecursive({
    int? ownerId,
  }) async {
    final List<VideoFolderModel> result = [];

    Future<void> walk(int? parentId) async {
      final items = await getFolders(
        ownerId: ownerId,
        parentId: parentId,
      );

      result.addAll(items);

      for (final folder in items) {
        await walk(folder.id);
      }
    }

    await walk(null);
    return result;
  }

  static Future<List<VideoLessonPreviewData>> getRandomPreviewLessons({
    int? ownerId,
    int limit = 12,
  }) async {
    final folders = await getAllFoldersRecursive(ownerId: ownerId);
    final List<VideoLessonPreviewData> previews = [];

    for (final folder in folders) {
      try {
        final lessons = await getLessons(folderId: folder.id);

        for (final lesson in lessons) {
          previews.add(
            VideoLessonPreviewData(
              lesson: lesson,
              folderId: folder.id,
              folderTitle: folder.title,
              folderColor: folder.color,
              parentId: folder.parentId,
            ),
          );
        }
      } catch (e) {
        debugPrint('getRandomPreviewLessons folder ${folder.id} error: $e');
      }
    }

    previews.shuffle(Random());

    if (previews.length > limit) {
      return previews.take(limit).toList();
    }

    return previews;
  }

  static Future<List<VideoFolderModel>> getRootFolders({
    int? ownerId,
  }) async {
    return getFolders(
      ownerId: ownerId,
      parentId: null,
    );
  }

  static Future<List<VideoFolderModel>> getSubfolders({
    int? ownerId,
    required int parentId,
  }) async {
    return getFolders(
      ownerId: ownerId,
      parentId: parentId,
    );
  }
}