# Report CMR compact + internal export viewer

Изменения:
- `TrackerTrainingReportScreen` получил `embedded: true` и больше не рисует свой Scaffold внутри CMR-окна.
- Экран отчёта стал компактнее: уменьшены header, tabs, section titles, KPI-карточки, таблицы и общий text scale.
- PDF/CSV экспорт больше не запускается через `LaunchMode.externalApplication`.
- Добавлено внутреннее окно просмотра экспорта в программе.
- На Flutter Web PDF/CSV открывается внутри `HtmlElementView` через iframe.
- Для остальных платформ добавлен безопасный fallback-панель без перехода в браузер.

Новые файлы:
- `reports/tracker_export_viewer.dart`
- `reports/tracker_export_viewer_stub.dart`
- `reports/tracker_export_viewer_web.dart`

Изменённые файлы:
- `reports/tracker_training_report_screen.dart`
- `screens/tracker_match_workspace_screen.dart`
