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

  String _s(dynamic v) => '${v ?? ''}'.trim();
  String _metric(dynamic v, String unit) => _s(v).isEmpty || _s(v) == 'null' ? '—' : '${_s(v)} $unit';

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PpSectionTitle(
            title: 'Здоровье',
            subtitle: 'Физические показатели и медицинская история игрока',
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final metrics = _healthBlock(child: _metricsCard());
            final medical = _healthBlock(child: _medicalCard(context));
            return c.maxWidth >= 820
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: metrics),
                        const SizedBox(width: 12),
                        Expanded(child: medical),
                      ],
                    ),
                  )
                : Column(children: [metrics, const SizedBox(height: 12), medical]);
          }),
        ],
      );


  Widget _healthBlock({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _metricsCard() {
    final p = data.player;
    final maxSession = data.trackerMaxHrSession;
    final restSession = data.trackerRestHrSession;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PpSectionTitle(
          title: 'Физические данные',
          subtitle: 'Рост и вес редактируются вручную, пульс рассчитывается по сессиям трекера',
          trailing: TextButton.icon(onPressed: onEditMetrics, icon: const Icon(Icons.edit_rounded, size: 17), label: const Text('Изменить')),
        ),
        const SizedBox(height: 12),
        _row('Рост', _metric(p['height'], 'см')),
        _row('Вес', _metric(p['weight'], 'кг')),
        _row('Индекс массы тела', _bmi(p)),
        _row('Максимальный пульс', maxSession == null ? '—' : '${maxSession.maxHr.round()} уд/мин'),
        _row('Дата HR max', _formatDate(maxSession?.date)),
        _row('Пульс покоя', restSession == null ? '—' : '${restSession.minHr.round()} уд/мин'),
        _row('Дата пульса покоя', _formatDate(restSession?.date)),
        const SizedBox(height: 8),
        Text('Пульсовые значения не редактируются вручную.', style: PpText.body(10.2)),
      ]);
  }

  Widget _medicalCard(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PpSectionTitle(
            title: 'Медицинские записи',
            subtitle: 'Осмотры, травмы, ограничения и рекомендации по датам',
            trailing: TextButton.icon(onPressed: onAddMedical, icon: const Icon(Icons.add_rounded, size: 17), label: const Text('Добавить')),
          ),
          const SizedBox(height: 10),
          if (data.medical.isEmpty)
            const SizedBox(height: 190, child: PpEmpty(title: 'Медицинских записей нет', text: 'Добавьте запись через правую панель'))
          else
            ...data.medical.map((e) => _medicalRow(context, e)),
        ]);

  Widget _medicalRow(BuildContext context, Map<String, dynamic> record) {
    final title = _s(record['title'] ?? record['diagnosis'] ?? record['type']).isEmpty ? 'Медицинская запись' : _s(record['title'] ?? record['diagnosis'] ?? record['type']);
    final note = _s(record['note'] ?? record['description'] ?? record['comment']);
    final date = _formatDate(record['record_date'] ?? record['date'] ?? record['created_at']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PpColors.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.medical_information_rounded, color: PpColors.green, size: 19),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(title, style: PpText.body(11.8, color: PpColors.text, weight: FontWeight.w600))), Text(date, style: PpText.body(10.3))]),
          if (note.isNotEmpty) ...[const SizedBox(height: 4), Text(note, style: PpText.body(10.8))],
          if (_fileUrl(record).isNotEmpty) ...[
            const SizedBox(height: 8),
            _attachmentChip(context, record),
          ],
        ])),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEditMedical(record);
            if (value == 'delete') _confirmDelete(context, record);
          },
          itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Редактировать')), PopupMenuItem(value: 'delete', child: Text('Удалить'))],
        ),
      ]),
    );
  }


  String _fileUrl(Map<String, dynamic> record) => _s(record['file_url'] ?? record['file_path']);

  Widget _attachmentChip(BuildContext context, Map<String, dynamic> record) {
    final url = _fileUrl(record);
    final name = _s(record['file_name']).isNotEmpty
        ? _s(record['file_name'])
        : ((Uri.tryParse(url)?.pathSegments.isNotEmpty ?? false) ? Uri.parse(url).pathSegments.last : 'Медицинский файл');
    final ext = _s(record['file_ext']).isNotEmpty
        ? _s(record['file_ext']).toLowerCase()
        : name.split('.').last.toLowerCase();
    final icon = ext == 'pdf'
        ? Icons.picture_as_pdf_rounded
        : (ext == 'doc' || ext == 'docx')
            ? Icons.description_rounded
            : Icons.image_rounded;
    final size = int.tryParse(_s(record['file_size'])) ?? 0;

    return Material(
      color: PpColors.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onOpenDocument(record),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 17, color: PpColors.greenDark),
            ),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: PpText.body(10.5, color: PpColors.text, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${ext.toUpperCase()}${size > 0 ? ' · ${_formatBytes(size)}' : ''}', style: PpText.body(9.7)),
            ])),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 16, color: PpColors.greenDark),
          ]),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> record) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Удалить медицинскую запись?'), content: const Text('Запись будет удалена из истории здоровья игрока.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Удалить'))])) ?? false;
    if (ok) await onDeleteMedical(record);
  }

  Widget _row(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [Expanded(child: Text(l, style: PpText.body(11))), Text(v, style: PpText.body(11.2, color: PpColors.text, weight: FontWeight.w600))]));

  String _bmi(Map<String, dynamic> p) {
    final h = double.tryParse(_s(p['height']).replaceAll(',', '.')) ?? 0;
    final w = double.tryParse(_s(p['weight']).replaceAll(',', '.')) ?? 0;
    if (h <= 0 || w <= 0) return '—';
    return (w / ((h / 100) * (h / 100))).toStringAsFixed(1);
  }

  String _formatDate(dynamic raw) {
    final d = raw is DateTime ? raw : DateTime.tryParse(_s(raw).replaceAll(' ', 'T'));
    return d == null ? '—' : DateFormat('dd.MM.yyyy').format(d);
  }
}
