import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'game_zone_api.dart';

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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF00A750), Color(0xFF2BC56B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Новый челлендж команды',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            teamName.isEmpty ? 'Командный челлендж' : teamName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Создай задание дня или недели, укажи очки и срок выполнения. Игроки увидят его в игровой зоне.',
            style: TextStyle(
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ],
      ),
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
            fontWeight: FontWeight.w800,
            fontSize: 14,
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
                        ? const Color(0xFFEAFBF1)
                        : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF00A750)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      item['label']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? const Color(0xFF00A750)
                            : Colors.black87,
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
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  backgroundColor: const Color(0xFF00A750),
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
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAFBF1),
              borderRadius: BorderRadius.circular(14),
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
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
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
            fontWeight: FontWeight.w900,
            fontSize: 18,
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
      appBar: AppBar(
        title: const Text('Создать челлендж'),
      ),
      body: !validTeam
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Не удалось определить команду для создания челленджа',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _headerCard(),
                const SizedBox(height: 16),
                _buildFormCard(),
                const SizedBox(height: 20),
                _ideasBlock(),
              ],
            ),
    );
  }
}