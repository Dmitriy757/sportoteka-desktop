# Sportoteka Tracker Live

Добавлена вкладка **Live** в `SportotekaTrackerProScreen`.

## Что работает сразу

1. Live-сессия команды.
2. Live-поле с движущимися точками игроков.
3. Сохранение live-точек в MySQL.
4. Расчёт по точкам:
   - скорость;
   - дистанция;
   - скоростная зона;
   - спринтовая зона;
   - GPS Load Score;
   - координаты `field_x_m / field_y_m`.
5. Привязка к игроку:
   - если игрок выбран в шапке — сессия пишется на него;
   - если игрок не выбран — сервер ищет владельца по `tracker_devices.device_uuid + team_id`.

## Два режима Live

### 1. Телефон GPS

Это рабочий режим для проверки:
- тренер выбирает игрока;
- нажимает Live → Телефон → Старт;
- телефон отдаёт координаты каждую секунду;
- точка появляется на поле;
- данные сохраняются в `tracker_live_sessions` и `tracker_live_points`.

Этот режим нужен, чтобы проверить поле, сервер, таблицы, визуализацию и расчёты без трекера.

### 2. Трекер, экспериментальный

В APK найдены функции:
- `SendCurrentGPSOrder`;
- `SendCurrentGPSOrderByPhone`;
- `GetCurrentGPS`.

Но байтовая команда текущего GPS зависит от прошивки. Поэтому в архиве добавлен диагностический режим:
- Live → Трекер;
- выбор команды-кандидата;
- отправка команды каждую секунду;
- если трекер отвечает GPS-пакетами `0x33 / 0x43 / 0x44 / 0x45`, экран сохраняет их как Live-точки.

Если на реальном устройстве в логах видны другие RX-пакеты, нужно прислать RX hex — по ним добавляется точный parser current GPS.

## Новые Flutter-файлы

```text
lib/presentation/tracker/tracker_live_panel.dart
lib/presentation/tracker/models/tracker_live_models.dart
lib/presentation/tracker/services/tracker_live_api.dart
lib/presentation/tracker/widgets/tracker_live_field_painter.dart
```

Обновлены:

```text
lib/presentation/tracker/sportoteka_tracker_pro_screen.dart
lib/presentation/tracker/services/action_tracker_ble_service.dart
lib/presentation/tracker/models/action_tracker_protocol.dart
```

## Новые PHP API

```text
api/tracker/start_tracker_live_session.php
api/tracker/save_tracker_live_point.php
api/tracker/get_tracker_live_state.php
api/tracker/stop_tracker_live_session.php
```

## Новые таблицы

```text
tracker_live_sessions
tracker_live_points
```

SQL:

```text
sql/sportoteka_tracker_live.sql
```

Также этот SQL добавлен в общий:

```text
sql/sportoteka_tracker_full.sql
```

## Важно

Это уже полноценный Live-слой для сервера и интерфейса.

Но прямой Live именно от трекера станет полностью рабочим после проверки команды текущего GPS на реальном устройстве. Пока в архиве есть:
- рабочий Live через телефон GPS;
- экспериментальный Live через BLE-команды-кандидаты;
- сохранение и визуализация live-точек.
