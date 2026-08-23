SPORTOTEKA TRACKER — TEAM LIVE V59

Исправления:
1. Командный Live больше не записывает status='superseded'.
   В рабочей MySQL-таблице status является ENUM без такого значения,
   поэтому сервер возвращал Warning 1265 и откатывал запуск всей команды.
2. Предыдущая активная строка закрывается штатным status='finished'.
3. Для $ATP/$ACT/$GPS закрываются также MAC/iOS-алиасы по имени
   физического трекера.
4. Личный Live не изменён.

Обновить на сервере:
- start_team_tracker_live_sessions.php
- start_tracker_live_session.php

SQL запускать не требуется.
