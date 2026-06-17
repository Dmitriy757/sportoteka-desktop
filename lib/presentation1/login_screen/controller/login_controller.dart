import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/core/push/push_service.dart';

class LoginController extends GetxController {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final RxBool isShowPassword = true.obs;
  final RxBool isLoading = false.obs;

  Future<void> loginUser() async {
  final uri = Uri.parse("https://sportotekaapp.ru/api/login.php");

  try {
    final response = await http.post(
      uri,
      body: {
        'email': emailController.text.trim(),
        'password': passwordController.text.trim(),
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['status'] == 'success' && data['user'] != null) {
        final u = data['user'];

        final int userId = int.tryParse(u['id'].toString()) ?? 0;
        if (userId <= 0) {
          Get.snackbar("Ошибка", "Не удалось получить ID пользователя");
          return;
        }

        // ✅ ОЧЕНЬ ВАЖНО: очищаем старое
        await PrefUtils.clearAll();

        // ✅ сохраняем нового пользователя
        await PrefUtils.setIsSignIn(true);
        await PrefUtils.setUserId(userId);
        await PrefUtils.setRole((u['role'] ?? '').toString());

        await PrefUtils.setUserFirstName((u['first_name'] ?? '').toString());
        await PrefUtils.setUserLastName((u['last_name'] ?? '').toString());
        await PrefUtils.setUserEmail((u['email'] ?? '').toString());

print("✅ LOGIN SUCCESS userId=$userId (before push init)");
try {
  await PushService.instance.init(userId: userId);
  print("✅ PUSH INIT DONE");
} catch (e) {
  print("❌ PUSH INIT ERROR: $e");
}
print("➡️ GO ROUTE NOW");

        // роутинг по роли
        final role = (u['role'] ?? '').toString().trim();
        if (role == 'club') {
          Get.offAllNamed(AppRoutes.clubDashboardScreen);
        } else {
          Get.offAllNamed(AppRoutes.homeContainerScreen);
        }
      } else {
        Get.snackbar("Ошибка входа", data['message'] ?? "Неверный логин или пароль");
      }
    } else {
      Get.snackbar("Ошибка", "Сервер вернул ${response.statusCode}");
    }
  } catch (e) {
    Get.snackbar("Ошибка", "Не удалось подключиться: $e");
  }
}

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
