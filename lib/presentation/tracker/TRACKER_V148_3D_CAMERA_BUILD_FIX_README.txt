SPORTOTEKA TRACKER V148 — 3D CAMERA BUILD FIX
============================================

Исправлено:
- методы _orbit3dCamera / _zoom3dCamera / _reset3dCamera перенесены из _MapTabState
  в _ExpandedMovementInspectorState, где реально находятся поля 3D-камеры;
- устранены ошибки undefined getter/setter для _perspective3d, _cameraYawDeg,
  _cameraTiltRad и _cameraZoom;
- callbacks круглого 3D-джойстика теперь разрешаются в том же State, где строится
  _AnalyticsPitchPerspective;
- функциональность V147 сохранена: увеличенная 3D-карта, круглый orbit-контрол,
  +/- масштаб, reset, кликабельные Replay-маркеры в режиме Матч.

Сервер/PHP/БД менять не требуется.
