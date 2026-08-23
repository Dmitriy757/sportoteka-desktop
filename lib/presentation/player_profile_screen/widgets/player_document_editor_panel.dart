import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'player_profile_ui.dart';

class PlayerDocumentEditorPanel extends StatefulWidget {
  static const categories = <String, String>{
    'consent': 'Согласие / заявление',
    'contract': 'Договор',
    'identity': 'Удостоверение личности',
    'insurance': 'Страхование',
    'medical': 'Медицинский допуск',
    'education': 'Документ об обучении',
    'transfer': 'Переход / регистрация',
    'certificate': 'Справка / сертификат',
    'other': 'Другое',
  };

  final Map<String, dynamic>? document;
  final VoidCallback onClose;
  final Future<void> Function(Map<String, dynamic>, PlatformFile?) onSave;

  const PlayerDocumentEditorPanel({
    super.key,
    this.document,
    required this.onClose,
    required this.onSave,
  });

  @override
  State<PlayerDocumentEditorPanel> createState() =>
      _PlayerDocumentEditorPanelState();
}

class _PlayerDocumentEditorPanelState
    extends State<PlayerDocumentEditorPanel> {
  late final TextEditingController _name;
  late final TextEditingController _number;
  late final TextEditingController _issuer;
  late final TextEditingController _issueDate;
  late final TextEditingController _expiryDate;
  late final TextEditingController _description;
  String _category = 'other';
  PlatformFile? _attachment;
  bool _removeExistingFile = false;
  bool _saving = false;

  String _s(dynamic value) => '${value ?? ''}'.trim();

  @override
  void initState() {
    super.initState();
    final row = widget.document ?? const <String, dynamic>{};
    _name = TextEditingController(
      text: _s(row['document_title'] ?? row['title']),
    );
    _number = TextEditingController(text: _s(row['document_number']));
    _issuer = TextEditingController(text: _s(row['document_issuer']));
    _issueDate = TextEditingController(
      text: _s(row['issue_date'] ?? row['record_date']),
    );
    _expiryDate = TextEditingController(text: _s(row['expiry_date']));
    _description = TextEditingController(
      text: _s(row['description'] ?? row['note']),
    );
    final savedCategory = _s(row['document_category']);
    _category = PlayerDocumentEditorPanel.categories.containsKey(savedCategory)
        ? savedCategory
        : 'other';
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _issuer.dispose();
    _issueDate.dispose();
    _expiryDate.dispose();
    _description.dispose();
    super.dispose();
  }

  String get _existingUrl =>
      _s(widget.document?['file_url'] ?? widget.document?['file_path']);

  String get _existingName => _s(widget.document?['file_name']);

  String get _shownFileName => _attachment?.name ??
      (!_removeExistingFile
          ? (_existingName.isNotEmpty
              ? _existingName
              : _fileNameFromUrl(_existingUrl))
          : '');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PpSurface(
                      color: PpColors.soft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PpSectionTitle(
                            title: 'Карточка документа',
                            subtitle: 'Название задаётся вручную и будет видно в списке',
                            dotColor: PpColors.greenDark,
                          ),
                          const SizedBox(height: 12),
                          _field(_name, 'Наименование документа *'),
                          const SizedBox(height: 10),
                          _categoryField(),
                          const SizedBox(height: 10),
                          _field(_number, 'Номер / серия'),
                          const SizedBox(height: 10),
                          _field(_issuer, 'Кем выдан / организация'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  _issueDate,
                                  'Дата выдачи',
                                  hint: 'ГГГГ-ММ-ДД',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _field(
                                  _expiryDate,
                                  'Действует до',
                                  hint: 'ГГГГ-ММ-ДД',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _field(
                            _description,
                            'Комментарий',
                            minLines: 3,
                            maxLines: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _fileCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PpColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.folder_copy_outlined,
              color: PpColors.greenDark,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.document == null
                      ? 'Новый документ'
                      : 'Редактирование документа',
                  style: PpText.title(16),
                ),
                const SizedBox(height: 2),
                Text('Архив игрока футбольной школы', style: PpText.body(10.8)),
              ],
            ),
          ),
          _action(Icons.close_rounded, 'Закрыть', widget.onClose),
          const SizedBox(width: 7),
          _action(
            Icons.save_rounded,
            'Сохранить',
            _saving ? null : _save,
            primary: true,
          ),
        ],
      ),
    );
  }

  Widget _fileCard() {
    final shown = _shownFileName;
    return PpSurface(
      color: PpColors.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PpSectionTitle(
            title: 'Файл',
            subtitle: 'PDF, DOC, DOCX или изображение · до 20 МБ',
            dotColor: PpColors.amber,
            trailing: PpTextAction(
              label: shown.isEmpty ? 'Загрузить' : 'Заменить',
              onTap: _saving ? null : _pickFile,
              dotColor: PpColors.amber,
            ),
          ),
          const SizedBox(height: 10),
          if (shown.isEmpty)
            const SizedBox(
              height: 90,
              child: PpEmpty(
                title: 'Файл не выбран',
                text: 'Загрузите документ для просмотра внутри приложения',
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(_fileIcon(shown), color: PpColors.greenDark, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shown,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PpText.body(
                            10.8,
                            color: PpColors.text,
                            weight: FontWeight.w600,
                          ),
                        ),
                        if (_attachment != null) ...[
                          const SizedBox(height: 2),
                          Text(_formatBytes(_attachment!.size), style: PpText.caption()),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Убрать файл',
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _attachment = null;
                              _removeExistingFile = _existingUrl.isNotEmpty;
                            }),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: PpText.caption(
              size: 9.5,
              color: PpColors.muted2,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            cursorColor: PpColors.greenDark,
            style: PpText.body(
              11,
              color: PpColors.text,
              weight: FontWeight.w500,
            ),
            decoration: InputDecoration.collapsed(
              hintText: hint ?? 'Введите данные',
              hintStyle: PpText.body(
                10.6,
                color: PpColors.muted2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 9, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Тип документа',
            style: PpText.caption(
              size: 9.5,
              color: PpColors.muted2,
            ),
          ),
          const SizedBox(height: 1),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _category,
              isExpanded: true,
              isDense: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(10),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: PpColors.muted,
                size: 20,
              ),
              style: PpText.body(
                11,
                color: PpColors.text,
                weight: FontWeight.w500,
              ),
              items: PlayerDocumentEditorPanel.categories.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PpText.body(
                          10.6,
                          color: PpColors.text,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _saving
                  ? null
                  : (value) => setState(
                        () => _category = value ?? 'other',
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    bool primary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: primary ? PpColors.greenSoft : PpColors.soft2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 38,
            height: 38,
            child: _saving && primary
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PpColors.greenDark,
                    ),
                  )
                : Icon(
                    icon,
                    size: 19,
                    color: primary ? PpColors.greenDark : PpColors.text,
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'heic',
      ],
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.size > 20 * 1024 * 1024) {
      _message('Файл больше 20 МБ');
      return;
    }
    setState(() {
      _attachment = file;
      _removeExistingFile = false;
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _message('Укажите наименование документа');
      return;
    }
    if (_shownFileName.isEmpty) {
      _message('Выберите файл документа');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        <String, dynamic>{
          ...?widget.document,
          'document_title': _name.text.trim(),
          'document_category': _category,
          'document_number': _number.text.trim(),
          'document_issuer': _issuer.text.trim(),
          'issue_date': _issueDate.text.trim(),
          'expiry_date': _expiryDate.text.trim(),
          'description': _description.text.trim(),
          'remove_file': _removeExistingFile,
        },
        _attachment,
      );
      if (!mounted) return;
      _message('Документ сохранён');
      widget.onClose();
    } catch (error) {
      if (mounted) _message('Не удалось сохранить документ: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  String _fileNameFromUrl(String raw) {
    final uri = Uri.tryParse(raw);
    return uri != null && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : '';
  }

  IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (ext == 'doc' || ext == 'docx') return Icons.description_rounded;
    return Icons.image_rounded;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
}
