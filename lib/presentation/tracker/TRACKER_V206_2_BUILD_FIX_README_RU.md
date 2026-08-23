# V206.2 BUILD FIX

Причина ошибки V206.1:
helper-методы были восстановлены после закрывающей `}` класса
`_PlayerTrainingNotificationsPanelState`, поэтому Dart видел их как код вне State
и продолжал писать `method isn't defined for the type`.

В V206.2:
- восстановлены все 32 метода, которые были в V205 и пропали из V206;
- все они вставлены до закрывающей `}` `_PlayerTrainingNotificationsPanelState`;
- проверено, что `_coachAlerts`, `_liveCard`, `_coachAttentionPanel`,
  `_coachDataQualityPanel`, `_coachRecentMiniPanel`, `_coachJournalBody`,
  `_coachComparisonBody`, `_coachCalendarBody`, `_coachSectionTitle`,
  `_coachEmptyCard`, `_coachCompletedFocusCard`, `_pulseLivePanel`
  являются методами State-класса;
- новый Personal Live V206 (переключение игрока, Поле/Карта/Спутник,
  3D PRO, Журнал/Скорость/Кардио) не откатан.
