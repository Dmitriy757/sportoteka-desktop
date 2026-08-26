import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'post_blocks.dart';

class CreatePostEditorScreen extends StatefulWidget {
  final String sportName;
  final bool isEdit;
  final int? postId;
  final String initialTitle;
  final String initialCoverUrl;
  final List<PostBlock> initialBlocks;
  final bool embedded;
  final VoidCallback? onClose;
  final VoidCallback? onSaved;

  const CreatePostEditorScreen({
    super.key,
    required this.sportName,
    this.isEdit = false,
    this.postId,
    this.initialTitle = "",
    this.initialCoverUrl = "",
    this.initialBlocks = const [],
    this.embedded = false,
    this.onClose,
    this.onSaved,
  });

  @override
  State<CreatePostEditorScreen> createState() => _CreatePostEditorScreenState();
}

class _CreatePostEditorScreenState extends State<CreatePostEditorScreen> {
  static const _apiBase = "https://sportotekaapp.ru/api";

  final _title = TextEditingController();
  bool _saving = false;
  bool _showBlockLibrary = false;

  late List<PostBlock> _blocks;

  String _coverUrl = "";
  File? _newCoverFile;

  int _userId = 0;

  final RegExp _urlRegExp = RegExp(
    r'((https?:\/\/)|(www\.))([^\s]+)',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _title.text = widget.initialTitle;
    _blocks = List<PostBlock>.from(widget.initialBlocks);
    _coverUrl = widget.initialCoverUrl;
    _initUser();
  }

