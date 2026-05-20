import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import 'team_calendar_models.dart';
import 'training_rating_sheet.dart';

class TrainingEventDetailSheet extends StatelessWidget {
  final String apiBase;
  final TeamEvent event;

  /// ✅ если true — режим игрока (только просмотр),
  /// скрываем рейтинг и планы-конспекты
  final bool playerView;

  const TrainingEventDetailSheet({
    super.key,
    required this.apiBase,
    required this.event,
    this.playerView = false,
  });

  String _dd(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
  String _hh(DateTime d) =>
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final primary = Theme.of(context).colorScheme.primary;

    final when = event.endAt == null
        ? "${_dd(event.startAt)} • ${_hh(event.startAt)}"
        : "${_dd(event.startAt)} • ${_hh(event.startAt)}–${_hh(event.endAt!)}";

    final isTrainingLike =
        (event.type == TeamEventType.training || event.type == TeamEventType.gym);

    return Container(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + pad),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F5F8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    playerView ? "Событие" : "Подробнее",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Закрыть"),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${eventTypeLabel(event.type)} • $when",
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (event.location.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.place,
                            size: 18, color: Color(0xFF6B7280)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (event.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Заметки",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(event.notes),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ✅ Планы/конспекты — СКРЫВАЕМ ИГРОКУ
            if (!playerView) ...[
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Планы / конспекты",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Сюда позже подключим прикрепление планов/схем/конспектов к тренировке.",
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Get.snackbar(
                            "Скоро",
                            "Подключим из твоих экранов планов",
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        },
                        icon: const Icon(Icons.article_outlined),
                        label: const Text("Открыть планы"),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ✅ Оценка — СКРЫВАЕМ ИГРОКУ
            if (!playerView) ...[
              if (isTrainingLike) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final coachId = await PrefUtils.getUserId() ?? 0;
                      if (coachId <= 0) {
                        Get.snackbar(
                          "Оценка",
                          "Не найден userId",
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }

                      // закрываем "Подробнее" и открываем оценку сверху
                      Navigator.pop(context);

                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => TrainingRatingSheet(
                          apiBase: apiBase,
                          teamId: event.teamId,
                          eventId: event.id,
                          coachId: coachId,
                          title: event.title,
                        ),
                      );
                    },
                    icon: const Icon(Icons.star_rate_rounded),
                    label: const Text("Оценка тренировки игроков"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ] else ...[
                const _MutedHint("Оценка доступна только для тренировок/ОФП."),
              ],
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _MutedHint extends StatelessWidget {
  final String text;
  const _MutedHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
