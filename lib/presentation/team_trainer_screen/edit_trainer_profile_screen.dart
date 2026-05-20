import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/utils/media_utils.dart';

class EditTrainerProfileScreen extends StatefulWidget {
  final int trainerId;
  final String trainerName;

  const EditTrainerProfileScreen({
    super.key,
    required this.trainerId,
    required this.trainerName,
  });

  @override
  State<EditTrainerProfileScreen> createState() => _EditTrainerProfileScreenState();
}

class _EditTrainerProfileScreenState extends State<EditTrainerProfileScreen> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getUrl = '$apiBase/get_trainer_profile.php';
  static const String saveUrl = '$apiBase/update_trainer_profile.php';

  bool loading = true;
  bool saving = false;
  String? error;

  final TextEditingController positionC = TextEditingController();
  final TextEditingController birthdayC = TextEditingController();
  final TextEditingController experienceC = TextEditingController();
  final TextEditingController bioC = TextEditingController();

  String? photoUrl;
  File? photoFile;
  XFile? newPhotoFile;

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final body = resp.body.trim();
      final start = body.indexOf('{');
      final raw = start >= 0 ? body.substring(start) : body;
      final j = json.decode(raw);
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return {'status': 'error', 'message': 'bad json', 'raw': resp.body};
  }

  String _asStr(dynamic v) => (v ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    positionC.dispose();
    birthdayC.dispose();
    experienceC.dispose();
    bioC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final resp = await http.post(
        Uri.parse(getUrl),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'trainer_id': widget.trainerId}),
      );

      final data = _decode(resp);

      if (data['status'] == 'success' && data['trainer'] is Map) {
        final t = Map<String, dynamic>.from(data['trainer']);

        positionC.text = _asStr(t['position']).trim();
        bioC.text = _asStr(t['bio']).trim();
        experienceC.text = _asStr(t['experience']).trim();

        final b = _asStr(t['birthday']).trim();
        birthdayC.text = (b.length >= 10) ? b.substring(0, 10) : b;

        final rawPhoto = _asStr(t['photo']).trim();
        photoUrl = MediaUtils.normalizeUrl(rawPhoto);

        if (mounted) setState(() => loading = false);
      } else {
        if (!mounted) return;
        setState(() {
          loading = false;
          error = _asStr(data['message']).isEmpty ? 'Не удалось загрузить профиль тренера' : _asStr(data['message']);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Ошибка загрузки: $e';
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final XFile? x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1400,
    );
    if (x == null) return;

    setState(() {
      newPhotoFile = x;
      photoFile = File(x.path);
    });
  }

  Future<void> _pickBirthday() async {
    DateTime initial = DateTime(2000, 1, 1);

    final raw = birthdayC.text.trim();
    if (raw.length >= 10) {
      final y = int.tryParse(raw.substring(0, 4));
      final m = int.tryParse(raw.substring(5, 7));
      final d = int.tryParse(raw.substring(8, 10));
      if (y != null && m != null && d != null) initial = DateTime(y, m, d);
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: CmrTrainerPalette.primary,
                  surface: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    final yyyy = picked.year.toString().padLeft(4, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    birthdayC.text = '$yyyy-$mm-$dd';
    setState(() {});
  }

  bool _validBirthday(String s) {
    if (s.trim().isEmpty) return true;
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s.trim());
  }

  Future<void> _save() async {
    final birthday = birthdayC.text.trim();
    if (!_validBirthday(birthday)) {
      _showSnack('Дата рождения', 'Формат должен быть YYYY-MM-DD. Например: 2008-05-17');
      return;
    }

    setState(() => saving = true);

    try {
      final req = http.MultipartRequest('POST', Uri.parse(saveUrl));

      req.fields['trainer_id'] = widget.trainerId.toString();
      req.fields['position'] = positionC.text.trim();
      req.fields['birthday'] = birthday;
      req.fields['experience'] = experienceC.text.trim();
      req.fields['bio'] = bioC.text.trim();

      if (newPhotoFile != null) {
        req.files.add(await http.MultipartFile.fromPath('photo', newPhotoFile!.path));
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp);

      if (data['status'] == 'success' || data['success'] == true) {
        final p = _asStr(data['photo']).trim();
        if (p.isNotEmpty) photoUrl = MediaUtils.normalizeUrl(p) ?? photoUrl;
        newPhotoFile = null;

        _showSnack('Готово', 'Визитка тренера сохранена');

        if (mounted) Navigator.pop(context, true);
      } else {
        _showSnack('Ошибка', _asStr(data['message']).isEmpty ? 'Не удалось сохранить' : _asStr(data['message']));
      }
    } catch (e) {
      _showSnack('Сеть', 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _showSnack(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(14),
      borderRadius: 18,
      backgroundColor: Colors.white,
      colorText: CmrTrainerPalette.text,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CmrTrainerPalette.bg,
      appBar: _CmrTrainerAppBar(
        title: 'Визитка тренера',
        subtitle: 'Единый профиль специалиста клуба',
        loading: loading,
        saving: saving,
        onRefresh: _load,
      ),
      bottomNavigationBar: _BottomSaveBar(
        loading: loading,
        saving: saving,
        onSave: _save,
      ),
      body: loading
          ? const _LoadingView()
          : error != null
              ? _ErrorView(text: error!, onRetry: _load)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final isTablet = width >= 820;
                    final maxWidth = isTablet ? 1180.0 : double.infinity;

                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 24 : 16,
                            isTablet ? 20 : 14,
                            isTablet ? 24 : 16,
                            28,
                          ),
                          child: isTablet ? _tabletLayout() : _mobileLayout(),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _tabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 340,
          child: Column(
            children: [
              _TrainerIdentityCard(
                name: widget.trainerName,
                trainerId: widget.trainerId,
                position: positionC.text,
                birthday: birthdayC.text,
                photoUrl: photoUrl,
                photoFile: photoFile,
                onPick: saving ? null : _pickPhoto,
              ),
              const SizedBox(height: 14),
              const _CoachTipsCard(),
              const SizedBox(height: 14),
              _ProfileCompletenessCard(
                position: positionC.text,
                birthday: birthdayC.text,
                experience: experienceC.text,
                bio: bioC.text,
                hasPhoto: photoFile != null || (photoUrl != null && photoUrl!.trim().isNotEmpty),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: [
              _FormPanel(
                title: 'Основные данные',
                subtitle: 'Эта информация отображается в карточке тренера и в панели клуба.',
                icon: const _TacticIcon(size: 26),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CmrField(
                          label: 'Должность / роль',
                          hint: 'Например: главный тренер, тренер по ОФП',
                          controller: positionC,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CmrDateField(
                          label: 'Дата рождения',
                          hint: 'YYYY-MM-DD',
                          controller: birthdayC,
                          onPick: _pickBirthday,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _FormPanel(
                title: 'Опыт и специализация',
                subtitle: 'Клубы, лицензии, стаж, направления работы, возрастные группы.',
                icon: const _WhistleIcon(size: 26),
                children: [
                  _CmrMultilineField(
                    label: 'Опыт / карьера',
                    hint: 'Например: 8 лет в академии, лицензия UEFA C, подготовка защитников...',
                    controller: experienceC,
                    minLines: 5,
                    maxLines: 8,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _FormPanel(
                title: 'Описание тренера',
                subtitle: 'Коротко и понятно: подход к тренировкам, сильные стороны, формат работы.',
                icon: const _CoachBoardIcon(size: 26),
                children: [
                  _CmrMultilineField(
                    label: 'Описание',
                    hint: 'Например: делаю акцент на дисциплине, командном взаимодействии и развитии игровых решений...',
                    controller: bioC,
                    minLines: 6,
                    maxLines: 10,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mobileLayout() {
    return Column(
      children: [
        _TrainerIdentityCard(
          name: widget.trainerName,
          trainerId: widget.trainerId,
          position: positionC.text,
          birthday: birthdayC.text,
          photoUrl: photoUrl,
          photoFile: photoFile,
          onPick: saving ? null : _pickPhoto,
        ),
        const SizedBox(height: 14),
        _FormPanel(
          title: 'Основные данные',
          subtitle: 'Карточка тренера в панели клуба.',
          icon: const _TacticIcon(size: 24),
          children: [
            _CmrField(
              label: 'Должность / роль',
              hint: 'Главный тренер, тренер по ОФП...',
              controller: positionC,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _CmrDateField(
              label: 'Дата рождения',
              hint: 'YYYY-MM-DD',
              controller: birthdayC,
              onPick: _pickBirthday,
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _CoachTipsCard(),
        const SizedBox(height: 14),
        _FormPanel(
          title: 'Опыт и специализация',
          subtitle: 'Поможет родителям и клубу понять профиль тренера.',
          icon: const _WhistleIcon(size: 24),
          children: [
            _CmrMultilineField(
              label: 'Опыт / карьера',
              hint: 'Клубы, лицензии, стаж, направления работы...',
              controller: experienceC,
              minLines: 4,
              maxLines: 7,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _FormPanel(
          title: 'Описание тренера',
          subtitle: 'Краткая визитка без лишнего текста.',
          icon: const _CoachBoardIcon(size: 24),
          children: [
            _CmrMultilineField(
              label: 'Описание',
              hint: 'Подход к тренировкам, сильные стороны, стиль работы...',
              controller: bioC,
              minLines: 5,
              maxLines: 9,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProfileCompletenessCard(
          position: positionC.text,
          birthday: birthdayC.text,
          experience: experienceC.text,
          bio: bioC.text,
          hasPhoto: photoFile != null || (photoUrl != null && photoUrl!.trim().isNotEmpty),
        ),
      ],
    );
  }
}

class CmrTrainerPalette {
  static const Color bg = Color(0xFFF7F9FB);
  static const Color surface = Colors.white;
  static const Color text = Color(0xFF17212B);
  static const Color muted = Color(0xFF6B7785);
  static const Color faint = Color(0xFFE9EEF3);
  static const Color primary = Color(0xFF00A750);
  static const Color primarySoft = Color(0xFFEAF8F0);
  static const Color blue = Color(0xFF2563EB);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color dark = Color(0xFF0F172A);
}

class _CmrTrainerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final bool loading;
  final bool saving;
  final VoidCallback onRefresh;

  const _CmrTrainerAppBar({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.saving,
    required this.onRefresh,
  });

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 74,
      backgroundColor: CmrTrainerPalette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 58,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: _RoundIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Назад',
            onTap: () => Navigator.maybePop(context),
          ),
        ),
      ),
      titleSpacing: 8,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CmrTrainerPalette.text,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CmrTrainerPalette.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        _RoundIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Обновить',
          onTap: saving || loading ? null : onRefresh,
        ),
        const SizedBox(width: 14),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: CmrTrainerPalette.faint),
      ),
    );
  }
}

class _BottomSaveBar extends StatelessWidget {
  final bool loading;
  final bool saving;
  final VoidCallback onSave;

  const _BottomSaveBar({
    required this.loading,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: const BoxDecoration(
          color: CmrTrainerPalette.surface,
          border: Border(top: BorderSide(color: CmrTrainerPalette.faint)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 420 : double.infinity),
                child: _PrimaryActionButton(
                  text: saving ? 'Сохраняю...' : 'Сохранить визитку',
                  icon: saving ? null : Icons.check_rounded,
                  loading: saving,
                  onTap: (loading || saving) ? null : onSave,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TrainerIdentityCard extends StatelessWidget {
  final String name;
  final int trainerId;
  final String position;
  final String birthday;
  final String? photoUrl;
  final File? photoFile;
  final VoidCallback? onPick;

  const _TrainerIdentityCard({
    required this.name,
    required this.trainerId,
    required this.position,
    required this.birthday,
    required this.photoUrl,
    required this.photoFile,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return _CmrCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrainerAvatar(
                photoUrl: photoUrl,
                photoFile: photoFile,
                onPick: onPick,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MiniLabel('ТРЕНЕР КЛУБА'),
                    const SizedBox(height: 6),
                    Text(
                      name.trim().isEmpty ? 'Тренер #$trainerId' : name.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CmrTrainerPalette.text,
                        fontSize: 22,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SoftPill(
                          text: position.trim().isEmpty ? 'Роль не указана' : position.trim(),
                          color: CmrTrainerPalette.primary,
                        ),
                        _SoftPill(
                          text: birthday.trim().isEmpty ? 'Дата не указана' : birthday.trim(),
                          color: CmrTrainerPalette.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CmrTrainerPalette.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: const [
                _FootballCircleIcon(size: 38),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Заполненная визитка делает профиль тренера понятным для клуба, родителей и игроков.',
                    style: TextStyle(
                      color: CmrTrainerPalette.text,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
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
}

class _TrainerAvatar extends StatelessWidget {
  final String? photoUrl;
  final File? photoFile;
  final VoidCallback? onPick;

  const _TrainerAvatar({
    required this.photoUrl,
    required this.photoFile,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (photoFile != null) {
      image = Image.file(photoFile!, width: 82, height: 82, fit: BoxFit.cover);
    } else if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      image = Image.network(
        photoUrl!.trim(),
        width: 82,
        height: 82,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _AvatarFallback(),
      );
    } else {
      image = const _AvatarFallback();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: CmrTrainerPalette.primary.withOpacity(0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(child: image),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onPick == null ? CmrTrainerPalette.muted : CmrTrainerPalette.primary,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 17),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: CmrTrainerPalette.primarySoft,
      ),
      child: const Icon(Icons.person_outline_rounded, color: CmrTrainerPalette.primary, size: 36),
    );
  }
}

class _FormPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final List<Widget> children;

  const _FormPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return _CmrCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconShell(child: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: CmrTrainerPalette.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: CmrTrainerPalette.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _CmrField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const _CmrField({
    required this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: CmrTrainerPalette.text, fontWeight: FontWeight.w800),
      decoration: _inputDecoration(label: label, hint: hint),
    );
  }
}

class _CmrMultilineField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _CmrMultilineField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.minLines,
    required this.maxLines,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(color: CmrTrainerPalette.text, fontWeight: FontWeight.w700, height: 1.3),
      decoration: _inputDecoration(label: label, hint: hint),
    );
  }
}

class _CmrDateField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onPick;

  const _CmrDateField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onPick,
      style: const TextStyle(color: CmrTrainerPalette.text, fontWeight: FontWeight.w800),
      decoration: _inputDecoration(label: label, hint: hint).copyWith(
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: CmrTrainerPalette.primary),
            onPressed: onPick,
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({required String label, required String hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: CmrTrainerPalette.muted, fontWeight: FontWeight.w800),
    hintStyle: TextStyle(color: CmrTrainerPalette.muted.withOpacity(0.72), fontWeight: FontWeight.w600),
    filled: true,
    fillColor: const Color(0xFFFAFBFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: CmrTrainerPalette.faint),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: CmrTrainerPalette.primary, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: CmrTrainerPalette.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: CmrTrainerPalette.red, width: 1.4),
    ),
  );
}

class _CoachTipsCard extends StatelessWidget {
  const _CoachTipsCard();

  @override
  Widget build(BuildContext context) {
    return _CmrCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _MiniLabel('ПОДСКАЗКИ'),
          SizedBox(height: 10),
          _TipRow(number: '1', text: 'Фото должно хорошо читаться в составе и карточке клуба.'),
          SizedBox(height: 10),
          _TipRow(number: '2', text: 'В должности лучше писать коротко: главный тренер, тренер вратарей.'),
          SizedBox(height: 10),
          _TipRow(number: '3', text: 'В опыте укажите лицензии, стаж, команды и сильные стороны.'),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String number;
  final String text;

  const _TipRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: CmrTrainerPalette.primarySoft,
          ),
          child: Text(
            number,
            style: const TextStyle(color: CmrTrainerPalette.primary, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: CmrTrainerPalette.text, fontWeight: FontWeight.w700, height: 1.28),
          ),
        ),
      ],
    );
  }
}

class _ProfileCompletenessCard extends StatelessWidget {
  final String position;
  final String birthday;
  final String experience;
  final String bio;
  final bool hasPhoto;

  const _ProfileCompletenessCard({
    required this.position,
    required this.birthday,
    required this.experience,
    required this.bio,
    required this.hasPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      hasPhoto,
      position.trim().isNotEmpty,
      birthday.trim().isNotEmpty,
      experience.trim().isNotEmpty,
      bio.trim().isNotEmpty,
    ];
    final filled = items.where((e) => e).length;
    final progress = filled / items.length;

    return _CmrCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _MiniLabel('ГОТОВНОСТЬ ПРОФИЛЯ')),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(color: CmrTrainerPalette.primary, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress,
              backgroundColor: CmrTrainerPalette.faint,
              valueColor: const AlwaysStoppedAnimation<Color>(CmrTrainerPalette.primary),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(text: 'Фото', done: hasPhoto),
              _StatusChip(text: 'Роль', done: position.trim().isNotEmpty),
              _StatusChip(text: 'Дата', done: birthday.trim().isNotEmpty),
              _StatusChip(text: 'Опыт', done: experience.trim().isNotEmpty),
              _StatusChip(text: 'Описание', done: bio.trim().isNotEmpty),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final bool done;

  const _StatusChip({required this.text, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: done ? CmrTrainerPalette.primarySoft : const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 15,
            color: done ? CmrTrainerPalette.primary : CmrTrainerPalette.muted,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: done ? CmrTrainerPalette.primary : CmrTrainerPalette.muted,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CmrCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _CmrCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: CmrTrainerPalette.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.055),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconShell extends StatelessWidget {
  final Widget child;

  const _IconShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CmrTrainerPalette.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _SoftPill extends StatelessWidget {
  final String text;
  final Color color;

  const _SoftPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final String text;

  const _MiniLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: CmrTrainerPalette.muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.9,
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onTap;

  const _PrimaryActionButton({
    required this.text,
    this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            color: onTap == null ? CmrTrainerPalette.muted.withOpacity(0.35) : CmrTrainerPalette.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: onTap == null
                ? []
                : [
                    BoxShadow(
                      color: CmrTrainerPalette.primary.withOpacity(0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 9),
                    ),
                  ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 21),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _RoundIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: onTap == null ? CmrTrainerPalette.muted : CmrTrainerPalette.text, size: 21),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: CmrTrainerPalette.primary),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _ErrorView({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _CmrCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _FootballCircleIcon(size: 58),
              const SizedBox(height: 14),
              const Text(
                'Не удалось загрузить данные',
                textAlign: TextAlign.center,
                style: TextStyle(color: CmrTrainerPalette.text, fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CmrTrainerPalette.muted, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _PrimaryActionButton(text: 'Повторить', icon: Icons.refresh_rounded, loading: false, onTap: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

class _FootballCircleIcon extends StatelessWidget {
  final double size;

  const _FootballCircleIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FootballPainter()),
    );
  }
}

class _FootballPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;
    final bg = Paint()..color = CmrTrainerPalette.primary;
    canvas.drawCircle(center, r, bg);

    final field = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08;
    canvas.drawCircle(center, r * 0.72, field);

    final ball = Paint()..color = Colors.white;
    canvas.drawCircle(center, r * 0.28, ball);

    final seam = Paint()
      ..color = CmrTrainerPalette.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx - r * 0.18, center.dy), Offset(center.dx + r * 0.18, center.dy), seam);
    canvas.drawLine(Offset(center.dx, center.dy - r * 0.18), Offset(center.dx, center.dy + r * 0.18), seam);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TacticIcon extends StatelessWidget {
  final double size;

  const _TacticIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _TacticPainter()));
  }
}

class _TacticPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = CmrTrainerPalette.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = CmrTrainerPalette.primary;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.18)),
      p,
    );
    canvas.drawLine(Offset(size.width * 0.5, size.height * 0.08), Offset(size.width * 0.5, size.height * 0.92), p);
    canvas.drawCircle(Offset(size.width * 0.30, size.height * 0.30), size.width * 0.075, dot);
    canvas.drawCircle(Offset(size.width * 0.70, size.height * 0.38), size.width * 0.075, dot);
    canvas.drawCircle(Offset(size.width * 0.36, size.height * 0.72), size.width * 0.075, dot);
    canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.72), size.width * 0.075, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WhistleIcon extends StatelessWidget {
  final double size;

  const _WhistleIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _WhistlePainter()));
  }
}

class _WhistlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = CmrTrainerPalette.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = CmrTrainerPalette.primary.withOpacity(0.14);

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.10, size.height * 0.33, size.width * 0.58, size.height * 0.38),
      Radius.circular(size.width * 0.16),
    );
    canvas.drawRRect(body, fill);
    canvas.drawRRect(body, p);
    canvas.drawCircle(Offset(size.width * 0.39, size.height * 0.52), size.width * 0.10, p);
    canvas.drawLine(Offset(size.width * 0.68, size.height * 0.42), Offset(size.width * 0.92, size.height * 0.28), p);
    canvas.drawLine(Offset(size.width * 0.70, size.height * 0.62), Offset(size.width * 0.92, size.height * 0.62), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CoachBoardIcon extends StatelessWidget {
  final double size;

  const _CoachBoardIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _CoachBoardPainter()));
  }
}

class _CoachBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = CmrTrainerPalette.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = CmrTrainerPalette.primary.withOpacity(0.12);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.13, size.height * 0.10, size.width * 0.74, size.height * 0.70),
      Radius.circular(size.width * 0.12),
    );
    canvas.drawRRect(rect, fill);
    canvas.drawRRect(rect, p);
    canvas.drawLine(Offset(size.width * 0.28, size.height * 0.30), Offset(size.width * 0.72, size.height * 0.30), p);
    canvas.drawLine(Offset(size.width * 0.28, size.height * 0.48), Offset(size.width * 0.60, size.height * 0.48), p);
    canvas.drawLine(Offset(size.width * 0.38, size.height * 0.86), Offset(size.width * 0.62, size.height * 0.86), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
