import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class PostComposerScreen extends StatefulWidget {
  final Map<String, dynamic>? initialPost;
  final String? selectedCategory;
  final String? selectedTeam;

  const PostComposerScreen({
    super.key,
    this.initialPost,
    this.selectedCategory,
    this.selectedTeam,
  });

  bool get isEditing => initialPost != null;

  @override
  State<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends State<PostComposerScreen> {
  static const _apiBase = 'https://sportotekaapp.ru/api';
  static const _green = Color(0xFF00A750);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF667085);
  static const _line = Color(0xFFE5E7EB);
  static const _soft = Color(0xFFF7F8FA);

  final _picker = ImagePicker();
  late final TextEditingController _captionController;
  late final TextEditingController _titleController;
  final FocusNode _captionFocus = FocusNode();

  XFile? _pickedImage;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final post = widget.initialPost ?? const <String, dynamic>{};
    _captionController = TextEditingController(
      text: _text(post['body'] ?? post['text'] ?? post['caption']),
    );
    _titleController = TextEditingController(text: _text(post['title']));
  }

  @override
  void dispose() {
    _captionController.dispose();
    _titleController.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  String _text(dynamic value) => (value ?? '').toString().trim();

  String _imageUrl(dynamic raw) {
    final value = _text(raw);
    if (value.isEmpty || value.toLowerCase() == 'null') return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final clean = value.startsWith('/') ? value.substring(1) : value;
    return 'https://sportotekaapp.ru/$clean';
  }

  String get _existingImageUrl {
    final post = widget.initialPost;
    if (post == null) return '';
    return _imageUrl(
      post['image'] ?? post['image_url'] ?? post['photo'] ?? post['cover'],
    );
  }

  Future<void> _showImageSourceSheet() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: const _ComposerIcon(Icons.photo_library_outlined),
                  title: const Text(
                    'Выбрать из медиатеки',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Фото для публикации'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) ...[
                  const SizedBox(height: 4),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: const _ComposerIcon(Icons.photo_camera_outlined),
                    title: const Text(
                      'Снять фото',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Открыть камеру'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2400,
      );
      if (image == null || !mounted) return;
      setState(() {
        _pickedImage = image;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось открыть изображение: $e');
    }
  }

  void _insertHash() {
    final value = _captionController.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? start : selection.end;
    final before = value.text.substring(0, start);
    final after = value.text.substring(end);
    final prefix = before.isEmpty || RegExp(r'\s$').hasMatch(before) ? '#' : ' #';
    final inserted = '$prefix$after';
    final text = '$before$inserted';
    final cursor = before.length + prefix.length;
    _captionController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _captionFocus.requestFocus();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final caption = _captionController.text.trim();
    final hasExistingImage = _existingImageUrl.isNotEmpty;
    if (caption.isEmpty && _pickedImage == null && !hasExistingImage) {
      setState(() => _error = 'Добавьте подпись или фотографию.');
      return;
    }

    final userId = await PrefUtils.getUserId();
    if (userId == null || userId <= 0) {
      if (mounted) setState(() => _error = 'Не удалось определить пользователя.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final post = widget.initialPost;
      final editing = post != null;
      final endpoint = editing ? '$_apiBase/update_post.php' : '$_apiBase/insert_post.php';
      final request = http.MultipartRequest('POST', Uri.parse(endpoint));

      request.fields['user_id'] = userId.toString();
      request.fields['title'] = _titleController.text.trim();
      request.fields['body'] = caption;

      if (post != null) {
        final postId = int.tryParse('${post['id'] ?? post['post_id'] ?? 0}') ?? 0;
        if (postId <= 0) throw Exception('Не найден id публикации');
        request.fields['post_id'] = postId.toString();
      } else {
        request.fields['category'] = (widget.selectedCategory ?? '').trim();
        request.fields['team'] = (widget.selectedTeam ?? '').trim();
        request.fields['author'] = '';
        request.fields['visibility'] = 'profile';
        request.fields['post_type'] = 'post';
      }

      if (_pickedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _pickedImage!.path),
        );
      }

      final streamed = await request.send().timeout(const Duration(seconds: 35));
      final responseBody = await streamed.stream.bytesToString();
      dynamic data;
      try {
        data = responseBody.trim().isEmpty ? null : jsonDecode(responseBody);
      } catch (_) {
        data = null;
      }

      final success = streamed.statusCode >= 200 &&
          streamed.statusCode < 300 &&
          (data == null ||
              data is! Map ||
              data['success'] == true ||
              data['status'] == 'ok' ||
              data['status'] == 'success');

      if (!success) {
        final message = data is Map
            ? _text(data['message'] ?? data['error'])
            : responseBody.trim();
        throw Exception(message.isEmpty ? 'Сервер вернул ${streamed.statusCode}' : message);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final compact = mq.size.width < 700;
    final hasPreview = _pickedImage != null || _existingImageUrl.isNotEmpty;
    final category = (widget.selectedCategory ?? '').trim();
    final team = (widget.selectedTeam ?? '').trim();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Закрыть',
          onPressed: _submitting ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: _ink),
        ),
        titleSpacing: 2,
        title: Text(
          widget.isEditing ? 'Редактировать' : 'Новая публикация',
          style: const TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Text(
                    widget.isEditing ? 'Готово' : 'Поделиться',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _line),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                compact ? 0 : 18,
                12,
                compact ? 0 : 18,
                30 + mq.padding.bottom,
              ),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 0),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: _soft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: _ink,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ваш профиль',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Публикация появится от вашего имени',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (hasPreview)
                  _buildMediaPreview(compact)
                else
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 0),
                    child: _buildEmptyMedia(),
                  ),
                const SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _line),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _captionController,
                            focusNode: _captionFocus,
                            minLines: 4,
                            maxLines: 10,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 16,
                              height: 1.42,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'Добавьте подпись…',
                              hintStyle: TextStyle(
                                color: Color(0xFF98A2B3),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Divider(height: 18, color: _line),
                          Row(
                            children: [
                              _ComposerMiniButton(
                                icon: Icons.tag_rounded,
                                label: 'Хэштег',
                                onTap: _insertHash,
                              ),
                              const SizedBox(width: 8),
                              _ComposerMiniButton(
                                icon: Icons.image_outlined,
                                label: hasPreview ? 'Заменить фото' : 'Фото',
                                onTap: _showImageSourceSheet,
                              ),
                              const Spacer(),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _captionController,
                                builder: (_, value, __) {
                                  return Text(
                                    '${value.text.characters.length}',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 0),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 2),
                    childrenPadding: const EdgeInsets.only(bottom: 10),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: const Text(
                      'Дополнительно',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: const Text(
                      'Заголовок и контекст публикации',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      TextField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Заголовок (необязательно)',
                          filled: true,
                          fillColor: _soft,
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      if (category.isNotEmpty || team.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (category.isNotEmpty)
                                _ComposerContextChip(
                                  icon: Icons.sports_soccer_rounded,
                                  text: category,
                                ),
                              if (team.isNotEmpty)
                                _ComposerContextChip(
                                  icon: Icons.groups_2_outlined,
                                  text: team,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFD92D20),
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFB42318),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyMedia() {
    return InkWell(
      onTap: _showImageSourceSheet,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 260,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ComposerIcon(Icons.add_photo_alternate_outlined, large: true),
            SizedBox(height: 12),
            Text(
              'Добавить фотографию',
              style: TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Можно опубликовать и только текст',
              style: TextStyle(
                color: _muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(bool compact) {
    final preview = _pickedImage != null
        ? Image.file(
            File(_pickedImage!.path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        : Image.network(
            _existingImageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined, color: _muted, size: 36),
            ),
          );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 0),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 0 : 20),
              child: ColoredBox(color: _soft, child: preview),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black.withOpacity(0.58),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Заменить фото',
                  onPressed: _showImageSourceSheet,
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerIcon extends StatelessWidget {
  final IconData icon;
  final bool large;

  const _ComposerIcon(this.icon, {this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: large ? 58 : 42,
      height: large ? 58 : 42,
      decoration: BoxDecoration(
        color: _PostComposerScreenState._green.withOpacity(.10),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: _PostComposerScreenState._green,
        size: large ? 28 : 21,
      ),
    );
  }
}

class _ComposerMiniButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ComposerMiniButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _PostComposerScreenState._soft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _PostComposerScreenState._line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _PostComposerScreenState._ink),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: _PostComposerScreenState._ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerContextChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ComposerContextChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _PostComposerScreenState._soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _PostComposerScreenState._line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _PostComposerScreenState._muted),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _PostComposerScreenState._ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
