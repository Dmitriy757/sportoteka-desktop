import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/widgets/support_button.dart';

class HelpProfileScreen extends StatelessWidget {
  const HelpProfileScreen({super.key});

  static const String deleteAccountUrl =
      'https://sportoteka.by/api/delete_account.php';
  static const String termsUrl = 'https://sportoteka.by/terms';
  static const String privacyUrl = 'https://sportoteka.by/privacy';
  static const String rulesUrl = 'https://sportoteka.by/community-rules';

  static const Color _bg = Color(0xFFF6F8FA);
  static const Color _card = Colors.white;
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF667085);
  static const Color _lightMuted = Color(0xFF98A2B3);
  static const Color _border = Color(0xFFE4E7EC);
  static const Color _borderSoft = Color(0xFFF0F2F5);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _blueSoft = Color(0xFFEFF6FF);
  static const Color _green = Color(0xFF178A45);
  static const Color _greenSoft = Color(0xFFEAF7EF);
  static const Color _teal = Color(0xFF0F766E);
  static const Color _tealSoft = Color(0xFFE6F6F4);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _purpleSoft = Color(0xFFF4EBFF);
  static const Color _orange = Color(0xFFEA580C);
  static const Color _orangeSoft = Color(0xFFFFF4ED);
  static const Color _red = Color(0xFFDC2626);
  static const Color _redSoft = Color(0xFFFFEDED);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 720;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: isWide ? _tabletBody(context) : _mobileBody(context),
      ),
    );
  }

  Widget _tabletBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heroCard(context, compact: false),
                const SizedBox(height: 12),
                _supportCard(),
                const Spacer(),
                _versionText(),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _sectionCard(
                    title: 'Профиль',
                    subtitle: 'Личные данные, параметры приложения и подписка',
                    children: _profileItems(context).map(_row).toList(),
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    title: 'Документы',
                    subtitle: 'Правила сервиса и юридическая информация',
                    children: _documentItems().map(_row).toList(),
                  ),
                  const SizedBox(height: 12),
                  _securityCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileBody(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _heroCard(context, compact: true),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Профиль',
                subtitle: 'Основные параметры аккаунта',
                children: _profileItems(context).map(_row).toList(),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Документы',
                subtitle: 'Правила и политика сервиса',
                children: _documentItems().map(_row).toList(),
              ),
              const SizedBox(height: 12),
              _supportCard(),
              const SizedBox(height: 12),
              _securityCard(context),
              const SizedBox(height: 16),
              _versionText(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _heroCard(BuildContext context, {required bool compact}) {
    return _plainCard(
      padding: EdgeInsets.all(compact ? 16 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _topButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Назад',
                onTap: () => Get.back(),
              ),
              const Spacer(),
              _topButton(
                icon: Icons.logout_rounded,
                tooltip: 'Выйти',
                danger: true,
                onTap: () => _showLogoutDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _blueSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.manage_accounts_outlined, color: _blue, size: 30),
          ),
          const SizedBox(height: 14),
          const Text(
            'Настройки профиля',
            style: TextStyle(
              fontSize: 24,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: _text,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Профиль, документы, поддержка и безопасность собраны в отдельном рабочем экране.',
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  List<_HelpProfileItem> _profileItems(BuildContext context) {
    return [
      _HelpProfileItem(
        title: 'Редактировать профиль',
        subtitle: 'Фото, имя и данные аккаунта',
        icon: Icons.edit_outlined,
        accent: _blue,
        soft: _blueSoft,
        onTap: () => Get.toNamed(AppRoutes.myProfileScreen),
      ),
      _HelpProfileItem(
        title: 'Настройки приложения',
        subtitle: 'Уведомления и параметры',
        icon: Icons.settings_outlined,
        accent: _teal,
        soft: _tealSoft,
        onTap: () => Get.toNamed(AppRoutes.settingsScreen),
      ),
      _HelpProfileItem(
        title: 'Мои подписки',
        subtitle: 'Тарифы и доступ к функциям',
        icon: Icons.subscriptions_outlined,
        accent: _purple,
        soft: _purpleSoft,
        onTap: () => Get.toNamed(AppRoutes.subscriptionsScreen),
      ),
    ];
  }

  List<_HelpProfileItem> _documentItems() {
    return [
      _HelpProfileItem(
        title: 'Условия использования',
        subtitle: 'Правила работы сервиса',
        icon: Icons.description_outlined,
        accent: _teal,
        soft: _tealSoft,
        onTap: () => _openUrl(termsUrl),
      ),
      _HelpProfileItem(
        title: 'Политика конфиденциальности',
        subtitle: 'Как обрабатываются данные',
        icon: Icons.privacy_tip_outlined,
        accent: _blue,
        soft: _blueSoft,
        onTap: () => _openUrl(privacyUrl),
      ),
      _HelpProfileItem(
        title: 'Правила сообщества',
        subtitle: 'Поведение и публикации',
        icon: Icons.shield_outlined,
        accent: _green,
        soft: _greenSoft,
        onTap: () => _openUrl(rulesUrl),
      ),
    ];
  }

  Widget _supportCard() {
    return _plainCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.support_agent_rounded, _green, _greenSoft),
              const SizedBox(width: 10),
              const Expanded(child: Text('Поддержка', style: _sectionStyle)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Связь с командой Sportoteka и помощь по работе приложения.',
            style: _captionStyle,
          ),
          const SizedBox(height: 12),
          const SupportButton(),
        ],
      ),
    );
  }

  Widget _securityCard(BuildContext context) {
    return _sectionCard(
      title: 'Безопасность',
      subtitle: 'Управление текущим сеансом и аккаунтом',
      children: [
        _row(
          _HelpProfileItem(
            title: 'Выйти из аккаунта',
            subtitle: 'Завершить текущий сеанс',
            icon: Icons.logout_rounded,
            accent: _red,
            soft: _redSoft,
            onTap: () => _showLogoutDialog(context),
          ),
        ),
        _row(
          _HelpProfileItem(
            title: 'Удалить аккаунт',
            subtitle: 'Навсегда удалить профиль и данные',
            icon: Icons.delete_forever_outlined,
            accent: _red,
            soft: _redSoft,
            onTap: () => _showDeleteAccountSheet(context),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
    String? subtitle,
  }) {
    return _plainCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _sectionStyle),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: _captionStyle),
          ],
          const SizedBox(height: 8),
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, color: _borderSoft),
          ],
        ],
      ),
    );
  }

  Widget _row(_HelpProfileItem item) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              _iconBadge(item.icon, item.accent, item.soft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _text,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _captionStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: _lightMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plainCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _iconBadge(IconData icon, Color color, Color soft) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _topButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? _red : _text;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: danger ? _red.withOpacity(.18) : _border),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }

  Widget _versionText() {
    return const Center(
      child: Text(
        'Sportoteka • настройки профиля',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _lightMuted,
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar('Ошибка', 'Не удалось открыть ссылку');
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _iconBadge(Icons.logout_rounded, _red, _redSoft),
                const SizedBox(height: 14),
                const Text(
                  'Выйти из аккаунта?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'После выхода потребуется снова войти в приложение.',
                  textAlign: TextAlign.center,
                  style: _captionStyle,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await _clearLocalAuth();
                          Get.offAllNamed(AppRoutes.loginScreen);
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Выйти'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteAccountSheet(BuildContext context) {
    bool agree = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    _iconBadge(Icons.warning_amber_rounded, _red, _redSoft),
                    const SizedBox(height: 14),
                    const Text(
                      'Удалить аккаунт?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Это действие необратимо. Профиль и связанные данные будут удалены навсегда.',
                      textAlign: TextAlign.center,
                      style: _captionStyle,
                    ),
                    const SizedBox(height: 14),
                    Material(
                      color: const Color(0xFFFAFBFC),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setSheetState(() => agree = !agree),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _borderSoft),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: agree,
                                activeColor: _red,
                                onChanged: (v) => setSheetState(() => agree = v ?? false),
                              ),
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: Text(
                                    'Я понимаю последствия и хочу удалить аккаунт навсегда.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _text,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: _border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Отмена'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: agree
                                ? () async {
                                    Navigator.pop(context);
                                    await _deleteAccount();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: _red,
                              disabledBackgroundColor: _redSoft,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Удалить'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final userId = await PrefUtils.getUserId();

    if (userId == 0) {
      Get.snackbar('Ошибка', 'Не найден идентификатор пользователя.');
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse(deleteAccountUrl),
        body: {'user_id': userId.toString()},
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        bool ok = false;
        String message = 'Аккаунт удалён.';

        try {
          final jsonBody = json.decode(resp.body);
          ok = jsonBody['success'] == true;
          if (jsonBody['message'] is String) message = jsonBody['message'];
        } catch (_) {
          ok = true;
        }

        if (ok) {
          await _clearLocalAuth();
          Get.snackbar('Готово', message);
          Get.offAllNamed(AppRoutes.loginScreen);
        } else {
          Get.snackbar('Ошибка', message);
        }
      } else {
        Get.snackbar('Ошибка', 'Сервер вернул статус ${resp.statusCode}.');
      }
    } catch (_) {
      Get.snackbar('Сеть недоступна', 'Не удалось связаться с сервером. Повторите позже.');
    }
  }

  Future<void> _clearLocalAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefUtils.userIdKey);
    await prefs.remove(PrefUtils.teamIdKey);
    await prefs.remove(PrefUtils.userRole);
    await prefs.remove(PrefUtils.userFirstName);
    await prefs.remove(PrefUtils.userLastName);
    await prefs.remove(PrefUtils.userEmail);
    await prefs.remove(PrefUtils.signIn);
  }

  static const TextStyle _sectionStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
    color: _text,
  );

  static const TextStyle _captionStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: _muted,
    height: 1.25,
  );
}

class _HelpProfileItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color soft;
  final VoidCallback onTap;

  const _HelpProfileItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.soft,
    required this.onTap,
  });
}
