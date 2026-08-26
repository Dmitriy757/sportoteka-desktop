import 'dart:async';

import '../models/action_tracker_protocol.dart';
import 'action_tracker_ble_service.dart';

class TeamTrackerBleEvent {
  final String deviceUuid;
  final String deviceName;
  final ActionTrackerParseResult data;

  const TeamTrackerBleEvent({
    required this.deviceUuid,
    required this.deviceName,
    required this.data,
  });
}

class TeamTrackerBleLog {
  final String deviceUuid;
  final String deviceName;
  final String line;

  const TeamTrackerBleLog({
    required this.deviceUuid,
    required this.deviceName,
    required this.line,
  });
}

class _TeamTrackerConnection {
  final ActionTrackerDevice info;
  final ActionTrackerBleService service;
  StreamSubscription<ActionTrackerParseResult>? dataSub;
  StreamSubscription<String>? logSub;
  DateTime? lastPoolCommandAt;
  DateTime? lastReconnectAttemptAt;
  DateTime? lastRecordProbeAt;
  List<ActionTrackerRecord> lastRecords = <ActionTrackerRecord>[];
  Completer<List<ActionTrackerRecord>>? recordListCompleter;
  bool offlineTransferActive = false;
  final List<ActionTrackerGpsPoint> offlinePoints = <ActionTrackerGpsPoint>[];
  Completer<List<ActionTrackerGpsPoint>>? offlineTransferCompleter;
  DateTime? offlineLastChunkAt;
  String? offlineTransferError;

  _TeamTrackerConnection({required this.info, required this.service});
}

class _PendingGpsPoll {
  final String deviceUuid;
  final int sequence;
  final DateTime sentAt;
  final Completer<void> response = Completer<void>();

  _PendingGpsPoll({
    required this.deviceUuid,
    required this.sequence,
    required this.sentAt,
  });
}

/// Командный GPS-pool: один экземпляр ActionTrackerBleService на каждый UUID.
/// Это принципиально: одиночный ActionTrackerBleService хранит один BluetoothDevice,
/// поэтому при подключении второго GPS отключал первый.
class TeamActionTrackerBlePool {
  static final Map<String, TeamActionTrackerBlePool> _sharedPools =
      <String, TeamActionTrackerBlePool>{};
  static final Map<String, int> _sharedPoolUsers = <String, int>{};

  /// Все окна одной команды должны работать с одним набором BLE-каналов.
  /// Иначе повторно открытый Live видел пустой pool, хотя экран назначения
  /// продолжал держать реальные подключения.
  static TeamActionTrackerBlePool acquireShared(String key) {
    final normalized = key.trim();
    final pool = _sharedPools.putIfAbsent(
      normalized,
      TeamActionTrackerBlePool.new,
    );
    _sharedPoolUsers[normalized] = (_sharedPoolUsers[normalized] ?? 0) + 1;
    return pool;
  }

