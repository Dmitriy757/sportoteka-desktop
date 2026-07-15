# Режим личной тренировки: запись на сервер

Polar H10 не определяет тип тренировки. Игрок выбирает режим до старта в кабинете.

Flutter уже передаёт `activity_type`:

- при старте личной Live-сессии;
- при heartbeat;
- при сохранении GPS-точек;
- при сохранении Polar HR-точек.

Поддерживаемые значения интерфейса:

- `football_field` — Поле;
- `outdoor_run` — Бег;
- `indoor_gym` — Зал;
- `strength` — Сила;
- `polar_only` — Только Polar.

На PHP при старте нужно записать значение в строку сессии:

```sql
ALTER TABLE tracker_live_sessions
  ADD COLUMN activity_type VARCHAR(32) NULL AFTER status;
```

Пример сохранения:

```php
$activityType = trim((string)($input['activity_type'] ?? 'football_field'));
$allowed = ['football_field', 'outdoor_run', 'indoor_gym', 'strength', 'polar_only'];
if (!in_array($activityType, $allowed, true)) {
    $activityType = 'football_field';
}
```

Для Polar-точек необязательно дублировать режим в каждой строке: аналитика может получать его через `live_session_id` и `tracker_live_sessions.activity_type`. Но дублирование допустимо, если таблица HR уже содержит `activity_type`.

API аналитики должен возвращать для каждой точки или сессии:

```json
{
  "live_session_id": 206,
  "activity_type": "outdoor_run",
  "bpm": 171,
  "measured_at": "2026-07-11 15:31:20"
}
```
