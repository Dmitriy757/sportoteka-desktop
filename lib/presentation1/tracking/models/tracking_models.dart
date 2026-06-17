import 'package:flutter/material.dart';

enum TrackingMode {
  team,
  individual,
}

enum SessionState {
  idle,
  scanning,
  connecting,
  ready,
  running,
  paused,
  finished,
  error,
}

enum DeviceType {
  vestTracker,
  heartRateMonitor,
  gpsTracker,
  unknown,
}

class TrackingDeviceModel {
  final String id;
  final String name;
  final String macAddress;
  final DeviceType type;
  final bool isConnected;
  final bool isConnecting;
  final int? batteryLevel;
  final int? rssi;
  final String serviceHint;

  const TrackingDeviceModel({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.type,
    required this.isConnected,
    required this.isConnecting,
    this.batteryLevel,
    this.rssi,
    this.serviceHint = '',
  });

  TrackingDeviceModel copyWith({
    String? id,
    String? name,
    String? macAddress,
    DeviceType? type,
    bool? isConnected,
    bool? isConnecting,
    int? batteryLevel,
    int? rssi,
    String? serviceHint,
  }) {
    return TrackingDeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      rssi: rssi ?? this.rssi,
      serviceHint: serviceHint ?? this.serviceHint,
    );
  }
}

class TrackingAthleteModel {
  final int id;
  final String fullName;
  final String? photo;
  final String? position;
  final int? number;

  const TrackingAthleteModel({
    required this.id,
    required this.fullName,
    this.photo,
    this.position,
    this.number,
  });
}

class AthleteDeviceBinding {
  final int athleteId;
  final String athleteName;
  final TrackingDeviceModel? vestDevice;
  final TrackingDeviceModel? hrDevice;

  const AthleteDeviceBinding({
    required this.athleteId,
    required this.athleteName,
    this.vestDevice,
    this.hrDevice,
  });

  AthleteDeviceBinding copyWith({
    int? athleteId,
    String? athleteName,
    TrackingDeviceModel? vestDevice,
    TrackingDeviceModel? hrDevice,
    bool clearVest = false,
    bool clearHr = false,
  }) {
    return AthleteDeviceBinding(
      athleteId: athleteId ?? this.athleteId,
      athleteName: athleteName ?? this.athleteName,
      vestDevice: clearVest ? null : (vestDevice ?? this.vestDevice),
      hrDevice: clearHr ? null : (hrDevice ?? this.hrDevice),
    );
  }

  bool get isReady => vestDevice != null || hrDevice != null;
}

Color trackingStatusColor(SessionState state) {
  switch (state) {
    case SessionState.idle:
      return const Color(0xFF94A3B8);
    case SessionState.scanning:
      return const Color(0xFF2563EB);
    case SessionState.connecting:
      return const Color(0xFFF59E0B);
    case SessionState.ready:
      return const Color(0xFF00A750);
    case SessionState.running:
      return const Color(0xFF00A750);
    case SessionState.paused:
      return const Color(0xFFF59E0B);
    case SessionState.finished:
      return const Color(0xFF6366F1);
    case SessionState.error:
      return const Color(0xFFEF4444);
  }
}

String trackingStatusText(SessionState state) {
  switch (state) {
    case SessionState.idle:
      return 'Ожидание';
    case SessionState.scanning:
      return 'Поиск устройств';
    case SessionState.connecting:
      return 'Подключение';
    case SessionState.ready:
      return 'Готово к старту';
    case SessionState.running:
      return 'Тренировка идет';
    case SessionState.paused:
      return 'Пауза';
    case SessionState.finished:
      return 'Завершено';
    case SessionState.error:
      return 'Ошибка';
  }
}

String deviceTypeTitle(DeviceType type) {
  switch (type) {
    case DeviceType.vestTracker:
      return 'Трекер';
    case DeviceType.heartRateMonitor:
      return 'Пульсометр';
    case DeviceType.gpsTracker:
      return 'GPS';
    case DeviceType.unknown:
      return 'Устройство';
  }
}