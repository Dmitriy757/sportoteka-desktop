import 'dart:convert';

class Sportoteka3DProScene {
  Sportoteka3DProScene({
    required this.title,
    required this.field,
    required this.camera,
    required this.lighting,
    required this.layers,
    required this.objects,
    this.meta = const Sportoteka3DProMeta(),
  });

  final String title;
  final Sportoteka3DProField field;
  final Sportoteka3DProCamera camera;
  final Sportoteka3DProLighting lighting;
  final List<Sportoteka3DProLayer> layers;
  final List<Sportoteka3DProObject> objects;
  final Sportoteka3DProMeta meta;

  Map<String, dynamic> toJson() => {
        'title': title,
        'meta': meta.toJson(),
        'field': field.toJson(),
        'camera': camera.toJson(),
        'lighting': lighting.toJson(),
        'layers': layers.map((e) => e.toJson()).toList(),
        'objects': objects.map((e) => e.toJson()).toList(),
      };

  String toRawJson() => jsonEncode(toJson());

  factory Sportoteka3DProScene.demoProfessionalAttack() {
    return Sportoteka3DProScene(
      title: 'Sportoteka 3D Pro — FIFA Pro',
      meta: const Sportoteka3DProMeta(
        clubName: 'ФК Гомель',
        opponentName: 'Соперник',
        phase: 'Атака',
        minute: '63:20',
      ),
      field: const Sportoteka3DProField(),
      camera: const Sportoteka3DProCamera(preset: 'fifa', fov: 35),
      lighting: const Sportoteka3DProLighting(),
      layers: const [
        Sportoteka3DProLayer(id: 'field', name: 'Поле', visible: true, locked: true),
        Sportoteka3DProLayer(id: 'players', name: 'Игроки', visible: true),
        Sportoteka3DProLayer(id: 'ball', name: 'Мяч', visible: true),
        Sportoteka3DProLayer(id: 'graphics', name: 'Графика', visible: true),
        Sportoteka3DProLayer(id: 'labels', name: 'Подписи', visible: true),
      ],
      objects: const [
        Sportoteka3DProObject.player(id: 'home_10', team: 'home', number: 10, label: '10', x: -22, z: -12, rotationY: 24, kitColor: '#16A34A'),
        Sportoteka3DProObject.player(id: 'home_7', team: 'home', number: 7, label: '7', x: 4, z: -18, rotationY: 18, kitColor: '#16A34A'),
        Sportoteka3DProObject.player(id: 'home_9', team: 'home', number: 9, label: '9', x: 23, z: -30, rotationY: -8, kitColor: '#16A34A'),
        Sportoteka3DProObject.player(id: 'away_5', team: 'away', number: 5, label: '5', x: 12, z: -7, rotationY: -30, kitColor: '#F8FAFC'),
        Sportoteka3DProObject.player(id: 'away_4', team: 'away', number: 4, label: '4', x: 27, z: -16, rotationY: -20, kitColor: '#F8FAFC'),
        Sportoteka3DProObject.ball(id: 'ball_1', x: -18, z: -11),
        Sportoteka3DProObject.arrow(id: 'pass_arrow_1', x: -18, z: -11, toX: 4, toZ: -18, color: '#FDE047', width: 1.1),
        Sportoteka3DProObject.arrow(id: 'run_arrow_9', x: 11, z: -20, toX: 29, toZ: -34, color: '#38BDF8', width: 1.0, effect: 'dash'),
        Sportoteka3DProObject.zone(id: 'danger_zone', x: 23, z: -26, width: 22, length: 18, color: '#22C55E', opacity: 0.22),
        Sportoteka3DProObject.label(id: 'phase_label', x: -31, y: 3.2, z: -20, label: 'Опасная атака', color: '#FFFFFF', scale: 1.0),
      ],
    );
  }
}

class Sportoteka3DProMeta {
  const Sportoteka3DProMeta({
    this.clubName = '',
    this.opponentName = '',
    this.phase = '',
    this.minute = '',
    this.matchId,
    this.teamId,
  });

  final String clubName;
  final String opponentName;
  final String phase;
  final String minute;
  final int? matchId;
  final int? teamId;

  Map<String, dynamic> toJson() => {
        'clubName': clubName,
        'opponentName': opponentName,
        'phase': phase,
        'minute': minute,
        'matchId': matchId ?? 0,
        'teamId': teamId ?? 0,
      };
}

class Sportoteka3DProField {
  const Sportoteka3DProField({
    this.type = 'football',
    this.length = 105,
    this.width = 68,
    this.grassStyle = 'broadcast',
    this.lineStyle = 'tv',
    this.stadiumStyle = 'training_arena',
  });

  final String type;
  final double length;
  final double width;
  final String grassStyle;
  final String lineStyle;
  final String stadiumStyle;

  Map<String, dynamic> toJson() => {
        'type': type,
        'length': length,
        'width': width,
        'grassStyle': grassStyle,
        'lineStyle': lineStyle,
        'stadiumStyle': stadiumStyle,
      };
}

class Sportoteka3DProCamera {
  const Sportoteka3DProCamera({
    this.preset = 'fifa',
    this.fov = 35,
    this.x = 0,
    this.y = 32,
    this.z = -78,
    this.targetX = 0,
    this.targetY = 0,
    this.targetZ = 0,
  });

  final String preset;
  final double fov;
  final double x;
  final double y;
  final double z;
  final double targetX;
  final double targetY;
  final double targetZ;

