SPORTOTEKA TRACKER V141 — PERSONAL MOBILE NO REGRESSION

Fix after V140:
- restored the latest clean/compact mobile "Мои тренировки -> Тренировка" screen from V136/V51;
- keeps V140 mobile analytics map modal/scroll changes;
- keeps compact analytics KPI styling and mobile AI modal from V139;
- keeps calendar auto-scroll to "Тренировки дня" and mobile AI access;
- no PHP/API changes.

The regression was caused by V140 carrying an older copy of
player/player_my_trainings_screen.dart. This archive merges the newest
training screen with the newest analytics file instead of replacing the
whole tracker tree with an older variant.
