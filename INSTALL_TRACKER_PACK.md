# Установка Sportoteka Tracker Full Function Pack

1. Скопировать `lib/presentation/tracker/...` в Flutter-проект.
2. Загрузить `api/tracker/*.php` на сервер в `public_html/api/tracker/`.
3. Выполнить SQL из папки `sql` в phpMyAdmin.
4. Запустить:

```bash
flutter clean
flutter pub get
flutter run
```

Если Live не стартует — сначала открыть в браузере:

```text
https://sportotekaapp.ru/api/tracker/ping_tracker.php
```
