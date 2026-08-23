-- СПОРТОТЕКА Tracker V82 — очистка уже сохранённых GPS-выбросов скорости.
-- Перед выполнением рекомендуется сделать резервную копию БД.
-- Raw-диагностику (raw_speed_kmh) не трогаем.

START TRANSACTION;

-- Финальные точки сессий: выброс >36 км/ч и дрожание <1.5 км/ч не участвуют в метриках.
UPDATE tracker_session_points
SET speed_kmh = 0,
    distance_delta_m = 0
WHERE speed_kmh IS NOT NULL
  AND (speed_kmh > 36 OR speed_kmh < 1.5);

-- Live-точки — то же правило.
UPDATE tracker_live_points
SET speed_kmh = 0,
    distance_delta_m = 0
WHERE speed_kmh IS NOT NULL
  AND (speed_kmh > 36 OR speed_kmh < 1.5);

-- Восстанавливаем max speed финальной сессии из очищенных точек.
UPDATE tracker_sessions s
LEFT JOIN (
  SELECT session_id, MAX(CASE WHEN speed_kmh BETWEEN 1.5 AND 36 THEN speed_kmh ELSE 0 END) AS clean_max
  FROM tracker_session_points
  GROUP BY session_id
) p ON p.session_id = s.id
SET s.max_speed_kmh = CASE
  WHEN p.session_id IS NOT NULL THEN COALESCE(p.clean_max, 0)
  WHEN s.max_speed_kmh > 36 THEN 0
  ELSE s.max_speed_kmh
END
WHERE s.max_speed_kmh > 36 OR p.session_id IS NOT NULL;

-- Сводная таблица, если она используется Аналитикой.
UPDATE tracker_session_summary ss
LEFT JOIN (
  SELECT session_id, player_id,
         MAX(CASE WHEN speed_kmh BETWEEN 1.5 AND 36 THEN speed_kmh ELSE 0 END) AS clean_max
  FROM tracker_session_points
  GROUP BY session_id, player_id
) p ON p.session_id = ss.session_id
   AND (p.player_id = ss.player_id OR (p.player_id IS NULL AND ss.player_id IS NULL))
SET ss.max_speed_kmh = CASE
  WHEN p.session_id IS NOT NULL THEN COALESCE(p.clean_max, 0)
  WHEN ss.max_speed_kmh > 36 THEN 0
  ELSE ss.max_speed_kmh
END
WHERE ss.max_speed_kmh > 36 OR p.session_id IS NOT NULL;

-- Live-сводка: не оставляем старый рекорд 42 даже если точка уже была очищена.
UPDATE tracker_live_sessions ls
LEFT JOIN (
  SELECT live_session_id, MAX(CASE WHEN speed_kmh BETWEEN 1.5 AND 36 THEN speed_kmh ELSE 0 END) AS clean_max
  FROM tracker_live_points
  GROUP BY live_session_id
) p ON p.live_session_id = ls.id
SET ls.max_speed_kmh = CASE
  WHEN p.live_session_id IS NOT NULL THEN COALESCE(p.clean_max, 0)
  WHEN ls.max_speed_kmh > 36 THEN 0
  ELSE ls.max_speed_kmh
END
WHERE ls.max_speed_kmh > 36 OR p.live_session_id IS NOT NULL;

COMMIT;
