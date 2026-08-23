import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'action_tracker_ble_service.dart';

class HeartRateBleProfile {
  static const String heartRateServiceUuid =
      '0000180D-0000-1000-8000-00805F9B34FB';
  static const String heartRateMeasurementUuid =
      '00002A37-0000-1000-8000-00805F9B34FB';
  static const String bodySensorLocationUuid =
      '00002A38-0000-1000-8000-00805F9B34FB';
  static const String batteryServiceUuid =
      '0000180F-0000-1000-8000-00805F9B34FB';
  static const String batteryLevelUuid = '00002A19-0000-1000-8000-00805F9B34FB';

  static const List<String> nameHints = <String>[
    'POLAR',
    'H10',
    'H9',
    'OH1',
    'VERITY',
    'HEART',
    'HRM',
  ];
}

class HeartRateBleDevice {
  final String id;
  final String name;
  final int rssi;
  final bool serviceHit;
  final bool rawProbe;

  const HeartRateBleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.serviceHit = false,
    this.rawProbe = false,
  });

  HeartRateBleDevice copyWith({
    String? id,
    String? name,
    int? rssi,
    bool? serviceHit,
    bool? rawProbe,
  }) =>
      HeartRateBleDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        rssi: rssi ?? this.rssi,
        serviceHit: serviceHit ?? this.serviceHit,
        rawProbe: rawProbe ?? this.rawProbe,
      );
}

class HeartRateSample {
  final String deviceId;
  final String deviceName;
  final int bpm;
  final int? batteryPercent;
  final bool? sensorContactDetected;
  final List<int> rrIntervalsMs;
  final DateTime measuredAt;

  const HeartRateSample({
    required this.deviceId,
    required this.deviceName,
    required this.bpm,
    this.batteryPercent,
    this.sensorContactDetected,
    this.rrIntervalsMs = const <int>[],
    required this.measuredAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'heart_rate_bpm': bpm,
        'heart_rate_device_id': deviceId,
        'heart_rate_device_uuid': deviceId,
        'heart_rate_device_name': deviceName,
        if (batteryPercent != null)
          'heart_rate_battery_percent': batteryPercent,
        if (sensorContactDetected != null)
          'heart_rate_contact': sensorContactDetected,
        if (rrIntervalsMs.isNotEmpty)
          'heart_rate_rr_intervals_ms': rrIntervalsMs,
        'heart_rate_measured_at': measuredAt.toIso8601String(),
      };
}

class _HeartRateCharacteristics {
  final BluetoothCharacteristic? measurement;
  final BluetoothCharacteristic? battery;
  final BluetoothCharacteristic? bodyLocation;

  const _HeartRateCharacteristics(
      {this.measurement, this.battery, this.bodyLocation});
}

class _HeartRateConnection {
  final BluetoothDevice device;
  HeartRateBleDevice info;
  BluetoothCharacteristic? measurement;
  BluetoothCharacteristic? battery;
  StreamSubscription<List<int>>? notifySub;
  StreamSubscription<BluetoothConnectionState>? connectionSub;
  int? batteryPercent;
  bool connecting = false;
  bool ready = false;

  _HeartRateConnection({required this.device, required this.info});
}

class HeartRateBleService {
  static Future<List<HeartRateBleDevice>>? _sharedScanInFlight;
  final StreamController<List<HeartRateBleDevice>> _devicesController =
      StreamController<List<HeartRateBleDevice>>.broadcast();
  final StreamController<HeartRateSample> _sampleController =
      StreamController<HeartRateSample>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  final Map<String, HeartRateBleDevice> _devices =
      <String, HeartRateBleDevice>{};
  final Map<String, _HeartRateConnection> _connections =
      <String, _HeartRateConnection>{};
  final Map<String, HeartRateSample> _lastSamplesByDeviceId =
      <String, HeartRateSample>{};

  bool _connectingAny = false;
  bool _disposed = false;

  Stream<List<HeartRateBleDevice>> get devicesStream =>
      _devicesController.stream;

  /// Последний накопленный результат поиска Polar/Heart Rate BLE.
  List<HeartRateBleDevice> get discoveredDevices {
    final result = _devices.values.toList(growable: false)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return result;
  }
  Stream<HeartRateSample> get sampleStream => _sampleController.stream;
  Stream<String> get logStream => _logController.stream;

