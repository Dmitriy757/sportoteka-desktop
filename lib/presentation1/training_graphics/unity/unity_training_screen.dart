// lib/presentation/training_graphics/unity/unity_training_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';

class UnityTrainingScreen extends StatefulWidget {
  const UnityTrainingScreen({
    super.key,
    required this.initialSchemeJson,
    required this.teamName,
  });

  final String initialSchemeJson;
  final String teamName;

  @override
  State<UnityTrainingScreen> createState() => _UnityTrainingScreenState();
}

class _UnityTrainingScreenState extends State<UnityTrainingScreen> {
  bool _unityReady = false;
  bool _sentInitial = false;
  String? _lastUnityMsg;

  void _sendInitialIfNeeded() {
    if (!_unityReady) return;
    if (_sentInitial) return;
    _sentInitial = true;

    // Flutter -> Unity
    sendToUnity("FlutterBridge", "LoadScheme", widget.initialSchemeJson);
  }

  void _handleUnityMessage(String message) {
    _lastUnityMsg = message;

    // 1) handshake: Unity -> Flutter {"type":"ready"}
    try {
      final j = jsonDecode(message);
      if (j is Map && j["type"] == "ready") {
        if (!_unityReady) {
          setState(() => _unityReady = true);
        }
        _sendInitialIfNeeded();
        return;
      }
    } catch (_) {
      // not json — ignore
    }

    // 2) если Unity не прислала ready, но присылает любые сообщения — тоже считаем что жива
    if (!_unityReady) {
      setState(() => _unityReady = true);
      _sendInitialIfNeeded();
    }

    // 3) тут можно обработать export обратно: {"type":"scheme_export", ...}
    // пока просто покажем snackbar (по желанию)
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Unity: $message")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("3D поле — ${widget.teamName}"),
        actions: [
          IconButton(
            tooltip: "Отправить схему в Unity",
            icon: const Icon(Icons.upload_rounded),
            onPressed: _unityReady
                ? () => sendToUnity("FlutterBridge", "LoadScheme", widget.initialSchemeJson)
                : null,
          ),
          IconButton(
            tooltip: "Запросить схему из Unity",
            icon: const Icon(Icons.download_rounded),
            onPressed: _unityReady
                ? () => sendToUnity("FlutterBridge", "ExportScheme", "")
                : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          EmbedUnity(
            onMessageFromUnity: _handleUnityMessage,
          ),

          if (!_unityReady)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text("Запускаю 3D движок…"),
                ],
              ),
            ),

          if (_unityReady && _lastUnityMsg != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Opacity(
                opacity: 0.85,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _lastUnityMsg!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
