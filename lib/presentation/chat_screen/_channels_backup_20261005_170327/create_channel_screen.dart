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
  static const Color greenSoft = Color(0xFFF0FAF5);
  static const Color mint = Color(0xFFE2F7EA);
  static const Color border = Color(0xFFE3E9E6);
  static const Color line = Color(0xFFEDF1EF);
  static const Color dark = Color(0xFF101714);
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

  Widget _brandDots({Color color = _ChannelCreateUi.green, bool compact = false}) {
    final scale = compact ? .78 : 1.0;
    Widget dot(double size, double opacity) => Container(
          width: size * scale,
          height: size * scale,
          decoration: BoxDecoration(
            color: color.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        dot(3.4, .32),
        SizedBox(width: 3 * scale),
        dot(4.4, .55),
        SizedBox(width: 3 * scale),
        dot(5.4, .78),
        SizedBox(width: 3 * scale),
        dot(6.4, 1),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: _ChannelCreateUi.line, width: .7),
        ),
      ),
      child: Row(
        children: <Widget>[
          Material(
            color: _ChannelCreateUi.greenSoft,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(11),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: _ChannelCreateUi.greenDark,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _brandDots(compact: true),
                    const SizedBox(width: 7),
                    Text(
                      'SPORTOTEKA',
                      style: AppTypography.caption(color: _ChannelCreateUi.greenDark)
                          .copyWith(fontWeight: FontWeight.w800, letterSpacing: .9),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Создание канала', style: _ChannelCreateUi.title(16.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: _isPublic
                  ? _ChannelCreateUi.greenSoft
                  : const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _isPublic ? Icons.public_rounded : Icons.lock_rounded,
                  size: 12,
                  color: _isPublic
                      ? _ChannelCreateUi.greenDark
                      : const Color(0xFFB76B00),
                ),
                const SizedBox(width: 4),
                Text(
                  _isPublic ? 'Открытый' : 'Закрытый',
                  style: AppTypography.caption(
                    color: _isPublic
                        ? _ChannelCreateUi.greenDark
                        : const Color(0xFFB76B00),
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      height: 142,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF087A49),
            Color(0xFF00A750),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1600A750),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -28,
            top: -46,
            child: Container(
              width: 138,
              height: 138,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x38FFFFFF), width: 18),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: -34,
            child: Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x10FFFFFF),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: <Widget>[
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0x19FFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x34FFFFFF)),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    size: 29,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _brandDots(color: Colors.white, compact: true),
                          const SizedBox(width: 7),
                          Text(
                            'CHANNEL',
                            style: AppTypography.caption(color: Colors.white)
                                .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Создай своё пространство',
                        style: AppTypography.screenTitle(color: Colors.white)
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Новости, материалы и сообщения для своей аудитории в SPORTOTEKA.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.secondary(color: const Color(0xE8FFFFFF))
                            .copyWith(height: 1.22),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _ChannelCreateUi.greenSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: _ChannelCreateUi.greenDark, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: _ChannelCreateUi.title(12.8)),
                const SizedBox(height: 1),
                Text(subtitle, style: _ChannelCreateUi.mutedText(9.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(13)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ChannelCreateUi.border, width: .7),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: _ChannelCreateUi.title(11.8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _ChannelCreateUi.mutedText(10.8),
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 17, color: _ChannelCreateUi.greenDark),
            filled: true,
            fillColor: _ChannelCreateUi.bg,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _ChannelCreateUi.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _ChannelCreateUi.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _ChannelCreateUi.green, width: 1.3),
            ),
          ),
          style: AppTypography.formText(color: _ChannelCreateUi.text),
        ),
      ],
    );
  }

  Widget _avatarCard() {
    return _card(
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: _pickAvatar,
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: 76,
                  height: 76,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: _avatar == null
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0xFFE2F7EA),
                              Color(0xFFF6FBF8),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _ChannelCreateUi.border),
                  ),
                  child: _avatar == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(
                              Icons.add_photo_alternate_rounded,
                              color: _ChannelCreateUi.greenDark,
                              size: 25,
                            ),
                            const SizedBox(height: 5),
                            _brandDots(compact: true),
                          ],
                        )
                      : Image.file(File(_avatar!.path), fit: BoxFit.cover),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: _ChannelCreateUi.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: Icon(
                      _avatar == null ? Icons.add_rounded : Icons.edit_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Логотип канала', style: _ChannelCreateUi.title(13.6)),
                const SizedBox(height: 4),
                Text(
                  'Используется в списке каналов, поиске и в шапке публикаций.',
                  style: _ChannelCreateUi.mutedText(10.5).copyWith(height: 1.25),
                ),
                const SizedBox(height: 8),
                Material(
                  color: _ChannelCreateUi.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _pickAvatar,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.photo_library_outlined,
                              size: 15, color: _ChannelCreateUi.greenDark),
                          const SizedBox(width: 6),
                          Text(
                            _avatar == null ? 'Выбрать изображение' : 'Заменить',
                            style: AppTypography.caption(color: _ChannelCreateUi.greenDark)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacyOption({
    required bool public,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _isPublic == public;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: () => setState(() => _isPublic = public),
          borderRadius: BorderRadius.circular(15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: selected ? _ChannelCreateUi.greenSoft : _ChannelCreateUi.bg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected ? _ChannelCreateUi.green : _ChannelCreateUi.border,
                width: selected ? 1.2 : .7,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 31,
                      height: 31,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : _ChannelCreateUi.greenSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 16, color: _ChannelCreateUi.greenDark),
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? _ChannelCreateUi.green : Colors.white,
                        border: Border.all(
                          color: selected ? _ChannelCreateUi.green : _ChannelCreateUi.border,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(title, style: _ChannelCreateUi.title(12.3)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: _ChannelCreateUi.mutedText(9.7).copyWith(height: 1.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _privacyCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _privacyOption(
                public: true,
                title: 'Открытый',
                subtitle: 'Виден в поиске. Подписка сразу.',
                icon: Icons.public_rounded,
              ),
              const SizedBox(width: 8),
              _privacyOption(
                public: false,
                title: 'Закрытый',
                subtitle: 'Вступление только после одобрения.',
                icon: Icons.lock_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _ChannelCreateUi.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _ChannelCreateUi.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _ChannelCreateUi.greenSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 15,
                    color: _ChannelCreateUi.greenDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Публикации создают владелец и администраторы. Подписчики читают сообщения и используют доступные реакции.',
                    style: _ChannelCreateUi.mutedText(9.9).copyWith(height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _createButton() {
    final enabled = !_submitting;
    return AnimatedOpacity(
      opacity: enabled ? 1 : .72,
      duration: const Duration(milliseconds: 120),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: enabled ? _createChannel : null,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  Color(0xFF087A49),
                  Color(0xFF00A750),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1800A750),
                  blurRadius: 13,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (_submitting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(Icons.campaign_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _submitting ? 'Создаём канал...' : 'Создать канал',
                  style: AppTypography.actionStrong(color: Colors.white),
                ),
                if (!_submitting) ...<Widget>[
                  const SizedBox(width: 10),
                  _brandDots(color: Colors.white, compact: true),
                ],
              ],
            ),
          ),
        ),
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
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  MediaQuery.paddingOf(context).bottom + 18,
                ),
                children: <Widget>[
                  _hero(),
                  const SizedBox(height: 14),
                  _sectionLabel(
                    'Оформление',
                    'Логотип и визуальная идентичность канала',
                    Icons.auto_awesome_rounded,
                  ),
                  _avatarCard(),
                  const SizedBox(height: 14),
                  _sectionLabel(
                    'Информация',
                    'Так пользователи увидят канал в SPORTOTEKA',
                    Icons.article_outlined,
                  ),
                  _card(
                    child: Column(
                      children: <Widget>[
                        _field(
                          controller: _nameController,
                          label: 'Название канала',
                          hint: 'Например: Академия SPORTOTEKA',
                          icon: Icons.edit_rounded,
                          maxLength: 80,
                        ),
                        const SizedBox(height: 11),
                        _field(
                          controller: _descriptionController,
                          label: 'Описание',
                          hint: 'О чём канал и для кого он создан',
                          icon: Icons.notes_rounded,
                          maxLines: 4,
                          maxLength: 500,
                        ),
                        const SizedBox(height: 11),
                        _field(
                          controller: _usernameController,
                          label: 'Публичный адрес',
                          hint: '@academy_sportoteka — необязательно',
                          icon: Icons.alternate_email_rounded,
                          maxLength: 32,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionLabel(
                    'Доступ',
                    'Кто сможет найти канал и подписаться',
                    Icons.shield_outlined,
                  ),
                  _privacyCard(),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: _ChannelCreateUi.line, width: .7),
                  ),
                ),
                child: _createButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