  /// Последний подключённый/выбранный пульсометр. Оставлено для совместимости старого UI.
  HeartRateBleDevice? connectedInfo;
  HeartRateBleDevice? lastKnownInfo;
  HeartRateSample? lastSample;

  List<HeartRateBleDevice> get connectedInfos => _connections.values
      .where((c) => c.ready)
      .map((c) => c.info)
      .toList(growable: false);
  Map<String, HeartRateSample> get lastSamplesByDeviceId =>
      Map<String, HeartRateSample>.unmodifiable(_lastSamplesByDeviceId);
  int get connectedCount => connectedInfos.length;

  bool get heartRateReady => _connections.values.any((c) => c.ready);
  int? get batteryPercent => connectedInfo == null
      ? null
      : _connections[connectedInfo!.id]?.batteryPercent;

  bool isConnected(String deviceId) => _connections[deviceId]?.ready == true;
  HeartRateSample? lastSampleForDevice(String deviceId) =>
      _lastSamplesByDeviceId[deviceId];
  HeartRateBleDevice? connectedDevice(String deviceId) =>
      _connections[deviceId]?.info;

  Future<void> init() async {
    // V175: общий runtime-check с GPS. На iOS/macOS этот путь не вызывает
    // FlutterBluePlus.isSupported и тем самым обходит duplicate FlutterResult.
    final state = await ActionTrackerBleService.ensureBluetoothRuntimeReady();
    if (state != BluetoothAdapterState.on) {
      _log('Bluetooth выключен. Включите Bluetooth перед поиском Polar H10.');
    }
  }

