import 'dart:typed_data';

class ActionTrackerBleProfile {
  static const String serviceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String notifyUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String writeUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';

  static const List<String> namePrefixes = ['\$ACT', '\$ATP', '\$GPS'];

  static const List<int> commandReadBatteryAndGps = [0x20];
  static const List<int> commandReadFileList = [0x30];

  /// Кандидаты команд для Live/current GPS.
  /// В APK найдены функции SendCurrentGPSOrder / GetCurrentGPS, но байты нужно подтвердить
  /// на реальном трекере. Экран Live умеет отправлять эти команды и показывать RX-логи.
  /// Если конкретная прошивка отвечает GPS-пакетами 0x33/0x43/0x44/0x45, экран сразу
  /// будет сохранять и отображать точки.
  static const List<List<int>> commandCurrentGpsCandidates = [
    [0x3A], // Live GPS: TX 3A -> RX 3B / 44
    [0x20], // Battery/GPS ready: RX 21

    [0x22],
    [0x23],
    [0x24],
    [0x25],
    [0x26],
    [0x27],
    [0x28],
    [0x29],

    [0x32],
    [0x34],
    [0x35],
    [0x36],
    [0x37],
    [0x38],
    [0x39],
    [0x3B],
    [0x3C],
    [0x3D],
    [0x3E],
    [0x3F],

    [0x40],
    [0x41],
    [0x46],
    [0x47],
    [0x49],
    [0x4A],
    [0x4B],
    [0x4C],
  ];

  static List<int> commandReadGpsByFileId(int fileId) {
    return [0x42, fileId & 0xff, (fileId >> 8) & 0xff, 10];
  }
}

enum ActionTrackerRecordState { ready, recording, finished, unknown }

class ActionTrackerBatteryState {
  final double voltage;
  final bool gpsReady;

  const ActionTrackerBatteryState({required this.voltage, required this.gpsReady});
}

class ActionTrackerRecord {
  final int fileId;
  final int startDateRaw;
  final int startTimeMs;
  final int endDateRaw;
  final int endTimeMs;
  final int length;
  final ActionTrackerRecordState state;
  final String title;

  const ActionTrackerRecord({
    required this.fileId,
    required this.startDateRaw,
    required this.startTimeMs,
    required this.endDateRaw,
    required this.endTimeMs,
    required this.length,
    required this.state,
    required this.title,
  });

  Map<String, dynamic> toJson() => {
        'file_id': fileId,
        'start_date_raw': startDateRaw,
        'start_time_ms': startTimeMs,
        'end_date_raw': endDateRaw,
        'end_time_ms': endTimeMs,
        'length': length,
        'state': state.name,
        'title': title,
      };
}

class ActionTrackerGpsPoint {
  final int timeMs;
  final double latitude;
  final double longitude;

  const ActionTrackerGpsPoint({
    required this.timeMs,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'time_ms': timeMs,
        'latitude': latitude,
        'longitude': longitude,
      };
}

class ActionTrackerGpsChunk {
  final int packetType;
  final int? chunkIndex;
  final double? progress;
  final List<ActionTrackerGpsPoint> points;
  final bool finished;

  const ActionTrackerGpsChunk({
    required this.packetType,
    required this.points,
    this.chunkIndex,
    this.progress,
    this.finished = false,
  });
}

class ActionTrackerParseResult {
  final int packetType;
  final ActionTrackerBatteryState? battery;
  final List<ActionTrackerRecord> records;
  final ActionTrackerGpsChunk? gpsChunk;
  final bool transferFinished;
  final List<int> raw;

  const ActionTrackerParseResult({
    required this.packetType,
    required this.raw,
    this.battery,
    this.records = const [],
    this.gpsChunk,
    this.transferFinished = false,
  });

  String get rawHex => raw.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
}

class ActionTrackerProtocolParser {
  const ActionTrackerProtocolParser();

