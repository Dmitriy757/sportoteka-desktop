import 'dart:convert';
import 'dart:io';

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
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (image == null) return;
      if (!mounted) return;
      setState(() => _logoFile = File(image.path));
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

    if (!mounted) return;
    setState(() => isLoading = true);

    final uri = Uri.parse('https://sportotekaapp.ru/api/create_team.php');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.fields['team_name'] = teamName;
      request.fields['coach_id'] = coachId.toString();
      request.fields['category'] = fixedSportCategory;

      if (_logoFile != null && await _logoFile!.exists()) {
        final fileName = p.basename(_logoFile!.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'logo',
            _logoFile!.path,
            filename: fileName,
          ),
        );
      }

      final streamed = await request.send();
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
        Get.snackbar(
          'Ошибка',
          (json['message'] ?? 'Не удалось создать команду').toString(),
        );
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
    final bool compact = width < 760;
    final bool wide = width >= 1040;

    return Scaffold(
      backgroundColor: _CmrColors.panel,
      resizeToAvoidBottomInset: true,
      appBar: _CreateTeamAppBar(compact: compact, onBack: () => Get.back()),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (compact) {
              return _MobileCreateTeamLayout(
                logoFile: _logoFile,
                isLoading: isLoading,
                teamNameController: teamNameController,
                onPickLogo: _pickLogo,
                onRemoveLogo: () => setState(() => _logoFile = null),
                onCreate: createTeam,
              );
            }

            final double horizontal = wide ? 30 : 24;
            final double maxWidth = wide ? 1180 : 900;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: wide
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
                                showCreateButton: true,
                                compact: false,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _PreviewPanel(),
                                  SizedBox(height: 14),
                                  _StartGuidePanel(),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            const _PreviewPanel(),
                            const SizedBox(height: 14),
                            _MainFormCard(
                              logoFile: _logoFile,
                              isLoading: isLoading,
                              teamNameController: teamNameController,
                              onPickLogo: _pickLogo,
                              onRemoveLogo: () => setState(() => _logoFile = null),
                              onCreate: createTeam,
                              showCreateButton: true,
                              compact: false,
                            ),
                            const SizedBox(height: 14),
                            const _StartGuidePanel(),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MobileCreateTeamLayout extends StatelessWidget {
  final File? logoFile;
  final bool isLoading;
  final TextEditingController teamNameController;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;
  final VoidCallback onCreate;

  const _MobileCreateTeamLayout({
    required this.logoFile,
    required this.isLoading,
    required this.teamNameController,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
            child: Column(
              children: [
                const _CompactTopInfo(),
                const SizedBox(height: 8),
                _MainFormCard(
                  logoFile: logoFile,
                  isLoading: isLoading,
                  teamNameController: teamNameController,
                  onPickLogo: onPickLogo,
                  onRemoveLogo: onRemoveLogo,
                  onCreate: onCreate,
                  showCreateButton: false,
                  compact: true,
                ),
                const SizedBox(height: 8),
                const _MobileHintPanel(),
              ],
            ),
          ),
        ),
        _BottomCreateBar(isLoading: isLoading, onCreate: onCreate),
      ],
    );
  }
}

class _CreateTeamAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool compact;
  final VoidCallback onBack;

  const _CreateTeamAppBar({required this.compact, required this.onBack});

  @override
  Size get preferredSize => Size.fromHeight(compact ? 58 : 70);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      centerTitle: false,
      backgroundColor: _CmrColors.panel,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 10 : 18, 0, compact ? 10 : 22, 0),
        child: Row(
          children: [
            _RoundIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
              compact: compact,
            ),
            SizedBox(width: compact ? 10 : 12),
            const _IconBadge(icon: Icons.groups_2_rounded),
            SizedBox(width: compact ? 10 : 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Создать команду',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrText.title(compact ? 17 : 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Название, логотип и футбольный раздел',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _CmrText.muted(compact ? 11 : 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const _SmallChip(text: 'Футбол'),
          ],
        ),
      ),
    );
  }
}

