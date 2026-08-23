## Сервер

```bash
cd /var/www/sportoteka-ai

unzip -o \
SPORTOTEKA_AI_Core_11_0_Intent_First_Pipeline.zip \
-d /tmp/SPORTOTEKA_AI_Core_11_0_Intent_First_Pipeline

bash \
/tmp/SPORTOTEKA_AI_Core_11_0_Intent_First_Pipeline/server/install.sh \
/var/www/sportoteka-ai

find app -type d -name "__pycache__" -exec rm -rf {} +

sudo systemctl restart sportoteka-ai.service
sleep 10
```

## Проверка

```bash
curl -sS -X POST \
"http://127.0.0.1:8091/v11/ai/analyze" \
-H "Content-Type: application/json" \
-d '{
  "club_id":164,
  "user_id":164,
  "team_id":40,
  "conversation_id":"core11-training-test",
  "sport_code":"football",
  "q":"Сделай анализ тренировки за вчера"
}' | python3 -m json.tool
```

## Flutter

```bash
python3 patch_flutter_core11.py
```
