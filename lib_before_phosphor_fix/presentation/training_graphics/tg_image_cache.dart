import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TgImageCache extends ChangeNotifier {
  final Map<String, ui.Image> _images = {};
  final Set<String> _loading = {};

  ui.Image? get(String key) => _images[key];

  Future<void> ensureLoaded(String assetPath) async {
    if (_images.containsKey(assetPath)) return;
    if (_loading.contains(assetPath)) return;

    _loading.add(assetPath);

    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      _images[assetPath] = frame.image;
      notifyListeners();
    } catch (_) {
      // если не загрузилось — просто не рисуем
    } finally {
      _loading.remove(assetPath);
    }
  }

  void warmUp(List<String> paths) {
    for (final p in paths) {
      // ignore: unawaited_futures
      ensureLoaded(p);
    }
  }

  @override
  void dispose() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    super.dispose();
  }
}
