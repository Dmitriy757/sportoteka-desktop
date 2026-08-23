-- 1. Гарантируем правильную классификацию личных HR-точек
UPDATE tracker_heart_rate_samples h
JOIN tracker_live_sessions l ON l.id = h.live_session_id
SET h.personal_session = 1,
    h.owner_user_id = COALESCE(h.owner_user_id, l.owner_user_id),
    h.player_id = COALESCE(h.player_id, l.player_id),
    h.activity_type = COALESCE(NULLIF(h.activity_type,''), l.activity_type)
WHERE l.personal_session = 1;

-- 2. Привязываем HR-точки к итоговым личным сессиям
UPDATE tracker_heart_rate_samples h
JOIN tracker_live_sessions l ON l.id = h.live_session_id
SET h.session_id = COALESCE(h.session_id, l.final_session_id)
WHERE l.personal_session = 1
  AND l.final_session_id IS NOT NULL;

-- 3. Исправляем классификацию итоговых сессий
UPDATE tracker_sessions s
JOIN tracker_live_sessions l ON l.id = s.live_session_id
SET s.personal_session = 1,
    s.started_by_role = 'player',
    s.owner_user_id = COALESCE(s.owner_user_id, l.owner_user_id),
    s.player_id = COALESCE(s.player_id, l.player_id),
    s.activity_type = COALESCE(NULLIF(s.activity_type,''), l.activity_type)
WHERE l.personal_session = 1;

-- 4. Пересчитываем пульс итоговых личных сессий из реально сохранённых точек
UPDATE tracker_sessions s
JOIN (
  SELECT session_id,
         COUNT(*) samples_count,
         ROUND(AVG(bpm),1) avg_bpm,
         MAX(bpm) max_bpm,
         MIN(bpm) min_bpm
  FROM tracker_heart_rate_samples
  WHERE session_id IS NOT NULL
  GROUP BY session_id
) h ON h.session_id = s.id
SET s.heart_rate_samples_count = h.samples_count,
    s.heart_rate_avg_bpm = h.avg_bpm,
    s.heart_rate_max_bpm = h.max_bpm,
    s.heart_rate_min_bpm = h.min_bpm
WHERE s.personal_session = 1;

-- 5. Закрываем Live-строки, у которых уже есть итоговая сессия
UPDATE tracker_live_sessions l
JOIN tracker_sessions s ON s.id = l.final_session_id
SET l.status = 'finished',
    l.stopped_at = COALESCE(l.stopped_at, s.stopped_at, s.finished_at),
    l.finished_at = COALESCE(l.finished_at, s.finished_at, s.stopped_at),
    l.duration_sec = GREATEST(COALESCE(l.duration_sec,0), COALESCE(s.duration_sec,0))
WHERE l.personal_session = 1;

-- Контроль
SELECT l.id live_id, l.status, l.personal_session, l.final_session_id,
       l.started_at, l.stopped_at, l.activity_type,
       s.id session_id, s.personal_session session_personal,
       s.heart_rate_samples_count, s.heart_rate_avg_bpm, s.heart_rate_max_bpm
FROM tracker_live_sessions l
LEFT JOIN tracker_sessions s ON s.id = l.final_session_id
WHERE l.personal_session = 1
ORDER BY l.id DESC
LIMIT 30;
