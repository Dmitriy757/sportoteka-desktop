import 'dart:io';
import 'package:flutter/material.dart'; // Добавить этот импорт
import 'package:get/get.dart';

class SnackbarHelper {
  static void showSuccess(String message) {
    Get.snackbar(
      "Готово",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF16A34A),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  static void showError(String message) {
    Get.snackbar(
      "Ошибка",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFDC2626),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  static void showInfo(String message) {
    Get.snackbar(
      "Внимание",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
}

class FileHelper {
  static Future<void> cleanupTempFile(File? file) async {
    if (file != null && await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        debugPrint('Error deleting temp file: $e');
      }
    }
  }
}

class ValidationHelper {
  static bool isValidVideoUrl(String url) {
    return url.isNotEmpty && (url.startsWith('http') || url.startsWith('https'));
  }

  static bool isValidPlayerId(int? id) {
    return id != null && id > 0;
  }
}