# Live GPS 0x3A / 0x3B

По реальным логам трекера найден рабочий live-запрос:

```text
TX 3A
RX 3B 01 A2 D2 03 14 EE 15 62 0D 24 1E 20 02
```

Расшифровка пакета `0x3B`:

```text
byte 0      = 0x3B, тип пакета current GPS
byte 1      = статус/номер
byte 2..5   = latitude int32 little endian / 6000000
byte 6..9   = longitude int32 little endian / 6000000
byte 10..13 = time_ms uint32 little endian
```

Пример:

```text
A2 D2 03 14 -> 55.965808
EE 15 62 0D -> 37.421992
24 1E 20 02 -> 35659300 ms
```

Что изменено:

```text
lib/presentation/tracker/models/action_tracker_protocol.dart
lib/presentation/tracker/tracker_live_panel.dart
```

Теперь в Live:
1. кандидат 1 = `3A`;
2. ответ `3B` парсится как текущая GPS-точка;
3. точка сохраняется в `tracker_live_points`;
4. скорость/дистанция начинают расти после движения;
5. игрок должен перейти из `ЖДЁМ GPS` в `LIVE`.
