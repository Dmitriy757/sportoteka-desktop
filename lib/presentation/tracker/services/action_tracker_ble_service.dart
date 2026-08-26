import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/action_tracker_protocol.dart';

class ActionTrackerDevice {
  final String id;
  final String name;
  final int rssi;

  const ActionTrackerDevice(
      {required this.id, required this.name, required this.rssi});
}

class _BleCommandPair {
  final BluetoothCharacteristic? notify;
  final BluetoothCharacteristic? write;
  final bool exactProfile;

  const _BleCommandPair({this.notify, this.write, this.exactProfile = false});
}

class ActionTrackerBleService {
  static const MethodChannel _nativeBleChannel =
      MethodChannel('sportoteka/action_tracker_ble');
  static Future<List<ActionTrackerDevice>>? _sharedScanInFlight;
  static List<ActionTrackerDevice> _sharedScanSnapshot =
      const <ActionTrackerDevice>[];
  // Последний реально увиденный CoreBluetooth UUID по стабильному имени ATP.
  // Нужен после sleep/wake macOS/iPad: старый runtime UUID может уже не
  // открываться, а один rescue scan должен помочь сразу всем GPS команды.
  static final Map<String, ActionTrackerDevice> _latestRuntimeByIdentity =
      <String, ActionTrackerDevice>{};
  static final Map<String, DateTime> _latestRuntimeSeenAt = <String, DateTime>{};
  static const Duration _recentRuntimeCacheTtl = Duration(seconds: 120);
  static int _teamLiveGuardHolders = 0;
  static DateTime? _lastAppleRuntimeScanAt;
  static DateTime? _lastReconnectScanAt;
  // Automatic Apple runtime-id resolution is intentionally slow. A background
  // recovery may need one short scan when only the server-side Android MAC is
  // known, but it must not keep waking CoreBluetooth every 12-15 seconds.
  // Manual GPS/Polar search is not affected by this cooldown.
  static const Duration _appleBackgroundResolutionScanCooldown =
      Duration(seconds: 90);

  // V175: FlutterBluePlus использует один общий method-channel на процесс.
  // Поэтому GPS, Polar и несколько Team BLE connections не должны одновременно
  // дергать isSupported/startScan/stopScan. На iOS это проявлялось как
  // "Message responses can be sent only once" и десятки "stopScan: already stopped".
  static Future<BluetoothAdapterState>? _runtimeInitInFlight;
  static bool _runtimeCapabilityChecked = false;
  static bool _runtimeSupported = true;
  static Future<void> _globalScanTail = Future<void>.value();
  static bool _managedScanActive = false;
  static Timer? _managedScanAutoStopTimer;
  static int _managedScanGeneration = 0;

  final ActionTrackerProtocolParser _parser =
      const ActionTrackerProtocolParser();

  final StreamController<List<ActionTrackerDevice>> _devicesController =
      StreamController<List<ActionTrackerDevice>>.broadcast();
  final StreamController<ActionTrackerParseResult> _dataController =
      StreamController<ActionTrackerParseResult>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  final Map<String, ActionTrackerDevice> _devices = {};
  final List<StreamSubscription<dynamic>> _subs = [];

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  ActionTrackerRecord? _selectedRecord;
  bool _connecting = false;
  bool _requestHighConnectionPriority = true;
  bool _livePollingMode = false;
  int _connectionGeneration = 0;
  Future<void> _writeQueue = Future<void>.value();
  bool _disposed = false;

  Stream<List<ActionTrackerDevice>> get devicesStream =>
      _devicesController.stream;

  /// Последний накопленный результат BLE-поиска. Нужен режиму
  /// «Сохранённая команда»: после одного общего scan экран может сопоставить
  /// найденные UUID/имена с серверными назначениями и открыть каналы без
  /// повторного ручного выбора каждого игрока.
  List<ActionTrackerDevice> get discoveredDevices {
    final result = _devices.values.toList(growable: false)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return result;
  }
  Stream<ActionTrackerParseResult> get dataStream => _dataController.stream;
  Stream<String> get logStream => _logController.stream;

  ActionTrackerDevice? connectedInfo;
  ActionTrackerDevice? lastKnownInfo;

  /// true только когда есть реальный BLE-канал команд: устройство + TX-характеристика.
  /// connectedInfo без TX/RX больше не считается подключением, иначе UI показывает
  /// «подключено», а старт Live сразу падает на TX.
  bool get commandChannelReady =>
      _device != null && _writeCharacteristic != null;
  BluetoothDevice? get connectedDevice => _device;
  ActionTrackerRecord? get selectedRecord => _selectedRecord;
  bool get recordTransferActive => _selectedRecord != null;

  void clearSelectedRecord() {
    if (_selectedRecord != null) {
      _log('GPS record selection cleared · file=${_selectedRecord!.fileId}');
    }
    _selectedRecord = null;
  }

  static bool get teamLiveGuardActive => _teamLiveGuardHolders > 0;
  static bool get appleRuntime => _appleRuntime;
  static DateTime? get lastAppleRuntimeScanAt => _lastAppleRuntimeScanAt;
  static DateTime? get lastReconnectScanAt => _lastReconnectScanAt;

  /// Общий guard на процесс: ни один второй экран не должен запускать BLE scan,
  /// пока командный Live опрашивает несколько уже открытых GATT-каналов.
  static void setTeamLiveGuard(bool active) {
    if (active) {
      _teamLiveGuardHolders++;
    } else if (_teamLiveGuardHolders > 0) {
      _teamLiveGuardHolders--;
    }
  }

  void setLivePollingMode(bool active) {
    _livePollingMode = active;
  }

  Future<bool> ensureCommandChannel({bool allowScanFallback = true}) =>
      _ensureReadyForWrite(allowScanFallback: allowScanFallback);

