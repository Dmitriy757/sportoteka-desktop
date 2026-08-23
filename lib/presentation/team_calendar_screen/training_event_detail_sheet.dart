import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import 'team_calendar_models.dart';
import 'training_rating_sheet.dart';

class TrainingEventDetailSheet extends StatelessWidget {
  final String apiBase;
  final TeamEvent event;

  /// Если true — режим игрока: только просмотр,
  /// без оценки и блока планов/конспектов.
  final bool playerView;

  const TrainingEventDetailSheet({
    super.key,
    required this.apiBase,
    required this.event,
    this.playerView = false,
  });

  String _dd(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  String _hh(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * .86;
    final accent = _eventAccent(event.type);

    final when = event.endAt == null
        ? '${_dd(event.startAt)} • ${_hh(event.startAt)}'
        : '${_dd(event.startAt)} • ${_hh(event.startAt)}–${_hh(event.endAt!)}';

    final isTrainingLike =
        event.type == TeamEventType.training || event.type == TeamEventType.gym;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: _CmrColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28), bottom: Radius.circular(22)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28), bottom: Radius.circular(22)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _CmrDragHandle(),
              _CmrSheetHeader(
                title: playerView ? 'Событие календаря' : 'Детали события',
                subtitle: '${eventTypeLabel(event.type)} · $when',
                icon: _eventIcon(event.type),
                accent: accent,
                onClose: () => Navigator.pop(context),
              ),
              const Divider(height: 1, color: _CmrColors.line),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EventSummaryPane(
                        event: event,
                        when: when,
                        accent: accent,
                      ),
                      if (!playerView) ...[
                        const SizedBox(height: 12),
                        _PlansPane(accent: _CmrColors.blue),
                      ],
                      if (!playerView) ...[
                        const SizedBox(height: 12),
                        if (isTrainingLike)
                          _CmrPrimaryAction(
                            icon: Icons.star_rate_rounded,
                            text: 'Оценка тренировки игроков',
                            onTap: () async {
                              final coachId = await PrefUtils.getUserId() ?? 0;
                              if (coachId <= 0) {
                                Get.snackbar(
                                  'Оценка',
                                  'Не найден userId',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                                return;
                              }

                              final rootContext = Get.context ?? context;
                              Navigator.pop(context);
                              await Future<void>.delayed(Duration.zero);

                              await showTrainingRatingWindow(
                                rootContext,
                                apiBase: apiBase,
                                teamId: event.teamId,
                                eventId: event.id,
                                coachId: coachId,
                                title: event.title,
                              );
                            },
                          )
                        else
                          const _CmrMutedHint('Оценка доступна только для тренировок/ОФП.'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CmrColors {
  static const Color surface = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF7F9FA);
  static const Color line = Color(0xFFE7ECEF);
  static const Color lineStrong = Color(0xFFD7E1E6);
  static const Color text = Color(0xFF0B0F14);
  static const Color softText = Color(0xFF354052);
  static const Color muted = Color(0xFF5F6670);
  static const Color icon = Color(0xFF6B7280);
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF087A48);
  static const Color blue = Color(0xFF2563EB);
  static const Color cyan = Color(0xFF0891B2);
  static const Color amber = Color(0xFFD97706);
  static const Color slate = Color(0xFF64748B);

  static Color tint(Color color, {double opacity = .075}) =>
      Color.alphaBlend(color.withOpacity(opacity), Colors.white);
}

class _CmrText {
  static TextStyle base(
    double size,
    FontWeight weight,
    Color color, {
    double height = 1.18,
    double letterSpacing = 0,
  }) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle title(double size) => base(size, FontWeight.w600, _CmrColors.text, height: 1.10);
  static TextStyle section(Color color) => base(12.0, FontWeight.w600, color, height: 1.08);
  static TextStyle body() => base(11.7, FontWeight.w400, _CmrColors.softText, height: 1.35);
  static TextStyle muted() => base(11.2, FontWeight.w400, _CmrColors.muted, height: 1.32);
  static TextStyle chip(Color color) => base(10.4, FontWeight.w600, color, height: 1.0);
}

Color _eventAccent(TeamEventType type) {
  switch (type) {
    case TeamEventType.training:
      return _CmrColors.green;
    case TeamEventType.gym:
      return _CmrColors.cyan;
    case TeamEventType.leagueMatch:
    case TeamEventType.friendlyMatch:
      return _CmrColors.blue;
    case TeamEventType.theory:
      return _CmrColors.amber;
    case TeamEventType.dayOff:
      return _CmrColors.slate;
    default:
      return _CmrColors.green;
  }
}

IconData _eventIcon(TeamEventType type) {
  switch (type) {
    case TeamEventType.training:
      return Icons.fitness_center_rounded;
    case TeamEventType.gym:
      return Icons.directions_run_rounded;
    case TeamEventType.leagueMatch:
    case TeamEventType.friendlyMatch:
      return Icons.sports_soccer_rounded;
    case TeamEventType.theory:
      return Icons.lightbulb_outline_rounded;
    case TeamEventType.dayOff:
      return Icons.weekend_rounded;
    default:
      return Icons.event_note_rounded;
  }
}

class _CmrDragHandle extends StatelessWidget {
  const _CmrDragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9, bottom: 5),
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFDDE4EA),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _CmrSheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onClose;

