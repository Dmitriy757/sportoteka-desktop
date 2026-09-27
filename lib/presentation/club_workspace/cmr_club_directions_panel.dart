import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_direction_service.dart';

class CmrClubDirectionsPanel extends StatefulWidget {
  final int clubId;
  final int userId;
  final String clubName;

  const CmrClubDirectionsPanel({
    super.key,
    required this.clubId,
    required this.userId,
    required this.clubName,
  });

  @override
  State<CmrClubDirectionsPanel> createState() => _CmrClubDirectionsPanelState();
}

class _CmrClubDirectionsPanelState extends State<CmrClubDirectionsPanel> {
  static const Color _green = Color(0xFF00A750);
  static const Color _greenDark = Color(0xFF067A46);
  static const Color _text = Color(0xFF0B0F14);
  static const Color _muted = Color(0xFF667085);
  static const Color _border = Color(0xFFE8ECEA);
  static const Color _soft = Color(0xFFF7F8F7);

  static const List<String> _availableDisciplines = <String>[
    'EA Sports FC',
    'eFootball',
    'Counter-Strike 2',
    'Dota 2',
    'Valorant',
  ];

  bool _loading = true;
  bool _saving = false;
  EsportsDirectionState _state = const EsportsDirectionState(
    active: false,
    serverConfirmed: false,
    status: 'not_configured',
  );
  final Set<String> _selectedDisciplines = <String>{'EA Sports FC'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await EsportsDirectionService.load(
      clubId: widget.clubId,
      userId: widget.userId,
    );
    if (!mounted) return;
    setState(() {
      _state = state;
      _selectedDisciplines
        ..clear()
        ..addAll(state.disciplines.isEmpty ? const <String>['EA Sports FC'] : state.disciplines);
      _loading = false;
    });
  }

  Future<void> _activate() async {
    if (_selectedDisciplines.isEmpty || _saving) return;
    setState(() => _saving = true);
    final state = await EsportsDirectionService.activate(
      clubId: widget.clubId,
      userId: widget.userId,
      disciplines: _selectedDisciplines.toList(growable: false),
    );
    if (!mounted) return;
    setState(() {
      _state = state;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.serverConfirmed
              ? 'Киберспортивное направление подключено. В HUB появится Sportoteka Esports.'
              : 'Киберспорт включён в приложении. В HUB появится Sportoteka Esports.',
        ),
      ),
    );
  }

  Future<void> _deactivate() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Отключить киберспорт?'),
            content: const Text(
              'Карточка Sportoteka Esports исчезнет из HUB. Существующие киберспортивные данные удалять не нужно — направление можно включить снова.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Отключить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    final state = await EsportsDirectionService.deactivate(
      clubId: widget.clubId,
      userId: widget.userId,
    );
    if (!mounted) return;
    setState(() {
      _state = state;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Киберспортивное направление отключено.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _green),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Направления клуба',
                  style: AppTypography.custom(
                    size: 22,
                    weight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Рабочие пространства подключаются отдельно. Команды не создаются автоматически — они создаются уже внутри выбранного направления.',
                  style: AppTypography.custom(
                    size: 12.5,
                    weight: FontWeight.w400,
                    color: _muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _directionCard(
                  icon: Icons.sports_soccer_rounded,
                  title: 'Футбол',
                  subtitle: 'Команды, состав, тренировки, матчи, Tracker и аналитика',
                  active: true,
                  footer: 'Основное направление клуба',
                ),
                const SizedBox(height: 12),
                _esportsCard(),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: _muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _state.serverConfirmed
                              ? 'Состояние направления подтверждено сервером. После возврата в HUB карточка Sportoteka Esports будет показана только при активном направлении.'
                              : 'Пока серверные endpoints esports/directions не установлены, приложение использует локальный кэш направления. После подключения API эта же форма начнёт синхронизироваться между устройствами.',
                          style: AppTypography.custom(
                            size: 11.5,
                            weight: FontWeight.w400,
                            color: _muted,
                            height: 1.4,
                          ),
                        ),
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

  Widget _esportsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _state.active ? _green.withOpacity(.28) : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _state.active ? const Color(0xFFF0FAF5) : _soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sports_esports_rounded,
                  color: _state.active ? _greenDark : _muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Киберспорт',
                      style: AppTypography.custom(
                        size: 16,
                        weight: FontWeight.w600,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _state.active
                          ? 'Sportoteka Esports подключён к ${widget.clubName.trim().isEmpty ? 'клубу' : widget.clubName.trim()}'
                          : 'Отдельный Workspace: команды, турниры, Live, видео и AI-анализ',
                      style: AppTypography.custom(
                        size: 11.5,
                        weight: FontWeight.w400,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(_state.active),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Дисциплины',
            style: AppTypography.custom(
              size: 11.5,
              weight: FontWeight.w600,
              color: _text,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableDisciplines.map((discipline) {
              final selected = _selectedDisciplines.contains(discipline);
              return FilterChip(
                label: Text(discipline),
                selected: selected,
                onSelected: _state.active || _saving
                    ? null
                    : (value) {
                        setState(() {
                          if (value) {
                            _selectedDisciplines.add(discipline);
                          } else {
                            _selectedDisciplines.remove(discipline);
                          }
                        });
                      },
                showCheckmark: false,
                selectedColor: const Color(0xFFF0FAF5),
                side: BorderSide(
                  color: selected ? _green.withOpacity(.28) : _border,
                ),
                labelStyle: AppTypography.custom(
                  size: 11,
                  weight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? _greenDark : _muted,
                ),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _state.active
                      ? 'Команды создаются внутри Sportoteka Esports. Никакая киберкоманда не создаётся автоматически.'
                      : 'После подключения в HUB появится отдельная карточка Sportoteka Esports.',
                  style: AppTypography.custom(
                    size: 11.5,
                    weight: FontWeight.w400,
                    color: _muted,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_state.active)
                OutlinedButton(
                  onPressed: _saving ? null : _deactivate,
                  child: const Text('Отключить'),
                )
              else
                FilledButton.icon(
                  onPressed: _saving || _selectedDisciplines.isEmpty ? null : _activate,
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  icon: _saving
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Подключить киберспорт'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _directionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool active,
    required String footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _greenDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.custom(
                    size: 16,
                    weight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTypography.custom(
                    size: 11.5,
                    weight: FontWeight.w400,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  footer,
                  style: AppTypography.custom(
                    size: 10.5,
                    weight: FontWeight.w500,
                    color: _greenDark,
                  ),
                ),
              ],
            ),
          ),
          _statusPill(active),
        ],
      ),
    );
  }

  Widget _statusPill(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF0FAF5) : _soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? _green : _muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Активно' : 'Не подключено',
            style: AppTypography.custom(
              size: 10.5,
              weight: FontWeight.w600,
              color: active ? _greenDark : _muted,
            ),
          ),
        ],
      ),
    );
  }
}
