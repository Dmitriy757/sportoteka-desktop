# Sportoteka 3D Pro V16.1 — compile hotfix

Исправлена ошибка компиляции Unity в `Sportoteka3DProEditorController.cs`:

- восстановлен helper `TypeToIconKey(string type)`;
- восстановлен helper `TypeTitle(string type)`;
- восстановлен helper `DistanceText(Sportoteka3DProPlanItem item)`;
- восстановлен helper `LayerItemTitle(Sportoteka3DProPlanItem item, int number)`;
- восстановлен метод `DeleteItem(string id)` для удаления строки из вкладки «Слои»;
- обновлён debug-log версии на `V16_PRO_INSPECTOR_LIBRARY_HOTFIX`.

Причина: при сборке V16 новые UI-вызовы инспектора и слоёв ссылались на helper-методы из V15, но сами методы не попали в итоговый файл.
