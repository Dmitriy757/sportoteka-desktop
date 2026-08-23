-- SPORTOTEKA: только диагностика, запросы ничего не изменяют.
-- Команда: club_id=164, team_id=40.

-- 1. Все сохранённые устройства команды.
SELECT
    id, club_id, team_id, player_id,
    device_uuid, device_name, device_type,
    battery_percent, is_nearby, status,
    created_at, updated_at
FROM tracker_devices
WHERE club_id = 164 AND team_id = 40
ORDER BY updated_at DESC, id DESC;

-- 2. Реальные владельцы устройств с ФИО.
SELECT
    d.id,
    d.player_id,
    CONCAT_WS(' ', u.first_name, u.last_name) AS player_name,
    d.device_uuid,
    d.device_name,
    d.status,
    d.updated_at
FROM tracker_devices d
LEFT JOIN players p ON p.id = d.player_id
LEFT JOIN users u ON u.id = p.user_id
WHERE d.club_id = 164 AND d.team_id = 40
ORDER BY d.player_id IS NULL, player_name, d.device_name;

-- 3. MAC/iOS UUID-алиасы одного физического GPS по одинаковому имени.
SELECT
    UPPER(TRIM(device_name)) AS normalized_name,
    COUNT(*) AS rows_count,
    GROUP_CONCAT(id ORDER BY id) AS row_ids,
    GROUP_CONCAT(device_uuid ORDER BY id SEPARATOR ' | ') AS uuids,
    GROUP_CONCAT(COALESCE(player_id, 'NULL') ORDER BY id SEPARATOR ' | ') AS player_ids
FROM tracker_devices
WHERE club_id = 164 AND team_id = 40
  AND status = 'active'
GROUP BY UPPER(TRIM(device_name))
HAVING COUNT(*) > 1
ORDER BY rows_count DESC, normalized_name;

-- 4. Ошибка привязок: одному игроку назначено больше одного физического GPS.
-- Polar исключён по имени, поскольку device_type в этой старой таблице
-- является служебным/legacy-полем и сейчас не разделяет GPS и H10.
SELECT
    player_id,
    COUNT(DISTINCT UPPER(TRIM(device_name))) AS gps_count,
    GROUP_CONCAT(DISTINCT device_name ORDER BY device_name SEPARATOR ' | ') AS gps_devices
FROM tracker_devices
WHERE club_id = 164 AND team_id = 40
  AND status = 'active'
  AND player_id IS NOT NULL
  AND LOWER(CONCAT(COALESCE(device_name, ''), ' ', COALESCE(device_uuid, '')))
      NOT REGEXP 'polar|h10|heart|hrm'
GROUP BY player_id
HAVING COUNT(DISTINCT UPPER(TRIM(device_name))) > 1;

-- 5. Ошибка владельцев: один физический GPS имеет разных игроков в MAC/UUID-алиасах.
SELECT
    UPPER(TRIM(device_name)) AS normalized_name,
    COUNT(DISTINCT player_id) AS owners_count,
    GROUP_CONCAT(DISTINCT player_id ORDER BY player_id) AS player_ids,
    GROUP_CONCAT(device_uuid ORDER BY id SEPARATOR ' | ') AS uuids
FROM tracker_devices
WHERE club_id = 164 AND team_id = 40
  AND status = 'active'
  AND player_id IS NOT NULL
  AND LOWER(CONCAT(COALESCE(device_name, ''), ' ', COALESCE(device_uuid, '')))
      NOT REGEXP 'polar|h10|heart|hrm'
GROUP BY UPPER(TRIM(device_name))
HAVING COUNT(DISTINCT player_id) > 1;

-- 6. Активные командные Live-сессии. После остановки здесь не должно
-- оставаться старых status='active'.
SELECT
    id, club_id, team_id, player_id, field_id,
    device_uuid, device_name, source, status,
    battery_percent, activity_type,
    started_at, last_seen_at, stopped_at, final_session_id
FROM tracker_live_sessions
WHERE club_id = 164 AND team_id = 40
  AND status = 'active'
ORDER BY started_at DESC, id DESC;

-- 7. Дубли активного Live для одного игрока или устройства.
SELECT
    player_id,
    COUNT(*) AS active_rows,
    GROUP_CONCAT(id ORDER BY id DESC) AS live_ids,
    GROUP_CONCAT(device_name ORDER BY id DESC SEPARATOR ' | ') AS devices
FROM tracker_live_sessions
WHERE club_id = 164 AND team_id = 40
  AND status = 'active'
  AND COALESCE(personal_session, 0) = 0
GROUP BY player_id
HAVING COUNT(*) > 1;

SELECT
    device_uuid,
    COUNT(*) AS active_rows,
    GROUP_CONCAT(id ORDER BY id DESC) AS live_ids,
    GROUP_CONCAT(COALESCE(player_id, 'NULL') ORDER BY id DESC) AS player_ids
FROM tracker_live_sessions
WHERE club_id = 164 AND team_id = 40
  AND status = 'active'
GROUP BY device_uuid
HAVING COUNT(*) > 1;

-- 8. Последние командные BLE-логи. В исправленной версии источник
-- workspace_team_ble_log показывает отдельные каналы каждого UUID.
SELECT
    id, created_at, level, source,
    player_id, live_session_id,
    device_uuid, device_name, message
FROM tracker_debug_logs
WHERE team_id = 40
  AND (
      source LIKE '%team_ble%'
      OR source LIKE '%team_live%'
      OR source LIKE '%workspace_ble%'
  )
ORDER BY id DESC
LIMIT 150;

-- 9. Проверка игроков, которые фигурировали в предыдущих тестах.
SELECT p.*, u.first_name, u.last_name, u.email
FROM players p
LEFT JOIN users u ON u.id = p.user_id
WHERE p.id IN (79, 87);

-- Если какой-то SELECT сообщает Unknown column, сначала пришлите структуру:
SHOW CREATE TABLE tracker_devices;
SHOW CREATE TABLE tracker_live_sessions;
SHOW CREATE TABLE tracker_debug_logs;
