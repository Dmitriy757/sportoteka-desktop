from pathlib import Path

path = Path(
    "lib/presentation/club_workspace/"
    "cmr_club_ai_assistant_panel.dart"
)

text = path.read_text(encoding="utf-8")

field_anchor = (
    "  final void Function(String url)? onOpenPdf;\n"
)

fields = (
    "\n"
    "  /// Для мобильного режима: вернуться к предыдущему экрану.\n"
    "  final VoidCallback? onBack;\n"
    "  final String? initialPrompt;\n"
    "  final Map<String, dynamic>? initialPayload;\n"
    "  final bool autoSendInitialPrompt;\n"
)

if "final VoidCallback? onBack;" not in text:
    if field_anchor not in text:
        raise SystemExit("Не найдено поле onOpenPdf")
    text = text.replace(
        field_anchor,
        field_anchor + fields,
        1,
    )

constructor_anchor = (
    "    this.onOpenPdf,\n"
)

constructor_args = (
    "    this.onBack,\n"
    "    this.initialPrompt,\n"
    "    this.initialPayload,\n"
    "    this.autoSendInitialPrompt = false,\n"
)

if "    this.onBack," not in text:
    if constructor_anchor not in text:
        raise SystemExit("Не найден параметр this.onOpenPdf")
    text = text.replace(
        constructor_anchor,
        constructor_anchor + constructor_args,
        1,
    )

path.write_text(text, encoding="utf-8")
print("Параметры onBack/initialPrompt восстановлены")
