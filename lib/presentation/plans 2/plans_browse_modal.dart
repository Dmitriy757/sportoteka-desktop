import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';

class PlansBrowseModal extends StatefulWidget {
  final int teamId;
  final String title;

  const PlansBrowseModal({
    super.key,
    required this.teamId,
    this.title = "Планы / конспекты",
  });

  @override
  State<PlansBrowseModal> createState() => _PlansBrowseModalState();
}

class _PlansBrowseModalState extends State<PlansBrowseModal> {
  bool loading = true;
  int clubId = 0;
  String clubName = "Мой клуб";

  @override
  void initState() {
    super.initState();
    _loadClub();
  }

  Future<void> _loadClub() async {
    final id = await PrefUtils.getUserClubId() ?? 0;
    final name = await PrefUtils.getUserClubName();

    if (!mounted) return;
    setState(() {
      clubId = id;
      clubName = name;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final baseTheme = Theme.of(context);
    final textTheme = baseTheme.textTheme.apply(
      fontFamily: AppTypography.fontFamily,
    );

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: DefaultTextStyle.merge(
        style: AppTypography.body(color: const Color(0xFF111827)),
        child: Container(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + pad),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9F8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w500, fontSize: AppTypography.screenTitleSize),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Закрыть"),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (clubId <= 0) ...[
              _InfoCard(
                title: "Материалы недоступны",
                subtitle:
                    "Не найден clubId. Обычно это значит, что клуб не сохранён в настройках пользователя.\n\n"
                    "Решение: выполните повторный вход или выберите клуб в профиле (если есть).",
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text("Ок, понял"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              _InfoCard(
                title: "Клуб: $clubName",
                subtitle: "Откроем папки и планы для команды #${widget.teamId}. Режим просмотра (без редактирования).",
                icon: Icons.folder_open_rounded,
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Закрываем это модальное окно
                    Navigator.pop(context);

                    // Открываем существующий экран, но без редактирования:
                    // 1) browsePlansMode=true — чтобы по нажатию возвращал результат (можно оставить false)
                    // 2) selectMode=false, selectGraphicsMode=false
                    await Get.to(() => PlanFoldersScreen(
                      clubId: clubId,
                      clubName: clubName,
                      teamId: widget.teamId,
                      browsePlansMode: false, // можно true если хочешь возвращать выбранный план
                      selectMode: false,
                      selectGraphicsMode: false,
                    ));
                  },
                  icon: const Icon(Icons.article_outlined),
                  label: const Text("Открыть папки и планы"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A750),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text("Отмена"),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF00A750).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF00A750)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}