  ActionTrackerParseResult parse(
    List<int> bytes, {
    ActionTrackerRecord? selectedRecord,
    int currentYear = 0,
  }) {
    if (bytes.isEmpty) return const ActionTrackerParseResult(packetType: -1, raw: []);

    final type = bytes[0];

    if (type == 0x21 && bytes.length >= 5) {
      final voltage = _u16(bytes, 2) / 100.0;
      final gpsReady = (bytes[4] & 0x01) == 1;
      return ActionTrackerParseResult(
        packetType: type,
        raw: bytes,
        battery: ActionTrackerBatteryState(voltage: voltage, gpsReady: gpsReady),
      );
    }

    if (type == 0x31 || type == 0x51) {
      return ActionTrackerParseResult(
        packetType: type,
        raw: bytes,
        records: _parseRecordList(bytes, currentYear: currentYear),
      );
    }

    if (type == 0x33) {
      return ActionTrackerParseResult(
        packetType: type,
        raw: bytes,
        gpsChunk: _parseAbsoluteGpsChunk(bytes, selectedRecord: selectedRecord),
      );
    }

    // Live/current GPS:
    // Реально найдено на трекере:
    // TX 3A -> RX 3B 01 [lat i32 le] [lon i32 le] [time u32 le]
    // latitude = raw / 6000000, longitude = raw / 6000000.
    if (type == 0x3B) {
      return ActionTrackerParseResult(
        packetType: type,
        raw: bytes,
        gpsChunk: _parseCurrentGps3B(bytes),
      );
    }

    if ((type == 0x44 || type == 0x45) && selectedRecord == null) {
      return ActionTrackerParseResult(
        packetType: type,
        raw: bytes,
        gpsChunk: _parseLiveAbsoluteFromCompressedPacket(bytes),
      );
    }

    if ((type == 0x44 || type == 0x45) && selectedRecord != null) {
      return ActionTrackerParseResult(
        packetType: type,
        raw: bytes,
        gpsChunk: _parseCompressedGps100ms(bytes, selectedRecord),
      );
    }

    if (type == 0x43 && selectedRecord != null) {
      return ActionTrackerParseResult(
        packetType: type,
        raw: bytes,
        gpsChunk: _parseCompressedGps500ms(bytes, selectedRecord),
      );
    }

    if (type == 0x48) {
      return const ActionTrackerParseResult(
        packetType: 0x48,
        raw: [0x48],
        transferFinished: true,
        gpsChunk: ActionTrackerGpsChunk(packetType: 0x48, points: [], finished: true),
      );
    }

    return ActionTrackerParseResult(packetType: type, raw: bytes);
  }

  List<ActionTrackerRecord> _parseRecordList(List<int> bytes, {required int currentYear}) {
    final records = <ActionTrackerRecord>[];
    final year = currentYear == 0 ? DateTime.now().year % 100 : currentYear % 100;

    var i = 1;
    while (i + 20 < bytes.length) {
      final startDate = _u32(bytes, i) + year * 10000;
      final startTime = _u32(bytes, i + 4);
      final endDate = _u32(bytes, i + 8) + year * 10000;
      final endTime = _u32(bytes, i + 12);

      var length = _u16(bytes, i + 16);
      final flag = bytes[i + 20];
      if ((flag & 0x80) != 0) length += 65536;

      final fileId = _u16(bytes, i + 18);
      final stateCode = flag & 0x7f;
      final state = switch (stateCode) {
        1 => ActionTrackerRecordState.recording,
        2 => ActionTrackerRecordState.finished,
        0 => ActionTrackerRecordState.ready,
        _ => ActionTrackerRecordState.unknown,
      };

      records.add(ActionTrackerRecord(
        fileId: fileId,
        startDateRaw: startDate,
        startTimeMs: startTime,
        endDateRaw: endDate,
        endTimeMs: endTime,
        length: length,
        state: state,
        title: _formatDateTitle(startDate, startTime),
      ));

      i += 21;
    }

    return records;
  }


  ActionTrackerGpsChunk _parseCurrentGps3B(List<int> bytes) {
    if (bytes.length < 14) {
      return ActionTrackerGpsChunk(packetType: bytes.first, points: const []);
    }

    final rawLat = _i32(bytes, 2);
    final rawLon = _i32(bytes, 6);

    // 3B 00 00 00... means the tracker answered but has no current coordinate.
    if (rawLat == 0 || rawLon == 0) {
      return ActionTrackerGpsChunk(packetType: bytes.first, points: const []);
    }

    final lat = rawLat / 6000000.0;
    final lon = rawLon / 6000000.0;
    final time = DateTime.now().millisecondsSinceEpoch;

    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return ActionTrackerGpsChunk(packetType: bytes.first, points: const []);
    }

    return ActionTrackerGpsChunk(
      packetType: bytes.first,
      points: [
        ActionTrackerGpsPoint(
          timeMs: time,
          latitude: lat,
          longitude: lon,
        ),
      ],
    );
  }


  ActionTrackerGpsChunk _parseLiveAbsoluteFromCompressedPacket(List<int> bytes) {
    // Live packet observed from ActionTracer:
    // RX 44 xx xx [lat i32 little-endian] [lon i32 little-endian] ...
    if (bytes.length < 11) {
      return ActionTrackerGpsChunk(packetType: bytes.first, points: const []);
    }

    final rawLat = _i32(bytes, 3);
    final rawLon = _i32(bytes, 7);

    if (rawLat == 0 || rawLon == 0) {
      return ActionTrackerGpsChunk(packetType: bytes.first, points: const []);
    }

    final lat = rawLat / 6000000.0;
    final lon = rawLon / 6000000.0;
    final time = DateTime.now().millisecondsSinceEpoch;

    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return ActionTrackerGpsChunk(packetType: bytes.first, points: const []);
    }

