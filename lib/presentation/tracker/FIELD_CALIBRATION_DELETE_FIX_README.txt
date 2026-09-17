СПОРТОТЕКА — FIELD CALIBRATION / NEW FIELD / DELETE FIX

Исправлено в Flutter:
- старые сохранённые поля остаются доступны и выбираются по id;
- новое поле создаётся отдельным черновиком и не заменяет старое по совпадению названия;
- перекалибровка сохраняет признак is_default выбранного поля вместо принудительного is_default=true;
- добавлено настоящее удаление поля через delete_tracker_field.php;
- удаление недоступно во время активной Live-сессии;
- для несохранённого нового поля кнопка удаления просто отменяет черновик;
- кнопка удаления добавлена и в мобильный интерфейс;
- ответ save_tracker_field.php разбирается устойчиво для нескольких форматов JSON.

Сервер:
Папка SERVER_API_FIELD_FIX содержит три готовых PHP-файла.
Загрузить их в /var/www/api/tracker/:
- get_tracker_fields.php (заменить)
- save_tracker_field.php (заменить)
- delete_tracker_field.php (добавить)

Удаление — мягкое. При первом удалении сервер добавит tracker_fields.is_archived.
Старые тренировки и GPS/Live-данные физически не удаляются.

BUILD FIX 2026-09-14 v2
- Restored _clearSelectedField(), which is still used by TrackerActionAnalyticsSuite.
- Kept _deleteSelectedField() as a separate action for actual field archival/deletion.
- Fixes Flutter build error: getter '_clearSelectedField' isn't defined.
