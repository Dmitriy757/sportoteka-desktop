import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/player_profile_models.dart';
import '../widgets/player_document_editor_panel.dart';
import '../widgets/player_profile_ui.dart';

class PlayerDocumentsSection extends StatefulWidget {
  final PlayerProfileSnapshot data;
  final bool readOnly;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  final void Function(Map<String, dynamic>) onOpen;

  const PlayerDocumentsSection({
    super.key,
    required this.data,
    required this.readOnly,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  State<PlayerDocumentsSection> createState() =>
      _PlayerDocumentsSectionState();
}

class _PlayerDocumentsSectionState extends State<PlayerDocumentsSection> {
  String _category = 'all';

  String _s(dynamic value) => '${value ?? ''}'.trim();

  DateTime? _date(dynamic value) =>
      DateTime.tryParse(_s(value).replaceAll(' ', 'T'));

  List<Map<String, dynamic>> get _visible {
    if (_category == 'all') return widget.data.documents;
    return widget.data.documents
        .where((row) => _s(row['document_category']) == _category)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final expiring = widget.data.documents.where((row) {
      final expiry = _date(row['expiry_date']);
      if (expiry == null) return false;
      final days = expiry.difference(now).inDays;
      return days >= 0 && days <= 30;
    }).length;
    final expired = widget.data.documents.where((row) {
      final expiry = _date(row['expiry_date']);
      return expiry != null && expiry.isBefore(now);
    }).length;

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Row(
            children: [
              const PpDot.green(size: 7),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Документы', style: PpText.title(18)),
                    const SizedBox(height: 3),
                    Text(
                      'Личный архив игрока · просмотр внутри приложения',
                      style: PpText.body(10.2),
                    ),
                  ],
                ),
              ),
              if (!widget.readOnly)
                PpTextAction(
                  label: 'Добавить документ',
                  onTap: widget.onAdd,
                  dotColor: PpColors.greenDark,
                  emphasized: true,
                )
              else
                const PpDotCluster(),
            ],
          ),
          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 3 : 2;
              final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
              final values = <({String label, String value, Color color})>[
                (label: 'Всего', value: '${widget.data.documents.length}', color: PpColors.green),
                (label: 'Истекают до 30 дней', value: '$expiring', color: PpColors.amber),
                (label: 'Просрочены', value: '$expired', color: PpColors.red),
              ];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: values
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: PpMetric(
                          label: item.label,
                          value: item.value,
                          dotColor: item.color,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 10),
          _filters(),
          const SizedBox(height: 10),
          if (_visible.isEmpty)
            SizedBox(
              height: 250,
              child: PpEmpty(
                title: _category == 'all'
                    ? 'Документы ещё не загружены'
                    : 'В этой категории документов нет',
                text: widget.readOnly
                    ? 'Архив заполнит сотрудник футбольной школы'
                    : 'Нажмите «Добавить документ», укажите название и выберите файл',
              ),
            )
          else
            ..._visible.asMap().entries.map((entry) {
              return Column(
                children: [
                  _documentRow(context, entry.value),
                  if (entry.key != _visible.length - 1)
                    const PpThinDivider(margin: EdgeInsets.zero),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _filters() {
    final used = <String>{
      'all',
      ...widget.data.documents.map((row) => _s(row['document_category'])),
    }..remove('');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: used.map((key) {
          final active = key == _category;
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Material(
              color: active ? PpColors.greenSoft : PpColors.soft,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => setState(() => _category = key),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  child: Row(
                    children: [
                      PpDot(
                        color: active ? PpColors.greenDark : PpColors.muted2,
                        size: active ? 6 : 4.5,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        key == 'all'
                            ? 'Все'
                            : PlayerDocumentEditorPanel.categories[key] ?? 'Другое',
                        style: PpText.body(
                          10.2,
                          color: active ? PpColors.greenDark : PpColors.text,
                          weight: active ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _documentRow(BuildContext context, Map<String, dynamic> row) {
    final title = _s(row['document_title']).isEmpty
        ? 'Документ игрока'
        : _s(row['document_title']);
    final category = PlayerDocumentEditorPanel.categories[
            _s(row['document_category'])] ??
        'Другое';
    final number = _s(row['document_number']);
    final issuer = _s(row['document_issuer']);
    final issue = _formatDate(row['issue_date']);
    final expiryDate = _date(row['expiry_date']);
    final expiry = _formatDate(expiryDate);
    final status = _status(expiryDate);
    final fileName = _fileName(row);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PpColors.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon(fileName), color: status.color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PpText.body(
                          11,
                          color: PpColors.text,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (expiryDate != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        status.label,
                        style: PpText.caption(color: status.color),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  <String>[
                    category,
                    if (number.isNotEmpty) '№ $number',
                    if (issue != '—') 'от $issue',
                    if (expiry != '—') 'до $expiry',
                  ].join(' · '),
                  style: PpText.body(10.2),
                ),
                if (issuer.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(issuer, style: PpText.caption()),
                ],
                const SizedBox(height: 7),
                Material(
                  color: PpColors.soft,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => widget.onOpen(row),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PpDot(color: status.color, size: 5.5),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PpText.body(10.2, weight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Text(
                            'Открыть',
                            style: PpText.caption(color: PpColors.greenDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!widget.readOnly) ...[
            const SizedBox(width: 7),
            PopupMenuButton<String>(
              tooltip: 'Действия',
              onSelected: (value) {
                if (value == 'edit') widget.onEdit(row);
                if (value == 'delete') _confirmDelete(context, row);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Map<String, dynamic> row,
  ) async {
    final ok = await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(.28),
          builder: (dialogContext) => PpDialogShell(
            title: 'Удалить документ?',
            subtitle: 'Действие нельзя отменить',
            dotColor: PpColors.red,
            child: PpActionRow(
              icon: Icons.delete_outline_rounded,
              title: _s(row['document_title']).isEmpty
                  ? 'Документ игрока'
                  : _s(row['document_title']),
              subtitle: 'Файл и его карточка будут удалены из архива игрока',
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
    if (!ok) return;
    try {
      await widget.onDelete(row);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Документ удалён')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить документ: $error')),
        );
      }
    }
  }

  ({String label, Color color}) _status(DateTime? expiry) {
    if (expiry == null) return (label: 'Без срока', color: PpColors.greenDark);
    final days = expiry.difference(DateTime.now()).inDays;
    if (days < 0) return (label: 'Просрочен', color: PpColors.red);
    if (days <= 30) return (label: 'Истекает', color: PpColors.amber);
    return (label: 'Действует', color: PpColors.green);
  }

  String _fileName(Map<String, dynamic> row) {
    final saved = _s(row['file_name']);
    if (saved.isNotEmpty) return saved;
    final uri = Uri.tryParse(_s(row['file_url'] ?? row['file_path']));
    return uri != null && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'Файл документа';
  }

  IconData _icon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (ext == 'doc' || ext == 'docx') return Icons.description_rounded;
    return Icons.image_rounded;
  }

  String _formatDate(dynamic raw) {
    final value = raw is DateTime ? raw : _date(raw);
    return value == null ? '—' : DateFormat('dd.MM.yyyy').format(value);
  }
}
