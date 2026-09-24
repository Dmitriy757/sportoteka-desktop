import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:sportoteka/presentation/training_graphics/tg_export_saver.dart';
import 'package:sportoteka/presentation/training_graphics/tg_models.dart';
import 'package:sportoteka/presentation/training_graphics/training_graphics_state.dart';

/// Открытый JSON-манифест для последующей привязки моделей в Unity/GLB.
/// Содержит геометрию и ссылки на пресеты, а не выдаёт 2.5D-макеты за mesh.
class TgSceneExport {
  TgSceneExport._();

  static Map<String, dynamic> build(TgState state) {
    final field = state.fieldLogicalSize;
    Map<String, double> world(Offset p) => {
      'x': (p.dx - field.width / 2) / 10,
      'y': 0,
      'z': (field.height / 2 - p.dy) / 10,
    };

    Map<String, dynamic> sceneObject(TgElement e) {
      final native = e.toJson();
      final rect = e.bounds();
      final base = <String, dynamic>{
        'id': e.id,
        'name': e.name ?? native['type'],
        'layer': e.layer,
        'visible': !e.hidden,
        'locked': e.locked,
        'position_m': world(rect.center),
        'source_element': native,
      };
      if (e is TgStamp) {
        final uri = Uri.tryParse(e.asset);
        base.addAll({
          'kind': 'billboard',
          'asset': e.asset,
          'prefab_hint': uri?.scheme == 'sportoteka' ? uri?.host : null,
          'position_m': world(e.pos),
          'size_m': e.size / 10,
          'rotation_rad': e.rotation,
          'opacity': e.opacity,
          'mesh_bound': false,
        });
      } else if (e is TgLine) {
        base.addAll({
          'kind': 'route',
          'start_m': world(e.a),
          'end_m': world(e.b),
          'width_m': e.width / 10,
        });
      } else if (e is TgRect) {
        base.addAll({
          'kind': 'zone',
          'width_m': e.width / 10,
          'length_m': e.height / 10,
          'rotation_rad': e.rotation,
          'opacity': e.opacity,
        });
      } else if (e is TgCircle) {
        base.addAll({
          'kind': 'zone',
          'radius_m': e.radius / 10,
          'opacity': e.opacity,
        });
      } else {
        base.addAll({
          'kind': 'graphic',
          'bounds_m': {'width': rect.width / 10, 'length': rect.height / 10},
        });
      }
      return base;
    }

    return {
      'schema': 'sportoteka.training_scene.v1',
      'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
      'team_id': state.teamId,
      'team_name': state.teamName,
      'units': 'metres; angles in radians',
      'field': {
        'length_m': field.width / 10,
        'width_m': field.height / 10,
        'logical_width': field.width,
        'logical_height': field.height,
        'view': state.fieldView.name,
        'texture_name': state.customFieldTextureName,
      },
      'camera': {
        'perspective_enabled': state.is3DMode,
        'rotation_x_rad': state.rotationX,
        'rotation_y_rad': state.rotationY,
        'rotation_z_rad': state.rotationZ,
        'perspective': state.perspective,
        'zoom': state.camera3DZoom,
      },
      'objects': state.elements.map(sceneObject).toList(growable: false),
      'mesh_assets_included': false,
    };
  }

  static Future<String> save(TgState state) async {
    final document = const JsonEncoder.withIndent('  ').convert(build(state));
    return saveTgExportFile(
      'sportoteka_scene.json',
      Uint8List.fromList(utf8.encode(document)),
      mimeType: 'application/json',
      folderName: 'sportoteka_training_scene',
    );
  }
}
