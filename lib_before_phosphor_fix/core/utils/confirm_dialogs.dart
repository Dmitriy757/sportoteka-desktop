import 'package:flutter/material.dart';

/// Универсальный диалог подтверждения сброса
/// Требует ввода слова "сбросить"
Future<bool> showResetConfirmDialog(
  BuildContext context, {
  String title = "Сбросить данные?",
  String description =
      "Это действие необратимо.\nВсе оценки будут удалены.",
  String confirmWord = "сбросить",
}) async {
  final controller = TextEditingController();
  bool confirmed = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final ok =
              controller.text.trim().toLowerCase() == confirmWord.toLowerCase();

          return AlertDialog(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Введите слово "$confirmWord" для подтверждения:',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: confirmWord,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Отмена"),
              ),
              ElevatedButton(
                onPressed: ok
                    ? () {
                        confirmed = true;
                        Navigator.pop(ctx);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Сбросить"),
              ),
            ],
          );
        },
      );
    },
  );

  return confirmed;
}
