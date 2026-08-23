SPORTOTEKA TRACKER V151 — 3D ROUTE PERFORMANCE

База: V150 journal markers clean.

Что исправлено:
1. 3D camera state перенесён внутрь _AnalyticsPitchPerspective.
   Движение круглого джойстика больше не вызывает setState всего
   _ExpandedMovementInspectorState и не пересчитывает тысячи GPS-точек.
2. RepaintBoundary вокруг тяжёлого слоя карты: вращение/наклон/zoom
   композитятся GPU поверх уже отрисованного маршрута.
3. Для режима Маршрут + 3D PRO включён fastRouteRender:
   - полный GPS-маршрут сохраняется;
   - аналитические расчёты не меняются;
   - линии группируются в 4 Path по зонам скорости;
   - вместо тысяч drawLine/glow/arrow вызовов рисуется несколько Path;
   - стрелки маршрута в 3D отключены как тяжёлый декоративный слой.
4. 2D, Матч, журнал Replay, клики по меткам, Polar/GPS и расчёты не менялись.

PHP/БД: изменений не требуется.
