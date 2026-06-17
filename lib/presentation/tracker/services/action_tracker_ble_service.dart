import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/action_tracker_protocol.dart';

class ActionTrackerDevice {
  final String id;
  final String name;
  final int rssi;

  const ActionTrackerDevice({required this.id, required this.name, required this.rssi});
}

class ActionTrackerBleService {
  final ActionTrackerProtocolParser _parser = const ActionTrackerProtocolParser();

  final StreamController<List<ActionTrackerDevice>> _devicesController = StreamController<List<ActionTrackerDevice>>.broadcast();
  final StreamController<ActionTrackerParseResult> _dataController = StreamController<ActionTrackerParseResult>.broadcast();
  final StreamController<String> _logController = StreamController<String>.broadcast();

  final Map<String, ActionTrackerDevice> _devices = {};
  final List<StreamSubscription<dynamic>> _subs = [];

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  ActionTrackerRecord? _selectedRecord;
  bool _connecting = false;

  Stream<List<ActionTrackerDevice>> get devicesStream => _devicesController.stream;
  Stream<ActionTrackerParseResult> get dataStream => _dataController.stream;
  Stream<String> get logStream => _logController.stream;

  ActionTrackerDevice? connectedInfo;
  BluetoothDevice? get connectedDevice => _device;
  ActionTrackerRecord? get selectedRecord => _selectedRecord;

