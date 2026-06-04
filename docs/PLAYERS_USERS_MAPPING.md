# Связка игроков Sportoteka для модуля трекера

В этой версии API трекера адаптированы под реальную структуру базы Sportoteka.

## Таблица players

```text
id
team_id
user_id
birth_date
citizenship
sport_data
nationality
photo_url
position
jersey_number
```

## Таблица users

```text
id
first_name
last_name
email
password
role
club_name
club_description
club_address
status
access_key
created_at
photo
rating
badges
device_token
bio
position
birthday
experience
```

## Правильная связка

```text
tracker_sessions.player_id / tracker_session_metrics.player_id
        ↓
players.id
        ↓
players.user_id
        ↓
users.id
        ↓
users.first_name + users.last_name + users.photo
```

## Что исправлено

API теперь не обращается к несуществующим полям `players.first_name`, `players.last_name`, `players.name`.

Исправленные файлы:

```text
api/tracker/get_tracker_players.php
api/tracker/get_tracker_devices.php
api/tracker/get_tracker_dashboard.php
api/tracker/get_tracker_sessions.php
api/tracker/tracker_math.php
```

Также `sql/sportoteka_tracker_full.sql` теперь совместим со старыми версиями MySQL и не использует `ADD COLUMN IF NOT EXISTS`.
