import 'dart:ui';

import 'package:flutter/material.dart';

/// ================== ЕДИНАЯ ЦВЕТОВАЯ ПАЛИТРА SPORTOTEKA (ФК ГОМЕЛЬ) ==================
/// Основной цвет: #00a750 - зеленый ФК Гомель
/// Дополнительные цвета: градиенты, акценты, фоны

class AppColors {
  // =============== ОСНОВНЫЕ ЦВЕТА (Primary) ===============
  static const Color primaryGreen = Color(0xFF00A750);      // Основной зеленый ФК Гомель
  static const Color primaryDark = Color(0xFF008C40);       // Темный зеленый
  static const Color primaryLight = Color(0xFF00C060);      // Светлый зеленый
  static const Color primaryExtraLight = Color(0xFFE8F5E9); // Очень светлый зеленый (фон)

  // =============== АКЦЕНТНЫЕ ЦВЕТА (Accent) ===============
  static const Color accentGreen = Color(0xFF7ED321);       // Яркий акцентный зеленый
  static const Color accentYellow = Color(0xFFFFCC00);      // Желтый акцент
  static const Color accentBlue = Color(0xFF0066CC);        // Синий акцент
  static const Color accentRed = Color(0xFFFF6B6B);         // Красный акцент

  // =============== НЕЙТРАЛЬНЫЕ ЦВЕТА (Neutral) ===============
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F9FA);        // Основной фон приложения
  static const Color card = Color(0xFFFFFFFF);             // Фон карточек
  static const Color border = Color(0xFFE5E7EB);           // Цвет границ

  // =============== ТЕКСТ (Text) ===============
  static const Color textPrimary = Color(0xFF1A1A1A);       // Основной текст
  static const Color textSecondary = Color(0xFF666666);     // Вторичный текст
  static const Color textTertiary = Color(0xFF999999);      // Третичный текст
  static const Color textInverted = Color(0xFFFFFFFF);      // Инвертированный текст

  // =============== СИСТЕМНЫЕ (System) ===============
  static const Color success = Color(0xFF34C759);           // Успех
  static const Color warning = Color(0xFFFF9500);           // Предупреждение
  static const Color error = Color(0xFFFF3B30);             // Ошибка
  static const Color info = Color(0xFF007AFF);              // Информация

  // =============== ГРАДИЕНТЫ (Gradients) ===============
  static const LinearGradient greenGradient = LinearGradient(
    colors: [primaryGreen, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightGreenGradient = LinearGradient(
    colors: [Color(0xFFF5FFF9), primaryExtraLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [white, Color(0xFFF5F7FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // =============== ТЕНИ (Shadows) ===============
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static const BoxShadow buttonShadow = BoxShadow(
    color: Color(0x4000A750),
    blurRadius: 8,
    offset: Offset(0, 4),
  );
}

/// ================== ТЕМЫ ДЛЯ КАРТОЧЕК МОДУЛЕЙ ==================
class ModuleThemes {
  // Основные модули (зеленая тема)
  static const ModuleTheme basic = ModuleTheme(
    color: Color(0xFFE8F5E9),
    iconColor: AppColors.primaryGreen,
  );

  // Календарь и расписание
  static const ModuleTheme calendar = ModuleTheme(
    color: Color(0xFFE8F8E8),
    iconColor: AppColors.primaryGreen,
  );

  // Тренеры и персонал
  static const ModuleTheme trainers = ModuleTheme(
    color: Color(0xFFE8F2FF),
    iconColor: AppColors.accentBlue,
  );

  // Посещаемость и статистика
  static const ModuleTheme attendance = ModuleTheme(
    color: Color(0xFFE6F7FF),
    iconColor: AppColors.info,
  );

  // Чат и коммуникации
  static const ModuleTheme chat = ModuleTheme(
    color: Color(0xFFF0F2FF),
    iconColor: Color(0xFF7E3AED),
  );

  // Планы и конспекты
  static const ModuleTheme plans = ModuleTheme(
    color: Color(0xFFFFF4E6),
    iconColor: AppColors.warning,
  );

  // Редактор и дизайн
  static const ModuleTheme editor = ModuleTheme(
    color: Color(0xFFF3E8FF),
    iconColor: Color(0xFF7E3AED),
  );

  // Видео и медиа
  static const ModuleTheme video = ModuleTheme(
    color: Color(0xFFFFF9E6),
    iconColor: AppColors.accentYellow,
  );

  // Аналитика и карты
  static const ModuleTheme analytics = ModuleTheme(
    color: Color(0xFFE8F5FF),
    iconColor: Color(0xFF00B8D4),
  );

  // Новости и лента
  static const ModuleTheme news = ModuleTheme(
    color: Color(0xFFFFF0F0),
    iconColor: AppColors.accentRed,
  );

  // Опасная зона
  static const ModuleTheme danger = ModuleTheme(
    color: Color(0xFFFFF5F5),
    iconColor: Color(0xFFB91C1C),
  );
}

class ModuleTheme {
  final Color color;
  final Color iconColor;

  const ModuleTheme({
    required this.color,
    required this.iconColor,
  });
}