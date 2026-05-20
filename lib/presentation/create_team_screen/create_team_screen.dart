import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final TextEditingController teamNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  static const String fixedSportCategory = 'Футбол';

  bool isLoading = false;
  File? _logoFile;

  Future<void> _pickLogo() async {
    try {
      final XFile? x = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (x == null) return;
      setState(() => _logoFile = File(x.path));
    } catch (e) {
      Get.snackbar('Ошибка', 'Не удалось выбрать логотип: $e');
    }
  }

  Future<void> createTeam() async {
    final teamName = teamNameController.text.trim();
    final coachId = await PrefUtils.getUserId();

    if (teamName.isEmpty || coachId == null) {
      Get.snackbar('Ошибка', 'Введите название команды и авторизуйтесь как тренер');
      return;
    }

    setState(() => isLoading = true);

    final uri = Uri.parse('https://sportotekaapp.ru/api/create_team.php');

    try {
      final req = http.MultipartRequest('POST', uri);
      req.fields['team_name'] = teamName;
      req.fields['coach_id'] = coachId.toString();

      // Вид спорта зафиксирован по умолчанию.
      req.fields['category'] = fixedSportCategory;

      if (_logoFile != null && await _logoFile!.exists()) {
        final fileName = p.basename(_logoFile!.path);
        req.files.add(
          await http.MultipartFile.fromPath(
            'logo',
            _logoFile!.path,
            filename: fileName,
          ),
        );
      }

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();

      Map<String, dynamic> json;
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('Сервер вернул не JSON: $body');
      }

      if (json['status'] == 'success') {
        final teamId = json['team_id'];
        await PrefUtils.setTeamId(teamId);
        Get.snackbar('Успех', 'Команда создана');
        Get.toNamed(AppRoutes.myTeamScreen);
      } else {
        Get.snackbar('Ошибка', (json['message'] ?? 'Не удалось создать команду').toString());
      }
    } catch (e) {
      Get.snackbar('Ошибка', 'Ошибка подключения: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    teamNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final bool isTablet = width >= 760;
    final bool isWide = width >= 1040;

    return Scaffold(
      backgroundColor: _C.background,
      appBar: _CmrAppBar(
        isTablet: isTablet,
        onBack: () => Get.back(),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = isTablet ? 28.0 : 16.0;
            final maxWidth = isWide ? 1180.0 : 860.0;

            final content = Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: isWide
                    ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _MainFormCard(
                                logoFile: _logoFile,
                                isLoading: isLoading,
                                teamNameController: teamNameController,

                                onPickLogo: _pickLogo,
                                onRemoveLogo: () => setState(() => _logoFile = null),

                                onCreate: createTeam,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: const [
                                  _CmrHeroPanel(),
                                  SizedBox(height: 14),
                                  _HelpPanel(),
                                ],
                              ),
                            ),
                          ],
                        )
                    : Column(
                          children: [
                            const _CmrHeroPanel(),
                            const SizedBox(height: 14),
                            _MainFormCard(
                              logoFile: _logoFile,
                              isLoading: isLoading,
                              teamNameController: teamNameController,

                              onPickLogo: _pickLogo,
                              onRemoveLogo: () => setState(() => _logoFile = null),

                              onCreate: createTeam,
                            ),
                            const SizedBox(height: 14),
                            const _HelpPanel(),
                          ],
                        ),
              ),
            );

            // На планшете/широком экране не включаем внутреннюю прокрутку,
            // чтобы форма ощущалась как цельная CMR-панель.
            // На телефоне прокрутка оставлена только как защита от маленькой высоты экрана.
            if (isTablet) {
              return Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 24),
                child: content,
              );
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
              child: content,
            );
          },
        ),
      ),
    );
  }
}

