TRACKER V144 — PERSONAL REPORT CONNECTION FIX

Проблема:
В «Мои тренировки» разделы отчёта/СПОРТОТЕКА ИИ открывали командный
get_training_report.php даже для личной сессии игрока. На production endpoint
мог закрыть соединение до HTTP-заголовков (ClientException: Connection closed
before full header was received), поэтому вместо ИИ появлялась ошибка.

Исправлено:
1. Для personalSessionMode отчёт больше НЕ зависит от get_training_report.php.
2. Личный отчёт собирается из тех же player_* источников, которые уже питают
   экран «Мои тренировки»:
   - player_get_sessions.php
   - player_get_session_points.php
   - get_tracker_heart_rate_summary.php (Polar, опционально)
3. Из личной сессии формируется проверенная TrackerTrainingReport-сводка:
   дистанция, длительность, средняя/макс. скорость, спринты,
   ускорения/торможения, нагрузка, GPS-точки и ЧСС.
4. Personal mode передаётся не только в ИИ, но и в личные разделы
   Локомоторика / Механика / Микроцикл / Отчёт.
5. Командная аналитика оставлена на старом report endpoint; добавлены лёгкие
   fallback-запросы без тяжёлых charts/maps на случай перегрузки PHP.
6. Тренерский журнал в личном ИИ остаётся отключённым (из V143).

Изменённые файлы:
- tracker/reports/tracker_training_report_api.dart
- tracker/reports/tracker_training_report_screen.dart
- tracker/widgets/tracker_action_analytics_suite.dart

Проверка в этом окружении:
- структура Dart-скобок проверена;
- ZIP проверен после упаковки;
- Flutter/Dart SDK в контейнере отсутствует, поэтому flutter analyze здесь
  запустить невозможно.