  Future<void> scan({
    Duration timeout = const Duration(seconds: 8),
    bool showAllBleCandidates = false,
  }) async {
    if (_disposed) return;
    if (ActionTrackerBleService.teamLiveGuardActive) {
      _log(
          'HEART SCAN BLOCKED: командный GPS Live уже идёт; новый общий BLE scan может оборвать работающие GPS-каналы. Переподключите Polar после Stop.');
      _emitDevices();
      return;
    }
    final sharedScan = _sharedScanInFlight;
    if (sharedScan != null) {
      _log('HEART SCAN JOIN: общий поиск уже выполняется в другом окне');
      final sharedDevices = await sharedScan;
      for (final device in sharedDevices) {
        _devices[device.id] = device;
      }
      _emitDevices();
      return;
    }
    final sharedCompleter = Completer<List<HeartRateBleDevice>>();
    final sharedFuture = sharedCompleter.future;
    _sharedScanInFlight = sharedFuture;
    try {
    // Не очищаем ни подключённые, ни недавно найденные H10. На Honor/MagicOS
    // рекламные пакеты приходят неравномерно, поэтому очистка перед scan визуально
    // заставляла датчики исчезать.
    for (final c in _connections.values) {
      _devices[c.info.id] =
          c.info.copyWith(rssi: c.info.rssi, serviceHit: true, rawProbe: false);
    }
    _emitDevices();

    final adapterState = await FlutterBluePlus.adapterState.first.timeout(
      const Duration(seconds: 2),
      onTimeout: () => BluetoothAdapterState.unknown,
    );
    final modeText =
        showAllBleCandidates ? 'all-ble-diagnostic' : 'heart-rate-only';
    _log(
        'HEART TEAM SCAN START: adapter=$adapterState · mode=$modeText · connected=${connectedInfos.length}/12 · service=Heart Rate 180D');

    await _addSystemHeartDevices(
        source: 'pre-scan', includeAllBleCandidates: showAllBleCandidates);

    final rawSeen = <String, HeartRateBleDevice>{};
    final rawServices = <String, String>{};

    Future<void> runStage({
      required String stage,
      required Duration stageTimeout,
      required bool androidUsesFineLocation,
    }) async {
      StreamSubscription<List<ScanResult>>? sub;
      var added = 0;
      var serviceHits = 0;
      var nameHits = 0;

      await ActionTrackerBleService.runExclusiveBleScan<void>(() async {
      try {
        await ActionTrackerBleService.stopManagedScan();
        // Honor/MagicOS нужен небольшой cooldown между остановкой и новым scan.
        await Future<void>.delayed(const Duration(milliseconds: 650));
        _log(
            'HEART SCAN STAGE[$stage]: timeout=${stageTimeout.inSeconds}s · androidFineLocation=$androidUsesFineLocation');
        sub = FlutterBluePlus.scanResults.listen((results) {
          for (final result in results) {
            final id = result.device.remoteId.str.trim();
            if (id.isEmpty) continue;

            final name = _deviceName(result);
            final serviceUuids = result.advertisementData.serviceUuids
                .map((u) => u.str.toUpperCase())
                .toList(growable: false);
            final servicesText = serviceUuids.isEmpty
                ? 'services=нет'
                : serviceUuids.take(6).join(',');
            rawServices[id] = servicesText;

            final serviceHit = result.advertisementData.serviceUuids.any((u) =>
                _sameUuid(u.str, HeartRateBleProfile.heartRateServiceUuid));
            final charHint = result.advertisementData.serviceUuids.any((u) =>
                _sameUuid(u.str, HeartRateBleProfile.heartRateMeasurementUuid));
            final nameHit = _looksLikeHeartRateName(name);
            final usableSignal = result.rssi >= -98;
            final hasName = name.trim().isNotEmpty;

            if (serviceHit || charHint) serviceHits++;
            if (nameHit) nameHits++;

            final rawName = name.isEmpty ? 'BLE ${_shortId(id)}' : name;
            rawSeen[id] = HeartRateBleDevice(
              id: id,
              name: rawName,
              rssi: result.rssi,
              serviceHit: serviceHit || charHint,
              rawProbe: !serviceHit && !charHint && !nameHit,
            );

            final shouldShow = serviceHit ||
                charHint ||
                nameHit ||
                (hasName && usableSignal) ||
                (showAllBleCandidates && usableSignal);
            if (!shouldShow) continue;

            final connected = _connections[id];
            final safeName = name.trim().isEmpty
                ? (serviceHit || charHint
                    ? 'Пульсометр ${_shortId(id)}'
                    : 'BLE ${_shortId(id)} · проверить')
                : name.trim();
            final item = connected?.info.copyWith(
                    rssi: result.rssi, serviceHit: true, rawProbe: false) ??
                HeartRateBleDevice(
                  id: id,
                  name: safeName,
                  rssi: result.rssi,
                  serviceHit: serviceHit || charHint,
                  rawProbe: !serviceHit && !charHint && !nameHit,
                );
            final isNew = !_devices.containsKey(id);
            _devices[id] = item;
            if (isNew) {
              added++;
              final marker = serviceHit || charHint || nameHit
                  ? 'HEART SENSOR?'
                  : 'BLE DIAG?';
              _log(
                  '$marker [$stage] $safeName / $id / RSSI ${result.rssi} / $servicesText');
            }
          }
          _emitDevices();
        }, onError: (Object e) {
          _log('Heart Rate scan stream error[$stage]: $e');
        });

        await ActionTrackerBleService.startManagedScan(
            timeout: stageTimeout,
            androidUsesFineLocation: androidUsesFineLocation);
        final scanDeadline = DateTime.now()
            .add(stageTimeout + const Duration(milliseconds: 250));
        while (!ActionTrackerBleService.teamLiveGuardActive &&
            DateTime.now().isBefore(scanDeadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (ActionTrackerBleService.teamLiveGuardActive) {
          _log('HEART SCAN CANCELLED: начался Team Live');
        }
      } catch (e) {
        _log('HEART SCAN ERROR[$stage]: $e');
      } finally {
        await ActionTrackerBleService.stopManagedScan();
        await sub?.cancel();
      }
      });

      _log(
          'HEART SCAN STAGE[$stage] END: raw_seen=${rawSeen.length} · shown=${_devices.length} · added=$added · service_hits=$serviceHits · name_hits=$nameHits · connected=${connectedInfos.length}/12');
    }

    final stableTimeout = timeout < const Duration(seconds: 12)
        ? const Duration(seconds: 12)
        : timeout;
    await runStage(
        stage: 'normal',
        stageTimeout: stableTimeout,
        androidUsesFineLocation: true);

    if (!ActionTrackerBleService.teamLiveGuardActive &&
        (_devices.length <= _connections.length || showAllBleCandidates)) {
      await runStage(
        stage:
            showAllBleCandidates ? 'diagnostic-wide' : 'fallback-no-location',
        stageTimeout: showAllBleCandidates
            ? const Duration(seconds: 15)
            : const Duration(seconds: 12),
        androidUsesFineLocation: false,
      );
    }

    await _addSystemHeartDevices(
        source: 'post-scan', includeAllBleCandidates: showAllBleCandidates);
    _emitDevices();

    final topRaw = rawSeen.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    final topText = topRaw
        .take(12)
        .map((d) =>
            '${d.name}/${d.id}/RSSI ${d.rssi}${d.serviceHit ? '/180D' : ''}/${rawServices[d.id] ?? 'services=?'}')
        .join(' | ');
    if (topText.isNotEmpty) _log('HEART SCAN RAW TOP: $topText');

    final visibleNew = _devices.length - _connections.length;
    if (_devices.isEmpty || visibleNew <= 0 && _connections.isEmpty) {
      final rawHint = rawSeen.isEmpty
          ? 'Телефон/планшет не увидел BLE-устройства. Проверьте Bluetooth/Nearby Devices/геолокацию Android, ремень и батарейку H10.'
          : 'BLE вокруг виден (${rawSeen.length}), но явного Polar/Heart Rate нет. Нажмите «Показать все BLE рядом» и проверьте ближайший BLE-кандидат.';
      _log(
          'POLAR H10 NOT FOUND DETAIL: $rawHint Для команды подключайте датчики по одному: подключили H10 → выбрали игрока → назначили → снова поиск следующего H10.');
    } else {
      final probeHint = showAllBleCandidates
          ? 'Диагностика включена: можно нажать ближайший BLE-кандидат. Подключение само проверит Heart Rate 180D/2A37.'
          : 'Можно подключать несколько Polar H10 подряд. Уже подключённые H10 остаются в списке.';
      _log(
          'HEART SCAN END: показано ${_devices.length}, подключено ${connectedInfos.length}/12. $probeHint');
    }
    } finally {
      if (!sharedCompleter.isCompleted) {
        sharedCompleter.complete(
          List<HeartRateBleDevice>.unmodifiable(_devices.values),
        );
      }
      if (identical(_sharedScanInFlight, sharedFuture)) {
        _sharedScanInFlight = null;
      }
    }
  }

  Future<void> connect(HeartRateBleDevice info) async {
    if (_disposed) throw StateError('Heart Rate BLE service уже закрыт');
    if (ActionTrackerBleService.teamLiveGuardActive &&
        !isConnected(info.id)) {
      throw StateError(
          'Командный GPS Live уже идёт: новый Polar подключается после Stop.');
    }
    await ActionTrackerBleService.stopManagedScan();

    final current = _connections[info.id];
    if (current != null &&
        current.ready &&
        await _isDeviceConnected(current.device)) {
      connectedInfo = current.info;
      lastKnownInfo = current.info;
      _log(
          'Пульсометр уже подключён: ${current.info.name} · всего ${connectedInfos.length}/12');
      return;
    }

    final device = current?.device ?? BluetoothDevice.fromId(info.id);
    final conn = current ?? _HeartRateConnection(device: device, info: info);
    conn.info = info.copyWith(serviceHit: true, rawProbe: false);
    _connections[info.id] = conn;
    connectedInfo = conn.info;
    lastKnownInfo = conn.info;
    _devices[info.id] = conn.info;
    _emitDevices();
    _log(
        'Подключение пульсометра: ${info.name} / ${info.id} · команда ${connectedInfos.length}/12...');

    try {
      await _connectAndDiscover(conn);
      _log(
          'Пульсометр подключён: ${conn.info.name}. Ожидаю bpm · всего ${connectedInfos.length}/12');
    } catch (_) {
      // Не держим незавершённый GATT-клиент после 133: он отнимает слот у GPS.
      await disconnect(deviceId: info.id, clearInfo: false);
      rethrow;
    }
  }

  Future<void> _connectAndDiscover(_HeartRateConnection conn) async {
    if (conn.connecting || _connectingAny) return;
    conn.connecting = true;
    _connectingAny = true;

    try {
      final device = conn.device;
      final info = conn.info;
      final alreadyConnected = await _isDeviceConnected(device);
      if (!alreadyConnected) {
        try {
          await device.connect(
              autoConnect: false, timeout: const Duration(seconds: 15));
        } catch (e) {
          final text = e.toString().toLowerCase();
          if (!text.contains('already') && !text.contains('connected')) rethrow;
        }
      }

      connectedInfo = info;
      lastKnownInfo = info;

      await conn.connectionSub?.cancel();
      conn.connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          conn.ready = false;
          conn.measurement = null;
          conn.battery = null;
          connectedInfo = connectedInfos.isEmpty ? info : connectedInfos.last;
          lastKnownInfo = info;
          _log(
              'Пульсометр отключился: ${info.name}. Осталось подключено ${connectedInfos.length}/12.');
          _emitDevices();
        }
      });

      final services = await device.discoverServices();
      final chars = _findHeartRateCharacteristics(services);
      final measurement = chars.measurement;
      if (measurement == null) {
        _connections.remove(info.id);
        final serviceList = services.map((s) {
          final c = s.characteristics
              .map((x) => '${x.uuid.str.toUpperCase()}(${_charProps(x)})')
              .join(', ');
          return '${s.uuid.str.toUpperCase()} [$c]';
        }).join(' | ');
        throw Exception(
            'Это BLE-устройство не отдаёт Heart Rate 180D/2A37. Services: $serviceList');
      }

      conn.measurement = measurement;
      conn.battery = chars.battery;

      if (conn.battery != null && conn.battery!.properties.read) {
        try {
          final raw = await conn.battery!.read();
          if (raw.isNotEmpty)
            conn.batteryPercent = raw.first.clamp(0, 100).toInt();
        } catch (e) {
          _log('Battery read skipped ${info.name}: $e');
        }
      }

      await conn.notifySub?.cancel();
      await measurement.setNotifyValue(true);
      conn.ready = true;
      connectedInfo = conn.info;
      _devices[conn.info.id] =
          conn.info.copyWith(serviceHit: true, rawProbe: false);
      _emitDevices();

      conn.notifySub = measurement.onValueReceived.listen((bytes) {
        if (_disposed) return;
        final sample =
            _parseHeartRateMeasurement(bytes, conn.info, conn.batteryPercent);
        if (sample == null) return;
        lastSample = sample;
        _lastSamplesByDeviceId[sample.deviceId] = sample;
        if (!_sampleController.isClosed) _sampleController.add(sample);
        final rr = sample.rrIntervalsMs.isEmpty
            ? ''
            : ' · RR ${sample.rrIntervalsMs.take(3).join('/')} мс';
        final contact = sample.sensorContactDetected == null
            ? ''
            : ' · контакт ${sample.sensorContactDetected! ? 'есть' : 'нет'}';
        final battery = sample.batteryPercent == null
            ? ''
            : ' · батарея ${sample.batteryPercent}%';
        _log('HR ${sample.deviceName}: ${sample.bpm} bpm$battery$contact$rr');
      });

      // Для постоянного online bpm высокая полоса не нужна. HIGH у Polar
      // занимал BLE connection intervals и на Honor оставлял место лишь для
      // шести GPS. BALANCED позволяет контроллеру обслуживать больше каналов.
      try {
        await device.requestConnectionPriority(
          connectionPriorityRequest: ConnectionPriority.balanced,
        );
      } catch (_) {}
    } finally {
      conn.connecting = false;
      _connectingAny = false;
    }
  }