  Future<void> _initUser() async {
    final uid = await PrefUtils.getUserId() ?? 0;
    if (!mounted) return;
    setState(() => _userId = uid);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _snack(String t) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t)),
    );
  }

  bool _isValidUrl(String input) {
    final uri = Uri.tryParse(input.trim());
    return uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
  }

  String _normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
      return trimmed;
    }
    return "https://$trimmed";
  }

  bool _looksLikeDirectVideoUrl(String url) {
    final clean = url.toLowerCase().split('?').first.split('#').first;
    return clean.endsWith(".mp4") ||
        clean.endsWith(".mov") ||
        clean.endsWith(".m4v") ||
        clean.endsWith(".webm") ||
        clean.endsWith(".m3u8");
  }

  bool _looksLikeExternalVideoPage(String url) {
    final u = url.toLowerCase();
    return u.contains("youtube.com/") ||
        u.contains("youtu.be/") ||
        u.contains("vimeo.com/") ||
        u.contains("rutube.ru/") ||
        u.contains("vkvideo.ru/") ||
        u.contains("vk.com/video") ||
        u.contains("dailymotion.com/") ||
        u.contains("tiktok.com/") ||
        u.contains("drive.google.com/") ||
        u.contains("dropbox.com/");
  }

  String? _tryBuildAutoThumbnail(String url) {
    try {
      final uri = Uri.parse(url);

      if (uri.host.contains("youtu.be")) {
        if (uri.pathSegments.isNotEmpty) {
          final id = uri.pathSegments.first.trim();
          if (id.isNotEmpty) {
            return "https://img.youtube.com/vi/$id/hqdefault.jpg";
          }
        }
      }

      if (uri.host.contains("youtube.com")) {
        final v = uri.queryParameters["v"];
        if (v != null && v.trim().isNotEmpty) {
          return "https://img.youtube.com/vi/${v.trim()}/hqdefault.jpg";
        }

        final segments = uri.pathSegments;
        final shortsIndex = segments.indexOf("shorts");
        if (shortsIndex != -1 && shortsIndex + 1 < segments.length) {
          final id = segments[shortsIndex + 1].trim();
          if (id.isNotEmpty) {
            return "https://img.youtube.com/vi/$id/hqdefault.jpg";
          }
        }

        final embedIndex = segments.indexOf("embed");
        if (embedIndex != -1 && embedIndex + 1 < segments.length) {
          final id = segments[embedIndex + 1].trim();
          if (id.isNotEmpty) {
            return "https://img.youtube.com/vi/$id/hqdefault.jpg";
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> _openUrl(String url) async {
    final normalized = _normalizeUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      _snack("Некорректная ссылка");
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _snack("Не удалось открыть ссылку");
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: _editorText(
        10.6,
        color: const Color(0xFF98A2B3),
      ),
      filled: true,
      fillColor: const Color(0xFFF7F9F8),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<bool?> _showEditorSheet({
    required String title,
    required Widget content,
    required String buttonText,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            padding: EdgeInsets.fromLTRB(
              14,
              12,
              14,
              14 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(14),
                bottom: Radius.circular(14),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _brandDots(),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        title,
                        style: _editorText(
                          13.2,
                          weight: FontWeight.w600,
                          color: const Color(0xFF0B0F14),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                content,
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF00A750),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: _editorText(
                        10.8,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addTextBlock() async {
    final ctrl = TextEditingController();

    final ok = await _showEditorSheet(
      title: "Текст",
      buttonText: "Добавить",
      content: TextField(
        controller: ctrl,
        maxLines: 8,
        minLines: 4,
        decoration: _fieldDecoration("Напишите текст…"),
      ),
    );

    if (ok == true) {
      final text = ctrl.text.trim();
      if (text.isNotEmpty) {
        setState(() => _blocks.add(TextBlock(text)));
      }
    }
  }

  Future<void> _addImageBlock() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (x == null) return;

    final file = File(x.path);
    final url = await _uploadPostImage(file);
    if (url == null) return;

    setState(() => _blocks.add(ImageBlock(url)));
  }

  Future<void> _addLinkBlock() async {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    final ok = await _showEditorSheet(
      title: "Добавить ссылку",
      buttonText: "Добавить",
      content: Column(
        children: [
          TextField(
            controller: titleCtrl,
            decoration: _fieldDecoration("Название ссылки (по желанию)"),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: urlCtrl,
            keyboardType: TextInputType.url,
            decoration: _fieldDecoration("https://example.com"),
          ),
        ],
      ),
    );

    if (ok == true) {
      final url = _normalizeUrl(urlCtrl.text);
      final title = titleCtrl.text.trim();

      if (!_isValidUrl(url)) {
        _snack("Введите корректную ссылку");
        return;
      }

      setState(() {
        _blocks.add(LinkBlock(url: url, title: title));
      });
    }
  }

  Future<Map<String, String>?> _uploadPostVideo(File file) async {
    try {
      final req = http.MultipartRequest(
        "POST",
        Uri.parse("$_apiBase/upload_post_video.php"),
      );

      req.fields["user_id"] = _userId.toString();
      req.files.add(await http.MultipartFile.fromPath("video", file.path));

      final res = await req.send();
      final body = await res.stream.bytesToString();

      if (res.statusCode != 200) {
        _snack("Ошибка загрузки видео: HTTP ${res.statusCode}");
        return null;
      }

      final j = json.decode(body);
      if (j is! Map || j["success"] != true) {
        _snack("Ошибка загрузки видео: $body");
        return null;
      }

      final url = (j["url"] ?? "").toString();
      final thumbnail = (j["thumbnail"] ?? "").toString();

      if (url.isEmpty) {
        _snack("Сервер не вернул ссылку на видео");
        return null;
      }

      return {
        "url": url,
        "thumbnail": thumbnail,
      };
    } catch (e) {
      _snack("Ошибка загрузки видео: $e");
      return null;
    }
  }

  Future<void> _pickAndUploadVideo() async {
    if (_userId <= 0) {
      _snack("Не найден user_id");
      return;
    }

    final picker = ImagePicker();
    final x = await picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;

    final file = File(x.path);

    setState(() => _saving = true);

    try {
      final uploaded = await _uploadPostVideo(file);
      if (uploaded == null) return;

      final title = p.basenameWithoutExtension(file.path);

      setState(() {
        _blocks.add(
          VideoBlock(
            url: uploaded["url"] ?? "",
            title: title,
            thumbnail: uploaded["thumbnail"] ?? "",
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addVideoBlock() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Добавить видео",
                    style: AppTypography.screenTitle(),
                  ),
                ),
                const SizedBox(height: 12),
                _addMenuTile(
                  icon: Icons.link,
                  title: "Видео по ссылке",
                  subtitle: "Ссылка на видео или страницу с видео",
                  onTap: () async {
                    Navigator.pop(context);

                    final titleCtrl = TextEditingController();
                    final urlCtrl = TextEditingController();
                    final thumbCtrl = TextEditingController();

                    final ok = await _showEditorSheet(
                      title: "Добавить видео по ссылке",
                      buttonText: "Добавить",
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: titleCtrl,
                            decoration: _fieldDecoration(
                              "Название видео (по желанию)",
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: urlCtrl,
                            keyboardType: TextInputType.url,
                            decoration: _fieldDecoration(
                              "https://site.com/video или https://site.com/video.mp4",
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: thumbCtrl,
                            keyboardType: TextInputType.url,
                            decoration: _fieldDecoration(
                              "Ссылка на превью (по желанию)",
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Можно добавить ссылку с любого источника. Если это прямая ссылка на видеофайл, такое видео можно использовать внутри поста. Если это страница с видео, она будет открываться отдельно.",
                            style: AppTypography.secondaryMedium(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    );

                    if (ok == true) {
                      final url = _normalizeUrl(urlCtrl.text);
                      final title = titleCtrl.text.trim();
                      String thumb = _normalizeUrl(thumbCtrl.text);

                      if (!_isValidUrl(url)) {
                        _snack("Введите корректную ссылку");
                        return;
                      }

                      if (thumbCtrl.text.trim().isEmpty) {
                        thumb = _tryBuildAutoThumbnail(url) ?? "";
                      } else if (!_isValidUrl(thumb)) {
                        _snack("Некорректная ссылка на превью");
                        return;
                      }

                      setState(() {
                        _blocks.add(
                          VideoBlock(
                            url: url,
                            title: title,
                            thumbnail: thumb,
                          ),
                        );
                      });
                    }
                  },
                ),
                _addMenuTile(
                  icon: Icons.video_library_outlined,
                  title: "Загрузить видео",
                  subtitle: "Выбрать видео из галереи телефона",
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadVideo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editTextBlock(int i, TextBlock b) async {
    final ctrl = TextEditingController(text: b.text);

    final ok = await _showEditorSheet(
      title: "Редактировать текст",
      buttonText: "Сохранить",
      content: TextField(
        controller: ctrl,
        maxLines: 10,
        minLines: 5,
        decoration: _fieldDecoration("Введите текст"),
      ),
    );

    if (ok == true) {
      final t = ctrl.text.trim();
      setState(() => _blocks[i] = TextBlock(t));
    }
  }

  Future<void> _editLinkBlock(int i, LinkBlock b) async {
    final titleCtrl = TextEditingController(text: b.title);
    final urlCtrl = TextEditingController(text: b.url);

    final ok = await _showEditorSheet(
      title: "Редактировать ссылку",
      buttonText: "Сохранить",
      content: Column(
        children: [
          TextField(
            controller: titleCtrl,
            decoration: _fieldDecoration("Название ссылки"),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: urlCtrl,
            keyboardType: TextInputType.url,
            decoration: _fieldDecoration("https://example.com"),
          ),
        ],
      ),
    );

    if (ok == true) {
      final url = _normalizeUrl(urlCtrl.text);
      final title = titleCtrl.text.trim();

      if (!_isValidUrl(url)) {
        _snack("Введите корректную ссылку");
        return;
      }

      setState(() {
        _blocks[i] = LinkBlock(url: url, title: title);
      });
    }
  }

  Future<void> _editVideoBlock(int i, VideoBlock b) async {
    final titleCtrl = TextEditingController(text: b.title);
    final urlCtrl = TextEditingController(text: b.url);
    final thumbCtrl = TextEditingController(text: b.thumbnail);

    final ok = await _showEditorSheet(
      title: "Редактировать видео",
      buttonText: "Сохранить",
      content: Column(
        children: [
          TextField(
            controller: titleCtrl,
            decoration: _fieldDecoration("Название видео"),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: urlCtrl,
            keyboardType: TextInputType.url,
            decoration: _fieldDecoration(
              "https://site.com/video или https://site.com/video.mp4",
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: thumbCtrl,
            keyboardType: TextInputType.url,
            decoration: _fieldDecoration("Ссылка на превью"),
          ),
        ],
      ),
    );

    if (ok == true) {
      final url = _normalizeUrl(urlCtrl.text);
      final title = titleCtrl.text.trim();
      String thumb = _normalizeUrl(thumbCtrl.text);

      if (!_isValidUrl(url)) {
        _snack("Введите корректную ссылку");
        return;
      }

      if (thumbCtrl.text.trim().isEmpty) {
        thumb = _tryBuildAutoThumbnail(url) ?? "";
      } else if (!_isValidUrl(thumb)) {
        _snack("Некорректная ссылка на превью");
        return;
      }

      setState(() {
        _blocks[i] = VideoBlock(
          url: url,
          title: title,
          thumbnail: thumb,
        );
      });
    }
  }

  void _moveUp(int i) {
    if (i <= 0) return;
    setState(() {
      final tmp = _blocks[i - 1];
      _blocks[i - 1] = _blocks[i];
      _blocks[i] = tmp;
    });
  }

  void _moveDown(int i) {
    if (i >= _blocks.length - 1) return;
    setState(() {
      final tmp = _blocks[i + 1];
      _blocks[i + 1] = _blocks[i];
      _blocks[i] = tmp;
    });
  }

  void _deleteBlock(int i) {
    setState(() => _blocks.removeAt(i));
  }

  Future<void> _showAddBlockMenu() async {
    if (!mounted) return;
    setState(() => _showBlockLibrary = !_showBlockLibrary);
  }

  Widget _blockLibrary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAF6),
        borderRadius: BorderRadius.circular(9),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 390;
          final width = twoColumns
              ? (constraints.maxWidth - 6) / 2
              : constraints.maxWidth;

          final items = <Widget>[
            _blockTool(
              width: width,
              icon: Icons.text_fields_rounded,
              title: 'Текст',
              subtitle: 'Текстовый блок',
              accent: const Color(0xFF00A750),
              onTap: () {
                setState(() => _showBlockLibrary = false);
                _addTextBlock();
              },
            ),
            _blockTool(
              width: width,
              icon: Icons.photo_outlined,
              title: 'Фото',
              subtitle: 'Изображение',
              accent: const Color(0xFFF59E0B),
              onTap: () {
                setState(() => _showBlockLibrary = false);
                _addImageBlock();
              },
            ),
            _blockTool(
              width: width,
              icon: Icons.link_rounded,
              title: 'Ссылка',
              subtitle: 'Сайт или страница',
              accent: const Color(0xFF067A46),
              onTap: () {
                setState(() => _showBlockLibrary = false);
                _addLinkBlock();
              },
            ),
            _blockTool(
              width: width,
              icon: Icons.play_circle_outline_rounded,
              title: 'Видео',
              subtitle: 'Ссылка или файл',
              accent: const Color(0xFFF59E0B),
              onTap: () {
                setState(() => _showBlockLibrary = false);
                _addVideoBlock();
              },
            ),
          ];

          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items,
          );
        },
      ),
    );
  }

  Widget _blockTool({
    required double width,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 9,
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _softForAccent(accent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _statusDot(
                            color: accent,
                            size: 4.5,
                            glow: false,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              style: _editorText(
                                10.4,
                                weight: FontWeight.w600,
                                color: const Color(0xFF0B0F14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _editorText(9.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(9),
                  ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0x1400A750),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF00A750)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _editorText(
                      10.8,
                      weight: FontWeight.w600,
                      color: const Color(0xFF0B0F14),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: _editorText(9.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (x == null) return;
    setState(() => _newCoverFile = File(x.path));
  }

  Future<String?> _uploadPostImage(File file) async {
    try {
      final req = http.MultipartRequest(
        "POST",
        Uri.parse("$_apiBase/upload_post_image.php"),
      );
      req.fields["user_id"] = _userId.toString();
      req.files.add(await http.MultipartFile.fromPath("image", file.path));

      final res = await req.send();
      final body = await res.stream.bytesToString();

      if (res.statusCode != 200) {
        _snack("Ошибка загрузки фото: HTTP ${res.statusCode}");
        return null;
      }

      final j = json.decode(body);
      if (j is! Map || j["success"] != true) {
        _snack("Ошибка загрузки фото: $body");
        return null;
      }

      final url = (j["url"] ?? "").toString();
      if (url.isEmpty) {
        _snack("Не пришёл url картинки");
        return null;
      }
      return url;
    } catch (e) {
      _snack("Ошибка загрузки фото: $e");
      return null;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_userId <= 0) {
      _snack("Не найден user_id");
      return;
    }

    final title = _title.text.trim();
    final htmlBody = PostHtmlParser.blocksToHtml(_blocks);

    if (title.isEmpty &&
        htmlBody.isEmpty &&
        _newCoverFile == null &&
        _coverUrl.trim().isEmpty) {
      _snack("Пустой пост");
      return;
    }

    setState(() => _saving = true);

    try {
      if (widget.isEdit) {
        if ((widget.postId ?? 0) <= 0) {
          _snack("postId не передан");
          return;
        }

        final req = http.MultipartRequest(
          "POST",
          Uri.parse("$_apiBase/update_post.php"),
        );
        req.fields["post_id"] = widget.postId.toString();
        req.fields["user_id"] = _userId.toString();
        req.fields["title"] = title;
        req.fields["body"] = htmlBody;

        if (_newCoverFile != null) {
          req.files.add(
            await http.MultipartFile.fromPath("image", _newCoverFile!.path),
          );
        }

        final res = await req.send();
        final body = await res.stream.bytesToString();

        if (res.statusCode != 200) {
          _snack("Ошибка сохранения: HTTP ${res.statusCode}");
          return;
        }

        final j = json.decode(body);
        final ok = (j is Map) && (j["success"] == true || j["status"] == "ok");
        if (!ok) {
          _snack("Ошибка: $body");
          return;
        }

        if (!mounted) return;
        _finishEditor(saved: true);
        return;
      }

      final req = http.MultipartRequest(
        "POST",
        Uri.parse("$_apiBase/insert_post.php"),
      );
      req.fields["title"] = title.isNotEmpty ? title : widget.sportName;
      req.fields["body"] = htmlBody;
      req.fields["category"] = widget.sportName;
      req.fields["team"] = "";
      req.fields["author"] = "";
      req.fields["user_id"] = _userId.toString();
      req.fields["visibility"] = "feed";
      req.fields["post_type"] = "post";

      if (_newCoverFile != null) {
        req.files.add(
          await http.MultipartFile.fromPath("image", _newCoverFile!.path),
        );
      }

      final res = await req.send();
      final body = await res.stream.bytesToString();

      if (res.statusCode != 200) {
        _snack("Ошибка публикации: HTTP ${res.statusCode}");
        return;
      }

      final j = json.decode(body);
      final ok = (j is Map) &&
          (j["success"] == true || j["status"] == "ok" || j["created"] == true);
      if (!ok) {
        _snack("Ошибка: $body");
        return;
      }

      if (!mounted) return;
      _finishEditor(saved: true);
    } catch (e) {
      _snack("Ошибка: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<InlineSpan> _buildTextSpans(String text) {
    final spans = <InlineSpan>[];
    final matches = _urlRegExp.allMatches(text);

    int current = 0;

    for (final match in matches) {
      if (match.start > current) {
        spans.add(
          TextSpan(
            text: text.substring(current, match.start),
            style: AppTypography.body(
              color: const Color(0xFF1A1A1A),
            ).copyWith(
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      final rawUrl = text.substring(match.start, match.end);
      final normalized = _normalizeUrl(rawUrl);

      spans.add(
        TextSpan(
          text: rawUrl,
          style: AppTypography.bodyMedium(
            color: Colors.blue,
          ).copyWith(
            decoration: TextDecoration.underline,
            height: 1.45,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _openUrl(normalized);
            },
        ),
      );

      current = match.end;
    }

    if (current < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(current),
          style: AppTypography.body(
            color: const Color(0xFF1A1A1A),
          ).copyWith(
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (spans.isEmpty) {
      spans.add(
        TextSpan(
          text: text,
          style: AppTypography.body(
            color: const Color(0xFF1A1A1A),
          ).copyWith(
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return spans;
  }

  Widget _buildTextBlockPreview(TextBlock b, int index) {
    return GestureDetector(
      onTap: () => _editTextBlock(index, b),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(2),
        child: RichText(
          text: TextSpan(children: _buildTextSpans(b.text)),
        ),
      ),
    );
  }

  Widget _buildVideoPreview(VideoBlock b, int index) {
    final title = b.title.trim().isEmpty ? "Видео" : b.title;
    final direct = _looksLikeDirectVideoUrl(b.url);
    final externalPage = _looksLikeExternalVideoPage(b.url);

    return InkWell(
      onTap: () => _editVideoBlock(index, b),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b.thumbnail.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      b.thumbnail,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                    Container(color: Colors.black.withOpacity(0.20)),
                    const Center(
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.play_arrow,
                          color: Color(0xFF00A750),
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 170,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white,
                  child: Icon(
                    direct ? Icons.play_arrow : Icons.open_in_new,
                    color: const Color(0xFF00A750),
                    size: 30,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTypography.itemTitle(),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openUrl(b.url),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(
              direct ? "Открыть видео" : "Открыть источник",
              style: AppTypography.action(),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: const Color(0xFF00A750),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(0, 0),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            direct
                ? "Эта ссылка выглядит как прямой видеофайл."
                : externalPage
                    ? "Видео доступно по внешней ссылке."
                    : "Ссылка добавлена как внешний источник. При необходимости можно указать отдельное превью.",
            style: AppTypography.secondaryMedium(
              color: direct || externalPage
                  ? Colors.green.shade700
                  : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  void _finishEditor({required bool saved}) {
    if (widget.embedded) {
      if (saved) {
        widget.onSaved?.call();
      } else {
        widget.onClose?.call();
      }
      return;
    }
    Navigator.of(context).pop(saved);
  }

  Widget _brandDots({Color color = const Color(0xFF00A750)}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final item in const <(double, double)>[
          (3.5, .34),
          (4.5, .48),
          (5.5, .68),
          (6.5, 1.0),
        ]) ...[
          Container(
            width: item.$1,
            height: item.$1,
            decoration: BoxDecoration(
              color: color.withOpacity(item.$2),
              shape: BoxShape.circle,
              boxShadow: item.$2 >= .9
                  ? [
                      BoxShadow(
                        color: color.withOpacity(.16),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 3),
        ],
      ],
    );
  }

  Widget _statusDot({
    required Color color,
    double size = 5.5,
    bool glow = true,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withOpacity(.18),
                  blurRadius: size * 1.9,
                  spreadRadius: .25,
                ),
                BoxShadow(
                  color: color.withOpacity(.08),
                  blurRadius: size * 3.0,
                  spreadRadius: .5,
                ),
              ]
            : null,
      ),
    );
  }

  Color _blockAccent(PostBlock block) {
    if (block is ImageBlock) return const Color(0xFFF59E0B);
    if (block is VideoBlock) return const Color(0xFFF59E0B);
    if (block is LinkBlock) return const Color(0xFF067A46);
    if (block is TextBlock) return const Color(0xFF00A750);
    return const Color(0xFF8A9099);
  }

  String _blockKind(PostBlock block) {
    if (block is ImageBlock) return 'Фото';
    if (block is VideoBlock) return 'Видео';
    if (block is LinkBlock) return 'Ссылка';
    if (block is TextBlock) return 'Текст';
    return 'Блок';
  }

  Color _softForAccent(Color color) {
    if (color == const Color(0xFFF59E0B)) {
      return const Color(0xFFFFF7E8);
    }
    if (color == const Color(0xFFD92D20)) {
      return const Color(0xFFFFF1F1);
    }
    if (color == const Color(0xFF067A46) ||
        color == const Color(0xFF00A750)) {
      return const Color(0xFFF3FAF6);
    }
    return const Color(0xFFF7F9F8);
  }

  TextStyle _editorText(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = const Color(0xFF5F6670),
  }) {
    final TextStyle base;
    if (size >= 14) {
      base = AppTypography.sectionTitle(color: color);
    } else if (size >= 13) {
      base = AppTypography.subsectionTitle(color: color);
    } else if (size >= 11.2) {
      base = AppTypography.formText(color: color);
    } else if (size >= 10) {
      base = AppTypography.formHint(color: color);
    } else {
      base = AppTypography.commentMeta(color: color);
    }
    return base.copyWith(fontWeight: weight);
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    final editorBody = ListView(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 12 : 16,
        10,
        widget.embedded ? 12 : 16,
        24,
      ),
      children: _buildEditorChildren(),
    );

    final baseTheme = Theme.of(context);
    final themed = Theme(
      data: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(
          fontFamily: AppTypography.fontFamily,
          bodyColor: const Color(0xFF0B0F14),
          displayColor: const Color(0xFF0B0F14),
        ),
      ),
      child: editorBody,
    );

    if (widget.embedded) {
      return Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              constraints: BoxConstraints(minHeight: isPhone ? 74 : 56),
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
              color: Colors.white,
              child: Row(
                children: [
                  Material(
                    color: const Color(0xFFF7F9F8),
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      onTap: _saving
                          ? null
                          : () => _finishEditor(saved: false),
                      borderRadius: BorderRadius.circular(9),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: Color(0xFF5F6670),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  _brandDots(),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEdit
                              ? 'Редактирование публикации'
                              : 'Новая публикация',
                          style: _editorText(
                            13.6,
                            weight: FontWeight.w600,
                            color: const Color(0xFF0B0F14),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.sportName,
                          style: _editorText(9.6),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, isPhone ? 16 : 0),
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF00A750),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        widget.isEdit ? 'Сохранить' : 'Опубликовать',
                        style: _editorText(
                          10.3,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: themed),
          ],
        ),
      );
    }

    return Theme(
      data: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(
          fontFamily: AppTypography.fontFamily,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 14,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _brandDots(),
              const SizedBox(width: 8),
              Text(
                widget.isEdit ? 'Редактирование поста' : 'Новый пост',
                style: _editorText(
                  14,
                  weight: FontWeight.w600,
                  color: const Color(0xFF0B0F14),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF00A750),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text(
                  widget.isEdit ? 'Сохранить' : 'Опубликовать',
                  style: _editorText(
                    10.4,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: themed,
      ),
    );
  }

  List<Widget> _buildEditorChildren() {
    return <Widget>[
      _editorSection(
        title: 'Заголовок',
        subtitle: 'Коротко сформулируйте тему публикации',
        dotColor: _title.text.trim().isNotEmpty
            ? const Color(0xFF00A750)
            : const Color(0xFF8A9099),
        statusText: _title.text.trim().isNotEmpty
            ? 'Готово'
            : 'Не заполнено',
        child: TextField(
          controller: _title,
          onChanged: (_) => setState(() {}),
          style: _editorText(
            11.2,
            weight: FontWeight.w500,
            color: const Color(0xFF0B0F14),
          ),
          decoration: _fieldDecoration('Введите заголовок…'),
        ),
      ),
      const SizedBox(height: 8),
      _editorSection(
        title: 'Обложка',
        subtitle: 'Необязательно · фото для превью публикации',
        dotColor: _newCoverFile != null || _coverUrl.trim().isNotEmpty
            ? const Color(0xFFF59E0B)
            : const Color(0xFF8A9099),
        statusText: _newCoverFile != null || _coverUrl.trim().isNotEmpty
            ? 'Добавлена'
            : 'Не выбрана',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: const Color(0xFFF7F9F8),
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: _saving ? null : _pickCover,
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3FAF6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.photo_outlined,
                          size: 17,
                          color: Color(0xFF067A46),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _newCoverFile != null ||
                                  _coverUrl.trim().isNotEmpty
                              ? 'Заменить обложку'
                              : 'Выбрать обложку',
                          style: _editorText(
                            10.5,
                            weight: FontWeight.w600,
                            color: const Color(0xFF0B0F14),
                          ),
                        ),
                      ),
                      if (_newCoverFile != null)
                        IconButton(
                          tooltip: 'Убрать',
                          onPressed: () =>
                              setState(() => _newCoverFile = null),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                          ),
                        )
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 17,
                          color: Color(0xFF98A2B3),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_newCoverFile != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.file(
                  _newCoverFile!,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ] else if (_coverUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.network(
                  _coverUrl,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 8),
      _editorSection(
        title: 'Содержание',
        subtitle: 'Текст, фото, ссылки и видео в нужном порядке',
        dotColor: _blocks.isNotEmpty
            ? const Color(0xFF00A750)
            : const Color(0xFF8A9099),
        statusText: _blocks.isEmpty
            ? 'Пусто'
            : '${_blocks.length} ${_blocks.length == 1 ? 'блок' : 'блока'}',
        trailing: Material(
          color: _showBlockLibrary
              ? const Color(0xFFF3FAF6)
              : const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: _saving ? null : _showAddBlockMenu,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 7,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showBlockLibrary
                        ? Icons.close_rounded
                        : Icons.add_rounded,
                    size: 15,
                    color: const Color(0xFF067A46),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _showBlockLibrary ? 'Закрыть' : 'Добавить блок',
                    style: _editorText(
                      9.8,
                      weight: FontWeight.w600,
                      color: const Color(0xFF067A46),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showBlockLibrary) ...[
              _blockLibrary(),
              const SizedBox(height: 8),
            ],
            if (_blocks.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9F8),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    _statusDot(
                      color: const Color(0xFF8A9099),
                      size: 5,
                      glow: false,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Добавьте первый блок публикации',
                        style: _editorText(10.4),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: List.generate(_blocks.length, (i) {
                  final b = _blocks[i];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9F8),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _statusDot(
                              color: _blockAccent(b),
                              size: 5.5,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    _blockKind(b),
                                    style: _editorText(
                                      9.8,
                                      weight: FontWeight.w600,
                                      color: _blockAccent(b),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Блок ${i + 1}',
                                    style: _editorText(
                                      9.4,
                                      weight: FontWeight.w500,
                                      color: const Color(0xFF8A9099),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _blockAction(
                              Icons.arrow_upward_rounded,
                              i == 0 ? null : () => _moveUp(i),
                              'Выше',
                            ),
                            _blockAction(
                              Icons.arrow_downward_rounded,
                              i == _blocks.length - 1
                                  ? null
                                  : () => _moveDown(i),
                              'Ниже',
                            ),
                            _blockAction(
                              Icons.delete_outline_rounded,
                              () => _deleteBlock(i),
                              'Удалить',
                              danger: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        if (b is TextBlock)
                          _buildTextBlockPreview(b, i),
                        if (b is ImageBlock)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Image.network(
                                b.url,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    Container(
                                  color: const Color(0xFFEFF2F0),
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Color(0xFF98A2B3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (b is LinkBlock)
                          InkWell(
                            onTap: () => _editLinkBlock(i, b),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.link_rounded,
                                        color: Color(0xFF067A46),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        'Ссылка',
                                        style: _editorText(
                                          10.2,
                                          weight: FontWeight.w600,
                                          color:
                                              const Color(0xFF0B0F14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (b.title.trim().isNotEmpty) ...[
                                    const SizedBox(height: 7),
                                    Text(
                                      b.title,
                                      style: _editorText(
                                        10.8,
                                        weight: FontWeight.w600,
                                        color:
                                            const Color(0xFF0B0F14),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 5),
                                  GestureDetector(
                                    onTap: () => _openUrl(b.url),
                                    child: Text(
                                      b.url,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: _editorText(
                                        9.6,
                                        weight: FontWeight.w500,
                                        color:
                                            const Color(0xFF067A46),
                                      ).copyWith(
                                        decoration:
                                            TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (b is VideoBlock)
                          _buildVideoPreview(b, i),
                      ],
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _editorSection({
    required String title,
    required String subtitle,
    required Widget child,
    required Color dotColor,
    String? statusText,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _statusDot(
                  color: dotColor,
                  size: 6,
                  glow: dotColor != const Color(0xFF8A9099),
                ),
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
                            style: _editorText(
                              11.5,
                              weight: FontWeight.w600,
                              color: const Color(0xFF0B0F14),
                            ),
                          ),
                        ),
                        if (statusText != null && statusText!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _softForAccent(dotColor),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              statusText!,
                              style: _editorText(
                                8.9,
                                weight: FontWeight.w600,
                                color: dotColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: _editorText(9.6),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }


  Widget _blockAction(
    IconData icon,
    VoidCallback? onTap,
    String tooltip, {
    bool danger = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            width: 29,
            height: 29,
            child: Icon(
              icon,
              size: 15,
              color: onTap == null
                  ? const Color(0xFFD0D5DD)
                  : danger
                      ? const Color(0xFFD92D20)
                      : const Color(0xFF667085),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}