import 'package:flutter/material.dart';

import '../../../data/services/video_lessons_service.dart';
import '../cmr_video_lessons_theme.dart';

class CreateVideoFolderDialog extends StatefulWidget {
  final int userId;
  final int? parentId;

  const CreateVideoFolderDialog({
    super.key,
    required this.userId,
    this.parentId,
  });

  @override
  State<CreateVideoFolderDialog> createState() =>
      _CreateVideoFolderDialogState();
}

class _CreateVideoFolderDialogState extends State<CreateVideoFolderDialog> {
  final TextEditingController _titleController = TextEditingController();

  bool _saving = false;
  String _selectedColor = '#00A750';

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  final List<String> _colors = const <String>[
    '#00A750',
    '#008C40',
    '#2563EB',
    '#7C3AED',
    '#F59E0B',
    '#EF4444',
    '#0EA5E9',
    '#EC4899',
  ];

  @override
  void dispose() {
    _titleController.removeListener(_refresh);
    _titleController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return CmrVideoColors.green;
    }
  }

  Future<void> _createFolder() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      final ok = await VideoLessonsService.createFolder(
        userId: widget.userId,
        title: title,
        color: _selectedColor,
        parentId: widget.parentId,
      );
      if (mounted) Navigator.of(context).pop(ok);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ошибка создания папки: $e',
            style: CmrVideoText.body(11, color: Colors.white),
          ),
        ),
      );
    }
  }

  Widget _colorItem(String hex) {
    final selected = _selectedColor == hex;
    final color = _parseColor(hex);

    return Tooltip(
      message: hex,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saving ? null : () => setState(() => _selectedColor = hex),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: selected ? 18 : 14,
                height: selected ? 18 : 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: color.withOpacity(.20),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CmrVideoDialogShell(
      title: 'Новая папка',
      subtitle: 'Создайте раздел для хранения видеоуроков',
      maxWidth: 430,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _titleController,
            autofocus: true,
            enabled: !_saving,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _createFolder(),
            cursorColor: CmrVideoColors.greenDark,
            style: CmrVideoText.body(
              11,
              color: CmrVideoColors.text,
              weight: FontWeight.w500,
            ),
            decoration: cmrVideoInputDecoration(
              'Название папки',
              hint: 'Например: Техника удара',
            ),
          ),
          const SizedBox(height: 13),
          const CmrVideoSectionTitle(
            title: 'Цвет папки',
            subtitle: 'Небольшой цветовой маркер для навигации',
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: CmrVideoColors.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _colors.map(_colorItem).toList(growable: false),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        CmrVideoTextButton(
          label: 'Отмена',
          onTap: _saving ? null : () => Navigator.of(context).pop(false),
        ),
        CmrVideoTextButton(
          label: 'Создать',
          primary: true,
          onTap: _saving || _titleController.text.trim().isEmpty
              ? null
              : _createFolder,
          leading: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