  /// Не даёт Android погасить экран по системному таймауту во время Live.
  /// Сам флаг ставится в MainActivity через уже используемый native BLE channel.
  /// На других платформах и в старой MainActivity метод безопасно ничего не делает.
  static Future<bool> setTrackerKeepScreenOn(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _nativeBleChannel.invokeMethod<bool>(
            'setTrackerKeepScreenOn',
            <String, dynamic>{'enabled': enabled},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Принудительно пересоздаёт GATT/TX/RX, когда Android всё ещё считает BLE
  /// подключённым, но notify-пакеты от датчика давно не приходят.
  Future<bool> forceReconnectCommandChannel({
    Duration settleDelay = const Duration(milliseconds: 900),
    Duration directConnectTimeout = const Duration(seconds: 7),
    bool allowScanFallback = true,
    bool allowTeamLiveRescueScan = false,
  }) async {
    final info = connectedInfo ?? lastKnownInfo;
    if (info == null) {
      _log('BLE watchdog: нет сохранённой цели для переподключения');
      return false;
    }

    _log('BLE watchdog: пересоздаю GATT/TX/RX для ${info.name} / ${info.id}');
    await disconnect(
      clearInfo: false,
      logMessage:
          'BLE reconnect cleanup: закрываю старый GATT перед повторным подключением',
    );
    connectedInfo = info;
    lastKnownInfo = info;
    await Future<void>.delayed(settleDelay);

    try {
      final ready = await _ensureReadyForWrite(
        allowScanFallback: allowScanFallback,
        allowTeamLiveRescueScan: allowTeamLiveRescueScan,
        directConnectTimeout: directConnectTimeout,
      );
      _log(ready
          ? 'BLE watchdog: GATT/TX/RX восстановлен'
          : 'BLE watchdog: датчик пока не вернулся в зону');
      return ready;
    } catch (e) {
      _log('BLE watchdog reconnect error: $e');
      return false;
    }
  }

  static bool get _appleRuntime =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<BluetoothAdapterState> _readAdapterState() async {
    try {
      return await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => BluetoothAdapterState.unknown,
      );
    } on MissingPluginException {
      throw StateError(
        'FlutterBluePlus native channel не зарегистрирован в текущем Flutter engine. Нужен полный перезапуск приложения, не hot-reload.',
      );
    }
  }

  /// Единая проверка BLE runtime для GPS + Polar + Team pool.
  ///
  /// На Apple намеренно НЕ вызываем FlutterBluePlus.isSupported: в некоторых
  /// версиях FBP iOS именно этот method-call может дважды ответить в один
  /// FlutterResult. CoreBluetooth всё равно сообщает доступность через
  /// adapterState, поэтому дополнительный isSupported там не нужен.
  static Future<BluetoothAdapterState> ensureBluetoothRuntimeReady() async {
    final inFlight = _runtimeInitInFlight;
    if (inFlight != null) return inFlight;

    final future = () async {
      if (!_appleRuntime && !_runtimeCapabilityChecked) {
        try {
          final supported = await FlutterBluePlus.isSupported;
          _runtimeSupported = supported;
          _runtimeCapabilityChecked = true;
        } on MissingPluginException {
          throw StateError(
            'FlutterBluePlus native channel не зарегистрирован в текущем Flutter engine. Нужен полный перезапуск приложения, не hot-reload.',
          );
        }
      }
      if (!_runtimeSupported) {
        throw Exception('Bluetooth не поддерживается на этом устройстве');
      }
      return _readAdapterState();
    }();
    _runtimeInitInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_runtimeInitInFlight, future)) {
        _runtimeInitInFlight = null;
      }
    }
  }

  /// Общая очередь scan для ActionTracker и Polar. Она не даёт двум сервисам
  /// одновременно останавливать/запускать один CoreBluetooth scanner.
  static Future<T> runExclusiveBleScan<T>(Future<T> Function() body) async {
    final previous = _globalScanTail;
    final release = Completer<void>();
    _globalScanTail = release.future;
    await previous;
    try {
      return await body();
    } finally {
      if (!release.isCompleted) release.complete();
    }
  }

  static Future<void> startManagedScan({
    required Duration timeout,
    required bool androidUsesFineLocation,
  }) async {
    if (_managedScanActive) {
      await stopManagedScan();
    }
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: androidUsesFineLocation,
    );
    _managedScanActive = true;
    final generation = ++_managedScanGeneration;
    _managedScanAutoStopTimer?.cancel();
    _managedScanAutoStopTimer = Timer(timeout, () {
      if (_managedScanGeneration == generation) {
        _managedScanActive = false;
      }
    });
  }

  static Future<void> stopManagedScan() async {
    if (!_managedScanActive) return;
    _managedScanAutoStopTimer?.cancel();
    _managedScanAutoStopTimer = null;
    ++_managedScanGeneration;
    try {
      await FlutterBluePlus.stopScan();
    } finally {
      _managedScanActive = false;
    }
  }

  Future<void> init() async {
    final state = await ensureBluetoothRuntimeReady();
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
    if (teamLiveGuardActive) {
      _log(
          'GPS SCAN BLOCKED: командный Live уже идёт; сохраняю текущие GATT-каналы. Потерянный датчик вернётся прямым reconnect по своему UUID.');
      _emitDevices();
      return;
    }

    // Несколько открытых workspace раньше одновременно делали stopScan/startScan
    // и разрушали набор из 5–9 GATT. Один процесс выполняет только один GPS scan;
    // остальные экраны получают его общий снимок результатов.
    final sharedScan = _sharedScanInFlight;
    if (sharedScan != null) {
      _log('GPS SCAN JOIN: уже выполняется общий поиск в другом окне');
      final sharedDevices = await sharedScan;
      for (final device in sharedDevices) {
        _devices[device.id] = device;
      }
      _emitDevices();
      return;
    }
    final sharedCompleter = Completer<List<ActionTrackerDevice>>();
    final sharedFuture = sharedCompleter.future;
    _sharedScanInFlight = sharedFuture;
    try {
    // Не очищаем уже найденные устройства перед повторным поиском.
    // На Honor/MagicOS BLE-реклама может приходить рывками, и очистка создавала
    // эффект: датчик появился, затем сразу пропал из списка.
    _emitDevices();

    final adapterState = await _readAdapterState();
    _log(
        'BLE DIAG: adapter=$adapterState · knownIds=${knownDeviceIds.length} · knownNames=${knownDeviceNames.length} · mode=${universalMode ? 'universal-compatible' : 'auto'}');
    if (adapterState != BluetoothAdapterState.on) {
      _log(
          'BLE DIAG WARNING: Bluetooth не включён, scan может ничего не найти');
    }

    final knownIds =
        knownDeviceIds.map(_normalizeId).where((e) => e.isNotEmpty).toSet();
    final knownNames =
        knownDeviceNames.map(_normalizeName).where((e) => e.isNotEmpty).toSet();

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

    Future<int> runScanStage(
        {required String nextStage,
        required Duration scanTimeout,
        required bool showWeakCandidates}) async {
      stage = nextStage;
      StreamSubscription<List<ScanResult>>? sub;
      var serviceHits = 0;
      var prefixHits = 0;
      var knownHits = 0;
      var candidateHits = 0;
      var shownBefore = _devices.length;

      _log(
          'GPS SCAN ${stage.toUpperCase()} START: timeout=${scanTimeout.inSeconds}s · filter=${showWeakCandidates ? 'candidate probe' : 'official-like'} · universalMode=$universalMode');
      await runExclusiveBleScan<void>(() async {
      try {
        await stopManagedScan();
        // MagicOS/Honor требуется пауза между stopScan и новым startScan, иначе
        // BluetoothGattScanner иногда возвращает пустой поток без ошибки.
        await Future<void>.delayed(const Duration(milliseconds: 650));
        sub = FlutterBluePlus.scanResults.listen((results) {
          if (_disposed) return;
          scanEvents++;
          for (final result in results) {
            final name = _deviceName(result);
            final id = result.device.remoteId.str.trim();
            if (id.isEmpty) continue;

            final serviceUuids = result.advertisementData.serviceUuids
                .map((u) => u.str.toUpperCase())
                .toList(growable: false);
            final servicesText = serviceUuids.isEmpty
                ? 'services=нет'
                : serviceUuids.take(4).join(',');
            rawServices[id] = servicesText;
            rawSeen[id] = ActionTrackerDevice(
              id: id,
              name: name.trim().isEmpty ? 'BLE ${_shortId(id)}' : name.trim(),
              rssi: result.rssi,
            );

            final serviceHit =
                serviceUuids.contains(ActionTrackerBleProfile.serviceUuid);
            final prefixOk = _looksLikeTrackerName(name);
            final knownHit = _matchesKnown(
                id: id, name: name, knownIds: knownIds, knownNames: knownNames);
            final strongSignal = result.rssi >= -78;
            final usableSignal = result.rssi >= -94;
            final hasName = name.trim().isNotEmpty;

            if (serviceHit) serviceHits++;
            if (prefixOk) prefixHits++;
            if (knownHit) knownHits++;

            final shouldShow = serviceHit ||
                prefixOk ||
                knownHit ||
                strongSignal ||
                (showWeakCandidates && (hasName || usableSignal));
            if (!shouldShow) continue;

            final safeName = _safeBleName(
                id: id,
                name: name,
                serviceHit: serviceHit,
                prefixOk: prefixOk,
                knownHit: knownHit,
                rssi: result.rssi,
                probe: showWeakCandidates &&
                    !serviceHit &&
                    !prefixOk &&
                    !knownHit);
            final item =
                ActionTrackerDevice(id: id, name: safeName, rssi: result.rssi);
            allSeen[id] = item;
            candidateHits++;

            final isNew = !_devices.containsKey(item.id);
            _devices[item.id] = item;
            if (isNew) {
              final marker = serviceHit || prefixOk || knownHit
                  ? 'GPS TRACKER?'
                  : 'BLE PROBE?';
              _log(
                  '$marker $stage: $safeName / $id / RSSI ${result.rssi} / $servicesText');
            }
          }
          _emitDevices();
        }, onError: (Object e) {
          _log('BLE scan stream error[$stage]: $e');
        });

        await startManagedScan(
          timeout: scanTimeout,
          // В проекте запрашивается locationWhenInUse. Для Honor/MagicOS это
          // стабильнее, чем менять режим location между последовательными scan.
          androidUsesFineLocation: true,
        );
        final scanDeadline = DateTime.now()
            .add(scanTimeout + const Duration(milliseconds: 250));
        while (!teamLiveGuardActive &&
            DateTime.now().isBefore(scanDeadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (teamLiveGuardActive) {
          _log('GPS SCAN CANCELLED: начался Team Live');
        }
      } catch (e) {
        _log('GPS SCAN ${stage.toUpperCase()} ERROR: $e');
      } finally {
        await stopManagedScan();
        await sub?.cancel();
      }
      });

      final added = _devices.length - shownBefore;
      final probable = _devices.values
          .where((d) =>
              _isProbableTracker(d, knownIds: knownIds, knownNames: knownNames))
          .length;
      _log(
          'GPS SCAN ${stage.toUpperCase()} END: raw_seen=${rawSeen.length} · added=$added · shown=${_devices.length} · probable=$probable · prefix=$prefixHits · service=$serviceHits · known=$knownHits · candidates=$candidateHits');
      return probable;
    }

    // Короткие 5–7 секунд недостаточны для Honor: используем минимум 12 секунд.
    final effectiveFastTimeout = timeout < const Duration(seconds: 12)
        ? const Duration(seconds: 12)
        : timeout;
    if (universalMode) {
      _log(
          'UNIVERSAL BLE MODE: включён совместимый BLE scan. Убедитесь, что включены Bluetooth, геолокация Android и разрешение «Устройства поблизости».');
    }
    var probable = await runScanStage(
        nextStage: 'fast',
        scanTimeout: effectiveFastTimeout,
        showWeakCandidates: false);

    if (!teamLiveGuardActive && probable == 0 && expandedFallback) {
      _log(
          'GPS SCAN FALLBACK: явный датчик не найден. Включаю расширенный поиск BLE-кандидатов для проверки через подключение.');
      probable = await runScanStage(
          nextStage: 'expanded',
          scanTimeout: const Duration(seconds: 15),
          showWeakCandidates: true);
    }

    _emitDevices();
    final topCandidates = allSeen.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    final candidatesText = topCandidates
        .take(10)
        .map((d) =>
            '${d.name}/${d.id}/RSSI ${d.rssi}/${rawServices[d.id] ?? 'services=?'}')
        .join(' | ');
    if (candidatesText.isNotEmpty)
      _log('GPS SCAN CANDIDATES TOP: $candidatesText');

    final topRaw = rawSeen.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    final topText = topRaw
        .take(12)
        .map((d) =>
            '${d.name}/${d.id}/RSSI ${d.rssi}/${rawServices[d.id] ?? 'services=?'}')
        .join(' | ');
    if (topText.isNotEmpty) _log('GPS SCAN RAW TOP: $topText');

    if (_devices.isEmpty) {
      final rawHint = rawSeen.isEmpty
          ? 'Планшет не увидел вообще ни одного BLE-устройства: обычно это Bluetooth/разрешения/геолокация Android или датчик выключен.'
          : 'BLE вокруг виден (${rawSeen.length}), но подходящего GPS-кандидата нет: проверьте имя/прошивку датчика или нажмите расширенный кандидат с сильным RSSI.';
      _log(
          'GPS SENSOR NOT FOUND DETAIL: $rawHint Проверьте Bluetooth, разрешение «Устройства поблизости», геолокацию Android, занятость датчика другим устройством и расстояние до датчика.');
    } else if (probable == 0) {
      _log(
          'GPS SENSOR PROBE MODE: явного имени \$ATP/\$ACT/\$GPS или сервиса NUS нет. Нажмите ближайший BLE-кандидат с хорошим RSSI — приложение подключится и проверит реальные TX/RX характеристики.');
    }
    } finally {
      _sharedScanSnapshot = _devices.values.toList(growable: false);
      for (final item in _sharedScanSnapshot) {
        final identity = _stableTrackerIdentity(item.name);
        if (identity.isNotEmpty && !_needsAppleRuntimeResolution(item.id)) {
          _latestRuntimeByIdentity[identity] = item;
          _latestRuntimeSeenAt[identity] = DateTime.now();
        }
      }
      if (!sharedCompleter.isCompleted) {
        sharedCompleter.complete(
          List<ActionTrackerDevice>.unmodifiable(_sharedScanSnapshot),
        );
      }
      if (identical(_sharedScanInFlight, sharedFuture)) {
        _sharedScanInFlight = null;
      }
    }
  }

  Future<void> connect(
    ActionTrackerDevice info, {
    bool inspectOfflineRecords = true,
    bool requestHighConnectionPriority = true,
  }) async {
    if (teamLiveGuardActive && !_livePollingMode) {
      throw StateError(
          'Командный Live уже идёт: новый BLE-канал подключается после Stop.');
    }
    _requestHighConnectionPriority = requestHighConnectionPriority;
    await stopManagedScan();

    // В серверной привязке GPS часто хранится Android MAC (CC:..). На iOS/macOS
    // CoreBluetooth НЕ использует MAC как remoteId: runtime-id там UUID.
    // V173 пытался сделать BluetoothDevice.fromId(serverMac), после чего FBP-iOS
    // получал connect -> немедленный disconnect и иногда отвечал в method-channel
    // дважды ("Message responses can be sent only once").
    // На Apple сначала разрешаем сохранённую цель в реальный CoreBluetooth UUID
    // по имени/стабильной identity. Первый recovery при необходимости делает
    // один короткий scan, остальные GPS берутся из общего snapshot этого scan.
    var runtimeInfo = info;
    if (_needsAppleRuntimeResolution(info.id)) {
      final cached = _cachedRuntimeDeviceFor(info);
      final now = DateTime.now();
      final lastScan = _lastAppleRuntimeScanAt;
      final scanRecently = lastScan != null &&
          now.difference(lastScan) < _appleBackgroundResolutionScanCooldown;
      final resolved = cached ??
          (scanRecently ? null : await _scanForReconnect(info));
      if (resolved == null) {
        _log(
            'BLE Apple reconnect wait: ${info.name} пока не найден в эфире; server id ${info.id} не передаю в CoreBluetooth как remoteId.');
        throw StateError(
            'GPS ${info.name} пока не найден рядом. На iOS/macOS сохранённый MAC нельзя подключать напрямую.');
      }
      runtimeInfo = resolved;
      _log(
          'BLE Apple runtime-id resolved: ${info.name} / ${info.id} -> ${runtimeInfo.id}');
    }

    final current = _device;
    if (current != null &&
        current.remoteId.str == runtimeInfo.id &&
        await _isDeviceConnected(current) &&
        _writeCharacteristic != null) {
      connectedInfo = runtimeInfo;
      lastKnownInfo = runtimeInfo;
      _log('GPS-датчик уже подключён: ${runtimeInfo.name}');
      return;
    }

    if (current != null && current.remoteId.str != runtimeInfo.id) {
      await disconnect(clearInfo: true);
    }

    final device = BluetoothDevice.fromId(runtimeInfo.id);
    connectedInfo = runtimeInfo;
    lastKnownInfo = runtimeInfo;
    _log(
        'Подключение к ${runtimeInfo.name} / ${runtimeInfo.id}...${runtimeInfo.name.contains('paired') ? ' (Android paired/bonded)' : ''}');

    try {
      await _connectAndDiscover(
        device,
        runtimeInfo,
        requestHighConnectionPriority: requestHighConnectionPriority,
      );
    } catch (e) {
      if (runtimeInfo.name.toLowerCase().contains('paired')) {
        _log(
            'BLE paired connect failed: Android видел устройство как paired, но GATT TX/RX не открылся. Возможны 2 причины: датчик занят другой программой/системой или это classic Bluetooth, а не BLE GATT. Ошибка: $e');
      }
      rethrow;
    }

    _log('GPS-датчик подключён');
    await requestBatteryAndGpsState();
    if (inspectOfflineRecords) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      await requestRecordList();
    }
  }

  Future<void> _connectAndDiscover(
    BluetoothDevice device,
    ActionTrackerDevice info, {
    bool requestHighConnectionPriority = true,
    Duration connectTimeout = const Duration(seconds: 15),
  }) async {
    if (_connecting) return;
    _connecting = true;

    try {
      final alreadyConnected = await _isDeviceConnected(device);
      if (!alreadyConnected) {
        // Сохраняем объект до connect(): если Android вернёт GATT 133,
        // disconnect() ниже сможет закрыть незавершённый client slot.
        _device = device;
        try {
          await device.connect(
              autoConnect: false, timeout: connectTimeout);
        } catch (e) {
          final text = e.toString().toLowerCase();
          if (!text.contains('already') && !text.contains('connected')) {
            // Немедленный disconnect внутри catch нужен только Android для
            // освобождения зависшего GATT slot (в т.ч. code 133). На iOS/macOS
            // connect и disconnect в одном method-call цикле FlutterBluePlus
            // могут дать duplicate response на flutter_blue_plus/methods.
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
              try {
                await device.disconnect();
              } catch (_) {}
            }
            _device = null;
            rethrow;
          }
        }
      }

      _device = device;
      connectedInfo = info;
      lastKnownInfo = info;

      final connectionGeneration = ++_connectionGeneration;
      await _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen((state) {
        if (_disposed || connectionGeneration != _connectionGeneration) return;
        if (state == BluetoothConnectionState.disconnected) {
          _writeCharacteristic = null;
          _notifyCharacteristic = null;
          _device = null;
          // Не очищаем connectedInfo сразу: это сохранённая цель для автоматического reconnect.
          // Реальная готовность канала всё равно определяется commandChannelReady.
          connectedInfo = info;
          lastKnownInfo = info;
          _log(
              'BLE вне зоны: ${info.name}. Канал TX/RX закрыт, Live не останавливаю — восстановлю связь при возврате датчика.');
          _emitDevices();
        }
      });

      final services = await device.discoverServices();
      _log(
          'BLE services discovered: ${services.map((s) => s.uuid.str.toUpperCase()).join(', ')}');
      final pair = _findCommandPair(services);
      final notifyChar = pair.notify;
      final writeChar = pair.write;

      if (notifyChar == null || writeChar == null) {
        final serviceList = services.map((s) {
          final chars = s.characteristics
              .map((c) => '  ${c.uuid.str.toUpperCase()}(${_charProps(c)})')
              .join(' ');
          return '${s.uuid.str.toUpperCase()} [$chars]';
        }).join(' | ');
        throw Exception(
            'Это BLE-устройство найдено, но не похоже на GPS-датчик: не найдены RX/TX характеристики. Services: $serviceList');
      }

      _writeCharacteristic = writeChar;
      _notifyCharacteristic = notifyChar;
      connectedInfo = info;
      lastKnownInfo = info;
      final serviceMode =
          pair.exactProfile ? 'official/NUS' : 'auto-discovered';
      _log(
          'BLE TX/RX найден ($serviceMode): TX=${writeChar.uuid.str.toUpperCase()} RX=${notifyChar.uuid.str.toUpperCase()}');

      await _notifySub?.cancel();
      await notifyChar.setNotifyValue(true);
      _log('BLE RX notify enabled');
      _notifySub = notifyChar.onValueReceived.listen((bytes) {
        if (_disposed) return;
        // Защита командного режима: characteristic должна принадлежать именно
        // тому remoteId, к которому подключён этот экземпляр сервиса. Pool ниже
        // дополнительно маршрутизирует ответ 3B по владельцу последней команды.
        final expectedId = _normalizeId(info.id);
        final sourceId = _normalizeId(notifyChar.remoteId.str);
        if (sourceId.isNotEmpty && expectedId.isNotEmpty && sourceId != expectedId) {
          _log('RX DROP foreign characteristic: expected=${info.id} source=${notifyChar.remoteId.str}');
          return;
        }
        final result = _parser.parse(bytes, selectedRecord: _selectedRecord);
        if (!_dataController.isClosed) _dataController.add(result);
        _log('RX ${result.rawHex}');
        // 0x48 завершает чтение офлайн-файла. Обязательно снимаем выбранную
        // запись, иначе следующие Live-пакеты 44/45 будут ошибочно парситься
        // как продолжение старого файла.
        if (result.transferFinished) {
          final finishedFileId = _selectedRecord?.fileId;
          _selectedRecord = null;
          _log('GPS record transfer finished · file=${finishedFileId ?? 0} · selectedRecord cleared');
        }
      });

      // HIGH резервирует слишком большой BLE connection interval. На Honor /
      // MagicOS семь таких GATT-каналов обычно работают, а при открытии 8–10-го
      // контроллер начинает отклонять либо сбрасывать соединения. Высокий
      // приоритет полезен одиночному трекеру, но командный pool его отключает.
      if (requestHighConnectionPriority) {
        try {
          await device.requestConnectionPriority(
            connectionPriorityRequest: ConnectionPriority.high,
          );
        } catch (_) {}
      } else {
        try {
          await device.requestConnectionPriority(
            connectionPriorityRequest: ConnectionPriority.balanced,
          );
        } catch (_) {}
      }
    } finally {
      _connecting = false;
    }
  }

  _BleCommandPair _findCommandPair(List<BluetoothService> services) {
    BluetoothCharacteristic? exactNotify;
    BluetoothCharacteristic? exactWrite;

    for (final service in services) {
      if (service.uuid.str.toUpperCase() != ActionTrackerBleProfile.serviceUuid)
        continue;
      for (final c in service.characteristics) {
        final uuid = c.uuid.str.toUpperCase();
        if (uuid == ActionTrackerBleProfile.notifyUuid) exactNotify = c;
        if (uuid == ActionTrackerBleProfile.writeUuid) exactWrite = c;
      }
    }
    if (exactNotify != null && exactWrite != null) {
      return _BleCommandPair(
          notify: exactNotify, write: exactWrite, exactProfile: true);
    }

    // Совместимость с оригинальным Action Tracer: он сначала подключается к
    // устройству, а потом проверяет service/notify/write. У разных партий прошивки
    // UUID сервиса может не рекламироваться или отличаться, поэтому разрешаем
    // auto-discover пары notify+write в одном сервисе.
    for (final service in services) {
      BluetoothCharacteristic? notify;
      BluetoothCharacteristic? write;
      for (final c in service.characteristics) {
        if (notify == null && (c.properties.notify || c.properties.indicate))
          notify = c;
        if (write == null &&
            (c.properties.write || c.properties.writeWithoutResponse))
          write = c;
      }
      if (notify != null && write != null) {
        _log(
            'BLE AUTO PROFILE: service=${service.uuid.str.toUpperCase()} notify=${notify.uuid.str.toUpperCase()} write=${write.uuid.str.toUpperCase()}');
        return _BleCommandPair(
            notify: notify, write: write, exactProfile: false);
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
      final state = await device.connectionState.first
          .timeout(const Duration(milliseconds: 600));
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
      final systemDevices =
          await FlutterBluePlus.systemDevices(const <Guid>[]).timeout(
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
      _log(
          'BLE SYSTEM[$source]: FlutterBluePlus системные/paired BLE устройства не найдены');
      return;
    }

    var added = 0;
    for (final device in candidates.values) {
      final id = device.remoteId.str.trim();
      final rawName = device.platformName.trim();
      final knownHit = _matchesKnown(
          id: id, name: rawName, knownIds: knownIds, knownNames: knownNames);
      final prefixOk = _looksLikeTrackerName(rawName);
      if (!showAllAsProbe && !knownHit && !prefixOk) continue;

      final name = rawName.isEmpty
          ? (knownHit || prefixOk
              ? 'GPS датчик ${_shortId(id)}'
              : 'Bluetooth ${_shortId(id)} · проверить')
          : rawName;
      final item = ActionTrackerDevice(id: id, name: name, rssi: 0);
      final isNew = !_devices.containsKey(id);
      _devices[id] = item;
      if (isNew) {
        added++;
        _log(
            'BLE SYSTEM[$source]: добавлен ${knownHit || prefixOk ? 'GPS-кандидат' : 'paired-кандидат'} $name / $id');
      }
    }

    if (added == 0) {
      _log(
          'BLE SYSTEM[$source]: найдено ${candidates.length}, но без совпадения имени/привязки. Включите универсальный поиск или добавьте датчик из списка Bluetooth.');
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
      final result = await _nativeBleChannel
          .invokeMethod<List<dynamic>>('getBondedBluetoothDevices')
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => const <dynamic>[],
          );
      raw = result ?? const <dynamic>[];
    } on MissingPluginException {
      _log(
          'BLE NATIVE[$source]: Android bridge не подключён. Добавьте MainActivity bridge из README_TRACKER_69_NATIVE_BONDED_BLE_BRIDGE.md.');
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
      final knownHit = _matchesKnown(
          id: id, name: rawName, knownIds: knownIds, knownNames: knownNames);
      final prefixOk = _looksLikeTrackerName(rawName);

      // В обычном режиме показываем только похожие/известные датчики.
      // В универсальном режиме показываем все paired/bonded устройства — именно так
      // можно вручную нажать трекер, который Android видит в Bluetooth-настройках.
      if (!showAllAsProbe && !knownHit && !prefixOk) continue;

      final label =
          rawName.isEmpty ? 'Android paired ${_shortId(id)}' : rawName;
      final suffix = prefixOk || knownHit ? '' : ' · paired';
      final item = ActionTrackerDevice(id: id, name: '$label$suffix', rssi: 0);
      final isNew = !_devices.containsKey(id);
      _devices[id] = item;
      if (isNew) {
        added++;
        _log(
            'BLE NATIVE[$source]: добавлен ${prefixOk || knownHit ? 'GPS-кандидат' : 'paired-кандидат'} $label / $id / type=$type / bond=$bond');
      }
    }

    if (added == 0) {
      _log(
          'BLE NATIVE[$source]: найдено ${raw.length} bonded, но подходящих не добавлено. Универсальный поиск покажет все paired-кандидаты.');
    }
    _emitDevices();
  }

  String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

  String _normalizeId(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  String _normalizeName(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  String _stableTrackerIdentity(String value) {
    final match = RegExp(
      r'(ATP|ACT|GPS)[^A-Z0-9]*([A-Z0-9]{3,})',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return '';
    return '${match.group(1) ?? ''}${match.group(2) ?? ''}'.toUpperCase();
  }

  bool _looksLikeTrackerName(String name) {
    final upper = name.trim().toUpperCase();
    if (upper.isEmpty) return false;
    return ActionTrackerBleProfile.namePrefixes
            .any((p) => upper.startsWith(p.toUpperCase())) ||
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
    if (idKey.isNotEmpty &&
        knownIds
            .any((k) => k == idKey || idKey.endsWith(k) || k.endsWith(idKey)))
      return true;
    if (nameKey.isNotEmpty &&
        knownNames.any(
            (k) => k == nameKey || nameKey.contains(k) || k.contains(nameKey)))
      return true;
    return false;
  }

  bool _isProbableTracker(
    ActionTrackerDevice device, {
    required Set<String> knownIds,
    required Set<String> knownNames,
  }) {
    return _looksLikeTrackerName(device.name) ||
        _matchesKnown(
            id: device.id,
            name: device.name,
            knownIds: knownIds,
            knownNames: knownNames) ||
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

  bool _needsAppleRuntimeResolution(String id) {
    if (kIsWeb) return false;
    final apple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (!apple) return false;
    return RegExp(r'^[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}$')
        .hasMatch(id.trim());
  }

  ActionTrackerDevice? _recentRuntimeDeviceFor(ActionTrackerDevice target) {
    final targetIdentity = _stableTrackerIdentity(target.name);
    if (targetIdentity.isEmpty) return null;
    final latest = _latestRuntimeByIdentity[targetIdentity];
    final seenAt = _latestRuntimeSeenAt[targetIdentity];
    if (latest == null || seenAt == null) return null;
    if (DateTime.now().difference(seenAt) > _recentRuntimeCacheTtl) return null;
    if (_needsAppleRuntimeResolution(latest.id)) return null;
    return latest;
  }

  ActionTrackerDevice? _cachedRuntimeDeviceFor(ActionTrackerDevice target) {
    final targetName = target.name.trim().toUpperCase();
    final targetIdentity = _stableTrackerIdentity(target.name);
    final recent = _recentRuntimeDeviceFor(target);
    if (recent != null) return recent;
    if (_sharedScanSnapshot.isEmpty) return null;
    final candidates = _sharedScanSnapshot.toList(growable: false)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    for (final item in candidates) {
      if (_needsAppleRuntimeResolution(item.id)) continue;
      final itemName = item.name.trim().toUpperCase();
      if (targetName.isNotEmpty && itemName == targetName) return item;
      final itemIdentity = _stableTrackerIdentity(item.name);
      if (targetIdentity.isNotEmpty && itemIdentity == targetIdentity) {
        return item;
      }
    }
    return null;
  }

  Future<bool> _ensureReadyForWrite({
    bool allowScanFallback = true,
    bool allowTeamLiveRescueScan = false,
    Duration directConnectTimeout = const Duration(seconds: 15),
  }) async {
    var info = connectedInfo ?? lastKnownInfo;
    var device = _device;
    // Team Live rescue scan разрешён только на Apple. На Android потерянный
    // канал восстанавливаем прямым reconnect по известному MAC/UUID: общий
    // startScan во время Live провоцировал GATT 133 и ронял соседние каналы.
    final teamLiveRescueAllowed =
        allowTeamLiveRescueScan && _appleRuntime;

    if (info == null) {
      _log('BLE reconnect skipped: нет connectedInfo/lastKnownInfo');
      return false;
    }

    // Та же Apple-защита нужна и для watchdog/TX retry. Если сервис знает
    // только server MAC, не делаем fromId(MAC) на CoreBluetooth.
    if (device == null && _needsAppleRuntimeResolution(info.id)) {
      final cached = _cachedRuntimeDeviceFor(info);
      final now = DateTime.now();
      final lastScan = _lastAppleRuntimeScanAt;
      final scanRecently = lastScan != null &&
          now.difference(lastScan) < _appleBackgroundResolutionScanCooldown;
      final scanAllowed = allowScanFallback &&
          (!teamLiveGuardActive || teamLiveRescueAllowed);
      final resolved = cached ??
          ((!scanAllowed || scanRecently)
              ? null
              : await _scanForReconnect(info));
      if (resolved == null) {
        _log(
            'BLE Apple reconnect wait: runtime UUID для ${info.name} пока не найден; прямой connect по MAC запрещён.');
        return false;
      }
      info = resolved;
      connectedInfo = resolved;
      lastKnownInfo = resolved;
    } else {
      connectedInfo ??= info;
    }

    device ??= BluetoothDevice.fromId(info.id);
    _device = device;

    final connected = await _isDeviceConnected(device);
    if (connected && _writeCharacteristic != null) return true;

    _log(
        'BLE reconnect direct: ${info.name} / ${info.id} · device=${device.remoteId.str} · write=${_writeCharacteristic != null}');
    try {
      await _connectAndDiscover(
        device,
        info,
        requestHighConnectionPriority: _requestHighConnectionPriority,
        connectTimeout: directConnectTimeout,
      );
      final ok =
          await _isDeviceConnected(device) && _writeCharacteristic != null;
      if (ok) {
        _log('BLE reconnect OK');
        return true;
      }
      _log(
          'BLE reconnect wait: TX/RX ещё не открыт, датчик может быть вне зоны или занят другим устройством.');
    } catch (e) {
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _log('BLE reconnect direct error: $e');
    }

    // Один rescue scan одного GPS видит весь BLE-эфир. Поэтому остальные
    // сервисы команды сначала пробуют свежий runtime UUID из общего cache и
    // могут восстановиться без собственного scan, даже когда scan gate закрыт.
    ActionTrackerDevice? found;
    if (_appleRuntime) {
      final cached = _recentRuntimeDeviceFor(info);
      if (cached != null) {
        found = cached;
        final sameId = _normalizeId(cached.id) == _normalizeId(info.id);
        _log(sameId
            ? 'BLE Apple rescue cache: ${info.name} снова виден в эфире · повторяю direct ${cached.id}'
            : 'BLE Apple rescue cache: ${info.name} ${info.id} -> ${cached.id}');
      }
    }

    final scanAllowed = allowScanFallback &&
        (!teamLiveGuardActive || teamLiveRescueAllowed);
    if (found == null && !scanAllowed) {
      _log(
          'BLE reconnect direct wait: scan во время Team Live запрещён; повторю точный UUID позже.');
      return false;
    }

    // Только первый watchdog, получивший общий rescue-window, запускает 4s scan.
    found ??= await _scanForReconnect(info);
    if (found == null) {
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _device = null;
      connectedInfo = null;
      _log(
          'BLE reconnect wait: GPS-датчик пока вне зоны · быстрый 4s scan · Live-сессия на сервере продолжается.');
      _emitDevices();
      return false;
    }

    try {
      final scannedDevice = BluetoothDevice.fromId(found.id);
      _device = scannedDevice;
      connectedInfo = found;
      lastKnownInfo = found;
      await _connectAndDiscover(
        scannedDevice,
        found,
        requestHighConnectionPriority: _requestHighConnectionPriority,
      );
      final ok = await _isDeviceConnected(scannedDevice) &&
          _writeCharacteristic != null;
      _log(ok
          ? 'BLE reconnect OK: ${found.name} / ${found.id} · можно выгружать офлайн-записи'
          : 'BLE reconnect wait: датчик найден, но TX/RX ещё не открыт');
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

  Future<ActionTrackerDevice?> _scanForReconnect(
      ActionTrackerDevice target) async {
    _lastReconnectScanAt = DateTime.now();
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      _lastAppleRuntimeScanAt = DateTime.now();
    }
    final targetName = target.name.trim().toUpperCase();
    final targetId = target.id.trim();
    final targetIdKey = _normalizeId(targetId);
    final targetIdentity = _stableTrackerIdentity(target.name);
    final found = <String, ActionTrackerDevice>{};
    StreamSubscription<List<ScanResult>>? sub;

    await runExclusiveBleScan<void>(() async {
    try {
      await stopManagedScan();
      sub = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final name = _deviceName(result);
          final id = result.device.remoteId.str;
          if (name.isEmpty && id.isEmpty) continue;
          found[id] = ActionTrackerDevice(
            id: id,
            name: name.isEmpty
                ? 'BLE ${id.length <= 8 ? id : id.substring(0, 8)}'
                : name,
            rssi: result.rssi,
          );
        }
      });

      await startManagedScan(
          timeout: const Duration(seconds: 4), androidUsesFineLocation: false);
      await Future<void>.delayed(const Duration(seconds: 4));
      await stopManagedScan();
    } catch (e) {
      _log('BLE reconnect scan exception: $e');
    } finally {
      await stopManagedScan();
      await sub?.cancel();
    }
    });

    if (found.isNotEmpty) {
      for (final item in found.values) {
        final identity = _stableTrackerIdentity(item.name);
        if (identity.isNotEmpty && !_needsAppleRuntimeResolution(item.id)) {
          _latestRuntimeByIdentity[identity] = item;
          _latestRuntimeSeenAt[identity] = DateTime.now();
        }
      }
      final merged = <String, ActionTrackerDevice>{
        for (final item in _sharedScanSnapshot) item.id: item,
        ...found,
      };
      _sharedScanSnapshot = merged.values.toList(growable: false);
    }

    if (found.containsKey(targetId)) return found[targetId];
    for (final item in found.values) {
      if (targetIdKey.isNotEmpty && _normalizeId(item.id) == targetIdKey) {
        return item;
      }
    }

    // Если эфирный scan не вернул датчик, но Android держит его в paired/bonded,
    // пробуем вернуть сохранённую цель напрямую по MAC/id. Для BLE GATT это даёт
    // шанс переподключиться без advertising, как в оригинальном Action Tracer.
    final bonded = await _nativeAndroidBondedByTarget(target);
    if (bonded != null) return bonded;

    final candidates = found.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    for (final item in candidates) {
      final name = item.name.toUpperCase();
      if (targetName.isNotEmpty && name == targetName) return item;
      final itemIdentity = _stableTrackerIdentity(item.name);
      if (targetIdentity.isNotEmpty && itemIdentity == targetIdentity) {
        return item;
      }
    }
    _log(
        'BLE reconnect safety: точный UUID/имя ${target.name} не найден; чужой ATP/GPS-кандидат не подключаю.');
    return null;
  }

  Future<ActionTrackerDevice?> _nativeAndroidBondedByTarget(
      ActionTrackerDevice target) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final raw = await _nativeBleChannel
          .invokeMethod<List<dynamic>>('getBondedBluetoothDevices')
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => const <dynamic>[],
          );
      if (raw == null || raw.isEmpty) return null;
      final targetId = _normalizeId(target.id);
      final targetName = _normalizeName(target.name.replaceAll('· paired', ''));
      final targetIdentity = _stableTrackerIdentity(target.name);
      for (final entry in raw) {
        if (entry is! Map) continue;
        final id = (entry['address'] ?? entry['id'] ?? '').toString().trim();
        final name = (entry['name'] ?? '').toString().trim();
        final idKey = _normalizeId(id);
        final nameKey = _normalizeName(name);
        final idMatch = targetId.isNotEmpty && idKey == targetId;
        final bondedIdentity = _stableTrackerIdentity(name);
        final nameMatch = targetName.isNotEmpty &&
            nameKey.isNotEmpty &&
            (nameKey == targetName ||
                (targetIdentity.isNotEmpty &&
                    bondedIdentity == targetIdentity));
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
    _log(
        'BLE RESET DONE: локальный канал очищен, сохранённые серверные привязки не удалялись');
  }

  Future<void> cleanScan({
    Duration timeout = const Duration(seconds: 5),
    Iterable<String> knownDeviceIds = const <String>[],
    Iterable<String> knownDeviceNames = const <String>[],
    bool universalMode = false,
  }) async {
    _log(
        'CLEAN SCAN requested: сначала resetLocalState, затем универсальный scan GPS-датчика');
    await resetLocalState(clearKnownDevice: true);
    await scan(
        timeout: timeout,
        knownDeviceIds: knownDeviceIds,
        knownDeviceNames: knownDeviceNames,
        universalMode: universalMode);
  }

  Future<void> disconnect({
    bool clearInfo = true,
    String logMessage = 'Отключение...',
  }) async {
    final device = _device;
    _log(logMessage);

    _connectionGeneration++;
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

  Future<void> requestBatteryAndGpsState() =>
      _write(ActionTrackerBleProfile.commandReadBatteryAndGps);
  Future<void> requestRecordList() =>
      _write(ActionTrackerBleProfile.commandReadFileList);

  /// Экспериментальный режим Live.
  /// В APK найдены функции текущего GPS, но байтовая команда зависит от прошивки.
  /// Этот метод позволяет отправлять диагностические команды и смотреть RX-пакеты.
  Future<void> sendRawCommand(List<int> bytes) => _write(bytes);

  Future<void> requestCurrentGpsCandidate({int candidateIndex = 0}) {
    final list = ActionTrackerBleProfile.commandCurrentGpsCandidates;
    final safeIndex = candidateIndex < 0 || candidateIndex >= list.length
        ? 0
        : candidateIndex;
    return _write(list[safeIndex]);
  }

  Future<void> requestGpsRecord(ActionTrackerRecord record) async {
    _selectedRecord = record;
    _log('Запрос GPS-записи ${record.fileId}');
    try {
      await _write(ActionTrackerBleProfile.commandReadGpsByFileId(record.fileId));
    } catch (_) {
      // Если сама команда не ушла, не оставляем сервис в режиме парсинга
      // офлайн-файла.
      _selectedRecord = null;
      rethrow;
    }
  }

  Future<void> _write(List<int> bytes) {
    final completer = Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _writeNow(bytes);
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _writeNow(List<int> bytes) async {
    // Live polling не имеет права сам запускать 15s connect + 4s scan из каждой
    // команды. Иначе один дальний датчик блокирует очередь, а исправные каналы
    // тоже замолкают. Переподключением занимается единый watchdog пула.
    if (_livePollingMode && !commandChannelReady) {
      _log('TX пропущен: Live-канал не готов, ожидаю BLE watchdog');
      throw StateError('TX/RX GPS не готов · ожидаю автоматический reconnect');
    }
    final ready = commandChannelReady ||
        await _ensureReadyForWrite(
          allowScanFallback: !_livePollingMode,
        );
    final c = _writeCharacteristic;

    final hex = bytes
        .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
    if (!ready || c == null) {
      _log('TX пропущен: BLE не подключён / $hex');
      throw Exception(
          'GPS-датчик не подключён. Нажмите «Сменить» и выберите датчик заново.');
    }

    _log('TX $hex');

    try {
      await c.write(bytes, withoutResponse: c.properties.writeWithoutResponse);
    } catch (e) {
      final text = e.toString().toLowerCase();
      final disconnected = text.contains('not connected') ||
          text.contains('device is not connected') ||
          text.contains('fbp-code: 6');
      if (!disconnected) rethrow;

      _log('TX ошибка: device is not connected. Повторное переподключение...');
      _writeCharacteristic = null;
      _notifyCharacteristic = null;

      if (_livePollingMode) {
        throw StateError(
            'TX/RX GPS отключился · автоматический reconnect выполнит BLE watchdog');
      }

      final recovered = await _ensureReadyForWrite();
      final retryChar = _writeCharacteristic;
      if (!recovered || retryChar == null) {
        throw Exception(
            'GPS-датчик отключился. Не удалось переподключиться автоматически.');
      }

      _log('TX retry $hex');
      await retryChar.write(bytes,
          withoutResponse: retryChar.properties.writeWithoutResponse);
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
    if (_disposed || _devicesController.isClosed) return;

    int priority(ActionTrackerDevice d) {
      final name = d.name.toUpperCase();
      if (ActionTrackerBleProfile.namePrefixes
          .any((p) => name.startsWith(p.toUpperCase()))) return 0;
      if (name.contains('GPS') ||
          name.contains('ATP') ||
          name.contains('ACT') ||
          name.contains('AT')) return 1;
      return 2;
    }

    final list = _devices.values.toList()
      ..sort((a, b) {
        final pa = priority(a);
        final pb = priority(b);
        if (pa != pb) return pa.compareTo(pb);
        return b.rssi.compareTo(a.rssi);
      });
    if (!_disposed && !_devicesController.isClosed) {
      _devicesController.add(list);
    }
  }

  void _log(String message) {
    if (_disposed || _logController.isClosed) return;
    _logController.add('[${DateTime.now().toIso8601String()}] $message');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    // Ставим флаг ДО первого await: scan/notify/connection callbacks могут
    // прийти в тот же момент, когда workspace освобождает BLE-service.
    _disposed = true;
    _connectionGeneration++;
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await disconnect(clearInfo: true);
    if (!_devicesController.isClosed) await _devicesController.close();
    if (!_dataController.isClosed) await _dataController.close();
    if (!_logController.isClosed) await _logController.close();
  }
}