  _HeartRateCharacteristics _findHeartRateCharacteristics(
      List<BluetoothService> services) {
    BluetoothCharacteristic? measurement;
    BluetoothCharacteristic? battery;
    BluetoothCharacteristic? bodyLocation;

    for (final service in services) {
      final serviceUuid = service.uuid.str;
      for (final c in service.characteristics) {
        final uuid = c.uuid.str;
        if (_sameUuid(serviceUuid, HeartRateBleProfile.heartRateServiceUuid) &&
            _sameUuid(uuid, HeartRateBleProfile.heartRateMeasurementUuid) &&
            (c.properties.notify || c.properties.indicate)) {
          measurement = c;
        }
        if (_sameUuid(serviceUuid, HeartRateBleProfile.heartRateServiceUuid) &&
            _sameUuid(uuid, HeartRateBleProfile.bodySensorLocationUuid)) {
          bodyLocation = c;
        }
        if (_sameUuid(serviceUuid, HeartRateBleProfile.batteryServiceUuid) &&
            _sameUuid(uuid, HeartRateBleProfile.batteryLevelUuid)) {
          battery = c;
        }
      }
    }

    measurement ??= services
        .expand((s) => s.characteristics)
        .where((c) =>
            _sameUuid(
                c.uuid.str, HeartRateBleProfile.heartRateMeasurementUuid) &&
            (c.properties.notify || c.properties.indicate))
        .cast<BluetoothCharacteristic?>()
        .firstWhere((c) => c != null, orElse: () => null);

    battery ??= services
        .expand((s) => s.characteristics)
        .where(
            (c) => _sameUuid(c.uuid.str, HeartRateBleProfile.batteryLevelUuid))
        .cast<BluetoothCharacteristic?>()
        .firstWhere((c) => c != null, orElse: () => null);

    return _HeartRateCharacteristics(
        measurement: measurement, battery: battery, bodyLocation: bodyLocation);
  }

