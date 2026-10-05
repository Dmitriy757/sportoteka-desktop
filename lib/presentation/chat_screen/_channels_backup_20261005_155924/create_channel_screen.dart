import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/theme/app_typography.dart';

class _ChannelCreateUi {
  static const Color bg = Color(0xFFF6F7F9);
  static const Color card = Colors.white;
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color border = Color(0xFFE8ECEA);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF667085);

  static TextStyle title(double size) {
    final base = size >= 16
        ? AppTypography.screenTitle(color: text)
        : size >= 13.4
            ? AppTypography.subsectionTitle(color: text)
            : AppTypography.itemTitle(color: text);
    return base.copyWith(fontWeight: FontWeight.w700);
  }

  static TextStyle mutedText(double size) {
    final base = size >= 11.5
        ? AppTypography.secondary(color: muted)
        : AppTypography.caption(color: muted);
    return base.copyWith(fontWeight: FontWeight.w500);
  }
}

class CreateChannelScreen extends StatefulWidget {
  final int userId;

  const CreateChannelScreen({
    super.key,
    required this.userId,
  });

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  static const _apiBase = 'https://sportotekaapp.ru/api';

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _usernameController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _avatar;
  bool _isPublic = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _normaliseUsername(String raw) {
    var value = raw.trim().toLowerCase();
    if (value.startsWith('@')) value = value.substring(1);
    value = value.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return value;
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1400,
      maxHeight: 1400,
    );
    if (picked == null || !mounted) return;
    setState(() => _avatar = picked);
  }

  Future<int?> _resolveCreatedChatId(String name) async {
    try {
      final uri = Uri.parse('$_apiBase/get_groups_feed.php?user_id=${widget.userId}');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final decoded = json.decode(res.body);
      final raw = decoded is Map ? decoded['groups'] : null;
      if (raw is! List) return null;

      final candidates = raw.whereType<Map>().where((entry) {
        final owner = int.tryParse('${entry['owner_id'] ?? 0}') ?? 0;
        final title = (entry['name'] ?? entry['title'] ?? '').toString().trim();
        return owner == widget.userId && title == name;
      }).toList();
      if (candidates.isEmpty) return null;
      candidates.sort((a, b) {
        final ai = int.tryParse('${a['id'] ?? 0}') ?? 0;
        final bi = int.tryParse('${b['id'] ?? 0}') ?? 0;
        return bi.compareTo(ai);
      });
      return int.tryParse('${candidates.first['id'] ?? 0}');
    } catch (_) {
      return null;
    }
  }

  Future<void> _createChannel() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final username = _normaliseUsername(_usernameController.text);

    if (name.length < 2) {
      _toast('Введите название канала');
      return;
    }
    if (username.isNotEmpty && username.length < 4) {
      _toast('Адрес канала должен быть не короче 4 символов');
      return;
    }

    setState(() => _submitting = true);
    try {
      // Канал остаётся совместимым с текущей системой сообщений: сначала
      // создаём базовый групповой чат, затем регистрируем его как канал.
      final createRes = await http.post(
        Uri.parse('$_apiBase/create_group_chat.php'),
        body: <String, String>{
          'user_id': widget.userId.toString(),
          'name': name,
          'is_public': _isPublic ? '1' : '0',
          'members': jsonEncode(<int>[widget.userId]),
        },
      ).timeout(const Duration(seconds: 15));

      dynamic createData;
      try {
        createData = json.decode(createRes.body);
      } catch (_) {
        createData = null;
      }
      final createOk = createRes.statusCode == 200 &&
          createData is Map &&
          createData['success'] == true;
      if (!createOk) {
        final error = createData is Map
            ? (createData['error'] ?? createData['message'] ?? 'Ошибка создания')
            : 'HTTP ${createRes.statusCode}';
        _toast('Не удалось создать канал: $error');
        return;
      }

      int? chatId;
      if (createData is Map) {
        chatId = int.tryParse(
          '${createData['chat_id'] ?? createData['group_id'] ?? createData['id'] ?? createData['data']?['id'] ?? ''}',
        );
      }
      chatId ??= await _resolveCreatedChatId(name);
      if (chatId == null || chatId <= 0) {
        _toast('Канал создан, но не удалось определить ID чата. Обновите список и повторите.');
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiBase/channel_register.php'),
      )
        ..fields['chat_id'] = chatId.toString()
        ..fields['owner_id'] = widget.userId.toString()
        ..fields['name'] = name
        ..fields['description'] = description
        ..fields['username'] = username
        ..fields['is_public'] = _isPublic ? '1' : '0';

      if (_avatar != null) {
        request.files.add(
          await http.MultipartFile.fromPath('avatar', _avatar!.path),
        );
      }

      final streamed = await request.send().timeout(const Duration(seconds: 20));
      final registerRes = await http.Response.fromStream(streamed);
      dynamic registerData;
      try {
        registerData = json.decode(registerRes.body);
      } catch (_) {
        registerData = null;
      }
      final registerOk = registerRes.statusCode == 200 &&
          registerData is Map &&
          registerData['success'] == true;
      if (!registerOk) {
        final error = registerData is Map
            ? (registerData['error'] ?? registerData['message'] ?? 'Ошибка регистрации канала')
            : 'HTTP ${registerRes.statusCode}';
        // Не оставляем в списке скрытую «группу-сироту», если регистрация
        // канала не прошла (например, занят публичный адрес).
        try {
          await http.post(
            Uri.parse('$_apiBase/delete_group_force.php'),
            body: <String, String>{
              'chat_id': chatId.toString(),
              'user_id': widget.userId.toString(),
            },
          ).timeout(const Duration(seconds: 8));
        } catch (_) {}
        _toast('Не удалось создать канал: $error');
        return;
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _toast('Ошибка сети: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              fixedSize: const Size(40, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _ChannelCreateUi.greenSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: _ChannelCreateUi.greenDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Новый канал', style: _ChannelCreateUi.title(17)),
                const SizedBox(height: 3),
                Text(
                  _isPublic
                      ? 'Открытый · подписка сразу'
                      : 'Закрытый · вступление по заявке',
                  style: _ChannelCreateUi.mutedText(11.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, size: 18),
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _ChannelCreateUi.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _ChannelCreateUi.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _ChannelCreateUi.green),
        ),
      ),
      style: AppTypography.formText(color: _ChannelCreateUi.text),
    );
  }

  Widget _avatarCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: _pickAvatar,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 72,
              height: 72,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _ChannelCreateUi.greenSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _ChannelCreateUi.border),
              ),
              child: _avatar == null
                  ? const Icon(
                      Icons.add_a_photo_rounded,
                      color: _ChannelCreateUi.greenDark,
                    )
                  : Image.file(File(_avatar!.path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Логотип канала', style: _ChannelCreateUi.title(13.6)),
                const SizedBox(height: 4),
                Text(
                  'Квадратное изображение будет показано в списке и в шапке канала.',
                  style: _ChannelCreateUi.mutedText(10.8),
                ),
                const SizedBox(height: 7),
                TextButton.icon(
                  onPressed: _pickAvatar,
                  icon: const Icon(Icons.photo_library_outlined, size: 17),
                  label: Text(_avatar == null ? 'Выбрать' : 'Заменить'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacyCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _ChannelCreateUi.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                  color: _ChannelCreateUi.greenDark,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _isPublic ? 'Открытый канал' : 'Закрытый канал',
                      style: _ChannelCreateUi.title(13.6),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isPublic
                          ? 'Любой пользователь сможет сразу подписаться.'
                          : 'Пользователь отправит заявку, а вы примете или отклоните её.',
                      style: _ChannelCreateUi.mutedText(10.8),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isPublic,
                activeColor: _ChannelCreateUi.green,
                onChanged: (value) => setState(() => _isPublic = value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _ChannelCreateUi.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Канал работает как вещание: публикуют владелец и назначенные администраторы, подписчики читают сообщения и используют доступные реакции.',
              style: _ChannelCreateUi.mutedText(10.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ChannelCreateUi.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _header(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  MediaQuery.paddingOf(context).bottom + 18,
                ),
                children: <Widget>[
                  _avatarCard(),
                  const SizedBox(height: 9),
                  _field(
                    controller: _nameController,
                    hint: 'Название канала',
                    icon: Icons.edit_rounded,
                    maxLength: 80,
                  ),
                  const SizedBox(height: 9),
                  _field(
                    controller: _descriptionController,
                    hint: 'Описание канала',
                    icon: Icons.notes_rounded,
                    maxLines: 4,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 9),
                  _field(
                    controller: _usernameController,
                    hint: '@адрес_канала — необязательно',
                    icon: Icons.alternate_email_rounded,
                    maxLength: 32,
                  ),
                  const SizedBox(height: 9),
                  _privacyCard(),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _createChannel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ChannelCreateUi.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.campaign_rounded, size: 18),
                    label: Text(
                      _submitting ? 'Создаём...' : 'Создать канал',
                      style: AppTypography.actionStrong(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
