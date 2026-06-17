import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final String latestVersion;
  final String title;
  final String message;

  final String apkUrl;
  final String ruStoreUrl;
  final String appleUrl;

  const UpdateRequiredScreen({
    super.key,
    required this.latestVersion,
    required this.title,
    required this.message,
    required this.apkUrl,
    required this.ruStoreUrl,
    required this.appleUrl,
  });

  static const _g1 = Color(0xFF00A750);
  static const _g2 = Color(0xFF008C40);

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;

    return WillPopScope(
      onWillPop: () async => false, // ✅ запрет назад
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_g1, _g2],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  SizedBox(height: safeTop > 0 ? 10 : 22),

                  // ✅ Верхний "glow" блок (декор)
                  _GlowBlob(),

                  const SizedBox(height: 22),

                  // ✅ Иконка
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.system_update_alt_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ✅ Заголовок
                  Text(
                    title.isEmpty ? "Требуется обновление" : title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ✅ Версия
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Text(
                      "Обновите до версии $latestVersion",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ✅ Описание
                  Text(
                    message.isEmpty
                        ? "Чтобы продолжить работу, нужно установить новую версию приложения."
                        : message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ✅ Блок кнопок
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _buildButtons(context),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ✅ Подсказка
                  Text(
                    "Если кнопка не открывается — проверьте интернет\nи попробуйте снова.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    final buttons = <Widget>[];

    if (Platform.isIOS) {
      if (appleUrl.isNotEmpty) {
        buttons.add(_PrimaryButton(
          icon: Icons.apple,
          text: "Открыть App Store",
          onTap: () => _launch(appleUrl),
        ));
      } else {
        buttons.add(_PrimaryButton(
          icon: Icons.info_outline,
          text: "Ссылка App Store не задана",
          onTap: () {},
          enabled: false,
        ));
      }
    } else {
      // Android: RuStore + APK (если есть)
      if (ruStoreUrl.isNotEmpty) {
        buttons.add(_PrimaryButton(
          icon: Icons.shop_rounded,
          text: "Обновить через RuStore",
          onTap: () => _launch(ruStoreUrl),
        ));
        buttons.add(const SizedBox(height: 12));
      }
      if (apkUrl.isNotEmpty) {
        buttons.add(_SecondaryButton(
          icon: Icons.download_rounded,
          text: "Скачать APK",
          onTap: () => _launch(apkUrl),
        ));
      }

      if (buttons.isEmpty) {
        buttons.add(_PrimaryButton(
          icon: Icons.info_outline,
          text: "Ссылки обновления не заданы",
          onTap: () {},
          enabled: false,
        ));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...buttons,
        const SizedBox(height: 12),
        _SecondaryButton(
          icon: Icons.refresh_rounded,
          text: "Проверить снова",
          onTap: () => Navigator.of(context).maybePop(), // вернёмся и снова проверим
        ),
      ],
    );
  }

  static Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool enabled;

  const _PrimaryButton({
    required this.icon,
    required this.text,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 20),
        label: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF008C40),
          disabledBackgroundColor: Colors.white.withOpacity(0.5),
          disabledForegroundColor: Colors.black54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Stack(
        children: [
          Positioned(
            left: 30,
            top: 10,
            child: _Blob(size: 90, opacity: 0.22),
          ),
          Positioned(
            right: 10,
            top: 30,
            child: _Blob(size: 110, opacity: 0.18),
          ),
          Positioned(
            left: 120,
            top: 50,
            child: _Blob(size: 70, opacity: 0.16),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double opacity;

  const _Blob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(opacity),
            blurRadius: 30,
            spreadRadius: 6,
          ),
        ],
      ),
    );
  }
}
