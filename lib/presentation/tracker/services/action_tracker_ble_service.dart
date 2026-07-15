import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/action_tracker_protocol.dart';

class ActionTrackerDevice {
  final String id;
  final String name;
  final int rssi;

  const ActionTrackerDevice({required this.id, required this.name, required this.rssi});
}

class _BleCommandPair {
  final BluetoothCharacteristic? notify;
  final BluetoothCharacteristic? write;
  final bool exactProfile;

  const _BleCommandPair({this.notify, this.write, this.exactProfile = false});
}

class ActionTrackerBleService {
  static const MethodChannel _nativeBleChannel = MethodChannel('sportoteka/action_tracker_ble');

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
  ActionTrackerDevice? lastKnownInfo;

  /// true только когда есть реальный BLE-канал команд: устройство + TX-характеристика.
  /// connectedInfo без TX/RX больше не считается подключением, иначе UI показывает
  /// «подключено», а старт Live сразу падает на TX.
  bool get commandChannelReady => _device != null && _writeCharacteristic != null;
  BluetoothDevice? get connectedDevice => _device;
  ActionTrackerRecord? get selectedRecord => _selectedRecord;

  Future<bool> ensureCommandChannel() => _ensureReadyForWrite();

  Future<void> init() async {
    final supported = await FlutterBluePlus.isSupported;
    if (!supported) throw Exception('Bluetooth не поддерживается на этом устройстве');

    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _log('Bluetooth выключен. Включите Bluetooth и повторите поиск.');
    }
  }

  /// Универсальный поиск GPS-датчика в 4 этапа:
  /// 0) подмешивает Android bonded/paired устройства через native BluetoothAdapter,
  ///    затем system/paired BLE устройства FlutterBluePlus как в оригинальном Action Tracer;
  /// 1) быстрый поиск как в официальной программе (5 секунд);
  /// 2) если явный датчик не найден — расширенный BLE scan без жёсткого фильтра;
  /// 3) найденные кандидаты можно нажать, после чего connect+discoverServices проверит TX/RX.
  Future<void> scan({
    Duration timeout = const Duration(seconds: 5),
    Iterable<String> knownDeviceIds = const <String>[],
    Iterable<String> knownDeviceNames = const <String>[],
    bool expandedFallback = true,
    bool universalMode = false,
  }) async {
    // Не очищаем уже найденные устройства перед повторным поиском.
    // На Honor/MagicOS BLE-реклама может приходить рывками, и очистка создавала
    // эффект: датчик появился, затем сразу пропал из списка.
    _emitDevices();

    final adapterState = await FlutterBluePlus.adapterState.first.timeout(
      const Duration(seconds: 2),
      onTimeout: () => BluetoothAdapterState.unknown,
    );
    _log('BLE DIAG: adapter=$adapterState · knownIds=${knownDeviceIds.length} · knownNames=${knownDeviceNames.length} · mode=${universalMode ? 'universal-compatible' : 'auto'}');
    if (adapterState != BluetoothAdapterState.on) {
      _log('BLE DIAG WARNING: Bluetooth не включён, scan может ничего не найти');
    }

    final knownIds = knownDeviceIds.map(_normalizeId).where((e) => e.isNotEmpty).toSet();
    final knownNames = knownDeviceNames.map(_normalizeName).where((e) => e.isNotEmpty).toSet();

    // В оригинальном Action Tracer используется не только эфирный BLE scan, но и
    // системные/paired устройства Android через Plugin.BLE. Поэтому перед обычным
    // scan подмешиваем уже подключённые/спаренные Bluetooth-устройства: именно их
    // Android часто показывает в настройках, но они не всегда рекламируются в BLE.
    await _addSystemOrPairedDevices(
      knownIds: knownIds,
      knownNames: knownNames,
      source: 'pre-scan',
      showAllAsProbe: universalMode,
    );

    final allSeen = <String, ActionTrackerDevice>{};
    final rawSeen = <String, ActionTrackerDevice>{};
    final rawServices = <String, String>{};
    var scanEvents = 0;
    var stage = 'fast';

    Future<int> runScanStage({required String nextStage, required Duration scanTimeout, required bool showWeakCandidates}) async {
      stage = nextStage;
      StreamSubscription<List<ScanResult>>? sub;
      var serviceHits = 0;
      var prefixHits = 0;
      var knownHits = 0;
      var candidateHits = 0;
      var shownBefore = _devices.length;

      _log('GPS SCAN ${stage.toUpperCase()} START: timeout=${scanTimeout.inSeconds}s · filter=${showWeakCandidates ? 'candidate probe' : 'official-like'} · universalMode=$universalMode');
      try {
        await FlutterBluePlus.stopScan();
        // MagicOS/Honor требуется пауза между stopScan и новым startScan, иначе
        // BluetoothGattScanner иногда возвращает пустой поток без ошибки.
        await Future<void>.delayed(const Duration(milliseconds: 650));
        sub = FlutterBluePlus.scanResults.listen((results) {
          scanEvents++;
          for (final result in results) {
            final name = _deviceName(result);
            final id = result.device.remoteId.str.trim();
            if (id.isEmpty) continue;

            final serviceUuids = result.advertisementData.serviceUuids
                .map((u) => u.str.toUpperCase())
                .toList(growable: false);
            final servicesText = serviceUuids.isEmpty ? 'services=нет' : serviceUuids.take(4).join(',');
            rawServices[id] = servicesText;
            rawSeen[id] = ActionTrackerDevice(
              id: id,
              name: name.trim().isEmpty ? 'BLE ${_shortId(id)}' : name.trim(),
              rssi: result.rssi,
            );

            final serviceHit = serviceUuids.contains(ActionTrackerBleProfile.serviceUuid);
            final prefixOk = _looksLikeTrackerName(name);
            final knownHit = _matchesKnown(id: id, name: name, knownIds: knownIds, knownNames: knownNames);
            final strongSignal = result.rssi >= -78;
            final usableSignal = result.rssi >= -94;
            final hasName = name.trim().isNotEmpty;

            if (serviceHit) serviceHits++;
            if (prefixOk) prefixHits++;
            if (knownHit) knownHits++;

            final shouldShow = serviceHit || prefixOk || knownHit || strongSignal || (showWeakCandidates && (hasName || usableSignal));
            if (!shouldShow) continue;

            final safeName = _safeBleName(id: id, name: name, serviceHit: serviceHit, prefixOk: prefixOk, knownHit: knownHit, rssi: result.rssi, probe: showWeakCandidates && !serviceHit && !prefixOk && !knownHit);
            final item = ActionTrackerDevice(id: id, name: safeName, rssi: result.rssi);
            allSeen[id] = item;
            candidateHits++;

            final isNew = !_devices.containsKey(item.id);
            _devices[item.id] = item;
            if (isNew) {
              final marker = serviceHit || prefixOk || knownHit ? 'GPS TRACKER?' : 'BLE PROBE?';
              _log('$marker $stage: $safeName / $id / RSSI ${result.rssi} / $servicesText');
            }
          }
          _emitDevices();
        }, onError: (Object e) {
          _log('BLE scan stream error[$stage]: $e');
        });

        await FlutterBluePlus.startScan(
          timeout: scanTimeout,
          // В проекте запрашивается locationWhenInUse. Для Honor/MagicOS это
          // стабильнее, чем менять режим location между последовательными scan.
          androidUsesFineLocation: true,
        );
        await Future<void>.delayed(scanTimeout + const Duration(milliseconds: 250));
      } catch (e) {
        _log('GPS SCAN ${stage.toUpperCase()} ERROR: $e');
      } finally {
        await FlutterBluePlus.stopScan();
        await sub?.cancel();
      }

      final added = _devices.length - shownBefore;
      final probable = _devices.values.where((d) => _isProbableTracker(d, knownIds: knownIds, knownNames: knownNames)).length;
      _log('GPS SCAN ${stage.toUpperCase()} END: raw_seen=${rawSeen.length} · added=$added · shown=${_devices.length} · probable=$probable · prefix=$prefixHits · service=$serviceHits · known=$knownHits · candidates=$candidateHits');
      return probable;
    }

    // Короткие 5–7 секунд недостаточны для Honor: используем минимум 12 секунд.
    final effectiveFastTimeout = timeout < const Duration(seconds: 12)
        ? const Duration(seconds: 12)
        : timeout;
    if (universalMode) {
      _log('UNIVERSAL BLE MODE: включён совместимый BLE scan. Убедитесь, что включены Bluetooth, геолокация Android и разрешение «Устройства поблизости».');
    }
    var probable = await runScanStage(nextStage: 'fast', scanTimeout: effectiveFastTimeout, showWeakCandidates: false);

    if (probable == 0 && expandedFallback) {
      _log('GPS SCAN FALLBACK: явный датчик не найден. Включаю расширенный поиск BLE-кандидатов для проверки через подключение.');
      probable = await runScanStage(nextStage: 'expanded', scanTimeout: const Duration(seconds: 15), showWeakCandidates: true);
    }

    _emitDevices();
    final topCandidates = allSeen.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    final candidatesText = topCandidates.take(10).map((d) => '${d.name}/${d.id}/RSSI ${d.rssi}/${rawServices[d.id] ?? 'services=?'}').join(' | ');
    if (candidatesText.isNotEmpty) _log('GPS SCAN CANDIDATES TOP: $candidatesText');

    final topRaw = rawSeen.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    final topText = topRaw.take(12).map((d) => '${d.name}/${d.id}/RSSI ${d.rssi}/${rawServices[d.id] ?? 'services=?'}').join(' | ');
    if (topText.isNotEmpty) _log('GPS SCAN RAW TOP: $topText');

    if (_devices.isEmpty) {
      final rawHint = rawSeen.isEmpty
          ? 'Планшет не увидел вообще ни одного BLE-устройства: обычно это Bluetooth/разрешения/геолокация Android или датчик выключен.'
          : 'BLE вокруг виден (${rawSeen.length}), но подходящего GPS-кандидата нет: проверьте имя/прошивку датчика или нажмите расширенный кандидат с сильным RSSI.';
      _log('GPS SENSOR NOT FOUND DETAIL: $rawHint Проверьте Bluetooth, разрешение «Устройства поблизости», геолокацию Android, занятость датчика другим устройством и расстояние до датчика.');
    } else if (probable == 0) {
      _log('GPS SENSOR PROBE MODE: явного имени \$ATP/\$ACT/\$GPS или сервиса NUS нет. Нажмите ближайший BLE-кандидат с хорошим RSSI — приложение подключится и проверит реальные TX/RX характеристики.');
    }
  }

  Future<void> connect(ActionTrackerDevice info) async {
    await FlutterBluePlus.stopScan();

    final current = _device;
    if (current != null && current.remoteId.str == info.id && await _isDeviceConnected(current) && _writeCharacteristic != null) {
      connectedInfo = info;
      _log('GPS-датчик уже подключён: ${info.name}');
      return;
    }

    if (current != null && current.remoteId.str != info.id) {
      await disconnect(clearInfo: true);
    }

    final device = BluetoothDevice.fromId(info.id);
    connectedInfo = info;
    lastKnownInfo = info;
    _log('Подключение к ${info.name} / ${info.id}...${info.name.contains('paired') ? ' (Android paired/bonded)' : ''}');

    try {
      await _connectAndDiscover(device, info);
    } catch (e) {
      if (info.name.toLowerCase().contains('paired')) {
        _log('BLE paired connect failed: Android видел устройство как paired, но GATT TX/RX не открылся. Возможны 2 причины: датчик занят другой программой/системой или это classic Bluetooth, а не BLE GATT. Ошибка: $e');
      }
      rethrow;
    }

    _log('GPS-датчик подключён');
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
      lastKnownInfo = info;

      await _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _writeCharacteristic = null;
          _notifyCharacteristic = null;
          _device = null;
          // Не очищаем connectedInfo сразу: это сохранённая цель для автоматического reconnect.
          // Реальная готовность канала всё равно определяется commandChannelReady.
          connectedInfo = info;
          lastKnownInfo = info;
          _log('BLE вне зоны: ${info.name}. Канал TX/RX закрыт, Live не останавливаю — восстановлю связь при возврате датчика.');
          _emitDevices();
        }
      });

      final services = await device.discoverServices();
      _log('BLE services discovered: ${services.map((s) => s.uuid.str.toUpperCase()).join(', ')}');
      final pair = _findCommandPair(services);
      final notifyChar = pair.notify;
      final writeChar = pair.write;

      if (notifyChar == null || writeChar == null) {
        final serviceList = services.map((s) {
          final chars = s.characteristics.map((c) => '  ${c.uuid.str.toUpperCase()}(${_charProps(c)})').join(' ');
          return '${s.uuid.str.toUpperCase()} [$chars]';
        }).join(' | ');
        throw Exception('Это BLE-устройство найдено, но не похоже на GPS-датчик: не найдены RX/TX характеристики. Services: $serviceList');
      }

      _writeCharacteristic = writeChar;
      _notifyCharacteristic = notifyChar;
      connectedInfo = info;
      lastKnownInfo = info;
      final serviceMode = pair.exactProfile ? 'official/NUS' : 'auto-discovered';
      _log('BLE TX/RX найден ($serviceMode): TX=${writeChar.uuid.str.toUpperCase()} RX=${notifyChar.uuid.str.toUpperCase()}');

      await _notifySub?.cancel();
      await notifyChar.setNotifyValue(true);
      _log('BLE RX notify enabled');
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

  _BleCommandPair _findCommandPair(List<BluetoothService> services) {
    BluetoothCharacteristic? exactNotify;
    BluetoothCharacteristic? exactWrite;

    for (final service in services) {
      if (service.uuid.str.toUpperCase() != ActionTrackerBleProfile.serviceUuid) continue;
      for (final c in service.characteristics) {
        final uuid = c.uuid.str.toUpperCase();
        if (uuid == ActionTrackerBleProfile.notifyUuid) exactNotify = c;
        if (uuid == ActionTrackerBleProfile.writeUuid) exactWrite = c;
      }
    }
    if (exactNotify != null && exactWrite != null) {
      return _BleCommandPair(notify: exactNotify, write: exactWrite, exactProfile: true);
    }

    // Совместимость с оригинальным Action Tracer: он сначала подключается к
    // устройству, а потом проверяет service/notify/write. У разных партий прошивки
    // UUID сервиса может не рекламироваться или отличаться, поэтому разрешаем
    // auto-discover пары notify+write в одном сервисе.
    for (final service in services) {
      BluetoothCharacteristic? notify;
      BluetoothCharacteristic? write;
      for (final c in service.characteristics) {
        if (notify == null && (c.properties.notify || c.properties.indicate)) notify = c;
        if (write == null && (c.properties.write || c.properties.writeWithoutResponse)) write = c;
      }
      if (notify != null && write != null) {
        _log('BLE AUTO PROFILE: service=${service.uuid.str.toUpperCase()} notify=${notify.uuid.str.toUpperCase()} write=${write.uuid.str.toUpperCase()}');
        return _BleCommandPair(notify: notify, write: write, exactProfile: false);
      }
    }

    return const _BleCommandPair();
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

  Future<bool> _isDeviceConnected(BluetoothDevice device) async {
    try {
      final state = await device.connectionState.first.timeout(const Duration(milliseconds: 600));
      return state == BluetoothConnectionState.connected;
    } catch (_) {
      return false;
    }
  }

  Future<void> _addSystemOrPairedDevices({
    required Set<String> knownIds,
    required Set<String> knownNames,
    required String source,
    bool showAllAsProbe = false,
  }) async {
    // Первый и самый важный слой совместимости с Action Tracer:
    // Android Settings может видеть датчик как paired/bonded устройство, но обычный
    // BLE advertising scan его не отдаёт. Поэтому достаём bonded devices напрямую
    // через BluetoothAdapter.getBondedDevices() в native Android.
    await _addNativeAndroidBondedDevices(
      knownIds: knownIds,
      knownNames: knownNames,
      source: source,
      showAllAsProbe: showAllAsProbe,
    );

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
      _log('BLE SYSTEM[$source]: connectedDevices недоступны: $e');
    }

    try {
      // flutter_blue_plus возвращает уже известные системе устройства. На Android это
      // помогает в ситуации, когда датчик виден в настройках Bluetooth, но не попадает
      // в обычные advertising scanResults.
      final systemDevices = await FlutterBluePlus.systemDevices(const <Guid>[]).timeout(
        const Duration(seconds: 3),
        onTimeout: () => <BluetoothDevice>[],
      );
      for (final device in systemDevices) {
        addDevice(device);
      }
    } catch (e) {
      _log('BLE SYSTEM[$source]: systemDevices недоступны/пусто: $e');
    }

    if (candidates.isEmpty) {
      _log('BLE SYSTEM[$source]: FlutterBluePlus системные/paired BLE устройства не найдены');
      return;
    }

    var added = 0;
    for (final device in candidates.values) {
      final id = device.remoteId.str.trim();
      final rawName = device.platformName.trim();
      final knownHit = _matchesKnown(id: id, name: rawName, knownIds: knownIds, knownNames: knownNames);
      final prefixOk = _looksLikeTrackerName(rawName);
      if (!showAllAsProbe && !knownHit && !prefixOk) continue;

      final name = rawName.isEmpty
          ? (knownHit || prefixOk ? 'GPS датчик ${_shortId(id)}' : 'Bluetooth ${_shortId(id)} · проверить')
          : rawName;
      final item = ActionTrackerDevice(id: id, name: name, rssi: 0);
      final isNew = !_devices.containsKey(id);
      _devices[id] = item;
      if (isNew) {
        added++;
        _log('BLE SYSTEM[$source]: добавлен ${knownHit || prefixOk ? 'GPS-кандидат' : 'paired-кандидат'} $name / $id');
      }
    }

    if (added == 0) {
      _log('BLE SYSTEM[$source]: найдено ${candidates.length}, но без совпадения имени/привязки. Включите универсальный поиск или добавьте датчик из списка Bluetooth.');
    }
    _emitDevices();
  }

  Future<void> _addNativeAndroidBondedDevices({
    required Set<String> knownIds,
    required Set<String> knownNames,
    required String source,
    required bool showAllAsProbe,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    List<dynamic> raw;
    try {
      final result = await _nativeBleChannel.invokeMethod<List<dynamic>>('getBondedBluetoothDevices').timeout(
        const Duration(seconds: 2),
        onTimeout: () => const <dynamic>[],
      );
      raw = result ?? const <dynamic>[];
    } on MissingPluginException {
      _log('BLE NATIVE[$source]: Android bridge не подключён. Добавьте MainActivity bridge из README_TRACKER_69_NATIVE_BONDED_BLE_BRIDGE.md.');
      return;
    } catch (e) {
      _log('BLE NATIVE[$source]: bondedDevices недоступны: $e');
      return;
    }

    if (raw.isEmpty) {
      _log('BLE NATIVE[$source]: Android bonded/paired список пуст');
      return;
    }

    var added = 0;
    for (final entry in raw) {
      if (entry is! Map) continue;
      final id = (entry['address'] ?? entry['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      final rawName = (entry['name'] ?? '').toString().trim();
      final type = (entry['type'] ?? '').toString().trim();
      final bond = (entry['bondState'] ?? '').toString().trim();
      final knownHit = _matchesKnown(id: id, name: rawName, knownIds: knownIds, knownNames: knownNames);
      final prefixOk = _looksLikeTrackerName(rawName);

      // В обычном режиме показываем только похожие/известные датчики.
      // В универсальном режиме показываем все paired/bonded устройства — именно так
      // можно вручную нажать трекер, который Android видит в Bluetooth-настройках.
      if (!showAllAsProbe && !knownHit && !prefixOk) continue;

      final label = rawName.isEmpty ? 'Android paired ${_shortId(id)}' : rawName;
      final suffix = prefixOk || knownHit ? '' : ' · paired';
      final item = ActionTrackerDevice(id: id, name: '$label$suffix', rssi: 0);
      final isNew = !_devices.containsKey(id);
      _devices[id] = item;
      if (isNew) {
        added++;
        _log('BLE NATIVE[$source]: добавлен ${prefixOk || knownHit ? 'GPS-кандидат' : 'paired-кандидат'} $label / $id / type=$type / bond=$bond');
      }
    }

    if (added == 0) {
      _log('BLE NATIVE[$source]: найдено ${raw.length} bonded, но подходящих не добавлено. Универсальный поиск покажет все paired-кандидаты.');
    }
    _emitDevices();
  }


  String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

  String _normalizeId(String value) => value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  String _normalizeName(String value) => value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  bool _looksLikeTrackerName(String name) {
    final upper = name.trim().toUpperCase();
    if (upper.isEmpty) return false;
    return ActionTrackerBleProfile.namePrefixes.any((p) => upper.startsWith(p.toUpperCase())) ||
        upper.contains('ATP') ||
        upper.contains('ACT') ||
        upper.contains('GPS');
  }

  bool _matchesKnown({
    required String id,
    required String name,
    required Set<String> knownIds,
    required Set<String> knownNames,
  }) {
    final idKey = _normalizeId(id);
    final nameKey = _normalizeName(name);
    if (idKey.isNotEmpty && knownIds.any((k) => k == idKey || idKey.endsWith(k) || k.endsWith(idKey))) return true;
    if (nameKey.isNotEmpty && knownNames.any((k) => k == nameKey || nameKey.contains(k) || k.contains(nameKey))) return true;
    return false;
  }

  bool _isProbableTracker(
    ActionTrackerDevice device, {
    required Set<String> knownIds,
    required Set<String> knownNames,
  }) {
    return _looksLikeTrackerName(device.name) ||
        _matchesKnown(id: device.id, name: device.name, knownIds: knownIds, knownNames: knownNames) ||
        device.name.toUpperCase().contains('GPS ДАТЧИК');
  }

  String _safeBleName({
    required String id,
    required String name,
    required bool serviceHit,
    required bool prefixOk,
    required bool knownHit,
    required int rssi,
    required bool probe,
  }) {
    final clean = name.trim();
    if (clean.isNotEmpty) return clean;
    if (prefixOk || serviceHit || knownHit) return 'GPS датчик ${_shortId(id)}';
    if (probe) return 'BLE ${_shortId(id)} · проверить';
    return 'BLE ${_shortId(id)}';
  }

  Future<bool> _ensureReadyForWrite() async {
    final info = connectedInfo ?? lastKnownInfo;
    var device = _device;

    if (info == null) {
      _log('BLE reconnect skipped: нет connectedInfo/lastKnownInfo');
      return false;
    }
    connectedInfo ??= info;

    device ??= BluetoothDevice.fromId(info.id);
    _device = device;

    final connected = await _isDeviceConnected(device);
    if (connected && _writeCharacteristic != null) return true;

    _log('BLE reconnect direct: ${info.name} / ${info.id} · device=${device.remoteId.str} · write=${_writeCharacteristic != null}');
    try {
      await _connectAndDiscover(device, info);
      final ok = await _isDeviceConnected(device) && _writeCharacteristic != null;
      if (ok) {
        _log('BLE reconnect OK');
        return true;
      }
      _log('BLE reconnect wait: TX/RX ещё не открыт, датчик может быть вне зоны или занят другим устройством.');
    } catch (e) {
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _log('BLE reconnect direct error: $e');
    }

    // macOS иногда меняет runtime-id BLE-устройства после разрыва.
    // Поэтому пробуем короткий повторный scan и ищем тот же id/name.
    final found = await _scanForReconnect(info);
    if (found == null) {
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _device = null;
      connectedInfo = null;
      _log('BLE reconnect wait: GPS-датчик пока вне зоны · быстрый 4s scan · Live-сессия на сервере продолжается.');
      _emitDevices();
      return false;
    }

    try {
      final scannedDevice = BluetoothDevice.fromId(found.id);
      _device = scannedDevice;
      connectedInfo = found;
      lastKnownInfo = found;
      await _connectAndDiscover(scannedDevice, found);
      final ok = await _isDeviceConnected(scannedDevice) && _writeCharacteristic != null;
      _log(ok ? 'BLE reconnect OK: ${found.name} / ${found.id} · можно выгружать офлайн-записи' : 'BLE reconnect wait: датчик найден, но TX/RX ещё не открыт');
      return ok;
    } catch (e) {
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _device = null;
      connectedInfo = null;
      _log('BLE reconnect scan error: $e');
      _emitDevices();
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

    // Если эфирный scan не вернул датчик, но Android держит его в paired/bonded,
    // пробуем вернуть сохранённую цель напрямую по MAC/id. Для BLE GATT это даёт
    // шанс переподключиться без advertising, как в оригинальном Action Tracer.
    final bonded = await _nativeAndroidBondedByTarget(target);
    if (bonded != null) return bonded;

    final candidates = found.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    for (final item in candidates) {
      final name = item.name.toUpperCase();
      if (targetName.isNotEmpty && name == targetName) return item;
      if (targetName.isNotEmpty && name.contains(targetName.replaceAll(' ', ''))) return item;
      if (name.contains('ATP') || name.contains('ACT') || name.contains('GPS')) return item;
    }
    return null;
  }

  Future<ActionTrackerDevice?> _nativeAndroidBondedByTarget(ActionTrackerDevice target) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final raw = await _nativeBleChannel.invokeMethod<List<dynamic>>('getBondedBluetoothDevices').timeout(
        const Duration(seconds: 2),
        onTimeout: () => const <dynamic>[],
      );
      if (raw == null || raw.isEmpty) return null;
      final targetId = _normalizeId(target.id);
      final targetName = _normalizeName(target.name.replaceAll('· paired', ''));
      for (final entry in raw) {
        if (entry is! Map) continue;
        final id = (entry['address'] ?? entry['id'] ?? '').toString().trim();
        final name = (entry['name'] ?? '').toString().trim();
        final idKey = _normalizeId(id);
        final nameKey = _normalizeName(name);
        final idMatch = targetId.isNotEmpty && (idKey == targetId || idKey.endsWith(targetId) || targetId.endsWith(idKey));
        final nameMatch = targetName.isNotEmpty && nameKey.isNotEmpty && (nameKey == targetName || nameKey.contains(targetName) || targetName.contains(nameKey));
        if (idMatch || nameMatch) {
          final label = name.isEmpty ? target.name : name;
          _log('BLE reconnect native bonded candidate: $label / $id');
          return ActionTrackerDevice(id: id, name: label, rssi: 0);
        }
      }
    } catch (e) {
      _log('BLE reconnect native bonded skipped: $e');
    }
    return null;
  }

  /// Полный локальный сброс BLE-состояния.
  /// Используется перед чистым поиском: удаляет старый device, TX/RX,
  /// выбранную запись и список найденных устройств. Серверные привязки не трогает.
  Future<void> resetLocalState({bool clearKnownDevice = true}) async {
    _log('BLE RESET START: закрываю локальный канал, TX/RX и список scan');
    await disconnect(clearInfo: true);
    _devices.clear();
    _selectedRecord = null;
    if (clearKnownDevice) lastKnownInfo = null;
    connectedInfo = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _device = null;
    _emitDevices();
    _log('BLE RESET DONE: локальный канал очищен, сохранённые серверные привязки не удалялись');
  }

  Future<void> cleanScan({
    Duration timeout = const Duration(seconds: 5),
    Iterable<String> knownDeviceIds = const <String>[],
    Iterable<String> knownDeviceNames = const <String>[],
    bool universalMode = false,
  }) async {
    _log('CLEAN SCAN requested: сначала resetLocalState, затем универсальный scan GPS-датчика');
    await resetLocalState(clearKnownDevice: true);
    await scan(timeout: timeout, knownDeviceIds: knownDeviceIds, knownDeviceNames: knownDeviceNames, universalMode: universalMode);
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
    if (connectedInfo != null) lastKnownInfo = connectedInfo;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    _device = null;
    if (clearInfo) {
      connectedInfo = null;
    }
    _emitDevices();
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
      throw Exception('GPS-датчик не подключён. Нажмите «Сменить» и выберите датчик заново.');
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
        throw Exception('GPS-датчик отключился. Не удалось переподключиться автоматически.');
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
      if (name.contains('GPS') || name.contains('ATP') || name.contains('ACT') || name.contains('AT')) return 1;
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
