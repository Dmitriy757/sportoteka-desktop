# Установка Sportoteka Tracker Pro с координатами футбольного поля

Архив включает полный модуль трекера: подключение BLE, привязку к игрокам, сохранение GPS, аналитику, тепловые карты, настройки скорости и калибровку поля.

## 1. Flutter-зависимости

```bash
flutter pub add flutter_blue_plus permission_handler http
```

## 2. Файлы Flutter

Скопировать в проект:

```text
lib/presentation/tracker/
lib/presentation/club_workspace/club_workspace_screen.dart
```

В `club_workspace_screen.dart` уже добавлен раздел `Трекер`, который открывает `SportotekaTrackerProScreen` по выбранной команде.

## 3. Сервер

Загрузить папку:

```text
api/tracker/
```

на сервер:

```text
https://sportotekaapp.ru/api/tracker/
```

Файлы ожидают подключение:

```php
require_once __DIR__ . '/../db.php';
```

То есть `db.php` должен лежать в `/api/db.php` и создавать `$pdo`.

## 4. SQL

Выполнить:

```text
sql/sportoteka_tracker_full.sql
```

Добавлены таблицы:

```text
tracker_devices
tracker_speed_settings
tracker_fields
tracker_sessions
tracker_gps_points
tracker_session_metrics
tracker_player_targets
tracker_alerts
```

`tracker_fields` хранит размеры поля и 4 GPS-угла. После обработки сессии каждая GPS-точка получает:

```text
field_x_m
field_y_m
is_inside_field
```

## 5. Калибровка поля

В разделе `Трекер → Поле` нужно указать:

```text
A — левый нижний угол
B — правый нижний угол
C — правый верхний угол
D — левый верхний угол
```

A—B задаёт ось длины поля, A—D задаёт ось ширины.

После этого обработчик `process_tracker_session.php` переводит latitude/longitude в координаты поля:

```text
x = метры по длине поля
y = метры по ширине поля
```

## 6. Android/iOS permissions

Готовые фрагменты лежат в:

```text
android_snippets/AndroidManifest_permissions.xml
ios_snippets/InfoPlist_bluetooth.xml
```

## 7. Логика работы

```text
Трекер → BLE → записи → GPS-точки → сохранение → обработка → координаты поля → аналитика/тепловая карта
```

## 8. Старые сессии

Если сессия была сохранена до калибровки поля, повторно вызовите:

```text
https://sportotekaapp.ru/api/tracker/process_tracker_session.php?session_id=ID
```

Тогда для старых GPS-точек будут рассчитаны `field_x_m` и `field_y_m`.

## Обновление под текущую базу Sportoteka

В этой сборке API трекера адаптированы под структуру:

```text
players.id -> players.user_id -> users.id
users.first_name + users.last_name + users.photo
```

Если у вас уже стоят таблицы трекера из предыдущего архива, повторно выполните `sql/sportoteka_tracker_full.sql`: внизу файла теперь используется совместимая миграция через `information_schema`, без `ADD COLUMN IF NOT EXISTS`.



## Live-режим

Выполнить SQL:

```text
sql/sportoteka_tracker_live.sql
```

Загрузить PHP-файлы:

```text
api/tracker/start_tracker_live_session.php
api/tracker/save_tracker_live_point.php
api/tracker/get_tracker_live_state.php
api/tracker/stop_tracker_live_session.php
```

Подробно: `docs/TRACKER_LIVE_MODE.md`.
