import 'package:flutter/material.dart';

class TgFieldPreset {
  const TgFieldPreset({
    required this.id,
    required this.title,
    required this.asset,
    required this.logicalSize,
    this.group,
  });

  final String id;
  final String title;
  final String asset;      // SVG/PNG
  final Size logicalSize;  // под это поле работает fit + координаты
  final String? group;     // для UI (группа)
}

class TgFieldPresets {
  // ✅ базовые логические размеры
  // футбол: 1050×680 (как у тебя)
  static const Size football = Size(1050, 680);

  // футзал можно сделать чуть меньше (если хочешь одинаково — оставь football)
  static const Size futsal = Size(900, 600);

  // helper
  static TgFieldPreset _p(String file, String title, {String? group, Size? size}) {
    final asset = 'assets/training/stamps/fields/$file';
    return TgFieldPreset(
      id: file.replaceAll('.svg', ''),
      title: title,
      asset: asset,
      logicalSize: size ?? football,
      group: group,
    );
  }

  // ✅ список всех твоих SVG
  static final List<TgFieldPreset> all = [
    // Football - top/bottom/left/right
    _p('top.svg', 'Top', group: 'Football'),
    _p('top1.svg', 'Top 1', group: 'Football'),
    _p('top3.svg', 'Top 3', group: 'Football'),
    _p('top4.svg', 'Top 4', group: 'Football'),
    _p('top6.svg', 'Top 6', group: 'Football'),

    _p('bottom.svg', 'Bottom', group: 'Football'),
    _p('bottom1.svg', 'Bottom 1', group: 'Football'),
    _p('bottom7.svg', 'Bottom 7', group: 'Football'),

    _p('left.svg', 'Left', group: 'Football'),
    _p('left1.svg', 'Left 1', group: 'Football'),
    _p('left2.svg', 'Left 2', group: 'Football'),
    _p('left7.svg', 'Left 7', group: 'Football'),

    _p('right.svg', 'Right', group: 'Football'),
    _p('right2.svg', 'Right 2', group: 'Football'),
    _p('right3.svg', 'Right 3', group: 'Football'),
    _p('right4.svg', 'Right 4', group: 'Football'),
    _p('right5.svg', 'Right 5', group: 'Football'),

    // Landscape / Portrait (это обычно “ориентации”/виды)
    _p('landscape.svg', 'Landscape', group: 'Layouts'),
    _p('landscape1.svg', 'Landscape 1', group: 'Layouts'),
    _p('landscape2.svg', 'Landscape 2', group: 'Layouts'),
    _p('landscape4.svg', 'Landscape 4', group: 'Layouts'),
    _p('landscape6.svg', 'Landscape 6', group: 'Layouts'),

    _p('portrait.svg', 'Portrait', group: 'Layouts'),
    _p('portrait3.svg', 'Portrait 3', group: 'Layouts'),
    _p('portrait5.svg', 'Portrait 5', group: 'Layouts'),

    // Futsal
    _p('futsal_top.svg', 'Futsal Top', group: 'Futsal', size: futsal),
    _p('futsal_bottom.svg', 'Futsal Bottom', group: 'Futsal', size: futsal),
    _p('futsal_left8.svg', 'Futsal Left 8', group: 'Futsal', size: futsal),
    _p('futsal_right.svg', 'Futsal Right', group: 'Futsal', size: futsal),
  ];

  static TgFieldPreset byAsset(String asset) {
    return all.firstWhere(
      (p) => p.asset == asset,
      orElse: () => all.first,
    );
  }
}