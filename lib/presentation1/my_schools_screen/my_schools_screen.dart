import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/add_school_screen/add_school_screen.dart';
import 'package:sportoteka/presentation/add_student_screen/add_student_screen.dart';
import 'package:sportoteka/presentation/add_class_screen/add_class_screen.dart';
import 'package:sportoteka/presentation/edit_school_screen/edit_school_screen.dart';


class MySchoolsScreen extends StatefulWidget {
  const MySchoolsScreen({super.key});

  @override
  State<MySchoolsScreen> createState() => _MySchoolsScreenState();
}

class _MySchoolsScreenState extends State<MySchoolsScreen> {
  int? trainerId;
  List<dynamic> schools = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTrainerId();
  }

  Future<void> loadTrainerId() async {
    trainerId = await PrefUtils.getUserId();
    await fetchSchools();
  }

  Future<void> fetchSchools() async {
    if (trainerId == null) return;
    final response = await http.get(Uri.parse(
        'https://sportotekaapp.ru/api/get_schools_by_trainer.php?trainer_id=$trainerId'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        schools = data;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при загрузке школ')),
      );
    }
  }

  void _navigateToAddSchool() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddSchoolScreen()),
    );
    await fetchSchools();
  }

  void _navigateToAddClass(int schoolId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddClassScreen(schoolId: schoolId),
      ),
    );
  }

  void _navigateToAddStudent(int schoolId) async {
    final response = await http.get(Uri.parse(
      'https://sportotekaapp.ru/api/get_classes_by_school.php?school_id=$schoolId',
    ));

    if (response.statusCode == 200) {
      final List classes = json.decode(response.body);

      if (classes.isEmpty) {
        _showHelpDialog();
        return;
      }

      final selectedClass = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) {
          return SimpleDialog(
            title: const Text('Выберите класс'),
            children: classes.map((cls) {
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, cls),
                child: Text(cls['name'] ?? 'Без названия'),
              );
            }).toList(),
          );
        },
      );

      if (selectedClass != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddStudentScreen(
              schoolId: schoolId,
              classId: int.parse(selectedClass['id'].toString()),
            ),
          ),
        );
      }
    } else {
      Get.snackbar('Ошибка', 'Не удалось получить классы');
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Нельзя добавить ученика'),
        content: const Text(
          'Чтобы добавить ученика, сначала необходимо создать хотя бы один класс в этой школе.\n\n'
          '1️⃣ Нажмите «Добавить класс»\n'
          '2️⃣ Укажите название и вид спорта\n'
          '3️⃣ После этого станет доступна функция добавления учеников',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

 Widget _buildSchoolCard(Map<String, dynamic> school) {
  final schoolId = int.parse(school['id'].toString());

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1E74C4), // синий фон карточки
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
       Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Row(
      children: [
        const Icon(Icons.school, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          school['name'] ?? 'Без названия',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    ),
    IconButton(
      icon: const Icon(Icons.edit, color: Colors.white),
      onPressed: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditSchoolScreen(school: school)),
        );
        if (updated == true) await fetchSchools();
      },
    ),
  ],
),
        const SizedBox(height: 6),
        Text(
          'Вид спорта: ${school['sport_type'] ?? 'Не указан'}',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildCircleAction(
              icon: Icons.class_,
              label: 'Класс',
              onTap: () => _navigateToAddClass(schoolId),
            ),
            const SizedBox(width: 20),
            _buildCircleAction(
              icon: Icons.person_add_alt_1,
              label: 'Ученик',
              onTap: () => _navigateToAddStudent(schoolId),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildCircleAction({required IconData icon, required String label, required VoidCallback onTap}) {
  return Column(
    children: [
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1E74C4), Color(0xFF007AD9)]),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Мои школы',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: _navigateToAddSchool,
                  ),
                ],
              ),
            ),
            isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : schools.isEmpty
                    ? const Expanded(
                        child: Center(
                          child: Text(
                            'У вас пока нет школ.\nНажмите на +, чтобы добавить первую.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: schools.length,
                          itemBuilder: (_, index) {
                            final school = schools[index];
                            return _buildSchoolCard(school);
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}
