# Оповещения ИИ по личной нагрузке

ИИ-помощник раз в 30 секунд проверяет `player_get_training_notifications.php`.
Сигнал создаётся при `heart_rate_bpm/max_bpm >= 160` или `load_score >= 80`.
В шапке ИИ отображается счётчик непрочитанных сигналов. Карточка сигнала содержит `player_id`, `session_id`, `team_id` и открывает target `report` через `onNavigate`.
