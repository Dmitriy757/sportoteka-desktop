# Sportoteka Tracker Full Function Pack

Этот пакет возвращает полный набор функций после изменения дизайна:

## Flutter
Заменить файлы:

```text
lib/presentation/tracker/sportoteka_tracker_pro_screen.dart
lib/presentation/tracker/tracker_live_panel.dart
lib/presentation/tracker/models/action_tracker_protocol.dart
lib/presentation/tracker/models/tracker_live_models.dart
lib/presentation/tracker/models/tracker_pro_models.dart
lib/presentation/tracker/models/tracker_pitch_projection.dart
lib/presentation/tracker/services/action_tracker_ble_service.dart
lib/presentation/tracker/services/tracker_live_api.dart
lib/presentation/tracker/services/tracker_pro_api.dart
lib/presentation/tracker/services/tracker_permissions.dart
lib/presentation/tracker/widgets/tracker_field_painter.dart
lib/presentation/tracker/widgets/tracker_heatmap_painter.dart
lib/presentation/tracker/widgets/tracker_live_field_painter.dart
```

## Что восстановлено

```text
1. Подключение BLE-трекера.
2. Live-панель с векторами, треком, тепловым слоем и debug.
3. Сессии и сохранение GPS-записей с трекера.
4. Аналитика команды/игроков.
5. Тепловая карта.
6. Поля команды и калибровка.
7. Управление привязкой трекеров к игрокам.
8. Настройки порогов скорости.
```

## Server

Загрузить PHP из папки:

```text
api/tracker/
```

Выполнить SQL из папки:

```text
sql/
```

Особенно важно выполнить SQL для `time_ms BIGINT`, иначе при остановке Live будет ошибка:

```text
Numeric value out of range for column 'time_ms'
```

## Проверка Live

1. Во вкладке `Подключение` подключить трекер.
2. Во вкладке `Live` выбрать `Трекер`.
3. Команда должна быть `Кандидат 1: 3A`.
4. Нажать `Старт Live`.
5. Если RX показывает `3B 00 00 00...`, трекер пока не отдаёт GPS-фикс.
6. Кнопка `Debug: добавить тестовую точку` проверяет UI без трекера.
