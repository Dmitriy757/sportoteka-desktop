import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

import 'training_lifecycle_api.dart';

class TrainingActivityPanel extends StatefulWidget {
  final String apiBase;
  final int clubId;
  final int teamId;
  final int eventId;

  const TrainingActivityPanel({
    super.key,
    required this.apiBase,
    required this.clubId,
    required this.teamId,
    required this.eventId,
  });

  @override
  State<TrainingActivityPanel> createState() => _TrainingActivityPanelState();
}

class _TrainingActivityPanelState extends State<TrainingActivityPanel> {
  static const _green = Color(0xFF00A750);
  static const _greenDark = Color(0xFF087A48);
  static const _greenSoft = Color(0xFFF3FAF6);
  static const _soft = Color(0xFFF7F8F7);
  static const _line = Color(0xFFE7EAE8);
  static const _text = Color(0xFF0B0F14);
  static const _muted = Color(0xFF667085);

  bool loading = true;
  TrainingLifecycleState state = const TrainingLifecycleState();

  TrainingLifecycleApi get _api => TrainingLifecycleApi(
        apiBase: widget.apiBase,
        clubId: widget.clubId,
        teamId: widget.teamId,
        eventId: widget.eventId,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TrainingActivityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.teamId != widget.teamId ||
        oldWidget.clubId != widget.clubId) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    final next = await _api.load();
    if (!mounted) return;
    setState(() {
      state = next;
      loading = false;
    });
  }

  String _time(DateTime? value) {
    if (value == null) return '—';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _dateTime(DateTime? value) {
    if (value == null) return '—';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')} '
        '${_time(value)}';
  }

  String _statusTitle() {
    if (state.finished) return 'Тренировка окончена';
    if (state.started) return 'Тренировка идёт';
    return 'Тренировка запланирована';
  }

  String _statusText() {
    if (state.finished) {
      final ratings = state.ratingsCount > 0
          ? ' · оценки: ${state.ratingsCount} игроков'
          : '';
      return '${state.finishedByLabel} завершил тренировку в ${_time(state.finishedAt)}$ratings.';
    }
    if (state.started) {
      final attendance = state.attendanceTotal > 0
          ? ' · присутствуют ${state.attendancePresent}/${state.attendanceTotal}'
          : '';
      return '${state.startedByLabel} начал тренировку в ${_time(state.startedAt)}$attendance.';
    }
    return 'После заполнения журнала посещаемости тренер сможет начать тренировку.';
  }

  IconData _activityIcon(String action) {
    switch (action) {
      case 'attendance_opened':
        return Icons.event_note_outlined;
      case 'attendance_ready':
        return Icons.fact_check_outlined;
      case 'started':
        return Icons.play_arrow_rounded;
      case 'ratings_saved':
        return Icons.star_outline_rounded;
      case 'coach_note':
        return Icons.sticky_note_2_outlined;
      case 'plan_linked':
        return Icons.assignment_turned_in_outlined;
      case 'document_added':
        return Icons.attach_file_rounded;
      case 'finished':
        return Icons.check_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _green),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: state.started ? _greenSoft : _soft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: state.started ? _green.withOpacity(.22) : _line,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  state.finished
                      ? Icons.check_rounded
                      : state.started
                          ? Icons.play_arrow_rounded
                          : Icons.event_available_outlined,
                  color: state.started ? _greenDark : _muted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusTitle(),
                      style: AppTypography.itemTitle(color: _text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _statusText(),
                      style: AppTypography.caption(color: _muted),
                    ),
                    if (state.startedAt != null && state.finishedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Начало: ${_dateTime(state.startedAt)} · окончание: ${_dateTime(state.finishedAt)}',
                        style: AppTypography.caption(color: _muted),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Обновить',
                onPressed: _load,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh_rounded, size: 18, color: _muted),
              ),
            ],
          ),
        ),
        if (state.activities.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 17, color: _greenDark),
                    const SizedBox(width: 7),
                    Text('История тренировки', style: AppTypography.itemTitle(color: _text)),
                  ],
                ),
                const SizedBox(height: 8),
                ...state.activities.map(_activityRow),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _activityRow(TrainingActivityEntry item) {
    final title = item.title.trim().isEmpty ? 'Событие тренировки' : item.title.trim();
    final detail = item.detail.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              _time(item.createdAt),
              style: AppTypography.caption(color: _muted),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _greenSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_activityIcon(item.action), size: 15, color: _greenDark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.secondary(color: _text)),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(detail, style: AppTypography.caption(color: _muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
