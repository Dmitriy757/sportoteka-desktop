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

  _TeamTrackerConnection({required this.info, required this.service});
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
    if (current > 1) {
      _sharedPoolUsers[normalized] = current - 1;
      return;
    }
    _sharedPoolUsers.remove(normalized);
    final pool = _sharedPools.remove(normalized);
    if (pool != null) await pool.dispose();
  }

  final Map<String, _TeamTrackerConnection> _connections = {};
  final StreamController<TeamTrackerBleEvent> _data =
      StreamController.broadcast();
  final StreamController<TeamTrackerBleLog> _logs =
      StreamController.broadcast();
  final StreamController<int> _state = StreamController<int>.broadcast();
  Timer? _idleKeepAliveTimer;
  Future<void> _commandQueue = Future<void>.value();
  bool _connectingAny = false;
  bool _livePolling = false;
  int _keepAliveCursor = 0;

  Stream<TeamTrackerBleEvent> get dataStream => _data.stream;
  Stream<TeamTrackerBleLog> get logStream => _logs.stream;
  Stream<int> get stateStream => _state.stream;

  List<ActionTrackerDevice> get connectedInfos => _connections.values
      .where((c) => c.service.commandChannelReady)
      .map((c) => c.info)
      .toList(growable: false);

  int get connectedCount => connectedInfos.length;

  bool isConnected(String uuid) =>
      _connections[uuid]?.service.commandChannelReady == true;

  ActionTrackerBleService? serviceFor(String uuid) =>
      _connections[uuid]?.service;

  /// Все connect/discover/notify операции проходят через ту же последовательную
  /// очередь, что и команды. Android BluetoothGatt, особенно на Honor/MagicOS,
  /// часто возвращает 133, когда второй GATT открывается до завершения первого.
  Future<void> connect(ActionTrackerDevice info) {
    return _serializedCommand(() => _connectNow(info));
  }

  Future<void> _connectNow(ActionTrackerDevice info) async {
    final existing = _connections[info.id];
    if (existing != null && existing.service.commandChannelReady) return;

    final service = existing?.service ?? ActionTrackerBleService();
    final conn =
        existing ?? _TeamTrackerConnection(info: info, service: service);
    _connections[info.id] = conn;

    await conn.dataSub?.cancel();
    conn.dataSub = service.dataStream.listen((event) {
      _data.add(TeamTrackerBleEvent(
        deviceUuid: info.id,
        deviceName: info.name,
        data: event,
      ));
    });

    await conn.logSub?.cancel();
    conn.logSub = service.logStream.listen((line) {
      _logs.add(TeamTrackerBleLog(
        deviceUuid: info.id,
        deviceName: info.name,
        line: line,
      ));
    });

    _connectingAny = true;
    try {
      await service.init();
      // В командном режиме не запрашиваем список офлайн-файлов при каждом
      // подключении: эта длинная операция перегружала GATT при наборе команды.
      // Также не включаем HIGH connection priority: на Honor/MagicOS он
      // практически ограничивал устойчивый набор семью одновременными GATT.
      Object? lastError;
      const maxAttempts = 4;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
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
          _logs.add(TeamTrackerBleLog(
            deviceUuid: info.id,
            deviceName: info.name,
            line:
                'Подключение $attempt/$maxAttempts не прошло${gatt133 ? ' (Android GATT 133)' : ''}: $e',
          ));
          if (attempt < maxAttempts) {
            // GATT Honor требуется время закрыть незавершённый client slot.
            // Для 133 используем более длинный backoff, не трогая остальные GPS.
            await service.disconnect(clearInfo: false);
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

  void setLivePolling(bool value) {
    _livePolling = value;
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
          now.difference(lastReconnect).inSeconds < 12) {
        return;
      }
      conn.lastReconnectAttemptAt = now;
      unawaited(_serializedCommand(() async {
        try {
          final restored = await conn.service.ensureCommandChannel();
          if (restored) {
            conn.lastPoolCommandAt = DateTime.now();
            _notifyState();
            _logs.add(TeamTrackerBleLog(
              deviceUuid: conn.info.id,
              deviceName: conn.info.name,
              line: 'Предстартовый BLE-канал восстановлен автоматически',
            ));
          }
        } catch (e) {
          _logs.add(TeamTrackerBleLog(
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
        _logs.add(TeamTrackerBleLog(
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

  Future<void> disconnect(String uuid) async {
    final conn = _connections.remove(uuid);
    if (conn == null) return;
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

  Future<void> requestCurrentGps(String uuid) async {
    final service = serviceFor(uuid);
    if (service == null) throw StateError('GPS $uuid не подключён');
    await _serializedCommand(() async {
      final ready = await service.ensureCommandChannel();
      if (!ready) throw StateError('TX/RX GPS $uuid не готов');
      await service.requestCurrentGpsCandidate();
      _connections[uuid]?.lastPoolCommandAt = DateTime.now();
    });
  }

  Future<void> requestBattery(String uuid) async {
    final service = serviceFor(uuid);
    if (service == null) return;
    await _serializedCommand(() async {
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

    var recovered = false;
    await _serializedCommand(() async {
      if (!identical(_connections[uuid], conn)) return;
      conn.lastReconnectAttemptAt = DateTime.now();
      _logs.add(TeamTrackerBleLog(
        deviceUuid: conn.info.id,
        deviceName: conn.info.name,
        line: 'BLE watchdog: $reason · восстанавливаю только этот канал',
      ));
      recovered = await conn.service.forceReconnectCommandChannel();
      if (recovered) {
        conn.lastPoolCommandAt = DateTime.now();
        _logs.add(TeamTrackerBleLog(
          deviceUuid: conn.info.id,
          deviceName: conn.info.name,
          line: 'BLE watchdog: канал восстановлен автоматически',
        ));
      } else {
        _logs.add(TeamTrackerBleLog(
          deviceUuid: conn.info.id,
          deviceName: conn.info.name,
          line: 'BLE watchdog: датчик пока не отвечает, повторю позже',
        ));
      }
      _notifyState();
    });
    return recovered;
  }

  void _notifyState() {
    if (!_state.isClosed) _state.add(connectedCount);
  }

  Future<void> dispose() async {
    _idleKeepAliveTimer?.cancel();
    _idleKeepAliveTimer = null;
    await disconnectAll();
    await _data.close();
    await _logs.close();
    await _state.close();
  }
}
