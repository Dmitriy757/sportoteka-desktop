import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';

import 'sportoteka_3d_pro_scene.dart';

/// Sportoteka 3D Pro screen for Unity 6000.x using flutter_embed_unity.
///
/// Requirements:
/// - pubspec.yaml: flutter_embed_unity: ^2.0.0
/// - Unity project has FlutterEmbed imported for Unity 6000.x
/// - Unity scene contains GameObject named exactly: Sportoteka3DProBridge
/// - Sportoteka3DProBridge has public methods:
///   ApplySceneJson(string json), SetCameraPreset(string preset), FocusObject(string id)
class Sportoteka3DProUnityScreen extends StatefulWidget {
  const Sportoteka3DProUnityScreen({super.key, required this.scene});

  final Sportoteka3DProScene scene;

  @override
  State<Sportoteka3DProUnityScreen> createState() => _Sportoteka3DProUnityScreenState();
}

class _Sportoteka3DProUnityScreenState extends State<Sportoteka3DProUnityScreen> with WidgetsBindingObserver {
  bool _unityReady = false;
  bool _sceneSent = false;
  String _lastMessage = 'Ожидание Unity...';
  Timer? _fallbackSendTimer;
  Timer? _retrySendTimer;
  int _sendAttempts = 0;

  static const String _bridgeObjectName = 'Sportoteka3DProBridge';

  bool get _isUnityEmbedSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  }

  String get _platformName {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (!_isUnityEmbedSupportedPlatform) {
      _lastMessage = 'Unity Embed недоступен на $_platformName. На macOS тестируем сцену в Unity Editor.';
      return;
    }

    // Unity may be ready before Flutter receives the ready message on some devices.
    // This fallback sends the scene after the first render to avoid a blank screen.
    _fallbackSendTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _startRetrySend(markReady: false);
      }
    });
  }

  @override
  void dispose() {
    _fallbackSendTimer?.cancel();
    _retrySendTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_isUnityEmbedSupportedPlatform) {
      pauseUnity();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isUnityEmbedSupportedPlatform) return;

    if (state == AppLifecycleState.resumed) {
      resumeUnity();
      if (_sceneSent) {
        Future<void>.delayed(const Duration(milliseconds: 350), () => _startRetrySend(markReady: true));
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      pauseUnity();
    }
  }

  void _onMessageFromUnity(String message) {
    debugPrint('Sportoteka 3D Pro Unity message: $message');
    if (!mounted) return;

    setState(() {
      _lastMessage = message;
      if (message.contains('Sportoteka3DProReady') || message.contains('Sportoteka3DProSceneApplied')) {
        _unityReady = true;
      }
    });

    if (message.contains('Sportoteka3DProReady') || message.contains('Sportoteka3DProRuntimeBootstrapReady')) {
      _startRetrySend(markReady: true);
    }
  }

  void _startRetrySend({bool markReady = true}) {
    if (!_isUnityEmbedSupportedPlatform) {
      if (!mounted) return;
      setState(() {
        _lastMessage = 'На $_platformName Unity Embed не запускается. Открой сцену в Unity Editor.';
      });
      return;
    }

    _retrySendTimer?.cancel();
    _sendAttempts = 0;
    _sendSceneToUnity(markReady: markReady);
    _retrySendTimer = Timer.periodic(const Duration(milliseconds: 850), (timer) {
      if (!mounted || _sendAttempts >= 6) {
        timer.cancel();
        return;
      }
      _sendSceneToUnity(markReady: markReady);
    });
  }

  void _sendSceneToUnity({bool markReady = true}) {
    if (!_isUnityEmbedSupportedPlatform) {
      if (!mounted) return;
      setState(() {
        _lastMessage = 'Unity Embed поддерживается только Android/iOS. Сейчас: $_platformName.';
      });
      return;
    }

    _sendAttempts += 1;
    final json = widget.scene.toRawJson();
    sendToUnity(_bridgeObjectName, 'ApplySceneJson', json);
    if (!mounted) return;
    setState(() {
      _sceneSent = true;
      if (markReady) _unityReady = true;
      _lastMessage = 'Сцена отправлена в Unity ($_sendAttempts)';
    });
  }

  void _setCamera(String preset) {
    if (!_isUnityEmbedSupportedPlatform) {
      setState(() => _lastMessage = 'Камера $preset доступна в Unity Editor или на Android/iOS.');
      return;
    }

    sendToUnity(_bridgeObjectName, 'SetCameraPreset', preset);
    setState(() => _lastMessage = 'Камера: $preset');
  }

  void _focusObject(String objectId) {
    if (!_isUnityEmbedSupportedPlatform) {
      setState(() => _lastMessage = 'Фокус $objectId доступен в Unity Editor или на Android/iOS.');
      return;
    }

    sendToUnity(_bridgeObjectName, 'FocusObject', objectId);
    setState(() => _lastMessage = 'Фокус: $objectId');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnityEmbedSupportedPlatform) {
      return _UnsupportedUnityPlatformScreen(
        platformName: _platformName,
        onClose: () => Navigator.of(context).maybePop(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07111E),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: EmbedUnity(
                onMessageFromUnity: _onMessageFromUnity,
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _UnityHeader(
                ready: _unityReady,
                sceneSent: _sceneSent,
                lastMessage: _lastMessage,
                onClose: () => Navigator.of(context).maybePop(),
                onSend: () => _startRetrySend(markReady: true),
                onCamera: _setCamera,
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: _QuickObjectsPanel(
                onFocus: _focusObject,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnityHeader extends StatelessWidget {
  const _UnityHeader({
    required this.ready,
    required this.sceneSent,
    required this.lastMessage,
    required this.onClose,
    required this.onSend,
    required this.onCamera,
  });

  final bool ready;
  final bool sceneSent;
  final String lastMessage;
  final VoidCallback onClose;
  final VoidCallback onSend;
  final ValueChanged<String> onCamera;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 760;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 26, offset: Offset(0, 10))],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Закрыть',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.view_in_ar_rounded, color: Color(0xFF0F8F68)),
          const SizedBox(width: 8),
          const Text(
            'Sportoteka 3D Pro',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
          ),
          const SizedBox(width: 10),
          _StatusBadge(
            text: ready ? 'Unity готов' : sceneSent ? 'Сцена отправлена' : 'Загрузка Unity',
            ready: ready || sceneSent,
          ),
          if (!isCompact) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const Spacer(),
          if (!isCompact) ...[
            _CameraButton(label: 'FIFA', value: 'fifa', onCamera: onCamera),
            _CameraButton(label: 'TV', value: 'tv', onCamera: onCamera),
            _CameraButton(label: 'Тактика', value: 'tactical', onCamera: onCamera),
            _CameraButton(label: 'Сверху', value: 'top', onCamera: onCamera),
            const SizedBox(width: 8),
          ],
          FilledButton.icon(
            onPressed: onSend,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(isCompact ? 'Обновить' : 'Обновить сцену'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F8F68),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ],
      ),
    );
  }
}


