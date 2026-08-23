import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'game_zone_api.dart';
import 'game_zone_cmr_style.dart';

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  late final int teamId;
  late final int userId;
  late final String teamName;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _pointsController =
      TextEditingController(text: '20');
  final TextEditingController _dueDateController = TextEditingController();

  String _challengeType = 'daily';
  bool _saving = false;

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();

    final rawArgs = Get.arguments;
    final args = rawArgs is Map
        ? Map<String, dynamic>.from(rawArgs)
        : <String, dynamic>{};

    teamId = _asInt(args['team_id']);
    userId = _asInt(args['user_id']);
    teamName = (args['team_name'] ?? '').toString();

    final now = DateTime.now().add(const Duration(days: 1));
    _dueDateController.text =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} 20:00:00';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (pickedDate == null) return;
    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );

    if (pickedTime == null) return;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    _dueDateController.text =
        '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00';

    if (mounted) setState(() {});
  }

  Future<void> _saveChallenge() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final res = await GameZoneApi.post('create_player_challenge.php', {
      'team_id': teamId,
      'created_by': userId,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'challenge_type': _challengeType,
      'points_reward': _pointsController.text.trim(),
      'due_date': _dueDateController.text.trim(),
    });

    if (!mounted) return;

    setState(() => _saving = false);

    if (res['success'] == true) {
      Get.snackbar(
        'Готово',
        res['message'] ?? 'Челлендж создан',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.back(result: true);
    } else {
      Get.snackbar(
        'Ошибка',
        res['message'] ?? 'Не удалось создать челлендж',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Widget _headerCard() {
    return GameZoneCmr.header(
      title: 'Новый челлендж команды',
      subtitle: '${teamName.isEmpty ? 'Командный челлендж' : teamName}\nСоздай задание дня или недели, укажи очки и срок выполнения. Игроки увидят его в игровой зоне.',
      icon: Icons.flag_rounded,
    );
  }

  Widget _buildTypeSelector() {
    final items = [
      {'value': 'daily', 'label': 'Ежедневный'},
      {'value': 'weekly', 'label': 'Недельный'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Тип челленджа',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: items.map((item) {
            final selected = _challengeType == item['value'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _challengeType = item['value']!;
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: item['value'] == 'daily' ? 8 : 0,
                    left: item['value'] == 'weekly' ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? GzColors.greenSoft
                        : GzColors.soft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? GzColors.greenBorder
                          : Colors.transparent,
                      width: .8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      item['label']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? GzColors.green
                            : GzColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
            ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Название челленджа',
                hintText: 'Например: 30 точных передач',
                border: InputBorder.none,
                filled: true,
                fillColor: GzColors.soft,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите название';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Описание',
                hintText:
                    'Опиши задание подробно: что должен сделать игрок, какой результат нужен',
                border: InputBorder.none,
                filled: true,
                fillColor: GzColors.soft,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите описание';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildTypeSelector(),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Награда в очках',
                hintText: '20',
                border: InputBorder.none,
                filled: true,
                fillColor: GzColors.soft,
                prefixIcon: const Icon(Icons.emoji_events_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите очки';
                }
                final n = int.tryParse(v.trim());
                if (n == null || n <= 0) {
                  return 'Введите корректное число';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _dueDateController,
              readOnly: true,
              onTap: _pickDateTime,
              decoration: InputDecoration(
                labelText: 'Срок выполнения',
                border: InputBorder.none,
                filled: true,
                fillColor: GzColors.soft,
                prefixIcon: const Icon(Icons.schedule_outlined),
                suffixIcon: IconButton(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.edit_calendar_outlined),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Выбери дату';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveChallenge,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.flag_outlined),
                label: Text(_saving ? 'Сохраняем...' : 'Создать челлендж'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: GzColors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ideaCard(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GzColors.soft,
        borderRadius: BorderRadius.circular(12),
              ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: GzColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: GzColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: GzColors.subtle,
                    fontSize: 10.8,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ideasBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Идеи для челленджей',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        _ideaCard(
          'Точность передач',
          'Сделать 30 точных коротких передач без ошибки',
          Icons.compare_arrows_rounded,
        ),
        const SizedBox(height: 10),
        _ideaCard(
          'Контроль мяча',
          'Набить мяч 50 раз и отправить результат',
          Icons.sports_soccer_outlined,
        ),
        const SizedBox(height: 10),
        _ideaCard(
          'Удары в створ',
          'Сделать 10 ударов в створ и написать итог',
          Icons.gps_fixed_rounded,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final validTeam = teamId > 0;

    return Scaffold(
      backgroundColor: GzColors.bg,
      appBar: GameZoneCmr.appBar(
        title: const Text('Создать челлендж'),
      ),
      body: GameZoneCmr.page(
        context,
        child: !validTeam
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Не удалось определить команду для создания челленджа',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : ListView(
              padding: GameZoneCmr.listPadding(context),
              children: [
                _headerCard(),
                const SizedBox(height: 16),
                _buildFormCard(),
                const SizedBox(height: 20),
                _ideasBlock(),
              ],
            ),
      ),
    );
  }
}