class _CompactTopInfo extends StatelessWidget {
  const _CompactTopInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: _CmrDecor.panel(radius: 22),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _CmrColors.greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.add_circle_outline_rounded, color: _CmrColors.green, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Быстрое добавление',
                  style: _CmrText.value(14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Минимум полей — список команд останется чистым и удобным.',
                  style: _CmrText.muted(11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
  final bool showCreateButton;
  final bool compact;

  const _MainFormCard({
    required this.logoFile,
    required this.isLoading,
    required this.teamNameController,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.onCreate,
    required this.showCreateButton,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: _CmrDecor.panel(radius: compact ? 24 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            const _SectionHeader(
              title: 'Основные данные',
              subtitle: 'Создайте карточку команды и сразу переходите к составу',
              icon: Icons.shield_outlined,
            ),
            const SizedBox(height: 18),
          ],
          _LogoPickerBlock(
            logoFile: logoFile,
            isLoading: isLoading,
            compact: compact,
            onPickLogo: onPickLogo,
            onRemoveLogo: onRemoveLogo,
          ),
          SizedBox(height: compact ? 12 : 16),
          _CmrTextField(
            controller: teamNameController,
            label: 'Название команды',
            hint: 'Например: Спортотека U-12',
            compact: compact,
          ),
          SizedBox(height: compact ? 12 : 16),
          _FixedSportBox(compact: compact),
          if (!compact) ...[
            const SizedBox(height: 16),
            const _SoftNotice(
              title: 'После создания',
              text: 'Команда появится в рабочей панели клуба. Затем можно открыть состав, добавить игроков и назначить тренеров.',
            ),
          ],
          if (showCreateButton) ...[
            const SizedBox(height: 22),
            _CreateButton(isLoading: isLoading, onPressed: onCreate),
          ],
        ],
      ),
    );
  }
}

class _LogoPickerBlock extends StatelessWidget {
  final File? logoFile;
  final bool isLoading;
  final bool compact;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;

  const _LogoPickerBlock({
    required this.logoFile,
    required this.isLoading,
    required this.compact,
    required this.onPickLogo,
    required this.onRemoveLogo,
  });