  HeartRateSample? _parseHeartRateMeasurement(
      List<int> bytes, HeartRateBleDevice info, int? batteryPercent) {
    if (bytes.length < 2) return null;
    var offset = 1;
    final flags = bytes[0];
    final is16Bit = (flags & 0x01) != 0;
    final contactSupported = (flags & 0x04) != 0;
    final contactDetected = contactSupported ? (flags & 0x02) != 0 : null;
    final energyPresent = (flags & 0x08) != 0;
    final rrPresent = (flags & 0x10) != 0;

    int bpm;
    if (is16Bit) {
      if (bytes.length < offset + 2) return null;
      bpm = bytes[offset] | (bytes[offset + 1] << 8);
      offset += 2;
    } else {
      bpm = bytes[offset];
      offset += 1;
    }

    if (energyPresent && bytes.length >= offset + 2) offset += 2;

    final rr = <int>[];
    if (rrPresent) {
      while (bytes.length >= offset + 2) {
        final raw = bytes[offset] | (bytes[offset + 1] << 8);
        rr.add(((raw / 1024.0) * 1000).round());
        offset += 2;
      }
    }

    return HeartRateSample(
      deviceId: info.id,
      deviceName: info.name,
      bpm: bpm.clamp(0, 260).toInt(),
      batteryPercent: batteryPercent,
      sensorContactDetected: contactDetected,
      rrIntervalsMs: rr,
      measuredAt: DateTime.now(),
    );
  }