class _UnsupportedUnityPlatformScreen extends StatelessWidget {
  const _UnsupportedUnityPlatformScreen({
    required this.platformName,
    required this.onClose,
  });

  final String platformName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A000000), blurRadius: 32, offset: Offset(0, 14)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F9EF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.desktop_mac_rounded, color: Color(0xFF0F8F68), size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Unity 3D Pro на macOS',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                              ),
                              Text(
                                'Текущая платформа: $platformName',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Закрыть',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Встроенный Unity через flutter_embed_unity запускается только на Android/iOS. '
                      'На macOS этот экран теперь не падает, а показывает безопасную заглушку.',
                      style: TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 18),
                    _MacTestStep(
                      icon: Icons.view_in_ar_rounded,
                      title: '3D-сцену тестируй в Unity Editor',
                      text: 'Открой /unity/Sportoteka3DPro, нажми Create FIFA Pro Tools Scene и Play.',
                    ),
                    const SizedBox(height: 10),
                    _MacTestStep(
                      icon: Icons.phone_android_rounded,
                      title: 'Полную связку Flutter + Unity тестируй на Android',
                      text: 'В Unity сделай Flutter → Export Android, затем flutter run на устройстве/эмуляторе.',
                    ),
                    const SizedBox(height: 10),
                    _MacTestStep(
                      icon: Icons.code_rounded,
                      title: 'Flutter-интерфейс на macOS можно тестировать отдельно',
                      text: 'Этот fallback нужен, чтобы приложение не падало при запуске desktop-версии.',
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: onClose,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Вернуться'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F8F68),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Это нормальное поведение для macOS: Unity внутри Flutter desktop сейчас не запускаем.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MacTestStep extends StatelessWidget {
  const _MacTestStep({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0F8F68), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.ready});
  final String text;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ready ? const Color(0xFFE8F9EF) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: ready ? const Color(0xFF15803D) : const Color(0xFFC2410C),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.label, required this.value, required this.onCamera});

  final String label;
  final String value;
  final ValueChanged<String> onCamera;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton(
        onPressed: () => onCamera(value),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF111827),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        child: Text(label),
      ),
    );
  }
}

class _QuickObjectsPanel extends StatelessWidget {
  const _QuickObjectsPanel({required this.onFocus});

  final ValueChanged<String> onFocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Быстрый фокус', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827))),
          const SizedBox(height: 8),
          _FocusButton(label: 'Игрок 10', objectId: 'home_10', onFocus: onFocus),
          _FocusButton(label: 'Мяч', objectId: 'ball', onFocus: onFocus),
          _FocusButton(label: 'Зона атаки', objectId: 'attack_zone', onFocus: onFocus),
        ],
      ),
    );
  }
}

class _FocusButton extends StatelessWidget {
  const _FocusButton({required this.label, required this.objectId, required this.onFocus});
  final String label;
  final String objectId;
  final ValueChanged<String> onFocus;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => onFocus(objectId),
      style: TextButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: const Color(0xFF0F8F68)),
      child: Text(label),
    );
  }
}