  @override
  Widget build(BuildContext context) {
    final double avatarSize = compact ? 66 : 86;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: _CmrDecor.softCard(radius: compact ? 20 : 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: isLoading ? null : onPickLogo,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.035),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: logoFile != null
                    ? Image.file(logoFile!, fit: BoxFit.cover)
                    : const Icon(Icons.add_photo_alternate_outlined, color: _CmrColors.green, size: 30),
              ),
            ),
          ),
          SizedBox(width: compact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Логотип команды', style: _CmrText.value(compact ? 13.5 : 15)),
                const SizedBox(height: 3),
                Text(
                  logoFile != null ? 'Файл выбран. Можно заменить.' : 'Можно добавить сейчас или позже.',
                  style: _CmrText.muted(compact ? 11 : 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: compact ? 8 : 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallActionButton(
                      text: logoFile == null ? 'Выбрать' : 'Заменить',
                      icon: Icons.image_outlined,
                      onTap: isLoading ? null : onPickLogo,
                      filled: true,
                    ),
                    if (logoFile != null)
                      _SmallActionButton(
                        text: 'Убрать',
                        icon: Icons.close_rounded,
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

class _CmrTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool compact;

  const _CmrTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _CmrText.caption()),
        const SizedBox(height: 7),
        Container(
          decoration: _CmrDecor.softCard(radius: compact ? 18 : 20),
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            style: _CmrText.value(compact ? 14.5 : 15.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: _CmrText.muted(compact ? 12 : 13),
              prefixIcon: const Icon(Icons.flag_outlined, color: _CmrColors.green, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: compact ? 14 : 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FixedSportBox extends StatelessWidget {
  final bool compact;

  const _FixedSportBox({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Вид спорта', style: _CmrText.caption()),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 11 : 13),
          decoration: BoxDecoration(
            color: _CmrColors.greenSoft,
            borderRadius: BorderRadius.circular(compact ? 18 : 20),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.sports_soccer_rounded, color: _CmrColors.green, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Футбол',
                  style: _CmrText.value(compact ? 14 : 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const _SmallChip(text: 'по умолчанию'),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomCreateBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onCreate;

  const _BottomCreateBar({required this.isLoading, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _CreateButton(isLoading: isLoading, onPressed: onCreate, compact: true),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final bool compact;

  const _CreateButton({
    required this.isLoading,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 52 : 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _CmrColors.green,
          disabledBackgroundColor: _CmrColors.green.withOpacity(.45),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(compact ? 18 : 20)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Создать команду',
                    style: TextStyle(
                      fontSize: compact ? 15 : 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _CmrDecor.panel(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Карточка команды',
            subtitle: 'Такой стиль будет совпадать с панелью команд',
            icon: Icons.account_tree_outlined,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _CmrDecor.softCard(radius: 24),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.groups_2_rounded, color: _CmrColors.green, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Новая команда', style: _CmrText.title(18)),
                      const SizedBox(height: 4),
                      Text('Футбол • рабочая панель клуба', style: _CmrText.muted(12)),
                    ],
                  ),
                ),
                const _SmallChip(text: 'новая'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FeaturePill(icon: Icons.people_alt_outlined, text: 'Состав'),
              _FeaturePill(icon: Icons.event_note_outlined, text: 'Матчи'),
              _FeaturePill(icon: Icons.fitness_center_rounded, text: 'Тренировки'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartGuidePanel extends StatelessWidget {
  const _StartGuidePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _CmrDecor.panel(radius: 30),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Дальше по шагам',
            subtitle: 'После создания команда сразу готова к работе',
            icon: Icons.route_outlined,
          ),
          SizedBox(height: 16),
          _GuideRow(number: '1', title: 'Откройте состав', text: 'Добавьте игроков и заполните профили.'),
          _GuideRow(number: '2', title: 'Назначьте тренеров', text: 'Привяжите ответственных к команде.'),
          _GuideRow(number: '3', title: 'Ведите события', text: 'Матчи, тренировки и посещаемость будут в одной панели.', isLast: true),
        ],
      ),
    );
  }
}

class _MobileHintPanel extends StatelessWidget {
  const _MobileHintPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _CmrDecor.panel(radius: 22),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(color: _CmrColors.greenSoft, shape: BoxShape.circle),
            child: const Icon(Icons.info_outline_rounded, color: _CmrColors.green, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'После создания команда появится в списке, где можно открыть состав и добавить игроков.',
              style: _CmrText.muted(11.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftNotice extends StatelessWidget {
  final String title;
  final String text;

  const _SoftNotice({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _CmrColors.greenSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.done_rounded, color: _CmrColors.green, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _CmrText.value(13.5)),
                const SizedBox(height: 3),
                Text(text, style: _CmrText.muted(12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _CmrColors.greenSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: _CmrColors.green, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _CmrText.section()),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: _CmrText.muted(12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideRow extends StatelessWidget {
  final String number;
  final String title;
  final String text;
  final bool isLast;

  const _GuideRow({
    required this.number,
    required this.title,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(color: _CmrColors.greenSoft, shape: BoxShape.circle),
            child: Center(
              child: Text(number, style: _CmrText.action()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _CmrText.value(13.5)),
                const SizedBox(height: 2),
                Text(text, style: _CmrText.muted(12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeaturePill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _CmrColors.greenSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _CmrColors.green, size: 16),
          const SizedBox(width: 6),
          Text(text, style: _CmrText.action()),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  const _SmallActionButton({
    required this.text,
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? _CmrColors.green : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: filled ? Colors.white : _CmrColors.green),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                color: filled ? Colors.white : _CmrColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  const _RoundIconButton({required this.icon, required this.onTap, required this.compact});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: compact ? 38 : 42,
        height: compact ? 38 : 42,
        decoration: const BoxDecoration(color: _CmrColors.soft, shape: BoxShape.circle),
        child: Icon(icon, color: _CmrColors.text, size: compact ? 19 : 20),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;

  const _IconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _CmrColors.greenSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: _CmrColors.green, size: 21),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String text;

  const _SmallChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _CmrColors.greenSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _CmrColors.green,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CmrColors {
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF6F8FA);
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color green = Color(0xFF1F7A4D);
  static const Color greenSoft = Color(0xFFF2F7F4);
}

class _CmrText {
  static TextStyle title(double size) => TextStyle(
        color: _CmrColors.text,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.12,
      );

  static TextStyle section() => const TextStyle(
        color: _CmrColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        height: 1.18,
      );

  static TextStyle value(double size) => TextStyle(
        color: _CmrColors.text,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.32,
      );

  static TextStyle muted(double size) => TextStyle(
        color: _CmrColors.muted,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.38,
      );

  static TextStyle caption() => const TextStyle(
        color: _CmrColors.text,
        fontSize: 13,
        fontWeight: FontWeight.w800,
        height: 1.15,
      );

  static TextStyle action() => const TextStyle(
        color: _CmrColors.green,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      );
}

class _CmrDecor {
  static BoxDecoration panel({double radius = 28}) => BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.018),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration softCard({double radius = 22}) => BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(radius),
      );
}
