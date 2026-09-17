# Sportoteka AI — live bbox / команды / ТТД

Исправления 2026-09-17:

- live-детектор запускается одновременно с серверным AI-анализом;
- если `/ai/analyze_frame_from_url` не может открыть видео, клиент извлекает JPEG текущего кадра и отправляет его в `/ai/analyze_frame`;
- поддерживаются bbox в форматах `left/top/right/bottom`, `x1/y1/x2/y2`, `x/y/w/h`, `bbox` как List и Map;
- поддерживаются вложенные ответы `data`, `result`, `output`, `analysis`;
- bbox 0..1, bbox в native-разрешении видео и bbox в analysis-space автоматически приводятся к одному пространству;
- в запрос AI передаются `home_color` и `away_color`, чтобы сервер мог сразу классифицировать команды по цветам формы;
- ответ детектора читает `team/team_tag/team_key/side`, `jersey_number`, `player_id`, `player_name`;
- рамки: home — зелёные, away — синие, referee — серые;
- подпись над рамкой показывает номер футболки, затем имя/track id как fallback;
- серверные треки также приведены к фирменной схеме зелёный/синий;
- парсер больше не требует обязательного `success: true`: ошибка только при явном `success: false`.

Рекомендуемый ответ `/ai/analyze_frame` и `/ai/analyze_frame_from_url`:

```json
{
  "success": true,
  "frame_width": 1920,
  "frame_height": 1080,
  "detections": [
    {
      "track_id": 10,
      "bbox": [510, 250, 590, 520],
      "bbox_format": "xyxy",
      "confidence": 0.94,
      "label": "player",
      "team": "home",
      "jersey_number": 10,
      "player_id": 123,
      "player_name": "Игрок #10"
    }
  ],
  "ball": {
    "bbox": [900, 570, 920, 590],
    "bbox_format": "xyxy",
    "confidence": 0.89
  }
}
```

Для автоматического ТТД тяжёлый Sportoteka AI анализ по-прежнему должен отдавать `auto_ttd`, `events`, `tracking_frames`, `player_stats` и т.д. UI уже использует эти данные в разделе ТТД.
