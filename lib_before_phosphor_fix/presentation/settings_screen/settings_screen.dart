import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'controller/settings_controller.dart';

/// ✅ Настройки (Sportoteka style)
/// - русские тексты
/// - секции + карточки
/// - Switch / стрелки / bottom-sheet
/// - пока заглушки (Get.snackbar / TODO)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(SettingsController());
  }

  // =============================
  // UI helpers
  // =============================
  Future<void> _showLanguagePicker() async {
    final langs = ["Русский", "English", "Беларуская"];
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _BottomSheetContainer(
          title: "Язык приложения",
          child: Column(
            children: [
              for (final l in langs)
                _RadioRow(
                  title: l,
                  selected: c.language == l,
                  onTap: () {
                    c.setLanguage(l);
                    Navigator.pop(context);
                    Get.snackbar("Готово", "Язык: $l (пока заглушка)");
                  },
                ),
              const SizedBox(height: 8),
              _Hint(
                "Позже подключим настоящую локализацию: GetX translations / intl.\n"
                "Сейчас это просто сохранение выбора.",
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showClearCacheDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Очистить кэш?"),
          content: const Text(
            "Удалим локальные временные файлы: изображения, превью, списки.\n\n"
            "Позже подключим реальную очистку (cache manager / файловая папка).",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Отмена"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
              ),
              child: const Text("Очистить"),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      Get.snackbar("Готово", "Кэш очищен (пока заглушка)");
    }
  }

  Future<void> _showChangePasswordStub() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        final oldCtrl = TextEditingController();
        final newCtrl = TextEditingController();
        final repeatCtrl = TextEditingController();

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _BottomSheetContainer(
            title: "Сменить пароль",
            child: Column(
              children: [
                _Field(
                  controller: oldCtrl,
                  label: "Текущий пароль",
                  obscure: true,
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: newCtrl,
                  label: "Новый пароль",
                  obscure: true,
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: repeatCtrl,
                  label: "Повтор нового пароля",
                  obscure: true,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Get.snackbar(
                        "Заглушка",
                        "Потом подключим API: change_password.php\n"
                        "и валидацию + правила сложности.",
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Сохранить"),
                  ),
                ),
                const SizedBox(height: 8),
                _Hint(
                  "Что будет дальше:\n"
                  "• проверка текущего пароля\n"
                  "• правила сложности\n"
                  "• обновление на сервере\n"
                  "• принудительный logout на других устройствах (опционально)",
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteAccountStub() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final confirm = TextEditingController();
        bool can = false;

        return StatefulBuilder(
          builder: (ctx, setD) {
            void recompute() {
              final v = confirm.text.trim().toLowerCase();
              final next = v == "удалить аккаунт";
              if (next != can) setD(() => can = next);
            }

            return AlertDialog(
              title: const Text("Удалить аккаунт навсегда?"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Это действие необратимо.\n\n"
                    "Для подтверждения введите фразу:\n"
                    "«Удалить аккаунт»",
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirm,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Введите: Удалить аккаунт",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => recompute(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Отмена"),
                ),
                ElevatedButton(
                  onPressed: can ? () => Navigator.pop(ctx, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text("Удалить"),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) {
      Get.snackbar(
        "Заглушка",
        "Потом подключим API delete_account.php\n"
        "и удаление данных/сессий.",
      );
    }
  }

  // =============================
  // UI
  // =============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Настройки",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: GetBuilder<SettingsController>(
        builder: (_) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // =========================
              // Профиль/аккаунт (заглушка)
              // =========================
              _HeaderCard(
                title: "Параметры приложения",
                subtitle:
                    "Здесь будут настройки уведомлений, интерфейса, безопасности и сети.",
                icon: Icons.tune_rounded,
              ),
              const SizedBox(height: 14),

              // =========================
              // Уведомления
              // =========================
              const _SectionTitle(title: "Уведомления", right: "управление"),
              const SizedBox(height: 8),
              _CardGroup(
                children: [
                  _ToggleTile(
                    icon: Icons.notifications_active_outlined,
                    title: "Push-уведомления",
                    subtitle: "Общие уведомления от Sportoteka",
                    value: c.pushEnabled,
                    onChanged: (_) => c.togglePush(),
                  ),
                  _DividerLine(),
                  _ToggleTile(
                    icon: Icons.chat_bubble_outline,
                    title: "Сообщения",
                    subtitle: "Уведомлять о новых сообщениях и чатах",
                    value: c.messageNotifications,
                    onChanged: (_) => c.toggleMessages(),
                  ),
                  _DividerLine(),
                  _ToggleTile(
                    icon: Icons.event_available_outlined,
                    title: "Напоминания о тренировках",
                    subtitle: "За 1 час / за 1 день (потом добавим выбор)",
                    value: c.trainingReminders,
                    onChanged: (_) => c.toggleTrainingReminders(),
                  ),
                  const SizedBox(height: 10),
                  _Hint(
                    "Дальше можно расширить:\n"
                    "• отдельные типы: игры/события/оценки/посещаемость\n"
                    "• тихие часы (ночью не беспокоить)\n"
                    "• критические уведомления (травма/медкарта)\n"
                    "• выбор звука и вибрации",
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // =========================
              // Безопасность
              // =========================
              const _SectionTitle(title: "Безопасность", right: "доступ"),
              const SizedBox(height: 8),
              _CardGroup(
                children: [
                  _ToggleTile(
                    icon: Icons.face_retouching_natural_outlined,
                    title: "Face ID / Touch ID",
                    subtitle: "Быстрый вход без пароля (заглушка)",
                    value: c.faceIdEnabled,
                    onChanged: (_) => c.toggleFaceId(),
                  ),
                  _DividerLine(),
                  _ToggleTile(
                    icon: Icons.lock_clock_outlined,
                    title: "Автоблокировка",
                    subtitle: "Блокировать при сворачивании (позже таймер)",
                    value: c.autoLockEnabled,
                    onChanged: (_) => c.toggleAutoLock(),
                  ),
                  _DividerLine(),
                  _ActionTile(
                    icon: Icons.password_outlined,
                    title: "Сменить пароль",
                    subtitle: "Откроем форму (пока заглушка)",
                    onTap: _showChangePasswordStub,
                  ),
                  const SizedBox(height: 10),
                  _Hint(
                    "Что можно добавить:\n"
                    "• 2FA (код на email)\n"
                    "• список устройств и выход со всех устройств\n"
                    "• PIN-код внутри приложения",
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // =========================
              // Интерфейс
              // =========================
              const _SectionTitle(title: "Интерфейс", right: "вид"),
              const SizedBox(height: 8),
              _CardGroup(
                children: [
                  _ToggleTile(
                    icon: Icons.dark_mode_outlined,
                    title: "Тёмная тема",
                    subtitle:
                        "Потом подключим реальное переключение ThemeMode",
                    value: c.darkMode,
                    onChanged: (_) {
                      c.toggleDarkMode();
                      Get.snackbar(
                        "Заглушка",
                        "Тему переключим глобально на следующем шаге",
                      );
                    },
                  ),
                  _DividerLine(),
                  _ToggleTile(
                    icon: Icons.vibration_outlined,
                    title: "Вибрация",
                    subtitle: "Отклик на нажатия и действия",
                    value: c.haptics,
                    onChanged: (_) => c.toggleHaptics(),
                  ),
                  _DividerLine(),
                  _ToggleTile(
                    icon: Icons.volume_up_outlined,
                    title: "Звуки",
                    subtitle: "Звуки уведомлений и интерфейса",
                    value: c.sounds,
                    onChanged: (_) => c.toggleSounds(),
                  ),
                  _DividerLine(),
                  _ActionTile(
                    icon: Icons.language_outlined,
                    title: "Язык",
                    subtitle: "Сейчас: ${c.language}",
                    onTap: _showLanguagePicker,
                  ),
                  const SizedBox(height: 10),
                  _Hint(
                    "Можно расширить:\n"
                    "• размер шрифта\n"
                    "• компактный режим списков\n"
                    "• настройка главного экрана (блоки/порядок)\n"
                    "• цветовой акцент клуба/команды",
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // =========================
              // Видео / медиа
              // =========================
              const _SectionTitle(title: "Видео и медиа", right: "контент"),
              const SizedBox(height: 8),
              _CardGroup(
                children: [
                  _ToggleTile(
                    icon: Icons.play_circle_outline,
                    title: "Автовоспроизведение видео",
                    subtitle: "Reels / упражнения / лента (пока заглушка)",
                    value: c.autoplayVideo,
                    onChanged: (_) => c.toggleAutoplay(),
                  ),
                  _DividerLine(),
                  _ToggleTile(
                    icon: Icons.image_outlined,
                    title: "Предзагрузка изображений",
                    subtitle: "Быстрее лента, но больше трафика",
                    value: c.preloadImages,
                    onChanged: (_) => c.togglePreloadImages(),
                  ),
                  const SizedBox(height: 10),
                  _Hint(
                    "Потом добавим:\n"
                    "• качество загрузки фото/видео\n"
                    "• ограничение по мобильной сети\n"
                    "• выбор кодека/сжатия",
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // =========================
              // Сеть / Кэш
              // =========================
              const _SectionTitle(title: "Сеть и кэш", right: "память"),
              const SizedBox(height: 8),
              _CardGroup(
                children: [
                  _ToggleTile(
                    icon: Icons.wifi_outlined,
                    title: "Загрузка только по Wi-Fi",
                    subtitle: "Фото/видео/файлы — только по Wi-Fi",
                    value: c.wifiOnlyUploads,
                    onChanged: (_) => c.toggleWifiOnlyUploads(),
                  ),
                  _DividerLine(),
                  _ActionTile(
                    icon: Icons.delete_sweep_outlined,
                    title: "Очистить кэш",
                    subtitle: "Удалить временные файлы (заглушка)",
                    onTap: _showClearCacheDialog,
                  ),
                  const SizedBox(height: 10),
                  _Hint(
                    "Подключим позже:\n"
                    "• реальный размер кэша (MB)\n"
                    "• очистка превью видео (thumbnails)\n"
                    "• офлайн-режим для планов и схем",
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // =========================
              // О приложении
              // =========================
              const _SectionTitle(title: "О приложении", right: "инфо"),
              const SizedBox(height: 8),
              _CardGroup(
                children: [
                  _ActionTile(
                    icon: Icons.info_outline,
                    title: "Версия",
                    subtitle: "Пока заглушка (потом из package_info_plus)",
                    onTap: () => Get.snackbar("Sportoteka", "Версия: 1.0.0 (stub)"),
                  ),
                  _DividerLine(),
                  _ActionTile(
                    icon: Icons.description_outlined,
                    title: "Политика конфиденциальности",
                    subtitle: "Откроем страницу/вебвью (позже)",
                    onTap: () => Get.snackbar("Заглушка", "Откроем WebView"),
                  ),
                  _DividerLine(),
                  _ActionTile(
                    icon: Icons.support_agent_outlined,
                    title: "Поддержка",
                    subtitle: "Чат/почта/тикет (позже)",
                    onTap: () => Get.snackbar("Заглушка", "Откроем поддержку"),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // =========================
              // Опасная зона
              // =========================
              const _SectionTitle(title: "Опасная зона", right: ""),
              const SizedBox(height: 8),
              _DangerCard(
                title: "Удаление аккаунта",
                text:
                    "Аккаунт будет удалён без возможности восстановления.\n"
                    "Потом добавим экспорт данных и подтверждение по email.",
                buttonText: "Удалить аккаунт",
                onTap: _showDeleteAccountStub,
              ),
            ],
          );
        },
      ),
    );
  }
}

// =====================================================
// WIDGETS (Sportoteka style)
// =====================================================

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String right;

  const _SectionTitle({required this.title, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Text(
          right,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CardGroup extends StatelessWidget {
  final List<Widget> children;

  const _CardGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(children: children),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: AppColors.textTertiary.withOpacity(0.16),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LeftIcon(icon: icon),
        const SizedBox(width: 10),
        Expanded(
          child: _TitleSubtitle(title: title, subtitle: subtitle),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primaryGreen,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _LeftIcon(icon: icon),
              const SizedBox(width: 10),
              Expanded(
                child: _TitleSubtitle(title: title, subtitle: subtitle),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeftIcon extends StatelessWidget {
  final IconData icon;

  const _LeftIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppColors.primaryGreen),
    );
  }
}

class _TitleSubtitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TitleSubtitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            fontSize: 13,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textTertiary.withOpacity(0.16)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          height: 1.25,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  final String title;
  final String text;
  final String buttonText;
  final VoidCallback onTap;

  const _DangerCard({
    required this.title,
    required this.text,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Опасная зона",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              color: Color(0xFFB91C1C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
              label: Text(
                buttonText,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                side: BorderSide(color: const Color(0xFFB91C1C).withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// Bottom sheet UI
// =====================================================

class _BottomSheetContainer extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheetContainer({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withOpacity(0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _RadioRow({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primaryGreen : AppColors.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;

  const _Field({
    required this.controller,
    required this.label,
    required this.obscure,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