  Future<void> disconnect({String? deviceId, bool clearInfo = true}) async {
    final ids = deviceId == null
        ? _connections.keys.toList(growable: false)
        : <String>[deviceId];
    for (final id in ids) {
      final conn = _connections.remove(id);
      if (conn == null) continue;
      await conn.notifySub?.cancel();
      await conn.connectionSub?.cancel();
      conn.measurement = null;
      conn.battery = null;
      conn.ready = false;
      if (connectedInfo?.id == id) lastKnownInfo = connectedInfo;
      try {
        // disconnect() также отменяет незавершённый connectGatt. Проверка
        // connectionState здесь вредна: после 133 состояние уже disconnected,
        // хотя нативный GATT-клиент ещё может занимать слот контроллера.
        await conn.device.disconnect();
      } catch (_) {}
      if (clearInfo && connectedInfo?.id == id)
        connectedInfo = connectedInfos.isEmpty ? null : connectedInfos.last;
      _log('Пульсометр отключён: ${conn.info.name}');
    }
    _emitDevices();
  }

  Future<void> resetLocalState() async {
    await disconnect(clearInfo: true);
    _devices.clear();
    _lastSamplesByDeviceId.clear();
    lastSample = null;
    connectedInfo = null;
    lastKnownInfo = null;
    _emitDevices();
    _log('Heart Rate BLE очищен');
  }

