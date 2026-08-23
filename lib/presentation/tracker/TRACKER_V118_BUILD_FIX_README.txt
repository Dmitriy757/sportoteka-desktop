Sportoteka Tracker V118 build fix

Исправление ошибки Flutter/Dart:
Not a constant expression: '${_monitorPlayersForGrid().length} игроков'

Причина: динамический Text находился внутри const Row.
Исправлено: Row больше не const; статические Icon и SizedBox оставлены const.
Функциональность окна «Все карточки» и «Лента моментов» не менялась.
