СПОРТОТЕКА Tracker V83 — исправление старых 42 км/ч в базе

Что обнаружено в дампе 2026-08-12
----------------------------------
Новый Live уже не хранит max_speed >= 36 км/ч, но старые значения остались в
tracker_session_metrics. В дампе повреждены как минимум сессии 15, 16, 17,
19, 20, 21 (player_id=79, tracker $ATP-C1074, 14–15 июня 2026).

Пример причины: debug-лог содержит raw speed 695 / 108 / 102 км/ч, а старый
код превращал невозможный GPS-скачок в ровно 42 км/ч. Поэтому 42 — это старый
потолок/clamp, а не реальная скорость игрока.

Почему V82 SQL было недостаточно
--------------------------------
REPAIR_SPEED_SPIKES_V82.sql не обновлял tracker_session_metrics. Поэтому
Аналитика/ИИ, если читали legacy-метрики, могли продолжать видеть 42.

Что делает V83
--------------
repair_tracker_corrupted_sessions_v83.php:
1. Находит подозрительные legacy-метрики автоматически.
2. В dry-run ничего не изменяет.
3. При --apply делает backup tracker_session_metrics_backup_v83.
4. Пересчитывает GPS по исходным координатам.
5. Значения <1.5 км/ч, дрожание <=0.35 м и >36 км/ч полностью исключаются.
6. Не обрезает 42 до 36 — выброс отбрасывается.
7. Пересчитывает tracker_session_metrics и tracker_sessions.
8. Если есть tracker_session_summary — обновляет и его.

Запуск
------
cd /var/www/<путь-к-api>/tracker
php repair_tracker_corrupted_sessions_v83.php

Проверь список. Затем:
php repair_tracker_corrupted_sessions_v83.php --apply

После выполнения проверка:
SELECT session_id, player_id, distance_m, avg_speed_kmh, max_speed_kmh,
       high_speed_distance_m, sprint_distance_m, sprint_count, load_score
FROM tracker_session_metrics
WHERE max_speed_kmh > 36 OR avg_speed_kmh > 36
ORDER BY session_id;

Запрос должен вернуть 0 строк.