class _CmrAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isTablet;
  final VoidCallback onBack;

  const _CmrAppBar({required this.isTablet, required this.onBack});

  @override
  Size get preferredSize => Size.fromHeight(isTablet ? 76 : 64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      centerTitle: false,
      backgroundColor: _C.surface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.only(right: isTablet ? 24 : 16),
        child: Row(
          children: [
            const SizedBox(width: 10),
            _CircleIconButton(
              onTap: onBack,
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: _C.text),
            ),
            const SizedBox(width: 12),
            Container(
              width: isTablet ? 42 : 38,
              height: isTablet ? 42 : 38,
              decoration: BoxDecoration(
                color: _C.primaryGreen.withOpacity(.10),
                shape: BoxShape.circle,
                border: Border.all(color: _C.primaryGreen.withOpacity(.20)),
              ),
              child: CustomPaint(painter: _BallBadgePainter(color: _C.primaryGreen)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Создание команды',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isTablet ? 21 : 18,
                      fontWeight: FontWeight.w900,
                      color: _C.text,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Единый стиль панели клуба',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 11,
                      fontWeight: FontWeight.w700,
                      color: _C.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.border),
      ),
    );
  }
}

class _CmrHeroPanel extends StatelessWidget {
  const _CmrHeroPanel();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 760;

