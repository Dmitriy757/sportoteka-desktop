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
  ActionTrackerRecord? _selectedRecord;

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
        final prefixOk = ActionTrackerBleProfile.namePrefixes.any((p) => name.startsWith(p));
        if (!prefixOk) continue;
        final item = ActionTrackerDevice(id: result.device.remoteId.str, name: name, rssi: result.rssi);
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
    final device = BluetoothDevice.fromId(info.id);
    _log('Подключение к ${info.name} / ${info.id}...');

    await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
    _device = device;
    connectedInfo = info;

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
    await notifyChar.setNotifyValue(true);

    final notifySub = notifyChar.onValueReceived.listen((bytes) {
      final result = _parser.parse(bytes, selectedRecord: _selectedRecord);
      _dataController.add(result);
      _log('RX ${result.rawHex}');
    });
    _subs.add(notifySub);

    try {
      await device.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high);
    } catch (_) {}

    _log('Трекер подключён');
    await requestBatteryAndGpsState();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await requestRecordList();
  }

  Future<void> disconnect() async {
    final device = _device;
    if (device == null) return;
    _log('Отключение...');
    await device.disconnect();
    _device = null;
    connectedInfo = null;
    _writeCharacteristic = null;
    _selectedRecord = null;
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
    final c = _writeCharacteristic;
    if (c == null) throw Exception('Трекер не подключён');
    _log('TX ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}');
    await c.write(bytes, withoutResponse: c.properties.writeWithoutResponse);
  }

  String _deviceName(ScanResult result) {
    final adv = result.advertisementData.advName.trim();
    if (adv.isNotEmpty) return adv;
    final platform = result.device.platformName.trim();
    if (platform.isNotEmpty) return platform;
    return '';
  }

  void _emitDevices() {
    final list = _devices.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    _devicesController.add(list);
  }

  void _log(String message) => _logController.add('[${DateTime.now().toIso8601String()}] $message');

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await disconnect();
    await _devicesController.close();
    await _dataController.close();
    await _logController.close();
  }
}
