-- SPORTOTEKA / командный Live v56
-- Только SELECT/SHOW: файл ничего не удаляет и не изменяет.
-- Команда ФК «Гомель» U13: club_id=164, team_id=40.

-- 1. Сначала пришлите структуру этих таблиц, если один из запросов ниже
-- сообщает Unknown column.
SHOW CREATE TABLE tracker_devices;
SHOW CREATE TABLE tracker_live_sessions;
SHOW CREATE TABLE tracker_debug_logs;

-- 2. Реальные GPS-привязки. Телефоны и Polar здесь исключены.
SELECT
    id,
    player_id,
    device_uuid,
    device_name,
    battery_percent,
    is_nearby,
    created_at,
    updated_at,
    TIMESTAMPDIFF(
        SECOND,
        COALESCE(updated_at, created_at),
        UTC_TIMESTAMP()
    ) AS device_row_age_sec
FROM tracker_devices
WHERE club_id = 164
  AND team_id = 40
  AND status = 'active'
  AND UPPER(TRIM(device_name)) REGEXP '^[$](ATP|ACT|GPS)'
ORDER BY player_id IS NULL, player_id, device_name, id;

-- 3. is_nearby=1, который давно не обновлялся. Такие строки нельзя считать
-- текущим BLE-online. В присланном дампе этот флаг стоит почти у всех устройств.
SELECT
    id,
    player_id,
    device_uuid,
    device_name,
    is_nearby,
    created_at,
    updated_at,
    TIMESTAMPDIFF(
        SECOND,
        COALESCE(updated_at, created_at),
        UTC_TIMESTAMP()
    ) AS stale_for_sec
FROM tracker_devices
WHERE club_id = 164
  AND team_id = 40
  AND status = 'active'
  AND is_nearby = 1
  AND COALESCE(updated_at, created_at) < UTC_TIMESTAMP() - INTERVAL 90 SECOND
ORDER BY stale_for_sec DESC;

-- 4. MAC/iOS UUID-алиасы одного физического трекера. У всех алиасов одного
-- имени должен быть один и тот же player_id.
SELECT
    UPPER(TRIM(device_name)) AS physical_tracker,
    COUNT(*) AS aliases_count,
    COUNT(DISTINCT player_id) AS owners_count,
    GROUP_CONCAT(id ORDER BY id SEPARATOR ' | ') AS row_ids,
    GROUP_CONCAT(device_uuid ORDER BY id SEPARATOR ' | ') AS uuids,
    GROUP_CONCAT(COALESCE(player_id, 'NULL') ORDER BY id SEPARATOR ' | ') AS player_ids
FROM tracker_devices
WHERE club_id = 164
  AND team_id = 40
  AND status = 'active'
  AND UPPER(TRIM(device_name)) REGEXP '^[$](ATP|ACT|GPS)'
GROUP BY UPPER(TRIM(device_name))
HAVING COUNT(*) > 1
ORDER BY aliases_count DESC, physical_tracker;

-- 5. Ошибка: одному игроку назначено больше одного физического GPS.
SELECT
    player_id,
    COUNT(DISTINCT UPPER(TRIM(device_name))) AS physical_gps_count,
    GROUP_CONCAT(
        DISTINCT CONCAT(device_name, ' / ', device_uuid)
        ORDER BY device_name
        SEPARATOR ' | '
    ) AS gps_devices
FROM tracker_devices
WHERE club_id = 164
  AND team_id = 40
  AND status = 'active'
  AND player_id IS NOT NULL
  AND UPPER(TRIM(device_name)) REGEXP '^[$](ATP|ACT|GPS)'
GROUP BY player_id
HAVING COUNT(DISTINCT UPPER(TRIM(device_name))) > 1;

-- 6. Все активные Live с возрастом heartbeat. age_sec > 45 или NULL означает:
-- строка зависла и не должна отображаться online.
SELECT
    id,
    player_id,
    device_uuid,
    device_name,
    source,
    status,
    COALESCE(personal_session, 0) AS personal_session,
    started_at,
    last_seen_at,
    stopped_at,
    TIMESTAMPDIFF(
        SECOND,
        COALESCE(last_seen_at, started_at),
        UTC_TIMESTAMP()
    ) AS age_sec,
    last_status_text
FROM tracker_live_sessions
WHERE club_id = 164
  AND team_id = 40
  AND status IN ('active', 'online', 'live')
ORDER BY age_sec DESC, id DESC;

-- 7. Только зависшие командные Live.
SELECT
    id,
    player_id,
    device_uuid,
    device_name,
    source,
    started_at,
    last_seen_at,
    TIMESTAMPDIFF(
        SECOND,
        COALESCE(last_seen_at, started_at),
        UTC_TIMESTAMP()
    ) AS age_sec
FROM tracker_live_sessions
WHERE club_id = 164
  AND team_id = 40
  AND status IN ('active', 'online', 'live')
  AND COALESCE(personal_session, 0) = 0
  AND (
      last_seen_at IS NULL
      OR last_seen_at < UTC_TIMESTAMP() - INTERVAL 45 SECOND
  )
ORDER BY id DESC;

-- 8. Дубли активного Live по игроку и по физическому устройству.
SELECT
    player_id,
    COUNT(*) AS live_rows,
    GROUP_CONCAT(id ORDER BY id DESC) AS live_ids,
    GROUP_CONCAT(device_name ORDER BY id DESC SEPARATOR ' | ') AS devices
FROM tracker_live_sessions
WHERE club_id = 164
  AND team_id = 40
  AND status IN ('active', 'online', 'live')
  AND COALESCE(personal_session, 0) = 0
GROUP BY player_id
HAVING COUNT(*) > 1;

SELECT
    UPPER(TRIM(device_name)) AS physical_device,
    COUNT(*) AS live_rows,
    GROUP_CONCAT(id ORDER BY id DESC) AS live_ids,
    GROUP_CONCAT(COALESCE(player_id, 'NULL') ORDER BY id DESC) AS player_ids
FROM tracker_live_sessions
WHERE club_id = 164
  AND team_id = 40
  AND status IN ('active', 'online', 'live')
GROUP BY UPPER(TRIM(device_name))
HAVING COUNT(*) > 1;

-- 9. Последние BLE-события: видны disconnect, reconnect, keep-alive и старт.
SELECT
    id,
    created_at,
    level,
    source,
    player_id,
    live_session_id,
    device_uuid,
    device_name,
    message
FROM tracker_debug_logs
WHERE team_id = 40
  AND (
      source LIKE '%team_ble%'
      OR source LIKE '%team_live%'
      OR source LIKE '%workspace_ble%'
      OR message LIKE '%вне зоны%'
      OR message LIKE '%keep-alive%'
  )
ORDER BY id DESC
LIMIT 200;