  Future<void> _addSystemHeartDevices(
      {required String source, bool includeAllBleCandidates = false}) async {
    final candidates = <String, BluetoothDevice>{};

    void addDevice(BluetoothDevice device) {
      final id = device.remoteId.str.trim();
      if (id.isEmpty) return;
      candidates[id] = device;
    }

    try {
      for (final device in FlutterBluePlus.connectedDevices) {
        addDevice(device);
      }
    } catch (e) {
      _log('HEART SYSTEM[$source]: connectedDevices недоступны: $e');
    }

    try {
      final systemDevices =
          await FlutterBluePlus.systemDevices(const <Guid>[]).timeout(
        const Duration(seconds: 3),
        onTimeout: () => <BluetoothDevice>[],
      );
      for (final device in systemDevices) {
        addDevice(device);
      }
    } catch (e) {
      _log('HEART SYSTEM[$source]: systemDevices недоступны/пусто: $e');
    }

    var added = 0;
    for (final device in candidates.values) {
      final id = device.remoteId.str.trim();
      final rawName = device.platformName.trim();
      if (!_looksLikeHeartRateName(rawName) &&
          !includeAllBleCandidates &&
          !_connections.containsKey(id)) continue;
      final name = rawName.isEmpty ? 'BLE ${_shortId(id)} · system' : rawName;
      final item = _connections[id]?.info ??
          HeartRateBleDevice(
              id: id,
              name: name,
              rssi: 0,
              serviceHit: _looksLikeHeartRateName(rawName),
              rawProbe: !_looksLikeHeartRateName(rawName));
      final isNew = !_devices.containsKey(id);
      _devices[id] = item;
      if (isNew) {
        added++;
        _log('HEART SYSTEM[$source]: добавлен $name / $id');
      }
    }
    if (added > 0) _emitDevices();
  }

  Future<bool> _isDeviceConnected(BluetoothDevice device) async {
    try {
      final state = await device.connectionState.first
          .timeout(const Duration(milliseconds: 600));
      return state == BluetoothConnectionState.connected;
    } catch (_) {
      return false;
    }
  }

  String _deviceName(ScanResult result) {
    final adv = result.advertisementData.advName.trim();
    if (adv.isNotEmpty) return adv;
    final platform = result.device.platformName.trim();
    if (platform.isNotEmpty) return platform;
    return '';
  }

  bool _looksLikeHeartRateName(String name) {
    final upper = name.trim().toUpperCase();
    if (upper.isEmpty) return false;
    return HeartRateBleProfile.nameHints.any(upper.contains);
  }

  bool _sameUuid(String a, String b) {
    String norm(String value) => value.toUpperCase().replaceAll('-', '');
    final aa = norm(a);
    final bb = norm(b);
    if (aa == bb) return true;
    if (aa.length == 4 && bb.startsWith('0000$aa')) return true;
    if (bb.length == 4 && aa.startsWith('0000$bb')) return true;
    return (aa.contains('180D') && bb.contains('180D')) ||
        (aa.contains('2A37') && bb.contains('2A37')) ||
        (aa.contains('2A19') && bb.contains('2A19'));
  }

  String _charProps(BluetoothCharacteristic c) {
    final p = <String>[];
    if (c.properties.read) p.add('read');
    if (c.properties.write) p.add('write');
    if (c.properties.writeWithoutResponse) p.add('writeNoRsp');
    if (c.properties.notify) p.add('notify');
    if (c.properties.indicate) p.add('indicate');
    return p.isEmpty ? 'none' : p.join(',');
  }

  String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

  void _emitDevices() {
    if (_disposed || _devicesController.isClosed) return;
    int priority(HeartRateBleDevice d) {
      final name = d.name.toUpperCase();
      if (_connections[d.id]?.ready == true) return 0;
      if (name.contains('POLAR H10')) return 1;
      if (name.contains('POLAR') || name.contains('H10') || d.serviceHit)
        return 2;
      if (d.rawProbe) return 4;
      return 3;
    }

    final list = _devices.values.toList()
      ..sort((a, b) {
        final pa = priority(a);
        final pb = priority(b);
        if (pa != pb) return pa.compareTo(pb);
        return b.rssi.compareTo(a.rssi);
      });
    if (!_devicesController.isClosed) _devicesController.add(list);
  }

  void _log(String message) {
    if (_disposed || _logController.isClosed) return;
    _logController.add('[${DateTime.now().toIso8601String()}] $message');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect(clearInfo: true);
    if (!_devicesController.isClosed) await _devicesController.close();
    if (!_sampleController.isClosed) await _sampleController.close();
    if (!_logController.isClosed) await _logController.close();
  }
}