    return ActionTrackerGpsChunk(
      packetType: bytes.first,
      points: [
        ActionTrackerGpsPoint(
          timeMs: time,
          latitude: lat,
          longitude: lon,
        ),
      ],
    );
  }

  ActionTrackerGpsChunk _parseAbsoluteGpsChunk(List<int> bytes, {required ActionTrackerRecord? selectedRecord}) {
    if (bytes.length < 15) return ActionTrackerGpsChunk(packetType: bytes.first, points: const []);

    final chunkIndex = _u16(bytes, 1);
    final progress = selectedRecord == null || selectedRecord.length <= 0
        ? null
        : ((chunkIndex + 1) * 14 / selectedRecord.length).clamp(0, 1).toDouble();

    final points = <ActionTrackerGpsPoint>[];
    var n = 3;
    while (n + 11 < bytes.length) {
      final time = _u32(bytes, n);
      if (time == 0xffffffff) break;
      points.add(ActionTrackerGpsPoint(
        timeMs: time,
        latitude: _i32(bytes, n + 4) / 6000000.0,
        longitude: _i32(bytes, n + 8) / 6000000.0,
      ));
      n += 12;
    }

    return ActionTrackerGpsChunk(packetType: bytes.first, chunkIndex: chunkIndex, progress: progress, points: points);
  }

  ActionTrackerGpsChunk _parseCompressedGps100ms(List<int> bytes, ActionTrackerRecord record) {
    if (bytes.length < 11) return ActionTrackerGpsChunk(packetType: bytes.first, points: const []);

    var time = record.startTimeMs + _u16(bytes, 1) * 100;
    if (bytes[0] == 0x45) time += 6553500;
    var latRaw = _i32(bytes, 3);
    var lonRaw = _i32(bytes, 7);

    final points = <ActionTrackerGpsPoint>[
      ActionTrackerGpsPoint(timeMs: time, latitude: latRaw / 6000000.0, longitude: lonRaw / 6000000.0),
    ];

    var n = 11;
    while (n + 1 < bytes.length) {
      time += 100;
      final b1 = _i8(bytes[n]);
      if (b1 == -128) {
        time += bytes[n + 1] * 100;
      } else {
        latRaw += b1 * 2;
        lonRaw += _i8(bytes[n + 1]) * 2;
        points.add(ActionTrackerGpsPoint(timeMs: time, latitude: latRaw / 6000000.0, longitude: lonRaw / 6000000.0));
      }
      n += 2;
    }

    return ActionTrackerGpsChunk(
      packetType: bytes.first,
      progress: record.length <= 0 ? null : (points.length / record.length).clamp(0, 1).toDouble(),
      points: points,
    );
  }

  ActionTrackerGpsChunk _parseCompressedGps500ms(List<int> bytes, ActionTrackerRecord record) {
    if (bytes.length < 11) return ActionTrackerGpsChunk(packetType: bytes.first, points: const []);

    var time = record.startTimeMs + _u16(bytes, 1) * 500;
    var latRaw = _i32(bytes, 3);
    var lonRaw = _i32(bytes, 7);

    final points = <ActionTrackerGpsPoint>[
      ActionTrackerGpsPoint(timeMs: time, latitude: latRaw / 6000000.0, longitude: lonRaw / 6000000.0),
    ];

    var n = 11;
    while (n + 1 < bytes.length) {
      time += 500;
      final b1 = _i8(bytes[n]);
      if (b1 == -128) {
        time += bytes[n + 1] * 500;
      } else {
        latRaw += b1 * 8;
        lonRaw += _i8(bytes[n + 1]) * 8;
        points.add(ActionTrackerGpsPoint(timeMs: time, latitude: latRaw / 6000000.0, longitude: lonRaw / 6000000.0));
      }
      n += 2;
    }

    return ActionTrackerGpsChunk(
      packetType: bytes.first,
      progress: record.length <= 0 ? null : ((points.length * 5) / record.length).clamp(0, 1).toDouble(),
      points: points,
    );
  }

  static int _u16(List<int> b, int i) => b[i] | (b[i + 1] << 8);

  static int _u32(List<int> b, int i) {
    final data = Uint8List.fromList([b[i], b[i + 1], b[i + 2], b[i + 3]]);
    return ByteData.sublistView(data).getUint32(0, Endian.little);
  }

  static int _i32(List<int> b, int i) {
    final data = Uint8List.fromList([b[i], b[i + 1], b[i + 2], b[i + 3]]);
    return ByteData.sublistView(data).getInt32(0, Endian.little);
  }

  static int _i8(int value) => value > 127 ? value - 256 : value;

  static String _formatDateTitle(int date, int timeMs) {
    final day = ((date % 10000) / 100).floor();
    final month = date % 100;
    if (month > 12 || day > 31 || month <= 0 || day <= 0) return 'Запись';
    final hour = timeMs ~/ 3600000;
    final min = (timeMs - hour * 3600000) ~/ 60000;
    final sec = (timeMs - hour * 3600000 - min * 60000) ~/ 1000;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(day)}.${two(month)} ${two(hour)}:${two(min)}:${two(sec)}';
  }
}
