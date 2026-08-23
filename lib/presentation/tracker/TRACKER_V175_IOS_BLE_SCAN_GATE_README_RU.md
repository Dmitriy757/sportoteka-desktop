# TRACKER V175 — iOS BLE method-channel / scan gate

База: V174. Все предыдущие исправления сохранены.

## Что исправлено

В логах iOS одновременно были два симптома:

- `Error: Message responses can be sent only once. Ignoring duplicate response on channel 'flutter_blue_plus/methods'.`
- много повторов `[FBP] stopScan: already stopped`.

Причина на уровне приложения: GPS, Polar и несколько Team BLE service экземпляров используют один общий FlutterBluePlus method-channel, но раньше каждый сервис мог отдельно вызвать `isSupported`, `startScan` и `stopScan`.

### 1. Убран `FlutterBluePlus.isSupported` на Apple

На iOS/macOS приложение теперь использует `adapterState` как проверку BLE runtime. `isSupported` остаётся только для не-Apple платформ и выполняется через общий runtime gate.

Это убирает показанный в логе iOS-вызов:

`[FBP-iOS] handleMethodCall: isSupported`

из нашего init-пути.

### 2. Один общий scan gate для GPS + Polar

`ActionTrackerBleService` теперь управляет единым процессным scan:

- GPS и Polar не запускают scan параллельно;
- start/stop сериализованы;
- `stopScan` вызывается только если Sportoteka действительно считает свой scan активным;
- после timeout scan автоматически считается завершённым, поэтому cleanup не спамит `stopScan: already stopped`.

### 3. connect больше не делает безусловный stopScan

GPS и Polar перед connect вызывают managed-stop, который является no-op, если scan уже остановлен.

## Что проверить на iPad/iPhone

После запуска и открытия Tracker в консоли не должно постоянно повторяться:

- `handleMethodCall: isSupported`
- `Message responses can be sent only once`
- серии `stopScan: already stopped`

При ручном поиске ожидается один `startScan`, затем найденные устройства/окончание timeout.

Если `Message responses can be sent only once` останется именно сразу после `startScan` при отсутствии `isSupported`, тогда источник уже внутри конкретной установленной версии `flutter_blue_plus_ios`; в таком случае нужен `pubspec.lock`/Pod lock основного проекта для точечного native/plugin fix.