  const _CmrSheetHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _CmrColors.tint(accent, opacity: .11),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(.18)),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(15.0)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.muted()),
              ],
            ),
          ),
          _CmrRoundIconButton(icon: Icons.close_rounded, onTap: onClose),
        ],
      ),
    );
  }
}

class _EventSummaryPane extends StatelessWidget {
  final TeamEvent event;
  final String when;
  final Color accent;

  const _EventSummaryPane({
    required this.event,
    required this.when,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final title = event.title.trim().isEmpty ? 'Событие календаря' : event.title.trim();

    return _CmrPane(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _CmrText.title(15.2),
                ),
              ),
              const SizedBox(width: 10),
              _TypeBadge(label: eventTypeLabel(event.type), color: accent),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(icon: Icons.schedule_rounded, text: when, color: accent),
          if (event.location.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.place_rounded, text: event.location.trim(), color: accent),
          ],
          if (event.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: _CmrColors.line),
            const SizedBox(height: 12),
            Text('Заметки', style: _CmrText.section(accent)),
            const SizedBox(height: 7),
            Text(event.notes.trim(), style: _CmrText.body()),
          ],
        ],
      ),
    );
  }
}

class _PlansPane extends StatelessWidget {
  final Color accent;
  const _PlansPane({required this.accent});

  @override
  Widget build(BuildContext context) {
    return _CmrPane(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Планы / конспекты', style: _CmrText.section(accent)),
          const SizedBox(height: 7),
          Text(
            'Сюда позже подключим прикрепление планов, схем и конспектов к тренировке.',
            style: _CmrText.muted(),
          ),
          const SizedBox(height: 12),
          _CmrSoftAction(
            icon: Icons.article_outlined,
            text: 'Открыть планы',
            color: accent,
            onTap: () {
              Get.snackbar(
                'Скоро',
                'Подключим из твоих экранов планов',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CmrPane extends StatelessWidget {
  final Widget child;
  final Color accent;

  const _CmrPane({required this.child, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _CmrColors.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _CmrColors.tint(color, opacity: .095),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.14)),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.chip(color)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _CmrColors.tint(color, opacity: .095),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _CmrText.body(),
          ),
        ),
      ],
    );
  }
}

class _CmrSoftAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _CmrSoftAction({
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _CmrColors.tint(color, opacity: .070),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(text, style: _CmrText.base(11.8, FontWeight.w600, color, height: 1)),
          ],
        ),
      ),
    );
  }
}

class _CmrPrimaryAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _CmrPrimaryAction({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _CmrColors.tint(_CmrColors.green, opacity: .090),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _CmrColors.green.withOpacity(.20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _CmrColors.green.withOpacity(.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.star_rate_rounded, color: _CmrColors.green, size: 15),
            ),
            const SizedBox(width: 9),
            Text(text, style: _CmrText.base(12.0, FontWeight.w600, _CmrColors.greenDark, height: 1)),
          ],
        ),
      ),
    );
  }
}

class _CmrMutedHint extends StatelessWidget {
  final String text;

  const _CmrMutedHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CmrColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CmrColors.line),
      ),
      child: Text(text, style: _CmrText.muted()),
    );
  }
}

class _CmrRoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CmrRoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _CmrColors.line),
        ),
        child: Icon(icon, color: _CmrColors.icon, size: 17),
      ),
    );
  }
}
