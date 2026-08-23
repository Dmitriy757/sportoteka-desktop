import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/models/class_model.dart';
import 'package:sportoteka/core/models/student_model.dart' as student;
import 'package:sportoteka/core/utils/pref_utils.dart';

class ApiService {
  static const String baseUrl = 'https://sportotekaapp.ru/api';

  // 🔹 Универсальный метод GET-запроса с логами
  static Future<dynamic> fetchApi(String endpoint) async {
    final url = Uri.parse('$baseUrl/$endpoint');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'SportotekaApp/1.0 (iOS)',
        },
      ).timeout(const Duration(seconds: 10));

      stopwatch.stop();
      print('✅ [$endpoint] Время: ${stopwatch.elapsedMilliseconds} мс | Размер: ${utf8.encode(response.body).length} байт');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ [$endpoint] Код: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      stopwatch.stop();
      print('❗ [$endpoint] Ошибка: $e');
      return null;
    }
  }

  // 🔹 POST: Добавление класса
  static Future<bool> addClass({
    required String name,
    required String sportType,
    required int schoolId,
    required int trainerId,
  }) async {
    final trainerId = await PrefUtils.getUserId();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add_class.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'sport_type': sportType,
          'school_id': schoolId,
          'trainer_id': trainerId ?? 0,
        }),
      ).timeout(const Duration(seconds: 10));

      final json = jsonDecode(response.body);
      print("🔁 Ответ сервера (addClass): $json");

      return response.statusCode == 200 && json['success'] == true;
    } catch (e) {
      print("❗ Ошибка addClass: $e");
      return false;
    }
  }

  // 🔹 GET: Классы по школе
  static Future<List<ClassModel>> getClassesBySchool(int schoolId) async {
    final data = await fetchApi('get_classes_by_school.php?school_id=$schoolId');
    if (data is List) {
      return data.map((e) => ClassModel.fromJson(e)).toList();
    } else {
      return [];
    }
  }

  // 🔹 GET: Ученики по классу
  static Future<List<student.StudentModel>> getStudentsByClass(int classId) async {
    final data = await fetchApi('get_students_by_class.php?class_id=$classId');
    if (data is List) {
      return data.map((e) => student.StudentModel.fromJson(e)).toList();
    } else {
      return [];
    }
  }

  // 🔹 POST: Добавить ученика
  static Future<bool> addStudent({
    required String firstName,
    required String lastName,
    required String birthDate,
    required String parentEmail,
    required int schoolId,
    required int classId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add_student.php'),
        body: {
          'first_name': firstName,
          'last_name': lastName,
          'birth_date': birthDate,
          'parent_email': parentEmail,
          'school_id': schoolId.toString(),
          'class_id': classId.toString(),
        },
      ).timeout(const Duration(seconds: 10));

      final json = jsonDecode(response.body);
      print("📥 Ответ сервера (addStudent): $json");

      return response.statusCode == 200 && json['status'] == 'success';
    } catch (e) {
      print("❗ Ошибка addStudent: $e");
      return false;
    }
  }
}
