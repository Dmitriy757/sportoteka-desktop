# ИИ-паспорт нагрузки — контракт данных

Интерфейс уже рассчитывает на клиенте интервалы Z4–Z5, восстановление через 30/60/120 секунд, первичную оценку риска и индекс готовности.

Для полной персонализации серверу желательно вернуть для каждой HR-точки:
- player_id, session_id, measured_at/time_ms, bpm, activity_type;
- latitude, longitude или связь с GPS-точкой той же временной шкалы;
- speed_kmh, sprint_flag;
- personal_hr_max или birth_date/age;
- baseline_avg_bpm, baseline_recovery_60, previous_session_load.

Для ИИ-чата рекомендуется endpoint уведомлений с полями:
- player_id, session_id, alert_type, severity, title, message;
- peak_time_ms, peak_bpm, recovery_60;
- report_deep_link / analytics_deep_link.
