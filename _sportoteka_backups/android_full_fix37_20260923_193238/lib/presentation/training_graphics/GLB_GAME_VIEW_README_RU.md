# Sportoteka Training Graphics — GLB Game View

Эта версия переводит Game View с ручного CustomPainter/pseudo-3D на настоящий 3D renderer `three_js`.

## Что используется

- `assets/training/3d/stadium_field_only.glb` — основной Game View (поле, ворота и окружение без тяжёлых трибун).
- `assets/training/3d/stadium_full.glb` — исходная полная модель оставлена как резерв для дальнейших экспериментов.
- `three_js: ^0.0.7` — добавлен в `pubspec.yaml`.
- В `flutter.assets` добавлена папка `assets/training/3d/`.

## Архитектура

Графический редактор остаётся единственным источником данных (`TgState`). Game View не создаёт второй документ.
Координаты редактора 1050×680 переводятся в реальные координаты футбольного поля 105×68 м внутри GLB.

В Game View уже переносятся:

- игроки (объёмные low-poly фигуры из примитивов);
- мяч;
- конусы;
- манекены;
- обычные линии;
- polyline;
- curve;
- контур zone;
- анимационные позиции игроков/мяча.

## Камеры

- ТВ
- Тренер
- Тактика
- Низкий
- Обзор

Камера управляется OrbitControls: мышь/палец — вращение, колесо/щипок — масштаб.

## Установка

1. Заменить `lib/presentation/training_graphics/` папкой из архива.
2. Скопировать `assets/training/3d/` в проект.
3. Слить изменения из вложенного `pubspec.yaml` или заменить им актуальный pubspec, если он не менялся после переданного варианта.
4. Выполнить:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run -d macos
```

## Важно

`three_js 0.3.0` требует Dart >= 3.3. Сам pubspec проекта допускает Dart >= 3.1, поэтому если фактический Flutter SDK старый и несёт Dart < 3.3, нужно сначала обновить Flutter SDK. На современном Flutter дополнительная правка environment не требуется.
