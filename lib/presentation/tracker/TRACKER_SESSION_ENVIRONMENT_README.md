# Координаты, город и погода для Tracker Live

## Что добавлено

- `player_update_session_environment.php` — принимает координаты телефона/планшета.
- `tracker_session_environment_lib.php` — хранение, reverse geocoding и погода.
- `MIGRATION_TRACKER_SESSION_ENVIRONMENT.sql` — безопасная миграция через две новые таблицы.
- Live, завершённые сессии и уведомления возвращают сохранённые место и температуру.

## Безопасность базы

Миграция **не изменяет** `tracker_sessions`, `tracker_live_sessions`, GPS-точки или таблицу пульса. Создаются только:

- `tracker_session_environment` — одна строка на Live/завершённую сессию;
- `tracker_environment_cache` — кеш города и погоды по округлённым координатам.

## Запрос Flutter

```json
POST /api/tracker/player_update_session_environment.php
{
  "live_session_id": 123,
  "latitude": 52.4345,
  "longitude": 30.9754,
  "accuracy_m": 8.5,
  "captured_at": "2026-07-14T12:55:00+03:00"
}
```

Отправлять при старте, затем не чаще одного раза в 10 минут или после перемещения более чем на 300 м. Сервер дополнительно сам отклоняет слишком частое обновление.

## Источники

- город/место: Nominatim/OpenStreetMap;
- температура: Open-Meteo.

Для Nominatim желательно задать переменную окружения:

```bash
SPORTOTEKA_GEOCODING_EMAIL=admin@sportotekaapp.ru
```

Внешняя ошибка не останавливает Live: координаты сохраняются, а место/температура могут остаться пустыми до следующего обновления.
