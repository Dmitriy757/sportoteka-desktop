import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'post_blocks.dart';

class CreatePostEditorScreen extends StatefulWidget {
  final String sportName;
  final bool isEdit;
  final int? postId;
  final String initialTitle;
  final String initialCoverUrl;
  final List<PostBlock> initialBlocks;

  const CreatePostEditorScreen({
    super.key,
    required this.sportName,
    this.isEdit = false,
    this.postId,
    this.initialTitle = "",
    this.initialCoverUrl = "",
    this.initialBlocks = const [],
  });

  @override
  State<CreatePostEditorScreen> createState() => _CreatePostEditorScreenState();
}

class _CreatePostEditorScreenState extends State<CreatePostEditorScreen> {
  static const _apiBase = "https://sportotekaapp.ru/api";

  final _title = TextEditingController();
  bool _saving = false;

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
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: const Color(0xFF00A750).withOpacity(0.7),
          width: 1.6,
        ),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            top: 12,
            bottom: 14 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              content,
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A750),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Добавить видео",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
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
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Добавить блок",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _addMenuTile(
                  icon: Icons.text_fields,
                  title: "Текст",
                  subtitle: "Обычный текстовый блок",
                  onTap: () {
                    Navigator.pop(context);
                    _addTextBlock();
                  },
                ),
                _addMenuTile(
                  icon: Icons.photo_library_outlined,
                  title: "Фото",
                  subtitle: "Загрузить изображение",
                  onTap: () {
                    Navigator.pop(context);
                    _addImageBlock();
                  },
                ),
                _addMenuTile(
                  icon: Icons.link,
                  title: "Ссылка",
                  subtitle: "Переход на сайт или страницу",
                  onTap: () {
                    Navigator.pop(context);
                    _addLinkBlock();
                  },
                ),
                _addMenuTile(
                  icon: Icons.play_circle_outline,
                  title: "Видео",
                  subtitle: "По ссылке или загрузить с телефона",
                  onTap: () {
                    Navigator.pop(context);
                    _addVideoBlock();
                  },
                ),
              ],
            ),
          ),
        );
      },
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w600,
                    ),
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
        Navigator.pop(context, true);
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
      Navigator.pop(context, true);
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
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 15,
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
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w700,
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
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 15,
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
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 15,
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
                      fit: BoxFit.cover,
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
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openUrl(b.url),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(
              direct ? "Открыть видео" : "Открыть источник",
              style: const TextStyle(fontWeight: FontWeight.w800),
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
            style: TextStyle(
              color: direct || externalPage
                  ? Colors.green.shade700
                  : Colors.orange.shade800,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isEdit ? "Редактирование поста" : "Новый пост",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A1A),
            fontSize: 16,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00A750), Color(0xFF008C40)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, color: Colors.white),
                label: Text(
                  widget.isEdit ? "Сохранить" : "Опубликовать",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Заголовок",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    hintText: "Введите заголовок…",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: const Color(0xFF00A750).withOpacity(0.7),
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Обложка (по желанию)",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _pickCover,
                        icon: const Icon(Icons.photo, color: Color(0xFF00A750)),
                        label: const Text(
                          "Выбрать обложку",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00A750),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (_newCoverFile != null) ...[
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => setState(() => _newCoverFile = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                if (_newCoverFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      _newCoverFile!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (_coverUrl.trim().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      _coverUrl,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const Text(
                    "Нет обложки",
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Контент (блоки)",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _showAddBlockMenu,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        "Добавить блок",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A750),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_blocks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        "Добавьте текст, фото, ссылку или видео",
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    children: List.generate(_blocks.length, (i) {
                      final b = _blocks[i];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "Блок ${i + 1}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: i == 0 ? null : () => _moveUp(i),
                                  icon: const Icon(Icons.arrow_upward, size: 18),
                                ),
                                IconButton(
                                  onPressed: i == _blocks.length - 1
                                      ? null
                                      : () => _moveDown(i),
                                  icon: const Icon(Icons.arrow_downward, size: 18),
                                ),
                                IconButton(
                                  onPressed: () => _deleteBlock(i),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (b is TextBlock) _buildTextBlockPreview(b, i),
                            if (b is ImageBlock)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: Image.network(
                                    b.url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (b is LinkBlock)
                              InkWell(
                                onTap: () => _editLinkBlock(i, b),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.link, color: Color(0xFF00A750)),
                                          SizedBox(width: 8),
                                          Text(
                                            "Ссылка",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      if (b.title.trim().isNotEmpty)
                                        Text(
                                          b.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      if (b.title.trim().isNotEmpty)
                                        const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: () => _openUrl(b.url),
                                        child: Text(
                                          b.url,
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            decoration: TextDecoration.underline,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (b is VideoBlock) _buildVideoPreview(b, i),
                          ],
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}