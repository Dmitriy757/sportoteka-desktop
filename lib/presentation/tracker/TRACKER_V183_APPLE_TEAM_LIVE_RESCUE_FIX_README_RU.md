# Tracker V183 — Apple Team Live BLE rescue fix

Дата: 2026-08-21

## Симптом

Во время Team Live несколько GPS одновременно оставались с `TX/RX не готов`,
`ожидаю BLE watchdog`, а `last RX / last GPS` росли до тысяч секунд. Watchdog
срабатывал, но связь не возвращалась. На экране при этом могла оставаться старая
ненулевая «текущая» скорость.

## Корень

V176–V178 правильно убрали старый BLE scan storm, но запретили scan во время
Team Live слишком жёстко. На iOS/macOS серверная привязка хранит Android MAC
`CC:..`, а CoreBluetooth работает с runtime UUID. После sleep/wake или сброса
BLE runtime старый UUID иногда перестаёт открываться. Direct reconnect продолжал
повторяться, но получить свежий runtime UUID было невозможно до Stop.

## Исправлено

1. Direct reconnect остаётся первым и основным способом восстановления.
2. На Apple watchdog может выполнить один общий 4s rescue scan, но не чаще
   одного раза в 90 секунд на весь Team BLE pool.
3. Rescue scan видит весь BLE-эфир и кеширует свежие runtime UUID по стабильному
   имени `$ATP-Cxxxx`.
4. Остальные GPS команды используют свежий cache и восстанавливаются без своих
   дополнительных scan, даже пока Team Live scan guard закрыт.
5. Если UUID не изменился, но датчик снова появился в эфире, выполняется один
   повторный direct connect после общего rescue scan.
6. На Android поведение не меняется: Team Live recovery остаётся direct-only,
   чтобы не возвращать GATT 133 / scan storm.
7. «Текущая скорость» становится 0.0 км/ч, если валидный GPS не приходил больше
   5 секунд. Максимум и накопленная дистанция не сбрасываются.

## Изменённые файлы

- `services/action_tracker_ble_service.dart`
- `services/team_action_tracker_ble_pool.dart`
- `services/team_tracker_live_coordinator.dart`

PHP менять не требуется.

## Что должно быть в диагностике после исправления

При длинном разрыве на Apple допустима последовательность примерно такого вида:

- `BLE watchdog: ... сначала direct reconnect`
- direct reconnect не прошёл
- один `общий Apple rescue scan`
- `BLE Apple rescue cache ...`
- `BLE watchdog: канал восстановлен`
- после первой реальной GPS-точки `last RX / last GPS` снова становятся свежими

Не должно быть постоянного scan каждые 10–15 секунд на каждый GPS.

## Проверка

После замены файлов выполнить **полный restart приложения**, не hot reload.
Старые Timer/статические BLE guard-состояния из V176–V178 могут жить в текущем
процессе и исказить тест.