  Map<String, dynamic> toJson() => {
        'preset': preset,
        'fov': fov,
        'x': x,
        'y': y,
        'z': z,
        'targetX': targetX,
        'targetY': targetY,
        'targetZ': targetZ,
      };
}

class Sportoteka3DProLighting {
  const Sportoteka3DProLighting({
    this.preset = 'stadium_day',
    this.intensity = 0.72,
    this.shadows = false,
  });

  final String preset;
  final double intensity;
  final bool shadows;

  Map<String, dynamic> toJson() => {
        'preset': preset,
        'intensity': intensity,
        'shadows': shadows,
      };
}

class Sportoteka3DProLayer {
  const Sportoteka3DProLayer({
    required this.id,
    required this.name,
    this.visible = true,
    this.locked = false,
    this.opacity = 1,
  });

  final String id;
  final String name;
  final bool visible;
  final bool locked;
  final double opacity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'visible': visible,
        'locked': locked,
        'opacity': opacity,
      };
}

class Sportoteka3DProObject {
  const Sportoteka3DProObject({
    required this.id,
    required this.type,
    this.layerId = 'graphics',
    this.team = 'home',
    this.number = 0,
    this.label = '',
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.toX = 0,
    this.toY = 0,
    this.toZ = 0,
    this.rotationY = 0,
    this.scale = 1,
    this.width = 1,
    this.length = 1,
    this.radius = 1,
    this.opacity = 1,
    this.color = '#22C55E',
    this.secondaryColor = '#FFFFFF',
    this.kitColor = '#16A34A',
    this.backgroundColor = '#0F172A',
    this.modelKey = '',
    this.effect = '',
    this.visible = true,
    this.locked = false,
  });

  final String id;
  final String type;
  final String layerId;
  final String team;
  final int number;
  final String label;
  final double x;
  final double y;
  final double z;
  final double toX;
  final double toY;
  final double toZ;
  final double rotationY;
  final double scale;
  final double width;
  final double length;
  final double radius;
  final double opacity;
  final String color;
  final String secondaryColor;
  final String kitColor;
  final String backgroundColor;
  final String modelKey;
  final String effect;
  final bool visible;
  final bool locked;

  const Sportoteka3DProObject.player({
    required String id,
    String layerId = 'players',
    String team = 'home',
    int number = 0,
    String label = '',
    double x = 0,
    double y = 0,
    double z = 0,
    double rotationY = 0,
    double scale = 1,
    String kitColor = '#16A34A',
    String modelKey = 'player_home',
    bool visible = true,
    bool locked = false,
  }) : this(
          id: id,
          type: 'player',
          layerId: layerId,
          team: team,
          number: number,
          label: label,
          x: x,
          y: y,
          z: z,
          rotationY: rotationY,
          scale: scale,
          kitColor: kitColor,
          modelKey: modelKey,
          visible: visible,
          locked: locked,
        );

  const Sportoteka3DProObject.ball({
    required String id,
    String layerId = 'ball',
    double x = 0,
    double y = 0,
    double z = 0,
    double scale = 1,
    bool visible = true,
  }) : this(
          id: id,
          type: 'ball',
          layerId: layerId,
          x: x,
          y: y,
          z: z,
          scale: scale,
          modelKey: 'ball',
          visible: visible,
        );

  const Sportoteka3DProObject.arrow({
    required String id,
    String layerId = 'graphics',
    double x = 0,
    double y = 0,
    double z = 0,
    double toX = 0,
    double toY = 0,
    double toZ = 0,
    double width = 1,
    String color = '#FDE047',
    String effect = 'glow',
    bool visible = true,
  }) : this(
          id: id,
          type: 'arrow',
          layerId: layerId,
          x: x,
          y: y,
          z: z,
          toX: toX,
          toY: toY,
          toZ: toZ,
          width: width,
          color: color,
          effect: effect,
          visible: visible,
        );

  const Sportoteka3DProObject.zone({
    required String id,
    String layerId = 'graphics',
    double x = 0,
    double z = 0,
    double width = 10,
    double length = 10,
    double opacity = 0.25,
    String color = '#22C55E',
    String effect = 'soft_area',
    bool visible = true,
  }) : this(
          id: id,
          type: 'zone',
          layerId: layerId,
          x: x,
          z: z,
          width: width,
          length: length,
          opacity: opacity,
          color: color,
          effect: effect,
          visible: visible,
        );

  const Sportoteka3DProObject.label({
    required String id,
    String layerId = 'labels',
    double x = 0,
    double y = 3,
    double z = 0,
    String label = '',
    String color = '#FFFFFF',
    String backgroundColor = '#0F172A',
    double scale = 1,
    bool visible = true,
  }) : this(
          id: id,
          type: 'label',
          layerId: layerId,
          x: x,
          y: y,
          z: z,
          label: label,
          color: color,
          backgroundColor: backgroundColor,
          scale: scale,
          visible: visible,
        );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'layerId': layerId,
        'team': team,
        'number': number,
        'label': label,
        'x': x,
        'y': y,
        'z': z,
        'toX': toX,
        'toY': toY,
        'toZ': toZ,
        'rotationY': rotationY,
        'scale': scale,
        'width': width,
        'length': length,
        'radius': radius,
        'opacity': opacity,
        'color': color,
        'secondaryColor': secondaryColor,
        'kitColor': kitColor,
        'backgroundColor': backgroundColor,
        'modelKey': modelKey,
        'effect': effect,
        'visible': visible,
        'locked': locked,
      };
}
