import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

class PlayerHealthSection extends StatelessWidget {
  final PlayerProfileSnapshot data;
  final VoidCallback onEditMetrics;
  final VoidCallback onAddMedical;
  final void Function(Map<String, dynamic>) onEditMedical;
  final Future<void> Function(Map<String, dynamic>) onDeleteMedical;
  final void Function(Map<String, dynamic>) onOpenDocument;

  const PlayerHealthSection({
    super.key,
    required this.data,
    required this.onEditMetrics,
    required this.onAddMedical,
    required this.onEditMedical,
    required this.onDeleteMedical,
    required this.onOpenDocument,
  });

  String _s(dynamic value) => '${value ?? ''}'.trim();

  String _metric(dynamic value, String unit) =>
      _s(value).isEmpty || _s(value) == 'null'
          ? '—'
          : '${_s(value)} $unit';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: [
          PpSurface(
            elevated: true,
            child: const PpSectionTitle(
              title: 'Здоровье',
              subtitle:
                  'Физические показатели и медицинская история игрока',
              dotColor: PpColors.red,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = _metricsCard();
              final medical = _medicalCard(context);

              if (constraints.maxWidth >= 820) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: metrics),
                    const SizedBox(width: 12),
                    Expanded(child: medical),
                  ],
                );
              }

              return Column(
                children: [
                  metrics,
                  const SizedBox(height: 10),
                  medical,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metricsCard() {
    final player = data.player;
    final maxSession = data.trackerMaxHrSession;
    final restSession = data.trackerRestHrSession;

    final rows = <({String label, String value, Color color})>[
      (
        label: 'Рост',
        value: _metric(player['height'] ?? player['height_cm'], 'см'),
        color: PpColors.green,
      ),
      (
        label: 'Вес',
        value: _metric(player['weight'] ?? player['weight_kg'], 'кг'),
        color: PpColors.amber,
      ),
      (
        label: 'Индекс массы тела',
        value: _bmi(player),
        color: PpColors.greenDark,
      ),
      (
        label: 'Максимальный пульс',
        value: maxSession == null
            ? '—'
            : '${maxSession.maxHr.round()} уд/мин',
        color: PpColors.red,
      ),
      (
        label: 'Дата HR max',
        value: _formatDate(maxSession?.date),
        color: PpColors.red,
      ),
      (
        label: 'Пульс покоя',
        value: restSession == null
            ? '—'
            : '${restSession.minHr.round()} уд/мин',
        color: PpColors.green,
      ),
      (
        label: 'Дата пульса покоя',
        value: _formatDate(restSession?.date),
        color: PpColors.green,
      ),
    ];

    return PpSurface(
      color: PpColors.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PpSectionTitle(
            title: 'Физические данные',
            subtitle:
                'Рост и вес редактируются вручную, пульс берётся из трекера',
            dotColor: PpColors.greenDark,
            trailing: PpTextAction(
              label: 'Изменить',
              onTap: onEditMetrics,
              dotColor: PpColors.greenDark,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      PpDot(color: row.color, size: 5.5),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          row.label,
                          style: PpText.body(10.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        row.value,
                        style: PpText.body(
                          10.6,
                          color: PpColors.text,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index != rows.length - 1)
                  const PpThinDivider(
                    margin: EdgeInsets.only(top: 1, bottom: 1),
                  ),
              ],
            );
          }),
          const SizedBox(height: 8),
          Text(
            'Пульсовые значения не редактируются вручную.',
            style: PpText.caption(),
          ),
        ],
      ),
    );
  }

  Widget _medicalCard(BuildContext context) {
    return PpSurface(
      color: PpColors.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PpSectionTitle(
            title: 'Медицинские записи',
            subtitle:
                'Осмотры, травмы, ограничения и рекомендации по датам',
            dotColor: PpColors.red,
            trailing: PpTextAction(
              label: 'Добавить',
              onTap: onAddMedical,
              dotColor: PpColors.red,
            ),
          ),
          const SizedBox(height: 8),
          if (data.medical.isEmpty)
            const SizedBox(
              height: 190,
              child: PpEmpty(
                title: 'Медицинских записей нет',
                text: 'Добавьте запись через правую панель',
              ),
            )
          else
            ...data.medical.toList().asMap().entries.map((entry) {
              final index = entry.key;
              return Column(
                children: [
                  _medicalRow(context, entry.value),
                  if (index != data.medical.length - 1)
                    const PpThinDivider(
                      margin: EdgeInsets.only(top: 2, bottom: 2),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _medicalRow(
    BuildContext context,
    Map<String, dynamic> record,
  ) {
    final titleRaw =
        _s(record['title'] ?? record['diagnosis'] ?? record['type']);
    final title =
        titleRaw.isEmpty ? 'Медицинская запись' : titleRaw;
    final note =
        _s(record['note'] ?? record['description'] ?? record['comment']);
    final date = _formatDate(
      record['record_date'] ??
          record['date'] ??
          record['created_at'],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: PpDot.red(size: 7),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: PpText.body(
                          11,
                          color: PpColors.text,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(date, style: PpText.caption()),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(note, style: PpText.body(10.2)),
                ],
                if (_fileUrl(record).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _attachmentChip(record),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Действия',
            onSelected: (value) {
              if (value == 'edit') onEditMedical(record);
              if (value == 'delete') {
                _confirmDelete(context, record);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Редактировать'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Удалить'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              child: Text(
                '•••',
                style: PpText.body(
                  12,
                  color: PpColors.muted,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fileUrl(Map<String, dynamic> record) =>
      _s(record['file_url'] ?? record['file_path']);

  Widget _attachmentChip(Map<String, dynamic> record) {
    final url = _fileUrl(record);
    final name = _s(record['file_name']).isNotEmpty
        ? _s(record['file_name'])
        : ((Uri.tryParse(url)?.pathSegments.isNotEmpty ?? false)
            ? Uri.parse(url).pathSegments.last
            : 'Медицинский файл');

    final ext = _s(record['file_ext']).isNotEmpty
        ? _s(record['file_ext']).toLowerCase()
        : (name.contains('.') ? name.split('.').last.toLowerCase() : '');

    final size = int.tryParse(_s(record['file_size'])) ?? 0;
    final color = ext == 'pdf'
        ? PpColors.red
        : (ext == 'doc' || ext == 'docx')
            ? PpColors.amber
            : PpColors.green;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () => onOpenDocument(record),
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          child: Row(
            children: [
              PpDot(color: color, size: 7),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PpText.body(
                        10.6,
                        color: PpColors.text,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ext.isEmpty ? 'ФАЙЛ' : ext.toUpperCase()}'
                      '${size > 0 ? ' · ${_formatBytes(size)}' : ''}',
                      style: PpText.caption(size: 9.5),
                    ),
                  ],
                ),
              ),
              Text(
                'Открыть',
                style: PpText.caption(
                  size: 9.5,
                  color: PpColors.greenDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Map<String, dynamic> record,
  ) async {
    final ok = await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(.28),
          builder: (dialogContext) => PpDialogShell(
            title: 'Удалить медицинскую запись?',
            subtitle: 'Действие нельзя отменить',
            dotColor: PpColors.red,
            child: const PpActionRow(
              icon: Icons.medical_information_outlined,
              title: 'История здоровья игрока',
              subtitle: 'Запись и прикреплённый файл будут удалены',
              danger: true,
            ),
            actions: [
              PpDialogButton(
                label: 'Отмена',
                onTap: () => Navigator.pop(dialogContext, false),
              ),
              PpDialogButton(
                label: 'Удалить',
                primary: true,
                danger: true,
                onTap: () => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
        ) ??
        false;

    if (ok) {
      await onDeleteMedical(record);
    }
  }

  String _bmi(Map<String, dynamic> player) {
    final height =
        double.tryParse(
              _s(player['height'] ?? player['height_cm']).replaceAll(',', '.'),
            ) ??
            0;
    final weight =
        double.tryParse(
              _s(player['weight'] ?? player['weight_kg']).replaceAll(',', '.'),
            ) ??
            0;

    if (height <= 0 || weight <= 0) return '—';

    return (weight / ((height / 100) * (height / 100)))
        .toStringAsFixed(1);
  }

  String _formatDate(dynamic raw) {
    final date = raw is DateTime
        ? raw
        : DateTime.tryParse(
            _s(raw).replaceAll(' ', 'T'),
          );

    return date == null
        ? '—'
        : DateFormat('dd.MM.yyyy').format(date);
  }
}
