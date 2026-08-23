# Tracker V174 — iOS/macOS BLE connect/disconnect race fix

База: V173 STABLE BLE / NO RELOAD.

## Что показал новый лог
На Apple-платформе FlutterBluePlus получал последовательность `connect` -> немедленный `disconnect`, а затем предупреждение:

`Message responses can be sent only once. Ignoring duplicate response on channel 'flutter_blue_plus/methods'.`

Причина в проекте: серверные привязки GPS могут хранить Android MAC вида `CC:06:26:AC:09:64`. Android умеет использовать такой адрес как BLE remoteId. CoreBluetooth на iOS/macOS использует свой UUID периферии и MAC в `BluetoothDevice.fromId(...)` передавать нельзя.

Фоновый post-Stop recovery из V173 стал автоматически пробовать сохранённые серверные binding-id. На iOS это могло дать connect по MAC, немедленную ошибку и cleanup/disconnect в том же method-channel цикле.

## Исправлено
- На iOS/macOS MAC-адрес из серверной привязки больше никогда не передаётся напрямую в `BluetoothDevice.fromId`.
- Сначала ищется реальный CoreBluetooth runtime UUID по имени/стабильной identity датчика.
- Результаты первого короткого Apple scan кешируются, поэтому recovery нескольких GPS не запускает отдельный scan для каждого найденного датчика.
- Добавлен 12-секундный общий scan cooldown: отсутствующие GPS не создают scan storm в одном recovery-pass.
- Немедленный `device.disconnect()` после неудачного `connect()` оставлен только для Android, где он нужен для освобождения GATT slot / code 133.
- На iOS/macOS connect-error больше не сопровождается мгновенным native disconnect, который и провоцировал duplicate MethodChannel response.
- Та же защита применяется к watchdog/TX retry, не только к первичному recovery connect.
- V173-исправления бесконечной перезагрузки Analytics и ограничения recovery cadence сохранены.

## Изменённый файл
`services/action_tracker_ble_service.dart`

## Что должно быть после установки
При post-Stop recovery на iOS/macOS не должно быть повторяющихся пар:
`[FBP-iOS] handleMethodCall: connect`
`[FBP-iOS] handleMethodCall: disconnect`
в одну и ту же миллисекунду, и не должно появляться `Message responses can be sent only once` из-за этого пути.

`[FBP] stopScan: already stopped` сам по себе не является ошибкой BLE-соединения; это диагностическое сообщение FlutterBluePlus.
