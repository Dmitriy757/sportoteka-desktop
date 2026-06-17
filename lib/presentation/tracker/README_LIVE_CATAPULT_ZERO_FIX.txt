Sportoteka Tracker Live — Catapult online zero fix

Что исправлено:
1. Убрана верхняя синяя операторская панель Live Center / Analytics / Quality Control / Process / System из layout.
2. На desktop/tablet поле вынесено вправо и получает больше места; слева оставлены активные игроки, таблица и онлайн-аналитика.
3. Развёрнутые окна теперь обновляются сами каждые 500 мс — поле/таблица/игроки не требуют ручного обновления.
4. Активные игроки и командная таблица больше не ждут только сервер: они берут свежие локальные runtime-метрики трекера и подмешивают их поверх server state.
5. HIR / VHIR / SPR / ACC / DEC / COD больше не залипают в нулях, если сервер вернул только speed/max/distance: Flutter показывает локальные расчёты, а при отсутствии зон на сервере — live-оценку по distance + max speed.
6. Пороги зон для live стали мягче: HIR от 10.8 км/ч, VHIR от 16.2 км/ч, Sprint от 22 км/ч; ACC/DEC считаются от ±1.2 м/с².
7. TrackerLiveSessionModel теперь читает метрики из analysis_json / analysis / metrics / zones / football_movement_profile, включая строковый JSON.
8. Перед остановкой Live сохраняется metric snapshot с HIR/VHIR/COD/metabolic и дополнительно создаётся финальная сессия через save_tracker_session.php по локальным точкам.

Файлы для замены:
- tracker/tracker_live_panel.dart
- tracker/models/tracker_live_models.dart
- tracker/services/tracker_live_api.dart

Важно:
Если после перезапуска приложения сервер всё равно возвращает старые нули, значит PHP save_tracker_live_point.php/get_tracker_live_state.php не сохраняют новые поля. В этом пакете UI уже показывает локальные онлайн-метрики сразу, но серверные таблицы после перезагрузки зависят от PHP.
