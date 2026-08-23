# TRACKER V176 — no background BLE scan / no fake analytics reload

Дата: 2026-08-20
База: V175.

## Что показал лог V175

После hot reload продолжался ровный цикл:

- `startScan`
- через ~4 секунды `stopScan`
- через ~10–15 секунд новый `startScan`

Это уже не конфликт `isSupported` и не параллельный scan. Это был наш собственный фоновой reconnect.

`TeamActionTrackerBlePool` раз в 30 секунд на каждый потерянный сохранённый GPS вызывал `ensureCommandChannel()` с разрешённым scan fallback. На Apple серверный MAC (`CC:..`) нельзя подключить напрямую, поэтому каждый такой reconnect превращался в 4-секундный `_scanForReconnect()`. Несколько GPS имели разные таймеры, поэтому в общей консоли scan выглядел как запуск примерно каждые 15 секунд.

Кроме того, background recovery lease отправлял `stateStream`, хотя число реально подключённых GPS не менялось. Это давало лишние rebuild верхнего Tracker workspace и визуально могло выглядеть как обновление/перезагрузка Analytics.

## Исправлено

1. Idle/pre-start keep-alive больше **никогда не имеет права запускать BLE scan**.
   - прямой reconnect по уже известному runtime UUID остаётся;
   - если на Apple известен только server MAC, idle pass просто ждёт;
   - новый radio scan запускается вручную кнопкой поиска либо редким post-Stop recovery.

2. Apple background runtime-id recovery scan получил общий cooldown **90 секунд** вместо 12 секунд.
   - это process-wide cooldown для всех GPS;
   - несколько coordinator/окон не смогут снова разбудить CoreBluetooth через 12–15 секунд;
   - ручной `Поиск GPS`/`Polar` этим cooldown не ограничен.

3. `retainBackgroundWork/releaseBackgroundWork` больше не отправляют BLE `stateStream`.
   - background lease не меняет connectedCount;
   - поэтому он не должен перестраивать весь workspace;
   - реальные connect/disconnect/recovery по-прежнему отправляют state update.

## Ожидаемый лог

Если ничего не нажимать и Live не запущен, больше не должно быть постоянного цикла:

`startScan -> 4s -> stopScan -> 10s -> startScan ...`

При ручном `Поиск GPS` один `startScan/stopScan` — нормально.
При наличии реальной pending post-Stop recovery на Apple допустим редкий background scan, но не чаще одного общего scan примерно в 90 секунд.

## Изменённые файлы

- `services/team_action_tracker_ble_pool.dart`
- `services/action_tracker_ble_service.dart`
- `screens/tracker_match_workspace_screen.dart` (только актуализированы комментарии поведения)