  Future<void> init() async {
    final supported = await FlutterBluePlus.isSupported;
    if (!supported) throw Exception('Bluetooth не поддерживается на этом устройстве');

    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _log('Bluetooth выключен. Включите Bluetooth и повторите поиск.');
    }
  }

  Future<void> scan({Duration timeout = const Duration(seconds: 10)}) async {
    _devices.clear();
    _emitDevices();
    _log('Поиск трекеров ActionTracer / GPS...');

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final name = _deviceName(result);
        final id = result.device.remoteId.str;
        final serviceHit = result.advertisementData.serviceUuids
            .map((u) => u.str.toUpperCase())
            .contains(ActionTrackerBleProfile.serviceUuid);
        final prefixOk = ActionTrackerBleProfile.namePrefixes.any((p) => name.startsWith(p));

        // macOS/DMG часто не отдаёт advertised name для BLE-устройств сразу.
        // Поэтому не режем список только по $ACT/$ATP/$GPS: показываем все видимые
        // BLE-устройства с именем, NUS service или хорошим RSSI.
        final visibleEnough = name.isNotEmpty || serviceHit || result.rssi > -82;
        if (!visibleEnough) continue;

        final safeName = name.isEmpty
            ? (prefixOk || serviceHit ? 'ActionTracker GPS' : 'BLE ${id.length <= 8 ? id : id.substring(0, 8)}')
            : name;
        final item = ActionTrackerDevice(id: id, name: safeName, rssi: result.rssi);
        _devices[item.id] = item;
      }
      _emitDevices();
    });
    _subs.add(sub);

    await FlutterBluePlus.startScan(timeout: timeout, androidUsesFineLocation: false);
    await Future<void>.delayed(timeout);
    await FlutterBluePlus.stopScan();
    _log('Поиск завершён. Найдено: ${_devices.length}');
  }

  Future<void> connect(ActionTrackerDevice info) async {
    await FlutterBluePlus.stopScan();

    final current = _device;
    if (current != null && current.remoteId.str == info.id && await _isDeviceConnected(current) && _writeCharacteristic != null) {
      connectedInfo = info;
      _log('Трекер уже подключён: ${info.name}');
      return;
    }

    if (current != null && current.remoteId.str != info.id) {
      await disconnect(clearInfo: true);
    }

    final device = BluetoothDevice.fromId(info.id);
    connectedInfo = info;
    _log('Подключение к ${info.name} / ${info.id}...');

    await _connectAndDiscover(device, info);

    _log('Трекер подключён');
    await requestBatteryAndGpsState();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await requestRecordList();
  }

  Future<void> _connectAndDiscover(BluetoothDevice device, ActionTrackerDevice info) async {
    if (_connecting) return;
    _connecting = true;

    try {
      final alreadyConnected = await _isDeviceConnected(device);
      if (!alreadyConnected) {
        try {
          await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
        } catch (e) {
          final text = e.toString().toLowerCase();
          if (!text.contains('already') && !text.contains('connected')) rethrow;
        }
      }

      _device = device;
      connectedInfo = info;

      await _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _writeCharacteristic = null;
          _notifyCharacteristic = null;
          _log('BLE отключился: ${info.name}. Live попробует переподключиться перед следующей TX-командой.');
        }
      });

      final services = await device.discoverServices();
      BluetoothCharacteristic? notifyChar;
      BluetoothCharacteristic? writeChar;

      for (final service in services) {
        if (service.uuid.str.toUpperCase() != ActionTrackerBleProfile.serviceUuid) continue;
        for (final c in service.characteristics) {
          final uuid = c.uuid.str.toUpperCase();
          if (uuid == ActionTrackerBleProfile.notifyUuid) notifyChar = c;
          if (uuid == ActionTrackerBleProfile.writeUuid) writeChar = c;
        }
      }

      if (notifyChar == null || writeChar == null) {
        throw Exception('Не найдены BLE-характеристики трекера');
      }

      _writeCharacteristic = writeChar;
      _notifyCharacteristic = notifyChar;

      await _notifySub?.cancel();
      await notifyChar.setNotifyValue(true);
      _notifySub = notifyChar.onValueReceived.listen((bytes) {
        final result = _parser.parse(bytes, selectedRecord: _selectedRecord);
        _dataController.add(result);
        _log('RX ${result.rawHex}');
      });

      try {
        await device.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high);
      } catch (_) {}
    } finally {
      _connecting = false;
    }
  }

  Future<bool> _isDeviceConnected(BluetoothDevice device) async {
    try {
      final state = await device.connectionState.first.timeout(const Duration(milliseconds: 600));
      return state == BluetoothConnectionState.connected;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureReadyForWrite() async {
    final info = connectedInfo;
    var device = _device;

    if (info == null) {
      _log('BLE reconnect skipped: connectedInfo is null');
      return false;
    }

    device ??= BluetoothDevice.fromId(info.id);
    _device = device;

    final connected = await _isDeviceConnected(device);
    if (connected && _writeCharacteristic != null) return true;

    _log('BLE reconnect: ${info.name} / ${info.id}...');
    try {
      await _connectAndDiscover(device, info);
      final ok = await _isDeviceConnected(device) && _writeCharacteristic != null;
      if (ok) {
        _log('BLE reconnect OK');
        return true;
      }
      _log('BLE reconnect failed: write characteristic is null');
    } catch (e) {
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _log('BLE reconnect direct error: $e');
    }

    // macOS иногда меняет runtime-id BLE-устройства после разрыва.
    // Поэтому пробуем короткий повторный scan и ищем тот же id/name.
    final found = await _scanForReconnect(info);
    if (found == null) {
      _log('BLE reconnect scan failed: tracker not found');
      return false;
    }

    try {
      final scannedDevice = BluetoothDevice.fromId(found.id);
      _device = scannedDevice;
      connectedInfo = found;
      await _connectAndDiscover(scannedDevice, found);
      final ok = await _isDeviceConnected(scannedDevice) && _writeCharacteristic != null;
      _log(ok ? 'BLE reconnect scan OK: ${found.name} / ${found.id}' : 'BLE reconnect scan failed: no write char');
      return ok;
    } catch (e) {
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _log('BLE reconnect scan error: $e');
      return false;
    }
  }

  Future<ActionTrackerDevice?> _scanForReconnect(ActionTrackerDevice target) async {
    final targetName = target.name.trim().toUpperCase();
    final targetId = target.id.trim();
    final found = <String, ActionTrackerDevice>{};
    StreamSubscription<List<ScanResult>>? sub;

    try {
      await FlutterBluePlus.stopScan();
      sub = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final name = _deviceName(result);
          final id = result.device.remoteId.str;
          if (name.isEmpty && id.isEmpty) continue;
          found[id] = ActionTrackerDevice(
            id: id,
            name: name.isEmpty ? 'BLE ${id.length <= 8 ? id : id.substring(0, 8)}' : name,
            rssi: result.rssi,
          );
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4), androidUsesFineLocation: false);
      await Future<void>.delayed(const Duration(seconds: 4));
      await FlutterBluePlus.stopScan();
    } catch (e) {
      _log('BLE reconnect scan exception: $e');
    } finally {
      await sub?.cancel();
    }

    if (found.containsKey(targetId)) return found[targetId];

    final candidates = found.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    for (final item in candidates) {
      final name = item.name.toUpperCase();
      if (targetName.isNotEmpty && name == targetName) return item;
      if (targetName.isNotEmpty && name.contains(targetName.replaceAll(' ', ''))) return item;
      if (name.contains('ATP') || name.contains('ACTION') || name.contains('TRACK') || name.contains('GPS')) return item;
    }
    return null;
  }

  Future<void> disconnect({bool clearInfo = true}) async {
    final device = _device;
    _log('Отключение...');

    await _notifySub?.cancel();
    _notifySub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;

    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _selectedRecord = null;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    _device = null;
    if (clearInfo) connectedInfo = null;
  }

  Future<void> requestBatteryAndGpsState() => _write(ActionTrackerBleProfile.commandReadBatteryAndGps);
  Future<void> requestRecordList() => _write(ActionTrackerBleProfile.commandReadFileList);

  /// Экспериментальный режим Live.
  /// В APK найдены функции текущего GPS, но байтовая команда зависит от прошивки.
  /// Этот метод позволяет отправлять диагностические команды и смотреть RX-пакеты.
  Future<void> sendRawCommand(List<int> bytes) => _write(bytes);

  Future<void> requestCurrentGpsCandidate({int candidateIndex = 0}) {
    final list = ActionTrackerBleProfile.commandCurrentGpsCandidates;
    final safeIndex = candidateIndex < 0 || candidateIndex >= list.length ? 0 : candidateIndex;
    return _write(list[safeIndex]);
  }

  Future<void> requestGpsRecord(ActionTrackerRecord record) async {
    _selectedRecord = record;
    _log('Запрос GPS-записи ${record.fileId}');
    await _write(ActionTrackerBleProfile.commandReadGpsByFileId(record.fileId));
  }

  Future<void> _write(List<int> bytes) async {
    final ready = await _ensureReadyForWrite();
    final c = _writeCharacteristic;

    final hex = bytes.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    if (!ready || c == null) {
      _log('TX пропущен: BLE не подключён / $hex');
      throw Exception('BLE-трекер не подключён. Нажмите «Сменить» и выберите трекер заново.');
    }

    _log('TX $hex');

    try {
      await c.write(bytes, withoutResponse: c.properties.writeWithoutResponse);
    } catch (e) {
      final text = e.toString().toLowerCase();
      final disconnected = text.contains('not connected') || text.contains('device is not connected') || text.contains('fbp-code: 6');
      if (!disconnected) rethrow;

      _log('TX ошибка: device is not connected. Повторное переподключение...');
      _writeCharacteristic = null;
      _notifyCharacteristic = null;

      final recovered = await _ensureReadyForWrite();
      final retryChar = _writeCharacteristic;
      if (!recovered || retryChar == null) {
        throw Exception('BLE-трекер отключился. Не удалось переподключиться автоматически.');
      }

      _log('TX retry $hex');
      await retryChar.write(bytes, withoutResponse: retryChar.properties.writeWithoutResponse);
    }
  }

  String _deviceName(ScanResult result) {
    final adv = result.advertisementData.advName.trim();
    if (adv.isNotEmpty) return adv;
    final platform = result.device.platformName.trim();
    if (platform.isNotEmpty) return platform;
    return '';
  }

  void _emitDevices() {
    int priority(ActionTrackerDevice d) {
      final name = d.name.toUpperCase();
      if (ActionTrackerBleProfile.namePrefixes.any((p) => name.startsWith(p.toUpperCase()))) return 0;
      if (name.contains('ACTION') || name.contains('TRACK') || name.contains('GPS') || name.contains('AT')) return 1;
      return 2;
    }

    final list = _devices.values.toList()
      ..sort((a, b) {
        final pa = priority(a);
        final pb = priority(b);
        if (pa != pb) return pa.compareTo(pb);
        return b.rssi.compareTo(a.rssi);
      });
    _devicesController.add(list);
  }

  void _log(String message) => _logController.add('[${DateTime.now().toIso8601String()}] $message');

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await disconnect(clearInfo: true);
    await _devicesController.close();
    await _dataController.close();
    await _logController.close();
  }
}
