import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../models/tracking_models.dart';

class TrackingBleService {
  TrackingBleService._();
  static final TrackingBleService instance = TrackingBleService._();

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  StreamSubscription<DiscoveredDevice>? _scanSub;
  final Map<String, StreamSubscription<ConnectionStateUpdate>> _connections = {};

  final StreamController<List<TrackingDeviceModel>> _devicesController =
      StreamController<List<TrackingDeviceModel>>.broadcast();

  final Map<String, TrackingDeviceModel> _devices = {};

  Stream<List<TrackingDeviceModel>> get devicesStream => _devicesController.stream;

  List<TrackingDeviceModel> get currentDevices => _devices.values.toList();

  Future<void> startScan() async {
    await stopScan();

    _scanSub = _ble.scanForDevices(
      withServices: const [],
      scanMode: ScanMode.lowLatency,
      requireLocationServicesEnabled: false,
    ).listen(
      (device) {
        final existing = _devices[device.id];

        final parsed = TrackingDeviceModel(
          id: device.id,
          name: device.name.isNotEmpty ? device.name : 'BLE device',
          macAddress: device.id,
          type: _detectType(
            name: device.name,
            serviceData: device.serviceData,
            manufacturerData: device.manufacturerData,
          ),
          isConnected: existing?.isConnected ?? false,
          isConnecting: existing?.isConnecting ?? false,
          batteryLevel: existing?.batteryLevel,
          rssi: device.rssi,
          serviceHint: _serviceHint(device),
        );

        _devices[device.id] = parsed;
        _emitDevices();
      },
      onError: (e) {
        debugPrint('BLE scan error: $e');
      },
    );
  }

  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
  }

  Future<void> connect(String deviceId) async {
    final current = _devices[deviceId];
    if (current == null) return;

    _devices[deviceId] = current.copyWith(
      isConnecting: true,
      isConnected: false,
    );
    _emitDevices();

    await _connections[deviceId]?.cancel();

    _connections[deviceId] = _ble
        .connectToDevice(
          id: deviceId,
          connectionTimeout: const Duration(seconds: 12),
        )
        .listen(
      (update) {
        final prev = _devices[deviceId];
        if (prev == null) return;

        switch (update.connectionState) {
          case DeviceConnectionState.connecting:
            _devices[deviceId] = prev.copyWith(
              isConnecting: true,
              isConnected: false,
            );
            break;
          case DeviceConnectionState.connected:
            _devices[deviceId] = prev.copyWith(
              isConnecting: false,
              isConnected: true,
            );
            _readBatteryBestEffort(deviceId);
            break;
          case DeviceConnectionState.disconnecting:
            _devices[deviceId] = prev.copyWith(
              isConnecting: true,
              isConnected: false,
            );
            break;
          case DeviceConnectionState.disconnected:
            _devices[deviceId] = prev.copyWith(
              isConnecting: false,
              isConnected: false,
            );
            break;
        }

        _emitDevices();
      },
      onError: (e) {
        final prev = _devices[deviceId];
        if (prev != null) {
          _devices[deviceId] = prev.copyWith(
            isConnecting: false,
            isConnected: false,
          );
          _emitDevices();
        }
        debugPrint('BLE connect error ($deviceId): $e');
      },
    );
  }

  Future<void> disconnect(String deviceId) async {
    await _connections[deviceId]?.cancel();
    _connections.remove(deviceId);

    final prev = _devices[deviceId];
    if (prev != null) {
      _devices[deviceId] = prev.copyWith(
        isConnected: false,
        isConnecting: false,
      );
      _emitDevices();
    }
  }

  Future<void> refreshRssi() async {
    _emitDevices();
  }

  Future<void> disposeAll() async {
    await stopScan();
    for (final sub in _connections.values) {
      await sub.cancel();
    }
    _connections.clear();
  }

  void _emitDevices() {
    _devicesController.add(_devices.values.toList()
      ..sort((a, b) {
        if (a.isConnected != b.isConnected) {
          return a.isConnected ? -1 : 1;
        }
        return (b.rssi ?? -999).compareTo(a.rssi ?? -999);
      }));
  }

  DeviceType _detectType({
    required String name,
    required Map<Uuid, List<int>> serviceData,
    required Uint8List manufacturerData,
  }) {
    final lower = name.toLowerCase();

    if (lower.contains('polar') ||
        lower.contains('hr') ||
        lower.contains('heart') ||
        lower.contains('h10') ||
        lower.contains('h9')) {
      return DeviceType.heartRateMonitor;
    }

    if (lower.contains('vest') ||
        lower.contains('tracker') ||
        lower.contains('gps')) {
      return DeviceType.vestTracker;
    }

    if (lower.contains('garmin')) {
      return DeviceType.gpsTracker;
    }

    return DeviceType.unknown;
  }

  String _serviceHint(DiscoveredDevice device) {
    if (device.serviceData.isNotEmpty) {
      return 'serviceData: ${device.serviceData.length}';
    }
    if (device.manufacturerData.isNotEmpty) {
      return 'manufacturerData';
    }
    return '';
  }

  Future<void> _readBatteryBestEffort(String deviceId) async {
    try {
     final batteryService =
    Uuid.parse('0000180F-0000-1000-8000-00805F9B34FB');
final batteryCharacteristic =
    Uuid.parse('00002A19-0000-1000-8000-00805F9B34FB');
    

      final q = QualifiedCharacteristic(
        serviceId: batteryService,
        characteristicId: batteryCharacteristic,
        deviceId: deviceId,
      );

      final value = await _ble.readCharacteristic(q);
      if (value.isEmpty) return;

      final battery = value.first;
      final prev = _devices[deviceId];
      if (prev != null) {
        _devices[deviceId] = prev.copyWith(batteryLevel: battery);
        _emitDevices();
      }
    } catch (_) {
      // не у всех устройств есть battery service
    }
  }
}