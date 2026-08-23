from pathlib import Path

path = Path(
    "lib/presentation/club_workspace/"
    "cmr_club_ai_assistant_panel.dart"
)

text = path.read_text(encoding="utf-8")

text = text.replace(
    "https://sportotekaapp.ru/api/ai/v4/ai/analyze",
    "https://sportotekaapp.ru/api/ai/v5/ai/analyze",
)

old = """              'sport_code': 'football',
              'context': widget.initialPayload ?? const <String, dynamic>{},
"""

new = """              'sport_code': 'football',
              'conversation_id': (
                'club:${widget.clubId}:'
                'user:${widget.userId}:'
                'team:${widget.teamId ?? 0}'
              ),
              'context': widget.initialPayload ?? const <String, dynamic>{},
"""

if old in text:
    text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8")

print("Flutter переведён на AI Core 5.0")
