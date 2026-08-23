import 'package:flutter/material.dart';

/// Единый контракт переходов из ИИ-чата.
/// Подключите реальные экраны проекта в switch ниже.
class AiWorkspaceNavigationBridge {
  static Future<void> open(
    BuildContext context, {
    required String target,
    required Map<String, dynamic> payload,
    required Future<void> Function(String, Map<String, dynamic>) fallback,
  }) async {
    switch (target) {
      case 'calendar':
      case 'attendance':
      case 'match':
      case 'tracker':
      case 'report':
      case 'plans':
      case 'training_graphics':
        await fallback(target, payload);
        return;
      default:
        await fallback(target, payload);
    }
  }
}
