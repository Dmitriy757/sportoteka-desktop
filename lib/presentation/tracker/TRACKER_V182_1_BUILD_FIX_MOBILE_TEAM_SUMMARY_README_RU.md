# TRACKER V182.1 — BUILD FIX

Исправлена ошибка сборки в `tracker_action_analytics_suite.dart`:

`_MobileTeamSummaryCard` после редизайна V182 требует параметры:
- `selectedSession`
- `local`
- `rows`

В мобильном командном разделе один старый вызов карточки не был обновлён. Теперь туда передаются текущие `selectedSession`, `local` и `rows`.

Функциональная логика V182 и дизайн не менялись — это только исправление сборки.
