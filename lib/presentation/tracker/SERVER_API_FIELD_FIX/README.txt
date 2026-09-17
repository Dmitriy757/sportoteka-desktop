СПОРТОТЕКА — FIX ПОЛЕ / КАЛИБРОВКА / УДАЛЕНИЕ

На сервер в /var/www/api/tracker/ загрузить (с заменой):
1) get_tracker_fields.php
2) save_tracker_field.php
3) delete_tracker_field.php (новый файл)

Удаление сделано безопасно как архивирование. При первом удалении endpoint сам добавит
tracker_fields.is_archived TINYINT(1) DEFAULT 0. Старые сессии и их field_id не удаляются.

После загрузки PHP можно проверить:
  php -l get_tracker_fields.php
  php -l save_tracker_field.php
  php -l delete_tracker_field.php
