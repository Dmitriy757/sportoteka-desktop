# Training Graphics v8.1 — compile fix

Исправлена ошибка `_border isn't defined for _ObjectPanelContentState` в `widgets/tg_right_panel.dart`.

- `_border` добавлен как `Colors.transparent`.
- Обычные CMR/Tracker-баннеры остаются без серых обводок.
- Зелёная граница остаётся только у выбранного/активного элемента.
- Остальная логика v8 не изменялась.
