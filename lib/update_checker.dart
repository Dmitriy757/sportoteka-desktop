import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/presentation/update_required/update_required_screen.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String minRequiredVersion;
  final String title;
  final String message;
  final String apkUrl;
  final String ruStoreUrl;
  final String appleUrl;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.title,
    required this.message,
    required this.apkUrl,
    required this.ruStoreUrl,
    required this.appleUrl,
  });

  bool get hasAnyLink =>
      apkUrl.trim().isNotEmpty ||
      ruStoreUrl.trim().isNotEmpty ||
      appleUrl.trim().isNotEmpty;
}

class AppUpdateService {
  // ✅ Твой эндпоинт
  static const String _endpoint = "https://sportotekaapp.ru/api/app_version.php";

  // ✅ чтобы не спамило баннерами
  static bool _alreadyCheckedOnce = false;

  static Future<void> checkAndShow(BuildContext context, {bool oncePerRun = true}) async {
    if (oncePerRun && _alreadyCheckedOnce) return;
    _alreadyCheckedOnce = true;

    final info = await _fetchUpdateInfo();
    if (info == null) return;

    final pkg = await PackageInfo.fromPlatform();
    final currentVersion = pkg.version;

    final mustUpdate = _isVersionGreater(info.minRequiredVersion, currentVersion);
    final hasUpdate = _isVersionGreater(info.latestVersion, currentVersion);

    if (!hasUpdate) return;

    if (!context.mounted) return;

    if (mustUpdate) {
      await _showForceScreen(context, info);
    } else {
      _showTopBanner(context, info);
    }
  }

  static Future<AppUpdateInfo?> _fetchUpdateInfo() async {
    final platform = Platform.isIOS ? "ios" : "android";
    final uri = Uri.parse("$_endpoint?platform=$platform");

    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;

      final j = jsonDecode(r.body);
      if (j is! Map || j["ok"] != true) return null;

      final links = (j["links"] is Map) ? (j["links"] as Map) : {};

      return AppUpdateInfo(
        latestVersion: (j["latest_version"] ?? "").toString(),
        minRequiredVersion: (j["min_required_version"] ?? "").toString(),
        title: (j["title"] ?? "Доступно обновление").toString(),
        message: (j["message"] ?? "").toString(),
        apkUrl: (links["apk"] ?? "").toString(),
        ruStoreUrl: (links["rustore"] ?? "").toString(),
        appleUrl: (links["apple"] ?? "").toString(),
      );
    } catch (_) {
      return null;
    }
  }

  // ✅ нормальное сравнение версий: 1.7.2 > 1.6.10
  static bool _isVersionGreater(String a, String b) {
    List<int> pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final n = pa.length > pb.length ? pa.length : pb.length;
    while (pa.length < n) pa.add(0);
    while (pb.length < n) pb.add(0);
    for (int i = 0; i < n; i++) {
      if (pa[i] > pb[i]) return true;
      if (pa[i] < pb[i]) return false;
    }
    return false;
  }

  // =========================
  // ✅ FULLSCREEN FORCE UPDATE
  // =========================
  static Future<void> _showForceScreen(BuildContext context, AppUpdateInfo info) async {
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => UpdateRequiredScreen(
          latestVersion: info.latestVersion,
          title: info.title,
          message: info.message,
          apkUrl: info.apkUrl,
          ruStoreUrl: info.ruStoreUrl,
          appleUrl: info.appleUrl,
        ),
      ),
      (_) => false,
    );
  }

  // =========================
  // ✅ BEAUTIFUL TOP BANNER
  // =========================
  static void _showTopBanner(BuildContext context, AppUpdateInfo info) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _SportotekaUpdateBanner(
        title: info.title,
        version: info.latestVersion,
        onClose: () => entry.remove(),
        onUpdate: () async {
          entry.remove();
          await _openUpdateLinks(context, info);
        },
      ),
    );

    overlay.insert(entry);

    // ✅ авто-скрытие через 10 секунд (можешь убрать)
    Future.delayed(const Duration(seconds: 10), () {
      try {
        entry.remove();
      } catch (_) {}
    });
  }

  // =========================
  // ✅ OPEN LINKS
  // =========================
  static Future<void> _openUpdateLinks(BuildContext context, AppUpdateInfo info) async {
    if (Platform.isIOS) {
      if (info.appleUrl.trim().isNotEmpty) {
        await _launch(info.appleUrl);
      }
      return;
    }

    // Android: если есть только одна ссылка — открываем сразу
    final options = <_UpdateLink>[];
    if (info.ruStoreUrl.trim().isNotEmpty) options.add(_UpdateLink("RuStore", info.ruStoreUrl));
    if (info.apkUrl.trim().isNotEmpty) options.add(_UpdateLink("Скачать APK", info.apkUrl));

    if (options.isEmpty) return;
    if (options.length == 1) {
      await _launch(options.first.url);
      return;
    }

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text("Выберите способ обновления"),
              subtitle: Text("RuStore или прямая загрузка APK"),
            ),
            for (final o in options)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(o.title),
                onTap: () async {
                  Navigator.pop(context);
                  await _launch(o.url);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _UpdateLink {
  final String title;
  final String url;
  _UpdateLink(this.title, this.url);
}

class _SportotekaUpdateBanner extends StatefulWidget {
  final String title;
  final String version;
  final VoidCallback onClose;
  final VoidCallback onUpdate;

  const _SportotekaUpdateBanner({
    required this.title,
    required this.version,
    required this.onClose,
    required this.onUpdate,
  });

  @override
  State<_SportotekaUpdateBanner> createState() => _SportotekaUpdateBannerState();
}

class _SportotekaUpdateBannerState extends State<_SportotekaUpdateBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _slide = Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Positioned(
      top: top + 10,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF00A750), Color(0xFF008C40)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Версия ${widget.version}",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: widget.onUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF008C40),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Обновить", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.onClose,
                  child: Icon(Icons.close, color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
