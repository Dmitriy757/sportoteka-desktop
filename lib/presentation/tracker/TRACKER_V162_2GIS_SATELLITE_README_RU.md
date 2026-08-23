# Спортотека V162 — 2ГИС и спутник в Live и аналитике

## Что добавлено

- общий переключатель `Поле / 2ГИС / Спутник` в расширенной Live-карте и аналитике;
- реальные маршруты, текущая позиция, скорость, имя и фото игрока берутся из существующих объектов архива и Live, без тестовых координат;
- курсор аналитики двигает маркеры игроков по времени сохранённой записи;
- в Live WebView получает обновления не чаще одного раза в 160 мс, поэтому сбор BLE/GPS и серверная запись не меняются;
- 2D/3D управляет наклоном 2ГИС, а на обычном поле сохраняет старую камеру;
- «Разбор / стоп-кадр» блокирует перемещение карты и оставляет инструменты рисования поверх зафиксированного кадра;
- если ключ или спутниковый источник не настроены, приложение не падает: `Поле` остаётся доступным, а карта показывает понятный статус.

## Куда положить файлы

- `tracker/widgets/tracker_2gis_map_layer.dart` → `lib/.../tracker/widgets/`
- обновлённые `tracker_live_panel.dart` и `tracker_action_analytics_suite.dart` → в их текущие места проекта;
- добавьте зависимость из `PUBSPEC_V162_2GIS_SNIPPET.yaml` в существующий `pubspec.yaml`, затем выполните `flutter pub get`.

## Как получить ключ 2ГИС

1. Откройте Platform Manager: <https://platform.2gis.ru/>
2. Создайте demo key или подписку для Map Tiles API / MapGL JS.
3. Не вставляйте ключ в Dart-файлы. Передавайте его при запуске или сборке:

```bash
flutter run -d macos \
  --dart-define=DGIS_MAPGL_KEY=ВАШ_КЛЮЧ
```

Для iOS используется тот же параметр:

```bash
flutter run -d ios \
  --dart-define=DGIS_MAPGL_KEY=ВАШ_КЛЮЧ
```

`dart-define` убирает ключ из репозитория, но ключ клиентской карты всё равно попадает в приложение. Ограничьте его в кабинете 2ГИС по доступным правилам и не используйте этот ключ для серверных API.

## Как включить спутник

2ГИС MapGL подключает спутниковые изображения как внешний WMTS/WMS raster source. Нужен разрешённый вашим поставщиком HTTPS URL тайлов с CORS и обязательной атрибуцией.

Шаблон WMTS:

```text
https://tiles.example.com/satellite/{z}/{x}/{y}.jpg?key=...
```

Для WMS можно использовать `{bbox}` — слой подставит границы тайла в EPSG:3857:

```text
https://maps.example.com/wms?SERVICE=WMS&REQUEST=GetMap&SRS=EPSG:3857&BBOX={bbox}&WIDTH=256&HEIGHT=256&FORMAT=image/jpeg&LAYERS=satellite
```

Запуск:

```bash
flutter run -d macos \
  --dart-define=DGIS_MAPGL_KEY=ВАШ_КЛЮЧ_2GIS \
  --dart-define=DGIS_SATELLITE_URL=https://tiles.example.com/satellite/{z}/{x}/{y}.jpg?key=КЛЮЧ_СНИМКОВ \
  --dart-define=DGIS_SATELLITE_ATTRIBUTION="Название поставщика"
```

Без `DGIS_SATELLITE_URL` пункт «Спутник» остаётся в интерфейсе и показывает карту 2ГИС с сообщением, что источник снимков ещё не задан.

## macOS

Если Runner использует App Sandbox, добавьте `com.apple.security.network.client = true` в `DebugProfile.entitlements` и `Release.entitlements`. Готовый фрагмент лежит в `MACOS_V162_2GIS_ENTITLEMENTS_SNIPPET.plist`.

## Важно при встраивании

- Минимальная версия `webview_flutter` для macOS — ветка 4.9.x.
- iOS 15.6 проекта выше минимального требования WebView.
- Слой использует официальный `https://mapgl.2gis.com/api/js/v1`.
- Спутниковый URL и его лицензия выбираются отдельно; в архив намеренно не вшит сторонний бесплатный сервер.
- Для полной географической привязки рисунков к координатам карта фиксируется в режиме разбора. В обычном Live карта остаётся интерактивной.

## Изменённые файлы V162

- `tracker/widgets/tracker_2gis_map_layer.dart` — общий слой MapGL, маршруты, маркеры, спутниковый raster source, состояния настройки;
- `tracker/tracker_live_panel.dart` — реальные Live-треки и переключатель подложки;
- `tracker/widgets/tracker_action_analytics_suite.dart` — архивные GPS-точки, курсор повтора и переключатель подложки;
- `PUBSPEC_V162_2GIS_SNIPPET.yaml` — зависимость WebView;
- `MACOS_V162_2GIS_ENTITLEMENTS_SNIPPET.plist` — доступ Runner к сети в App Sandbox.
