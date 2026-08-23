# V193 — build fix MobileMapDashboard

Исправлена ошибка сборки после V192:
- `inspectorDistance` в `_MobileMapDashboardState` заменён на `local.distanceM`;
- `inspectorSprintCount` заменён на `local.sprintCount`;
- переменные `inspector*` сохранены только в полном повторе матча, где они объявлены и используются для KPI по позиции таймлайна.
