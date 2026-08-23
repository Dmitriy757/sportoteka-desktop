TRACKER V142 — МОИ ТРЕНИРОВКИ: ИИ + ЕДИНЫЕ KPI
Дата: 2026-08-16

Что исправлено
1. СПОРТОТЕКА ИИ в «Мои тренировки» больше не блокируется только из-за отсутствующего clubId.
   - Для личного отчёта обязательны валидные userId + teamId.
   - clubId берётся из параметра экрана, затем из отчёта/сессии; при отсутствии в старом маршруте ассистент открывается с 0, как и в CMR.
   - club_id теперь сохраняется в TrackerTrainingReport и не теряется при фильтрации/объединении отчётов.

2. В личном экране добавлено восстановление clubId из загруженных персональных сессий.
   Поддержаны ключи: club_id, clubId, team_club_id, teamClubId.
   Восстановленный id используется для аналитики, Live-сессии, GPS и Polar H10.

3. KPI во всех основных мобильных разделах аналитики приведены к KPI вкладки «Тренировка»:
   - фон #F5F7F5;
   - radius 12;
   - padding 8x5;
   - иконка 26x26, radius 9, icon 14.5;
   - заголовок 8.9 / w500;
   - значение 12.8 / w600;
   - единица 8.9 / w500;
   - табличные цифры для значений;
   - сетка: 2 колонки до 520px, 3 колонки от 520px;
   - gap 7;
   - aspect ratio 2.72 / 2.48.

4. Разделы Обзор / Карта / Скорость / Пульс / Команда / Рейтинги используют одинаковый горизонтальный отступ 8px, чтобы ширина баннеров не прыгала между вкладками.

Изменённые файлы
- tracker/player/player_my_trainings_screen.dart
- tracker/player_my_trainings_screen.dart
- tracker/widgets/tracker_action_analytics_suite.dart
- tracker/reports/tracker_training_report_models.dart
- tracker/reports/tracker_training_report_api.dart
- tracker/reports/tracker_training_report_screen.dart

Примечание
В контейнере нет Flutter/Dart SDK, поэтому flutter analyze/build здесь не запускался. Изменения проверены по структуре кода и сравнением с исходным архивом.
