import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class SignUpController extends GetxController {
  // ==========================
  // Обычная регистрация
  // ==========================
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final RxBool isShowPassword = true.obs;
  final RxString selectedRole = "Тренер".obs;

  // ==========================
  // ✅ Клубная заявка
  // ==========================
  final GlobalKey<FormState> clubFormKey = GlobalKey<FormState>();

  final TextEditingController clubNameController = TextEditingController();
  final TextEditingController clubDescriptionController = TextEditingController();
  final TextEditingController clubAddressController = TextEditingController();
  final TextEditingController clubEmailController = TextEditingController();
  final TextEditingController clubPasswordController = TextEditingController();

  final RxBool clubIsShowPassword = true.obs;
  final RxBool clubAgreedToTerms = false.obs;

  final RxBool isLoading = false.obs;

  void resetClubForm() {
    clubNameController.clear();
    clubDescriptionController.clear();
    clubAddressController.clear();
    clubEmailController.clear();
    clubPasswordController.clear();
    clubIsShowPassword.value = true;
    clubAgreedToTerms.value = false;
  }

  // ==========================
  // Обычная регистрация
  // ==========================
  Future<void> registerUser() async {
    if (isLoading.value) return;

    if (firstNameController.text.trim().isEmpty ||
        lastNameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      Get.snackbar("Ошибка", "Заполните все поля");
      return;
    }

    final uri = Uri.parse("https://sportotekaapp.ru/api/register.php");
    final body = {
      "first_name": firstNameController.text.trim(),
      "last_name": lastNameController.text.trim(),
      "email": emailController.text.trim(),
      "password": passwordController.text.trim(),
      "role": getApiRole(selectedRole.value),
    };

    isLoading.value = true;

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      final data = _safeJson(response.body);

      if (response.statusCode != 200) {
        throw "HTTP ${response.statusCode}: ${data?['message'] ?? 'Ошибка сервера'}";
      }

      if (data == null || data["status"] != "success") {
        Get.snackbar("Ошибка", data?["message"] ?? "Неизвестная ошибка");
        return;
      }

      await _saveUserData(data);

      Get.snackbar("Успех", "Регистрация прошла успешно");

      // роутинг по роли
      final role = (data['user']?['role'] ?? getApiRole(selectedRole.value)).toString().trim();
      // ✅ всегда идём в Shell с нижним меню
if (role == 'club') {
  Get.offAllNamed(AppRoutes.homeContainerScreen, arguments: {"tab": 4});
} else {
  Get.offAllNamed(AppRoutes.homeContainerScreen, arguments: {"tab": 0});
}
    } catch (e) {
      Get.snackbar("Ошибка регистрации", e.toString(), duration: const Duration(seconds: 5));
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================
  // ✅ Клубная заявка + авто-вход
  // ==========================
  Future<void> submitClubApplication() async {
    if (isLoading.value) return;

    if (clubNameController.text.trim().isEmpty ||
        clubDescriptionController.text.trim().isEmpty ||
        clubAddressController.text.trim().isEmpty ||
        clubEmailController.text.trim().isEmpty ||
        clubPasswordController.text.trim().isEmpty) {
      Get.snackbar("Ошибка", "Заполните все поля заявки");
      return;
    }

    if (!GetUtils.isEmail(clubEmailController.text.trim())) {
      Get.snackbar("Ошибка", "Введите корректный e-mail");
      return;
    }

    if (clubPasswordController.text.trim().length < 6) {
      Get.snackbar("Ошибка", "Пароль должен быть минимум 6 символов");
      return;
    }

    if (!clubAgreedToTerms.value) {
      Get.snackbar("Требуется согласие", "Подтвердите Условия и Политику");
      return;
    }

    final uri = Uri.parse("https://sportotekaapp.ru/api/register_club.php");

    final body = {
      "club_name": clubNameController.text.trim(),
      "club_description": clubDescriptionController.text.trim(),
      "club_address": clubAddressController.text.trim(),
      "email": clubEmailController.text.trim(),
      "password": clubPasswordController.text.trim(),
      "role": "club",
      "status": "pending",
    };

    isLoading.value = true;

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      final data = _safeJson(response.body);

      if (response.statusCode != 200) {
        throw "HTTP ${response.statusCode}: ${data?['message'] ?? 'Ошибка сервера'}";
      }

      if (data == null || data["status"] != "success") {
        Get.snackbar("Ошибка", data?["message"] ?? "Неизвестная ошибка");
        return;
      }

      if (Get.isBottomSheetOpen == true) Get.back();

      await _saveClubUserData(data);

      Get.snackbar(
        "Заявка отправлена",
        "Клуб создан. Доступ будет расширен после подтверждения.",
        duration: const Duration(seconds: 4),
      );

      // клуб — сразу в панель клуба
     Get.offAllNamed(AppRoutes.homeContainerScreen, arguments: {"tab": 4});
    } catch (e) {
      Get.snackbar("Ошибка", e.toString(), duration: const Duration(seconds: 5));
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================
  // Сохранение данных
  // ==========================
  Future<void> _saveUserData(Map<String, dynamic> data) async {
    // ✅ чистим старьё
    await PrefUtils.clearAll();

    final pref = PrefUtils();
    await pref.init();

    await PrefUtils.setIsSignIn(true);

    // ✅ userId (очень важно!)
    final user = (data['user'] ?? {}) as Map;
    final int userId = int.tryParse((user['id'] ?? 0).toString()) ?? 0;
    if (userId > 0) {
      await PrefUtils.setUserId(userId);
    }

    // ✅ user data (instance методы)
    await pref.setUserRole((user['role'] ?? getApiRole(selectedRole.value)).toString());
    await pref.setUserFirstName((user['first_name'] ?? '').toString());
    await pref.setUserLastName((user['last_name'] ?? '').toString());
    await pref.setUserEmail((user['email'] ?? '').toString());
  }

  Future<void> _saveClubUserData(Map<String, dynamic> data) async {
    // ✅ чистим старьё
    await PrefUtils.clearAll();

    final pref = PrefUtils();
    await pref.init();

    await PrefUtils.setIsSignIn(true);

    // Вариант 1: backend вернул user
    if (data['user'] != null && data['user'] is Map) {
      final u = (data['user'] as Map);

      final int userId = int.tryParse((u['id'] ?? 0).toString()) ?? 0;
      if (userId > 0) {
        await PrefUtils.setUserId(userId);
      }

      await pref.setUserRole((u['role'] ?? 'club').toString());
      await pref.setUserFirstName((u['first_name'] ?? clubNameController.text.trim()).toString());
      await pref.setUserLastName((u['last_name'] ?? '').toString());
      await pref.setUserEmail((u['email'] ?? clubEmailController.text.trim()).toString());
      return;
    }

    // Вариант 2: backend без user — сохраняем из формы
    await pref.setUserRole('club');
    await pref.setUserFirstName(clubNameController.text.trim());
    await pref.setUserLastName('');
    await pref.setUserEmail(clubEmailController.text.trim());
  }

  // ==========================
  // Роли для API
  // ==========================
 String getApiRole(String role) {
  final r = role.trim().toLowerCase();

  // ✅ если уже пришла API-роль — возвращаем как есть
  const api = {"coach", "player", "parent", "user", "club"};
  if (api.contains(r)) return r;

  // ✅ если пришла русская строка
  switch (role) {
    case "Тренер":
      return "coach";
    case "Игрок":
      return "player";
    case "Родитель":
      return "parent";
    case "Пользователь":
      return "user";
    case "Клуб":
      return "club";
    default:
      return "coach";
  }
}

  Map<String, dynamic>? _safeJson(String raw) {
    try {
      final x = jsonDecode(raw);
      if (x is Map<String, dynamic>) return x;
      if (x is Map) return Map<String, dynamic>.from(x);
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();

    clubNameController.dispose();
    clubDescriptionController.dispose();
    clubAddressController.dispose();
    clubEmailController.dispose();
    clubPasswordController.dispose();

    super.onClose();
  }
}