    return _CmrCard(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -24,
            child: CustomPaint(
              size: const Size(150, 150),
              painter: _PitchLinesPainter(color: _C.primaryGreen.withOpacity(.10)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: isTablet ? 52 : 46,
                    height: isTablet ? 52 : 46,
                    decoration: BoxDecoration(
                      color: _C.primaryGreen,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _C.primaryGreen.withOpacity(.25),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: CustomPaint(painter: _WhistlePainter(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Tag(text: 'Панель тренера'),
                        const SizedBox(height: 7),
                        Text(
                          'Новая команда в системе клуба',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isTablet ? 22 : 18,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                            color: _C.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Заполните основные данные и добавьте логотип. Вид спорта уже закреплён как футбол, чтобы команда сразу попала в правильный раздел рабочей панели.',
                style: TextStyle(
                  fontSize: isTablet ? 13.5 : 12.5,
                  height: 1.45,
                  color: _C.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _MiniFeature(label: 'Состав', iconType: _FeatureIconType.players, color: _C.blue),
                  _MiniFeature(label: 'Матчи', iconType: _FeatureIconType.field, color: _C.orange),
                  _MiniFeature(label: 'Тренировки', iconType: _FeatureIconType.cone, color: _C.primaryGreen),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MainFormCard extends StatelessWidget {
  final File? logoFile;
  final bool isLoading;
  final TextEditingController teamNameController;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;
  final VoidCallback onCreate;

  const _MainFormCard({
    required this.logoFile,
    required this.isLoading,
    required this.teamNameController,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 760;

    return _CmrCard(
      padding: EdgeInsets.all(isTablet ? 22 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Основные данные',
            subtitle: 'Минимум полей, чтобы быстро создать рабочую команду',
            icon: CustomPaint(painter: _ShieldPainter(color: _C.primaryGreen)),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _LogoPickerBlock(
            logoFile: logoFile,
            isLoading: isLoading,
            onPickLogo: onPickLogo,
            onRemoveLogo: onRemoveLogo,
          ),
          const SizedBox(height: 18),
          _CmrTextField(
            controller: teamNameController,
            label: 'Название команды',
            hint: 'Например: Спортотека U-12',
            helper: 'Название будет видно игрокам, родителям и тренерам.',
          ),
          const SizedBox(height: 16),
          const _FixedFootballField(),
          const SizedBox(height: 20),
          _AlertHint(
            title: 'Совет',
            text: 'Вид спорта закреплён как «Футбол». Это убирает лишний выбор и сразу ведёт команду в футбольную структуру клуба.',
          ),
          SizedBox(height: isTablet ? 24 : 20),
          _CreateButton(
            isLoading: isLoading,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _LogoPickerBlock extends StatelessWidget {
  final File? logoFile;
  final bool isLoading;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;

  const _LogoPickerBlock({
    required this.logoFile,
    required this.isLoading,
    required this.onPickLogo,
    required this.onRemoveLogo,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 760;

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: _C.soft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: isLoading ? null : onPickLogo,
            child: Container(
              width: isTablet ? 92 : 78,
              height: isTablet ? 92 : 78,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _C.primaryGreen.withOpacity(.24), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: _C.primaryGreen.withOpacity(.10),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: logoFile != null
                    ? Image.file(logoFile!, fit: BoxFit.cover)
                    : Padding(
                        padding: const EdgeInsets.all(17),
                        child: CustomPaint(painter: _CameraBallPainter(color: _C.primaryGreen)),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Логотип команды',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w900,
                    color: _C.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  logoFile != null ? 'Файл выбран. Можно заменить или удалить.' : 'Нажмите на круг, чтобы выбрать изображение.',
                  style: TextStyle(
                    fontSize: isTablet ? 12.5 : 11.5,
                    height: 1.35,
                    color: _C.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallActionButton(
                      text: logoFile != null ? 'Заменить' : 'Выбрать',
                      onTap: isLoading ? null : onPickLogo,
                      filled: true,
                    ),
                    if (logoFile != null)
                      _SmallActionButton(
                        text: 'Убрать',
                        onTap: isLoading ? null : onRemoveLogo,
                        filled: false,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpPanel extends StatelessWidget {
  const _HelpPanel();

  @override
  Widget build(BuildContext context) {
    return _CmrCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionHeader(
            title: 'Как правильно начать',
            subtitle: 'Короткий порядок работы после создания команды',
            icon: _CircleNumber(number: 'i', active: true),
          ),
          SizedBox(height: 16),
          _StepRow(
            number: '1',
            title: 'Создайте команду',
            text: 'Название и логотип формируют первую карточку команды.',
          ),
          _StepRow(
            number: '2',
            title: 'Добавьте игроков',
            text: 'После создания откройте состав и заполните профили.',
          ),
          _StepRow(
            number: '3',
            title: 'Ведите работу',
            text: 'Матчи, тренировки, посещаемость и медкарта будут в одной панели.',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String title;
  final String text;
  final bool isLast;

  const _StepRow({
    required this.number,
    required this.title,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _CircleNumber(number: number),
            if (!isLast)
              Container(
                width: 2,
                height: 42,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: _C.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: _C.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12.2,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: _C.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CmrTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String helper;

  const _CmrTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(text: label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _C.text,
          ),
          decoration: _inputDecoration(hint).copyWith(
            prefixIcon: Padding(
              padding: const EdgeInsets.all(13),
              child: CustomPaint(painter: _FlagPainter(color: _C.primaryGreen)),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          helper,
          style: const TextStyle(fontSize: 11.5, color: _C.muted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _FixedFootballField extends StatelessWidget {
  const _FixedFootballField();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(text: 'Вид спорта'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _C.soft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.primaryGreen.withOpacity(.22)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CustomPaint(painter: _BootPainter(color: _C.primaryGreen)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Футбол',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _C.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.primaryGreen.withOpacity(.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _C.primaryGreen.withOpacity(.16)),
                ),
                child: const Text(
                  'по умолчанию',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _C.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Выбор скрыт, чтобы команда всегда создавалась в футбольном разделе.',
          style: TextStyle(fontSize: 11.5, color: _C.muted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _CreateButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _CreateButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _C.primaryGreen,
          disabledBackgroundColor: _C.primaryGreen.withOpacity(.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [_C.primaryGreen, _C.greenDark],
            ),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CustomPaint(painter: _PlusBallPainter(color: Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Создать команду',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget icon;

  const _SectionHeader({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _C.primaryGreen.withOpacity(.10),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _C.primaryGreen.withOpacity(.18)),
          ),
          child: Padding(padding: const EdgeInsets.all(10), child: icon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _C.text)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _C.muted),
              ),
            ],
          ),
        ),
      ],
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
        color: _C.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AlertHint extends StatelessWidget {
  final String title;
  final String text;

  const _AlertHint({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.primaryGreen.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.primaryGreen.withOpacity(.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(color: _C.primaryGreen, shape: BoxShape.circle),
            child: const Icon(Icons.lightbulb_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _C.text)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(fontSize: 12, height: 1.35, fontWeight: FontWeight.w600, color: _C.secondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFeature extends StatelessWidget {
  final String label;
  final _FeatureIconType iconType;
  final Color color;

  const _MiniFeature({required this.label, required this.iconType, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _C.softFor(color),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 16, height: 16, child: CustomPaint(painter: _FeaturePainter(type: iconType, color: color))),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool filled;

  const _SmallActionButton({required this.text, required this.onTap, required this.filled});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? _C.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: filled ? _C.primaryGreen : _C.border),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: filled ? Colors.white : _C.text,
          ),
        ),
      ),
    );
  }
}

class _CircleNumber extends StatelessWidget {
  final String number;
  final bool active;

  const _CircleNumber({required this.number, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: active ? _C.primaryGreen : _C.primaryGreen.withOpacity(.10),
        shape: BoxShape.circle,
        border: Border.all(color: _C.primaryGreen.withOpacity(.18)),
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            color: active ? Colors.white : _C.primaryGreen,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _CircleIconButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _C.soft,
          shape: BoxShape.circle,
          border: Border.all(color: _C.border),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _C.text));
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _C.primaryGreen.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.primaryGreen.withOpacity(.16)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _C.primaryGreen)),
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _C.muted, fontWeight: FontWeight.w600),
    filled: true,
    fillColor: _C.soft,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _C.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _C.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _C.primaryGreen, width: 1.4),
    ),
  );
}

class _C {
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color text = Color(0xFF0F172A);
  static const Color secondary = Color(0xFF475569);
  static const Color muted = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color soft = Color(0xFFF8FAFC);

  static const Color primaryGreen = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF008C40);
  static const Color blue = Color(0xFF2563EB);
  static const Color orange = Color(0xFFEA580C);
  static const Color purple = Color(0xFF7C3AED);

  static Color softFor(Color color) {
    if (color == blue) return const Color(0xFFEFF6FF);
    if (color == orange) return const Color(0xFFFFF1E8);
    if (color == purple) return const Color(0xFFF3E8FF);
    return const Color(0xFFEAF5EE);
  }
}

enum _FeatureIconType { players, field, cone }

class _FeaturePainter extends CustomPainter {
  final _FeatureIconType type;
  final Color color;

  _FeaturePainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case _FeatureIconType.players:
        _drawPlayers(canvas, size);
        break;
      case _FeatureIconType.field:
        _drawField(canvas, size);
        break;
      case _FeatureIconType.cone:
        _drawCone(canvas, size);
        break;
    }
  }

  void _drawPlayers(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.7..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(size.width * .35, size.height * .34), size.width * .16, p);
    canvas.drawCircle(Offset(size.width * .66, size.height * .40), size.width * .13, p);
    canvas.drawArc(Rect.fromLTWH(size.width * .14, size.height * .52, size.width * .42, size.height * .35), math.pi, math.pi, false, p);
    canvas.drawArc(Rect.fromLTWH(size.width * .50, size.height * .58, size.width * .36, size.height * .28), math.pi, math.pi, false, p);
  }

  void _drawField(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.6;
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4));
    canvas.drawRRect(r.deflate(1), p);
    canvas.drawLine(Offset(size.width / 2, 1), Offset(size.width / 2, size.height - 1), p);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * .18, p);
  }

  void _drawCone(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.7..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .5, size.height * .12)
      ..lineTo(size.width * .22, size.height * .78)
      ..lineTo(size.width * .78, size.height * .78)
      ..close();
    canvas.drawPath(path, p);
    canvas.drawLine(Offset(size.width * .32, size.height * .52), Offset(size.width * .68, size.height * .52), p);
    canvas.drawLine(Offset(size.width * .16, size.height * .88), Offset(size.width * .84, size.height * .88), p);
  }

  @override
  bool shouldRepaint(covariant _FeaturePainter oldDelegate) => oldDelegate.type != type || oldDelegate.color != color;
}

class _BallBadgePainter extends CustomPainter {
  final Color color;
  _BallBadgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * .25;
    canvas.drawCircle(c, r, p);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), p);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, math.pi, false, p);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi / 2, math.pi, false, p);
  }

  @override
  bool shouldRepaint(covariant _BallBadgePainter oldDelegate) => oldDelegate.color != color;
}

class _ShieldPainter extends CustomPainter {
  final Color color;
  const _ShieldPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .50, size.height * .05)
      ..lineTo(size.width * .86, size.height * .20)
      ..lineTo(size.width * .78, size.height * .72)
      ..lineTo(size.width * .50, size.height * .94)
      ..lineTo(size.width * .22, size.height * .72)
      ..lineTo(size.width * .14, size.height * .20)
      ..close();
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(size.width * .5, size.height * .48), size.width * .14, p);
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter oldDelegate) => oldDelegate.color != color;
}

class _WhistlePainter extends CustomPainter {
  final Color color;
  const _WhistlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .18, size.height * .38, size.width * .46, size.height * .30),
      const Radius.circular(8),
    );
    canvas.drawRRect(body, p);
    canvas.drawCircle(Offset(size.width * .50, size.height * .53), size.width * .07, p);
    canvas.drawPath(Path()..moveTo(size.width * .64, size.height * .41)..lineTo(size.width * .84, size.height * .34)..lineTo(size.width * .84, size.height * .48), p);
    canvas.drawLine(Offset(size.width * .22, size.height * .34), Offset(size.width * .34, size.height * .22), p);
  }

  @override
  bool shouldRepaint(covariant _WhistlePainter oldDelegate) => oldDelegate.color != color;
}

class _CameraBallPainter extends CustomPainter {
  final Color color;
  const _CameraBallPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .10, size.height * .28, size.width * .80, size.height * .52), const Radius.circular(8));
    canvas.drawRRect(body, p);
    canvas.drawLine(Offset(size.width * .28, size.height * .28), Offset(size.width * .36, size.height * .16), p);
    canvas.drawLine(Offset(size.width * .36, size.height * .16), Offset(size.width * .58, size.height * .16), p);
    canvas.drawLine(Offset(size.width * .58, size.height * .16), Offset(size.width * .66, size.height * .28), p);
    canvas.drawCircle(Offset(size.width * .50, size.height * .54), size.width * .14, p);
    canvas.drawLine(Offset(size.width * .43, size.height * .54), Offset(size.width * .57, size.height * .54), p);
  }

  @override
  bool shouldRepaint(covariant _CameraBallPainter oldDelegate) => oldDelegate.color != color;
}

class _FlagPainter extends CustomPainter {
  final Color color;
  const _FlagPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.1..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawLine(Offset(size.width * .25, size.height * .12), Offset(size.width * .25, size.height * .88), p);
    final path = Path()..moveTo(size.width * .25, size.height * .14)..lineTo(size.width * .78, size.height * .24)..lineTo(size.width * .25, size.height * .40);
    canvas.drawPath(path, p);
    canvas.drawLine(Offset(size.width * .17, size.height * .88), Offset(size.width * .52, size.height * .88), p);
  }

  @override
  bool shouldRepaint(covariant _FlagPainter oldDelegate) => oldDelegate.color != color;
}

class _BootPainter extends CustomPainter {
  final Color color;
  const _BootPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.0..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .18, size.height * .42)
      ..quadraticBezierTo(size.width * .36, size.height * .34, size.width * .48, size.height * .52)
      ..lineTo(size.width * .82, size.height * .62)
      ..quadraticBezierTo(size.width * .90, size.height * .65, size.width * .84, size.height * .75)
      ..lineTo(size.width * .22, size.height * .75)
      ..quadraticBezierTo(size.width * .12, size.height * .72, size.width * .18, size.height * .42);
    canvas.drawPath(path, p);
    canvas.drawLine(Offset(size.width * .28, size.height * .80), Offset(size.width * .28, size.height * .88), p);
    canvas.drawLine(Offset(size.width * .45, size.height * .80), Offset(size.width * .45, size.height * .88), p);
    canvas.drawLine(Offset(size.width * .62, size.height * .80), Offset(size.width * .62, size.height * .88), p);
  }

  @override
  bool shouldRepaint(covariant _BootPainter oldDelegate) => oldDelegate.color != color;
}

class _PlusBallPainter extends CustomPainter {
  final Color color;
  const _PlusBallPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, size.shortestSide * .42, p);
    canvas.drawLine(Offset(c.dx - 5, c.dy), Offset(c.dx + 5, c.dy), p);
    canvas.drawLine(Offset(c.dx, c.dy - 5), Offset(c.dx, c.dy + 5), p);
  }

  @override
  bool shouldRepaint(covariant _PlusBallPainter oldDelegate) => oldDelegate.color != color;
}

class _PitchLinesPainter extends CustomPainter {
  final Color color;
  const _PitchLinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2;
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)), p);
    canvas.drawLine(Offset(size.width / 2, 8), Offset(size.width / 2, size.height - 8), p);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * .16, p);
    canvas.drawRect(Rect.fromLTWH(8, size.height * .32, size.width * .22, size.height * .36), p);
  }

  @override
  bool shouldRepaint(covariant _PitchLinesPainter oldDelegate) => oldDelegate.color != color;
}