  static Future<void> releaseShared(String key) async {
    final normalized = key.trim();
    final current = _sharedPoolUsers[normalized] ?? 0;
    if (current <= 0) return;
    if (current > 1) {
      _sharedPoolUsers[normalized] = current - 1;
      return;
    }
    _sharedPoolUsers[normalized] = 0;
    final pool = _sharedPools[normalized];
    if (pool == null) {
      _sharedPoolUsers.remove(normalized);
      return;
    }

    // Закрытие workspace не должно обрывать уже начатую послематчевую
    // выгрузку. Pool остаётся доступен по тому же shared key, поэтому новый
    // экран/Team Live может сразу переиспользовать каналы и при необходимости
    // поставить file-transfer на паузу.
    while (pool.backgroundWorkActive || pool.offlineTransferActive) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if ((_sharedPoolUsers[normalized] ?? 0) > 0) return;
    }
    if ((_sharedPoolUsers[normalized] ?? 0) > 0) return;
    _sharedPoolUsers.remove(normalized);
    if (identical(_sharedPools[normalized], pool)) {
      _sharedPools.remove(normalized);
      await pool.dispose();
    }
  }

  final Map<String, _TeamTrackerConnection> _connections = {};
  final StreamController<TeamTrackerBleEvent> _data =
      StreamController.broadcast();
  final StreamController<TeamTrackerBleLog> _logs =
      StreamController.broadcast();
  final StreamController<int> _state = StreamController<int>.broadcast();
  bool _disposed = false;
  Timer? _idleKeepAliveTimer;
  Future<void> _commandQueue = Future<void>.value();
  bool _connectingAny = false;
  bool _livePolling = false;
  bool _recoveryInFlight = false;
  String? _recoveryDeviceUuid;
  DateTime? _lastLiveRescueScanAt;
  int _backgroundWorkLeases = 0;
  int _keepAliveCursor = 0;
  _PendingGpsPoll? _pendingGpsPoll;
  int _gpsPollSequence = 0;
  int _orphanLiveDrops = 0;
  int _crossRoutedLiveDrops = 0;
  static const Duration _gpsResponseTimeout = Duration(milliseconds: 350);
  // Прямой UUID/MAC reconnect остаётся основным путём. Общий rescue scan
  // во время Team Live нужен только Apple для обновления CoreBluetooth runtime
  // UUID. На Android scan во время Live запрещён: он повышает риск GATT 133 и
  // разрыва уже работающих каналов. Apple rescue дополнительно ограничен 90s.
  static const Duration _liveRescueScanCooldown = Duration(seconds: 90);

  Stream<TeamTrackerBleEvent> get dataStream => _data.stream;
  Stream<TeamTrackerBleLog> get logStream => _logs.stream;
  Stream<int> get stateStream => _state.stream;

  List<ActionTrackerDevice> get connectedInfos => _connections.values
      .where((c) => c.service.commandChannelReady)
      .map((c) => c.info)
      .toList(growable: false);

  /// Каналы, которые pool уже знает, включая временно потерявшие TX/RX.
  /// Между таймами это важнее обычного scan: Android может продолжать держать
  /// старый GATT, и такой ATP в этот момент вообще не advertising-ится.
  List<ActionTrackerDevice> get knownInfos => _connections.values
      .map((c) => c.info)
      .toList(growable: false);

  int get connectedCount => connectedInfos.length;

  bool get livePolling => _livePolling;
  bool get recoveryInProgress => _recoveryInFlight;
  String? get recoveryDeviceUuid => _recoveryDeviceUuid;
  bool get backgroundWorkActive => _backgroundWorkLeases > 0;

  bool get offlineTransferActive =>
      _connections.values.any((c) => c.offlineTransferActive);

  void retainBackgroundWork() {
    // Background recovery lease itself does not change the visible BLE state.
    // Emitting state here rebuilt the whole Tracker workspace every retry tick
    // and made Analytics look as if it was reloading. Real connection changes
    // still call _notifyState() from connect/disconnect/recovery paths.
    _backgroundWorkLeases++;
  }

  void releaseBackgroundWork() {
    if (_backgroundWorkLeases > 0) _backgroundWorkLeases--;
  }

  List<ActionTrackerRecord> recordsFor(String uuid) =>
      List<ActionTrackerRecord>.unmodifiable(
        _connections[uuid]?.lastRecords ?? const <ActionTrackerRecord>[],
      );

  bool isConnected(String uuid) =>
      _connections[uuid]?.service.commandChannelReady == true;

  ActionTrackerBleService? serviceFor(String uuid) =>
      _connections[uuid]?.service;

  /// Все connect/discover/notify операции проходят через ту же последовательную
  /// очередь, что и команды. Android BluetoothGatt, особенно на Honor/MagicOS,
  /// часто возвращает 133, когда второй GATT открывается до завершения первого.
  Future<void> connect(
    ActionTrackerDevice info, {
    int maxAttempts = 4,
  }) {
    return _serializedCommand(
      () => _connectNow(info, maxAttempts: maxAttempts),
    );
  }

  Future<void> _connectNow(
    ActionTrackerDevice info, {
    int maxAttempts = 4,
  }) async {
    if (_disposed) throw StateError('Team BLE pool уже закрыт');
    final existing = _connections[info.id];
    if (_livePolling && existing == null) {
      throw StateError(
        'Новый BLE-канал нельзя открывать во время Team Live. Дождитесь Stop.',
      );
    }
    if (existing != null && existing.service.commandChannelReady) return;

    final service = existing?.service ?? ActionTrackerBleService();
    service.setLivePollingMode(_livePolling);
    final conn =
        existing ?? _TeamTrackerConnection(info: info, service: service);
    _connections[info.id] = conn;

    await conn.dataSub?.cancel();
    conn.dataSub = service.dataStream.listen((event) {
      // Список файлов — лёгкий служебный ответ. Сохраняем его отдельно, чтобы
      // Team Live мог проверить внутреннюю запись после reconnect, не запуская
      // тяжёлую выгрузку файла во время матча.
      if (event.records.isNotEmpty ||
          event.packetType == 0x31 ||
          event.packetType == 0x51) {
        conn.lastRecords = List<ActionTrackerRecord>.from(event.records);
        final completer = conn.recordListCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(List<ActionTrackerRecord>.from(conn.lastRecords));
        }
      }

      // Во время послематчевой выгрузки 44/45 — это уже НЕ Live-пакеты, а
      // фрагменты выбранного файла. Их нельзя прогонять через orphan/cross-route
      // фильтр Live, иначе часть записи будет отброшена.
      if (conn.offlineTransferActive) {
        final chunk = event.gpsChunk;
        if (chunk != null && chunk.points.isNotEmpty) {
          conn.offlinePoints.addAll(chunk.points);
          conn.offlineLastChunkAt = DateTime.now();
        }
        if (event.transferFinished || chunk?.finished == true) {
          final completer = conn.offlineTransferCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete(
              List<ActionTrackerGpsPoint>.from(conn.offlinePoints),
            );
          }
        }
        return;
      }

      // Live GPS 3B/44/45 — это ответ на конкретный poll. На части Android BLE
      // стека два NUS notify-канала могли получать один и тот же payload. В БД
      // это проявилось как 2468/2470 точек у двух UUID вместо ~1230 и полный
      // RAW-overlap. Поэтому ответ принимает только владелец текущей команды.
      if (_isLiveGpsPacket(event.packetType)) {
        final pending = _pendingGpsPoll;
        if (pending == null) {
          _orphanLiveDrops++;
          if (_orphanLiveDrops <= 5 || _orphanLiveDrops % 100 == 0) {
            _emitLog(TeamTrackerBleLog(
              deviceUuid: info.id,
              deviceName: info.name,
              line: 'RX DROP orphan live packet #$_orphanLiveDrops type=${event.packetType.toRadixString(16).toUpperCase()}',
            ));
          }
          return;
        }
        if (pending.deviceUuid != info.id) {
          _crossRoutedLiveDrops++;
          if (_crossRoutedLiveDrops <= 10 || _crossRoutedLiveDrops % 100 == 0) {
            _emitLog(TeamTrackerBleLog(
              deviceUuid: info.id,
              deviceName: info.name,
              line: 'RX DROP cross-routed #$_crossRoutedLiveDrops: owner=${pending.deviceUuid} source=${info.id} seq=${pending.sequence}',
            ));
          }
          return;
        }
        if (!pending.response.isCompleted) pending.response.complete();
        if (identical(_pendingGpsPoll, pending)) _pendingGpsPoll = null;
      }

      _emitData(TeamTrackerBleEvent(
        deviceUuid: info.id,
        deviceName: info.name,
        data: event,
      ));
    });

    await conn.logSub?.cancel();
    conn.logSub = service.logStream.listen((line) {
      _emitLog(TeamTrackerBleLog(
        deviceUuid: info.id,
        deviceName: info.name,
        line: line,
      ));
      // Раньше обрыв GATT во время чтения файла оставлял Future ждать полный
      // 15-минутный timeout и блокировал очередь остальных GPS. Завершаем
      // попытку сразу; job останется waiting и повторится после reconnect.
      if (conn.offlineTransferActive) {
        final lower = line.toLowerCase();
        final disconnected = lower.contains('ble вне зоны') ||
            lower.contains('device is not connected') ||
            lower.contains('reconnect direct error');
        if (disconnected) {
          conn.offlineTransferError =
              'BLE оборвался при чтении offline-файла · получено ${conn.offlinePoints.length} точек';
        }
      }
    });

    _connectingAny = true;
    try {
      await service.init();
      // В командном режиме не запрашиваем список офлайн-файлов при каждом
      // подключении: эта длинная операция перегружала GATT при наборе команды.
      // Также не включаем HIGH connection priority: на Honor/MagicOS он
      // практически ограничивал устойчивый набор семью одновременными GATT.
      Object? lastError;
      final attempts = maxAttempts < 1
          ? 1
          : (maxAttempts > 4 ? 4 : maxAttempts);
      for (var attempt = 1; attempt <= attempts; attempt++) {
        try {
          await service.connect(
            info,
            inspectOfflineRecords: false,
            requestHighConnectionPriority: false,
          );
          lastError = null;
          // Даём Android закончить service discovery/CCCD до следующего GATT.
          await Future<void>.delayed(const Duration(milliseconds: 750));
          break;
        } catch (e) {
          lastError = e;
          final gatt133 = _isAndroidGatt133(e);
          final expectedAppleWait = _isExpectedAppleRecoveryWait(e);
          // На Apple отсутствие runtime UUID, пока GPS не появился в эфире,
          // является нормальным ожиданием recovery, а не ошибкой соединения.
          if (!expectedAppleWait) {
            _emitLog(TeamTrackerBleLog(
              deviceUuid: info.id,
              deviceName: info.name,
              line:
                  'Подключение $attempt/$attempts не прошло${gatt133 ? ' (Android GATT 133)' : ''}: $e',
            ));
          }
          if (attempt < attempts) {
            // GATT Honor требуется время закрыть незавершённый client slot.
            // Для 133 используем более длинный backoff, не трогая остальные GPS.
            await service.disconnect(
              clearInfo: false,
              logMessage:
                  'BLE connect retry cleanup: закрываю незавершённый GATT перед следующей попыткой',
            );
            await Future<void>.delayed(
              Duration(milliseconds: (gatt133 ? 1800 : 900) * attempt),
            );
          }
        }
      }
      if (lastError != null) throw lastError;
      conn.lastPoolCommandAt = DateTime.now();
      _ensureIdleKeepAlive();
      _notifyState();
    } catch (_) {
      // Не оставляем в пуле полуподключённый канал. Остальные UUID не трогаем.
      if (identical(_connections[info.id], conn)) {
        _connections.remove(info.id);
      }
      await conn.dataSub?.cancel();
      await conn.logSub?.cancel();
      await service.dispose();
      _notifyState();
      rethrow;
    } finally {
      _connectingAny = false;
    }
  }

  bool _isAndroidGatt133(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('android-code: 133') ||
        text.contains('android code: 133') ||
        text.contains('gatt_error') && text.contains('133');
  }

  bool _isExpectedAppleRecoveryWait(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('на ios/macos сохранённый mac нельзя подключать напрямую') ||
        (text.contains('gps ') && text.contains('пока не найден рядом'));
  }

  bool _isLiveGpsPacket(int packetType) =>
      packetType == 0x3B || packetType == 0x44 || packetType == 0x45;

  void setLivePolling(bool value) {
    if (_livePolling == value) return;
    _livePolling = value;
    ActionTrackerBleService.setTeamLiveGuard(value);
    for (final conn in _connections.values) {
      conn.service.setLivePollingMode(value);
    }
    if (!value) _ensureIdleKeepAlive();
  }

  void _ensureIdleKeepAlive() {
    if (_idleKeepAliveTimer != null || _connections.isEmpty) return;
    _idleKeepAliveTimer = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => _runIdleKeepAliveTick(),
    );
  }

  void _runIdleKeepAliveTick() {
    if (_livePolling || _connectingAny || _connections.isEmpty) return;
    final connections = _connections.values.toList(growable: false);
    if (_keepAliveCursor >= connections.length) _keepAliveCursor = 0;
    final conn = connections[_keepAliveCursor++];

    final now = DateTime.now();
    if (!conn.service.commandChannelReady) {
      final lastReconnect = conn.lastReconnectAttemptAt;
      if (lastReconnect != null &&
          now.difference(lastReconnect).inSeconds < 30) {
        return;
      }
      conn.lastReconnectAttemptAt = now;
      unawaited(_serializedCommand(() async {
        try {
          // Idle keep-alive must NEVER start a radio scan. On Apple a saved
          // server MAC cannot be used as a CoreBluetooth remoteId, so the old
          // default allowScanFallback=true produced a 4s startScan/stopScan
          // cycle for every disconnected saved GPS. With multiple devices the
          // cycles were staggered and appeared roughly every 15 seconds.
          // A direct reconnect is still allowed when we already know a runtime
          // UUID. Radio discovery is reserved for explicit user search or the
          // much slower post-Stop recovery path.
          final restored = await conn.service.ensureCommandChannel(
            allowScanFallback: false,
          );
          if (restored) {
            conn.lastPoolCommandAt = DateTime.now();
            _notifyState();
            _emitLog(TeamTrackerBleLog(
              deviceUuid: conn.info.id,
              deviceName: conn.info.name,
              line: 'Предстартовый BLE-канал восстановлен автоматически',
            ));
          }
        } catch (e) {
          _emitLog(TeamTrackerBleLog(
            deviceUuid: conn.info.id,
            deviceName: conn.info.name,
            line: 'Предстартовое восстановление BLE ожидает датчик: $e',
          ));
        }
      }));
      return;
    }

    final last = conn.lastPoolCommandAt;
    if (last != null && now.difference(last).inSeconds < 8) return;
    unawaited(_serializedCommand(() async {
      if (!conn.service.commandChannelReady) return;
      try {
        await conn.service.requestBatteryAndGpsState();
        conn.lastPoolCommandAt = DateTime.now();
      } catch (e) {
        _emitLog(TeamTrackerBleLog(
          deviceUuid: conn.info.id,
          deviceName: conn.info.name,
          line: 'Предстартовый keep-alive не прошёл: $e',
        ));
      }
    }));
  }

  Future<void> _serializedCommand(Future<void> Function() action) {
    final completer = Completer<void>();
    _commandQueue = _commandQueue.then((_) async {
      try {
        await action();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> ensureConnected(Iterable<ActionTrackerDevice> devices) async {
    for (final device in devices) {
      if (!isConnected(device.id)) {
        await connect(device);
      }
    }
  }

  /// Послематчевое восстановление должно уметь вернуть канал даже после того,
  /// как Android GATT 133 заставил pool удалить неудачное соединение. UUID/MAC
  /// уже известен из серверной привязки, поэтому повторный scan не обязателен:
  /// FlutterBluePlus умеет открыть BluetoothDevice.fromId(uuid) напрямую.
  Future<bool> ensureRecoveryConnection(
    String uuid, {
    required String deviceName,
  }) async {
    if (_livePolling) return false;
    if (isConnected(uuid)) return true;

    final existing = _connections[uuid];
    final info = existing?.info ??
        ActionTrackerDevice(
          id: uuid,
          name: deviceName.trim().isEmpty ? uuid : deviceName.trim(),
          rssi: -100,
        );
    try {
      // Background recovery owns its retry cadence. One retry pass must
      // perform only one connectGatt, otherwise 8 GPS x 4 attempts create a
      // GATT-133/disconnect storm and keep rebuilding the UI.
      await connect(info, maxAttempts: 1);
      return isConnected(uuid);
    } catch (e) {
      // Expected Apple wait stays silent. The recovery job remains pending and
      // coordinator retries through the process-wide cooldown. Real BLE/GATT
      // errors are still emitted to diagnostics.
      if (!_isExpectedAppleRecoveryWait(e)) {
        _emitLog(TeamTrackerBleLog(
          deviceUuid: uuid,
          deviceName: info.name,
          line: 'POST-STOP AUTO RECOVERY: GPS пока не переподключён: $e',
        ));
      }
      return false;
    }
  }

  /// Новый Team Live имеет абсолютный приоритет над послематчевым recovery.
  /// На паузу ставим не только уже начатый download 44/45, но и запрос списка
  /// ATP-файлов. Это важно: Start может быть нажат ровно в те 10–12 секунд,
  /// когда recovery ждёт record-list, и старый запрос не должен держать GATT
  /// или попасть в очередь перед первым Live GPS poll. Server job при этом не
  /// удаляется: после следующего Stop он будет прочитан заново с нуля.
  Future<List<ActionTrackerDevice>> pauseOfflineRecoveryForLive({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final active = _connections.values
        .where((conn) =>
            conn.offlineTransferActive || conn.recordListCompleter != null)
        .toList(growable: false);
    if (active.isEmpty) return const <ActionTrackerDevice>[];

    final interrupted = active.map((conn) => conn.info).toList(growable: false);
    for (final conn in active) {
      const reason = 'Offline recovery поставлен на паузу новым Team Live';

      // Record-list может ждать до timeout. Завершаем его сразу, чтобы Start
      // не висел в общей BLE-очереди и не провоцировал Android GATT 133.
      final listCompleter = conn.recordListCompleter;
      if (listCompleter != null && !listCompleter.isCompleted) {
        // Пустой ответ безопаснее completeError: listener на Future может ещё
        // не успеть установиться, если Start попал ровно между TX и await.
        // Coordinator сразу увидит _starting и прекратит этот recovery-pass.
        listCompleter.complete(const <ActionTrackerRecord>[]);
      }

      // DownloadFinishedRecord проверяет offlineTransferError каждые 5 секунд,
      // но при Start нам нужен немедленный выход. Возвращаем пустой технический
      // результат (не частичный буфер!), а coordinator после await проверит
      // _starting и не отправит ни одной точки в server staging.
      conn.offlineTransferError = reason;
      final transferCompleter = conn.offlineTransferCompleter;
      if (transferCompleter != null && !transferCompleter.isCompleted) {
        transferCompleter.complete(const <ActionTrackerGpsPoint>[]);
      }

      _emitLog(TeamTrackerBleLog(
        deviceUuid: conn.info.id,
        deviceName: conn.info.name,
        line: 'OFFLINE RECOVERY PAUSE · приоритет новому Team Live',
      ));
      await conn.service.disconnect(clearInfo: false);
    }

    bool recoveryBleBusy() => _connections.values.any((conn) =>
        conn.offlineTransferActive || conn.recordListCompleter != null);

    final deadline = DateTime.now().add(timeout);
    while (recoveryBleBusy() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (recoveryBleBusy()) {
      throw TimeoutException(
        'Не удалось поставить offline recovery на паузу перед Team Live',
        timeout,
      );
    }
    _notifyState();
    return interrupted;
  }

  // Совместимость с уже собранными вызовами V164. Новые вызовы используют
  // более точное имя, потому что на паузу теперь ставится весь BLE recovery,
  // а не только скачивание finished-файла.
  Future<List<ActionTrackerDevice>> pauseOfflineTransfersForLive({
    Duration timeout = const Duration(seconds: 8),
  }) =>
      pauseOfflineRecoveryForLive(timeout: timeout);

  Future<void> disconnect(String uuid) async {
    final pending = _pendingGpsPoll;
    if (pending != null && pending.deviceUuid == uuid) {
      if (!pending.response.isCompleted) pending.response.complete();
      _pendingGpsPoll = null;
    }
    final conn = _connections.remove(uuid);
    if (conn == null) return;
    final listCompleter = conn.recordListCompleter;
    if (listCompleter != null && !listCompleter.isCompleted) {
      listCompleter.completeError(StateError('BLE $uuid отключён'));
    }
    final transferCompleter = conn.offlineTransferCompleter;
    if (transferCompleter != null && !transferCompleter.isCompleted) {
      transferCompleter.completeError(StateError('BLE $uuid отключён во время выгрузки'));
    }
    conn.recordListCompleter = null;
    conn.offlineTransferCompleter = null;
    conn.offlineTransferActive = false;
    conn.service.clearSelectedRecord();
    await conn.dataSub?.cancel();
    await conn.logSub?.cancel();
    await conn.service.disconnect(clearInfo: true);
    await conn.service.dispose();
    _notifyState();
    if (_connections.isEmpty) {
      _idleKeepAliveTimer?.cancel();
      _idleKeepAliveTimer = null;
      _keepAliveCursor = 0;
    }
  }

  Future<void> disconnectAll() async {
    final ids = _connections.keys.toList(growable: false);
    for (final id in ids) {
      await disconnect(id);
    }
  }

  /// Освобождает GATT-слоты, которые не участвуют в текущем составе Live.
  /// Сохранённые назначения на сервере не удаляются: между тренировками эти
  /// датчики снова подключатся режимом «Сохранённая команда».
  Future<List<ActionTrackerDevice>> disconnectExcept(
    Set<String> keepUuids,
  ) async {
    final extras = _connections.entries
        .where((entry) => !keepUuids.contains(entry.key))
        .map((entry) => entry.value.info)
        .toList(growable: false);
    for (final info in extras) {
      _emitLog(TeamTrackerBleLog(
        deviceUuid: info.id,
        deviceName: info.name,
        line: 'BLE LIVE CAPACITY: отключаю канал вне текущего состава',
      ));
      await disconnect(info.id);
    }
    return extras;
  }

  Future<List<ActionTrackerRecord>> requestRecordListFor(
    String uuid, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final conn = _connections[uuid];
    if (conn == null) throw StateError('GPS $uuid не найден в командном pool');

    List<ActionTrackerRecord> result = const <ActionTrackerRecord>[];
    await _serializedCommand(() async {
      if (_livePolling) {
        throw StateError(
          'Полный запрос списка записей выполняется только вне Team Live',
        );
      }
      final ready = await conn.service.ensureCommandChannel();
      if (!ready) throw StateError('TX/RX GPS $uuid не готов');

      final completer = Completer<List<ActionTrackerRecord>>();
      conn.recordListCompleter = completer;
      try {
        await conn.service.requestRecordList();
        result = await completer.future.timeout(timeout);
        conn.lastRecordProbeAt = DateTime.now();
      } finally {
        if (identical(conn.recordListCompleter, completer)) {
          conn.recordListCompleter = null;
        }
        conn.lastPoolCommandAt = DateTime.now();
      }
    });
    return result;
  }

  Future<List<ActionTrackerGpsPoint>> downloadFinishedRecord(
    String uuid,
    ActionTrackerRecord record, {
    Duration timeout = const Duration(minutes: 15),
  }) async {
    final conn = _connections[uuid];
    if (conn == null) throw StateError('GPS $uuid не найден в командном pool');
    if (record.state != ActionTrackerRecordState.finished) {
      throw StateError(
        'Файл ${record.fileId} ещё не finished (${record.state.name})',
      );
    }

    List<ActionTrackerGpsPoint> result = const <ActionTrackerGpsPoint>[];
    await _serializedCommand(() async {
      if (_livePolling) {
        throw StateError(
          'Офлайн-файл нельзя скачивать во время Team Live',
        );
      }
      final ready = await conn.service.ensureCommandChannel();
      if (!ready) throw StateError('TX/RX GPS $uuid не готов');

      conn.offlineTransferActive = true;
      conn.offlinePoints.clear();
      conn.offlineLastChunkAt = null;
      conn.offlineTransferError = null;
      final completer = Completer<List<ActionTrackerGpsPoint>>();
      conn.offlineTransferCompleter = completer;
      try {
        _emitLog(TeamTrackerBleLog(
          deviceUuid: conn.info.id,
          deviceName: conn.info.name,
          line: 'OFFLINE DOWNLOAD START · file=${record.fileId}',
        ));
        await conn.service.requestGpsRecord(record);
        final startedAt = DateTime.now();
        while (true) {
          try {
            result = await completer.future.timeout(
              const Duration(seconds: 5),
            );
            break;
          } on TimeoutException {
            final now = DateTime.now();
            final transferError = conn.offlineTransferError;
            if (transferError != null) throw StateError(transferError);
            if (!conn.service.commandChannelReady) {
              throw StateError(
                'BLE отключён при чтении file ${record.fileId} · получено ${conn.offlinePoints.length} точек',
              );
            }
            final lastActivity = conn.offlineLastChunkAt ?? startedAt;
            if (now.difference(lastActivity) >= const Duration(seconds: 35)) {
              throw TimeoutException(
                'file ${record.fileId}: нет новых BLE-данных 35s · получено ${conn.offlinePoints.length} точек; повтор после reconnect',
                const Duration(seconds: 35),
              );
            }
            if (now.difference(startedAt) >= timeout) {
              throw TimeoutException(
                'file ${record.fileId}: общий timeout · получено ${conn.offlinePoints.length} точек',
                timeout,
              );
            }
          }
        }
        _emitLog(TeamTrackerBleLog(
          deviceUuid: conn.info.id,
          deviceName: conn.info.name,
          line:
              'OFFLINE DOWNLOAD DONE · file=${record.fileId} · points=${result.length}',
        ));
      } finally {
        conn.offlineTransferActive = false;
        conn.offlineTransferCompleter = null;
        conn.offlineLastChunkAt = null;
        conn.offlineTransferError = null;
        conn.service.clearSelectedRecord();
        conn.lastPoolCommandAt = DateTime.now();
      }
    });
    return result;
  }

  Future<void> requestCurrentGps(String uuid) async {
    final service = serviceFor(uuid);
    if (service == null) throw StateError('GPS $uuid не подключён');
    if (_recoveryInFlight) return;
    if (_livePolling && !service.commandChannelReady) {
      throw StateError('TX/RX GPS $uuid не готов · ожидаю BLE watchdog');
    }
    await _serializedCommand(() async {
      if (_recoveryInFlight) return;
      final ready = _livePolling
          ? service.commandChannelReady
          : await service.ensureCommandChannel();
      if (!ready) throw StateError('TX/RX GPS $uuid не готов');

      final poll = _PendingGpsPoll(
        deviceUuid: uuid,
        sequence: ++_gpsPollSequence,
        sentAt: DateTime.now(),
      );
      _pendingGpsPoll = poll;
      try {
        await service.requestCurrentGpsCandidate();
        try {
          await poll.response.future.timeout(_gpsResponseTimeout);
        } on TimeoutException {
          _emitLog(TeamTrackerBleLog(
            deviceUuid: uuid,
            deviceName: _connections[uuid]?.info.name ?? uuid,
            line: 'GPS poll timeout seq=${poll.sequence} · ответ 3B/44/45 не пришёл за ${_gpsResponseTimeout.inMilliseconds} ms',
          ));
        }
      } finally {
        if (identical(_pendingGpsPoll, poll)) _pendingGpsPoll = null;
      }
      _connections[uuid]?.lastPoolCommandAt = DateTime.now();
    });
  }

  Future<void> requestBattery(String uuid) async {
    final service = serviceFor(uuid);
    if (service == null) return;
    if (_recoveryInFlight) return;
    if (_livePolling && !service.commandChannelReady) return;
    await _serializedCommand(() async {
      if (_recoveryInFlight) return;
      if (_livePolling && !service.commandChannelReady) return;
      await service.requestBatteryAndGpsState();
      _connections[uuid]?.lastPoolCommandAt = DateTime.now();
    });
  }

  /// Восстанавливает только один замолчавший GPS, не сбрасывая остальные
  /// командные подключения. Весь reconnect проходит через общую BLE-очередь,
  /// чтобы Honor/MagicOS не получил несколько connectGatt одновременно.
  Future<bool> recoverConnection(
    String uuid, {
    String reason = 'давно нет RX',
  }) async {
    final conn = _connections[uuid];
    if (conn == null) return false;
    if (_recoveryInFlight) {
      _emitLog(TeamTrackerBleLog(
        deviceUuid: conn.info.id,
        deviceName: conn.info.name,
        line:
            'BLE watchdog: восстановление ${_recoveryDeviceUuid ?? 'другого канала'} уже идёт · новый reconnect не ставлю в очередь',
      ));
      return false;
    }

    var recovered = false;
    _recoveryInFlight = true;
    _recoveryDeviceUuid = uuid;
    try {
      await _serializedCommand(() async {
        if (!identical(_connections[uuid], conn)) return;
        conn.lastReconnectAttemptAt = DateTime.now();
        _emitLog(TeamTrackerBleLog(
          deviceUuid: conn.info.id,
          deviceName: conn.info.name,
          line:
              'BLE watchdog: $reason · сначала direct reconnect; общий rescue scan только при необходимости',
        ));
        final now = DateTime.now();
        final lastRescueScan = _lastLiveRescueScanAt;
        final rescueCooldownPassed = lastRescueScan == null ||
            now.difference(lastRescueScan) >= _liveRescueScanCooldown;
        final allowLiveRescueScan =
            ActionTrackerBleService.appleRuntime && rescueCooldownPassed;
        final scanBefore = ActionTrackerBleService.lastReconnectScanAt;
        recovered = await conn.service.forceReconnectCommandChannel(
          allowScanFallback: allowLiveRescueScan,
          allowTeamLiveRescueScan: allowLiveRescueScan,
        );
        final scanAfter = ActionTrackerBleService.lastReconnectScanAt;
        final rescueScanActuallyRan = allowLiveRescueScan &&
            scanAfter != null &&
            (scanBefore == null || scanAfter.isAfter(scanBefore));
        if (rescueScanActuallyRan) {
          _lastLiveRescueScanAt = scanAfter;
          _emitLog(TeamTrackerBleLog(
            deviceUuid: conn.info.id,
            deviceName: conn.info.name,
            line:
                'BLE watchdog: общий rescue scan выполнен · следующий не раньше ${_liveRescueScanCooldown.inSeconds}s',
          ));
        }
        if (recovered) {
          conn.lastPoolCommandAt = DateTime.now();
          _emitLog(TeamTrackerBleLog(
            deviceUuid: conn.info.id,
            deviceName: conn.info.name,
            line:
                'BLE watchdog: канал восстановлен · Live GPS продолжен, разрыв будет дочитан после Stop',
          ));
          // Во время Live не запрашиваем TX30/file-list. Текущий recording-файл
          // всё равно нельзя скачать до Stop, а лишний ответ забивал GPS polling.
          try {
            await conn.service.requestBatteryAndGpsState();
            conn.lastPoolCommandAt = DateTime.now();
          } catch (e) {
            _emitLog(TeamTrackerBleLog(
              deviceUuid: conn.info.id,
              deviceName: conn.info.name,
              line: 'BLE восстановлен, проверка батареи ожидает следующий poll: $e',
            ));
          }
        } else {
          _emitLog(TeamTrackerBleLog(
            deviceUuid: conn.info.id,
            deviceName: conn.info.name,
            line:
                'BLE watchdog: датчик пока далеко · Live не останавливаю, повторю прямой UUID позже',
          ));
        }
        _notifyState();
      });
    } finally {
      _recoveryInFlight = false;
      _recoveryDeviceUuid = null;
    }
    return recovered;
  }

  void _emitLog(TeamTrackerBleLog value) {
    if (_disposed || _logs.isClosed) return;
    _logs.add(value);
  }

  void _emitData(TeamTrackerBleEvent value) {
    if (_disposed || _data.isClosed) return;
    _data.add(value);
  }

  void _notifyState() {
    if (_disposed || _state.isClosed) return;
    _state.add(connectedCount);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_livePolling) setLivePolling(false);
    _idleKeepAliveTimer?.cancel();
    _idleKeepAliveTimer = null;
    await disconnectAll();
    await _data.close();
    await _logs.close();
    await _state.close();
  }
}
