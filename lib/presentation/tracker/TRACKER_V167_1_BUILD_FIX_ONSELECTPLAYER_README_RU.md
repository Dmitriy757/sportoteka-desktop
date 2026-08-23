# SPORTOTEKA Tracker V167.1 — build fix `onSelectPlayer`

Исправлена ошибка сборки:

```text
tracker_match_workspace_screen.dart:6531:13:
Error: No named parameter with the name 'onSelectPlayer'.
```

## Причина

`tracker_match_workspace_screen.dart` из V167 передавал `onSelectPlayer` в
`PlayerTrainingNotificationsPanel`. В полной версии V167 этот callback уже был
добавлен в конструктор панели, но если в проекте остался предыдущий файл
`player_training_notifications_panel.dart`, его конструктор такого параметра не
имеет. В результате получалась несовместимость между двумя версиями файлов.

## Исправление

В workspace убрана зависимость от нового named parameter. Теперь вызов
`PlayerTrainingNotificationsPanel` совместим как со старой, так и с новой
версией виджета.

Двухблочная CMR-компоновка V167, Auto Recovery и Live Priority не менялись.
