# Sportoteka — киберспортивный профиль, UI Stage 2

На этом этапе меняется только экранный слой `player_profile_screen`. База данных и PHP API не меняются.

## Как профиль понимает, что это киберспортсмен

Достаточно одного из признаков:

- `athlete_type`, `player_type`, `sport_type` или `profile_type` содержит `esports`, `cyber` или `кибер`;
- либо заполнено одно из полей `esports_game`, `game_title`, `gamer_tag`, `esports_nickname`.

## Поддерживаемые поля профиля

- ник: `gamer_tag`, `esports_nickname`, `nickname`;
- игра: `esports_game`, `game_title`, `discipline`, `esports_discipline`;
- платформа: `gaming_platform`, `platform`, `console`;
- режим: `game_mode`, `esports_mode`, `mode`;
- рейтинг: `esports_rating`, `elo`, `rank_points`, `rating`;
- ранг: `esports_rank`, `rank_name`, `division`, `league_rank`;
- регион: `esports_region`, `region`, `server_region`.

## Разделы киберспортсмена

- Обзор
- Матчи
- Видео
- Статистика
- Турниры
- Документы
- ИИ киберспорт

Футбольные `Готовность`, `Здоровье`, GPS-активность и обычное `Тестирование` для киберспортсмена в меню не показываются.

## Поля матча, которые UI уже умеет использовать

Результат и счёт:

- `our_score`, `player_score`, `team_score`, `home_score`, `goals_for`;
- `opponent_score`, `rival_score`, `away_score`, `goals_against`;
- либо готовая строка `score` / `result`.

Дополнительная аналитика:

- `possession` / `possession_percent`;
- `shots` / `shots_total`;
- `shots_on_target`;
- `xg` / `expected_goals`;
- `pass_accuracy` / `pass_accuracy_percent`;
- `competition`, `tournament`, `league`.

Если этих полей пока нет, интерфейс не падает и показывает аккуратное пустое состояние.

## Важно

`PlayerProfileSection` не расширялся новыми enum-значениями. Это сделано специально, чтобы не сломать существующие маршруты и switch-блоки в других частях приложения.
