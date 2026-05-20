import 'package:flutter/material.dart';

class TtdPanelWidget extends StatefulWidget {
  final Map<String, dynamic>? selectedPlayer;
  final Map<String, dynamic>? selectedEpisode;
  final bool quickSaving;
  final bool saving;
  final TextEditingController noteCtrl;
  final String? message;
  final bool isMessageError;
  final String ttdSection;
  final Function(String) onSectionChanged;
  final VoidCallback onSaveEvent;
  final Function(String, String, bool) onSaveQuickTtd;
  final Function(String, String, int) onSaveSingleTtd;
  final Map<String, int> successCounters;
  final Map<String, int> failCounters;
  final Map<String, int> singleCounters;
  final int currentRating;

  const TtdPanelWidget({
  super.key,
  this.selectedPlayer,
  this.selectedEpisode,
  required this.successCounters,
  required this.failCounters,
  required this.singleCounters,
  required this.currentRating,
  required this.quickSaving,
  required this.saving,
  required this.noteCtrl,
  this.message,
  required this.isMessageError,
  required this.ttdSection,
  required this.onSectionChanged,
  required this.onSaveEvent,
  required this.onSaveQuickTtd,
  required this.onSaveSingleTtd,
});

  @override
  State<TtdPanelWidget> createState() => _TtdPanelWidgetState();
}

class _TtdPanelWidgetState extends State<TtdPanelWidget> {
  int _selectedRating = 5;
  late String _currentSection;

  final Map<String, int> _localCounters = {};
  final Map<String, int> _localSuccessCounters = {};
  final Map<String, int> _localFailCounters = {};

  static final Map<String, Map<String, int>> _episodeCountersCache = {};
  static final Map<String, Map<String, int>> _episodeSuccessCountersCache = {};
  static final Map<String, Map<String, int>> _episodeFailCountersCache = {};
  static final Map<String, int> _episodeRatingsCache = {};

  String _storageKey() {
    final playerId = widget.selectedPlayer?['id']?.toString() ?? 'no_player';
    final episodeId = widget.selectedEpisode?['id']?.toString() ?? 'no_episode';
    return '${playerId}_$episodeId';
  }

  String _normalizeEventType(String type) {
  final normalized = type.trim();

  switch (normalized) {
    case 'interception_ball':
      return 'interception';
    case 'recovery_ball':
      return 'recovery';

    case 'pass_forward_short':
      return 'forward_short';
    case 'pass_forward_medium':
      return 'forward_medium';
    case 'pass_forward_long':
      return 'forward_long';

    case 'pass_side_short':
      return 'side_short';
    case 'pass_side_medium':
      return 'side_medium';
    case 'pass_side_long':
      return 'side_long';

    case 'pass_back_short':
      return 'back_short';
    case 'pass_back_medium':
      return 'back_medium';
    case 'pass_back_long':
      return 'back_long';

    case 'gk_saves':
      return 'saves';
    case 'gk_conceded':
      return 'conceded';
    case 'gk_hand_distribution':
      return 'hand_distribution';
    case 'gk_coming_out':
      return 'coming_out';
    case 'gk_close_combat':
      return 'close_combat';
    case 'gk_interceptions':
      return 'interceptions';
    case 'gk_outside_box':
      return 'outside_box';
    case 'gk_pass_short':
      return 'pass_short';
    case 'gk_pass_medium':
      return 'pass_medium';
    case 'gk_pass_long':
      return 'pass_long';

    default:
      return normalized;
  }
}


  void _restoreStateForCurrentSelection() {
    _localCounters.clear();
    _localSuccessCounters.clear();
    _localFailCounters.clear();
    _selectedRating = 5;

    final playerId = widget.selectedPlayer?['id'];
    final episode = widget.selectedEpisode;

    if (playerId == null || episode == null) {
      return;
    }

    final childrenRaw = episode['children'];
    if (childrenRaw is! List) {
      final key = _storageKey();

      _localCounters.addAll(_episodeCountersCache[key] ?? {});
      _localSuccessCounters.addAll(_episodeSuccessCountersCache[key] ?? {});
      _localFailCounters.addAll(_episodeFailCountersCache[key] ?? {});
      _selectedRating = _episodeRatingsCache[key] ?? 5;
      return;
    }

    for (final item in childrenRaw) {
      if (item is! Map) continue;

      final child = Map<String, dynamic>.from(item as Map);
      final childPlayerId = child['player_id'];

      if (childPlayerId == null ||
          childPlayerId.toString() != playerId.toString()) {
        continue;
      }

      final rawType = (child['event_type'] ?? '').toString().trim();
      final eventType = _normalizeEventType(rawType);
      final isPositive =
          int.tryParse((child['is_positive'] ?? '0').toString()) ?? 0;
      final rating = int.tryParse((child['rating'] ?? '0').toString()) ?? 0;

      if (eventType.isEmpty || eventType == 'episode') continue;

      if (eventType == 'rating') {
        _selectedRating = rating > 0 ? rating : 5;
        continue;
      }

      const singleMetrics = {
        'saves',
        'conceded',
      };

      if (singleMetrics.contains(eventType)) {
        final delta = rating == 0 ? 1 : rating;
        _localCounters[eventType] = (_localCounters[eventType] ?? 0) + delta;
        if ((_localCounters[eventType] ?? 0) < 0) {
          _localCounters[eventType] = 0;
        }
        continue;
      }

      if (isPositive > 0) {
        _localSuccessCounters[eventType] =
            (_localSuccessCounters[eventType] ?? 0) + 1;
      } else {
        _localFailCounters[eventType] =
            (_localFailCounters[eventType] ?? 0) + 1;
      }
    }

    _saveStateForCurrentSelection();
  }

  void _saveStateForCurrentSelection() {
    final key = _storageKey();
    _episodeCountersCache[key] = Map<String, int>.from(_localCounters);
    _episodeSuccessCountersCache[key] =
        Map<String, int>.from(_localSuccessCounters);
    _episodeFailCountersCache[key] = Map<String, int>.from(_localFailCounters);
    _episodeRatingsCache[key] = _selectedRating;
  }

  int _successTotal() {
    return _localSuccessCounters.values.fold<int>(0, (a, b) => a + b);
  }

  int _failTotal() {
    return _localFailCounters.values.fold<int>(0, (a, b) => a + b);
  }

  int _singleCountersTotal() {
    return _localCounters.values.fold<int>(0, (a, b) => a + b);
  }

  int _allActionsTotal() {
    return _successTotal() + _failTotal() + _singleCountersTotal();
  }

  int _filledMetricsCount() {
    final allKeys = <String>{
      ..._localCounters.keys,
      ..._localSuccessCounters.keys,
      ..._localFailCounters.keys,
    };

    return allKeys.where((key) {
      final normal = _localCounters[key] ?? 0;
      final success = _localSuccessCounters[key] ?? 0;
      final fail = _localFailCounters[key] ?? 0;
      return normal > 0 || success > 0 || fail > 0;
    }).length;
  }

  String _successPercent(int success, int fail) {
    final total = success + fail;
    if (total <= 0) return '0%';
    final percent = ((success / total) * 100).round();
    return '$percent%';
  }

  @override
  void initState() {
    super.initState();
    _currentSection = widget.ttdSection;
    _restoreStateForCurrentSelection();
  }

  @override
  void didUpdateWidget(covariant TtdPanelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.ttdSection != widget.ttdSection) {
      _currentSection = widget.ttdSection;
    }

    final oldPlayerId = oldWidget.selectedPlayer?['id']?.toString();
    final newPlayerId = widget.selectedPlayer?['id']?.toString();

    final oldEpisodeId = oldWidget.selectedEpisode?['id']?.toString();
    final newEpisodeId = widget.selectedEpisode?['id']?.toString();

    final selectionChanged =
        oldPlayerId != newPlayerId || oldEpisodeId != newEpisodeId;

    if (selectionChanged) {
      _saveStateForCurrentSelection();
      setState(() {
        _restoreStateForCurrentSelection();
      });
    }
  }

  @override
  void dispose() {
    _saveStateForCurrentSelection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection =
        widget.selectedPlayer != null && widget.selectedEpisode != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSelectionStatus(),
        const SizedBox(height: 14),
        if (!hasSelection) _buildNoSelectionMessage(),
        if (hasSelection) ...[
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildSectionTabs(),
          const SizedBox(height: 16),
          if (widget.message != null) ...[
            _buildMessageBanner(),
            const SizedBox(height: 12),
          ],
          _buildSectionCard(),
          const SizedBox(height: 18),
          _buildRatingBlock(),
          const SizedBox(height: 18),
          _buildNoteField(),
          const SizedBox(height: 18),
          _buildSaveButton(),
        ],
      ],
    );
  }

  Widget _buildSelectionStatus() {
    final firstName = widget.selectedPlayer?['first_name']?.toString() ?? '';
    final lastName = widget.selectedPlayer?['last_name']?.toString() ?? '';
    final playerName = '$firstName $lastName'.trim();

    final success = _successTotal();
    final fail = _failTotal();
    final efficiency = _successPercent(success, fail);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.selectedPlayer != null
                      ? Icons.sports_soccer_rounded
                      : Icons.person_outline_rounded,
                  color: const Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerName.isNotEmpty ? playerName : 'Игрок не выбран',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.selectedEpisode != null
                          ? 'Эпизод: ${widget.selectedEpisode!['event_title'] ?? 'Без названия'}'
                          : 'Эпизод не выбран',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.quickSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (widget.selectedPlayer != null && widget.selectedEpisode != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _topMetricCard(
                    'Удачные',
                    success.toString(),
                    const Color(0xFF16A34A),
                    const Color(0xFFECFDF3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _topMetricCard(
                    'Неудачные',
                    fail.toString(),
                    const Color(0xFFDC2626),
                    const Color(0xFFFEF2F2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _topMetricCard(
                    'Эффективность',
                    efficiency,
                    const Color(0xFF2563EB),
                    const Color(0xFFEFF6FF),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _topMetricCard(
    String title,
    String value,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalActions = _allActionsTotal();
    final noteExists = widget.noteCtrl.text.trim().isNotEmpty ? 'Есть' : 'Нет';
    final efficiency = _successPercent(_successTotal(), _failTotal());
    final filledMetrics = _filledMetricsCount();

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: 'Всего ТТД',
            value: totalActions.toString(),
            icon: Icons.analytics_outlined,
            tint: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: 'Эффективность',
            value: efficiency,
            icon: Icons.pie_chart_outline_rounded,
            tint: const Color(0xFFF0FDF4),
            iconColor: const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: 'Показателей',
            value: filledMetrics.toString(),
            icon: Icons.table_rows_rounded,
            tint: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: 'Заметка',
            value: noteExists,
            icon: Icons.edit_note_rounded,
            tint: const Color(0xFFF8FAFC),
            iconColor: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color tint,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSelectionMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Выберите игрока и эпизод',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Чтобы начать заполнение ТТД, выберите игрока слева и эпизод из списка справа',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTabs() {
  final sections = [
  {'id': 'main', 'label': 'Основное', 'icon': Icons.sports_soccer},
  {'id': 'passes', 'label': 'Передачи', 'icon': Icons.compare_arrows_rounded},
  {'id': 'gk', 'label': 'Вратарь', 'icon': Icons.sports_handball},
];


    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: sections.map((section) {
          final id = section['id'] as String;
          final isSelected = _currentSection == id;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentSection = id;
                });
                widget.onSectionChanged(id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      section['icon'] as IconData,
                      size: 15,
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        section['label'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isMessageError
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isMessageError
              ? const Color(0xFFFECACA)
              : const Color(0xFFBBDEFB),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.isMessageError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 20,
            color: widget.isMessageError
                ? const Color(0xFFEF4444)
                : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.message!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isMessageError
                    ? const Color(0xFF991B1B)
                    : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _buildQuickActionsList(),
    );
  }

  Widget _buildQuickActionsList() {
  switch (_currentSection) {
    case 'passes':
      return _buildPassSection();
    case 'gk':
      return _buildGoalkeeperSection();
    case 'main':
    default:
      return _buildMainSection();
  }
}

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildMainSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionHeader(
        'Основные действия',
        '+ = удачно, − = неудачно',
        Icons.sports_soccer_rounded,
      ),
      _buildQuickTtdRow('Финт / дриблинг', 'feint_dribble'),
      _buildQuickTtdRow('Удар', 'shot_on_goal'),
      _buildQuickTtdRow('Отбор', 'tackle_duel'),
      _buildQuickTtdRow('Перехват', 'interception_ball'),
      _buildQuickTtdRow('Подбор', 'recovery_ball'),
      _buildQuickTtdRow('Игра головой', 'header_play'),
      _buildQuickTtdRow('Аут', 'throw_ins'),
      _buildQuickTtdRow('Пас АВП', 'pass_avp'),
    ],
  );
}

 Widget _buildPassSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionHeader(
        'Передачи',
        '+ = точная, − = неточная',
        Icons.compare_arrows_rounded,
      ),
      _buildQuickTtdRow('Вперед К', 'pass_forward_short'),
      _buildQuickTtdRow('Вперед С', 'pass_forward_medium'),
      _buildQuickTtdRow('Вперед Д', 'pass_forward_long'),
      _buildQuickTtdRow('Поперек К', 'pass_side_short'),
      _buildQuickTtdRow('Поперек С', 'pass_side_medium'),
      _buildQuickTtdRow('Поперек Д', 'pass_side_long'),
      _buildQuickTtdRow('Назад К', 'pass_back_short'),
      _buildQuickTtdRow('Назад С', 'pass_back_medium'),
      _buildQuickTtdRow('Назад Д', 'pass_back_long'),
    ],
  );
}

   Widget _buildDefenseSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionHeader(
        'Оборона',
        '+ = удачное действие, − = неудачное',
        Icons.shield_rounded,
      ),
      _buildQuickTtdRow('Отбор', 'tackle_duel'),
      _buildQuickTtdRow('Перехват', 'interception_ball'),
      _buildQuickTtdRow('Подбор', 'recovery_ball'),
      _buildQuickTtdRow('Игра головой', 'header_play'),
      _buildQuickTtdRow('Аут', 'throw_ins'),
    ],
  );
}


  Widget _buildGoalkeeperSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionHeader(
        'Действия вратаря',
        'Для ТТД: + = удачно, − = неудачно',
        Icons.sports_handball,
      ),
      _buildQuickTtdRow('Ввод рукой', 'gk_hand_distribution'),
      _buildQuickTtdRow('Выход', 'gk_coming_out'),
      _buildQuickTtdRow('Ближний бой', 'gk_close_combat'),
      _buildQuickTtdRow('Перехваты', 'gk_interceptions'),
      _buildQuickTtdRow('За штрафной', 'gk_outside_box'),
      _buildQuickTtdRow('Пас К', 'gk_pass_short'),
      _buildQuickTtdRow('Пас С', 'gk_pass_medium'),
      _buildQuickTtdRow('Пас Д', 'gk_pass_long'),
      _buildCounterRow('Сэйв', 'gk_saves'),
      _buildCounterRow('Пропущено', 'gk_conceded'),
    ],
  );
}

  Widget _buildQuickTtdRow(String label, String code) {
    final successValue = _localSuccessCounters[code] ?? 0;
    final failValue = _localFailCounters[code] ?? 0;
    final totalValue = successValue + failValue;
    final percent = _successPercent(successValue, failValue);
    final hasValue = totalValue > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasValue
              ? const Color(0xFFCBD5E1)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCompactBadge(
                'Уд',
                successValue.toString(),
                const Color(0xFF16A34A),
                const Color(0xFFECFDF3),
              ),
              const SizedBox(width: 6),
              _buildCompactBadge(
                'Неуд',
                failValue.toString(),
                const Color(0xFFDC2626),
                const Color(0xFFFEF2F2),
              ),
              const SizedBox(width: 6),
              _buildCompactBadge(
                '%',
                percent,
                const Color(0xFF2563EB),
                const Color(0xFFEFF6FF),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildWideActionButton(
                  icon: Icons.add_rounded,
                  text: 'Удачно',
                  color: const Color(0xFF16A34A),
                  bg: const Color(0xFFECFDF3),
                  border: const Color(0xFFBBF7D0),
                  onTap: () {
                    setState(() {
                      _localSuccessCounters[code] =
                          (_localSuccessCounters[code] ?? 0) + 1;
                      _saveStateForCurrentSelection();
                    });
                    widget.onSaveQuickTtd(code, label, true);
                    _showSnack('$label: удачно +1', Colors.green);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildWideActionButton(
                  icon: Icons.remove_rounded,
                  text: 'Неудачно',
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEF2F2),
                  border: const Color(0xFFFECACA),
                  onTap: () {
                    setState(() {
                      _localFailCounters[code] =
                          (_localFailCounters[code] ?? 0) + 1;
                      _saveStateForCurrentSelection();
                    });
                    widget.onSaveQuickTtd(code, label, false);
                    _showSnack('$label: неудачно +1', Colors.red);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBadge(
    String title,
    String value,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(0.85),
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterRow(String label, String code) {
    final currentValue = _localCounters[code] ?? 0;
    final hasValue = currentValue > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasValue ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasValue
              ? const Color(0xFFFDE68A)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: hasValue ? const Color(0xFFF59E0B) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: hasValue
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              currentValue.toString(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: hasValue ? Colors.white : const Color(0xFFF59E0B),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildActionButton(
            icon: Icons.add,
            color: const Color(0xFF16A34A),
            bg: const Color(0xFFECFDF3),
            border: const Color(0xFFBBF7D0),
            onTap: () {
              setState(() {
                _localCounters[code] = (_localCounters[code] ?? 0) + 1;
                _saveStateForCurrentSelection();
              });
              widget.onSaveSingleTtd(code, label, 1);
              _showSnack('$label +1', Colors.green);
            },
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.remove,
            color: const Color(0xFFDC2626),
            bg: const Color(0xFFFEF2F2),
            border: const Color(0xFFFECACA),
            onTap: () {
              final old = _localCounters[code] ?? 0;
              if (old <= 0) return;

              setState(() {
                _localCounters[code] = old - 1;
                _saveStateForCurrentSelection();
              });
              widget.onSaveSingleTtd(code, label, -1);
              _showSnack('$label -1', Colors.red);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    required VoidCallback onTap,
  }) {
    return _AnimatedPulseActionButton(
      onTap: widget.quickSaving ? null : onTap,
      pulseColor: color,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildWideActionButton({
    required IconData icon,
    required String text,
    required Color color,
    required Color bg,
    required Color border,
    required VoidCallback onTap,
  }) {
    return _AnimatedPulseActionButton(
      onTap: widget.quickSaving ? null : onTap,
      pulseColor: color,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 7),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBlock() {
    final label = _ratingLabel(_selectedRating);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Оценка эпизода',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(5, (index) {
              final rating = index + 1;
              return Expanded(child: _buildRatingCard(rating));
            }),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Ужасно';
      case 2:
        return 'Плохо';
      case 3:
        return 'Средне';
      case 4:
        return 'Хорошо';
      case 5:
      default:
        return 'Отлично';
    }
  }

  Widget _buildRatingCard(int rating) {
    final isSelected = _selectedRating == rating;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRating = rating;
          _saveStateForCurrentSelection();
        });
        widget.onSaveSingleTtd('rating', 'Оценка', rating);
        _showSnack('Оценка: $rating', Colors.blue);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(right: rating == 5 ? 0 : 6),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              rating.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: widget.noteCtrl,
        maxLines: 4,
        minLines: 3,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Добавить комментарий к действию...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          suffixIcon: widget.noteCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    widget.noteCtrl.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.saving
            ? null
            : () {
                _saveStateForCurrentSelection();
                widget.onSaveEvent();
                _showSnack('Сохранение...', Colors.blue);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: widget.saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Сохранить действие',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showSnack(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 500),
        backgroundColor: color,
      ),
    );
  }
}

class _AnimatedPulseActionButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color pulseColor;

  const _AnimatedPulseActionButton({
    required this.child,
    required this.onTap,
    required this.pulseColor,
  });

  @override
  State<_AnimatedPulseActionButton> createState() =>
      _AnimatedPulseActionButtonState();
}

class _AnimatedPulseActionButtonState
    extends State<_AnimatedPulseActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _pressed = false;
  bool _glowVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runTapAnimation() async {
    if (widget.onTap == null) return;

    setState(() {
      _pressed = true;
      _glowVisible = true;
    });

    await _controller.forward(from: 0);

    if (mounted) {
      setState(() {
        _pressed = false;
      });
    }

    widget.onTap?.call();

    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) {
      setState(() {
        _glowVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.86 : 1.0;

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap == null) return;
        setState(() => _pressed = true);
      },
      onTapCancel: () {
        if (mounted) {
          setState(() => _pressed = false);
        }
      },
      onTapUp: (_) {
        if (mounted) {
          setState(() => _pressed = false);
        }
      },
      onTap: _runTapAnimation,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulseScale = 1.0 + (_controller.value * 0.45);
          final pulseOpacity = (1.0 - _controller.value) * 0.30;

          return Stack(
            alignment: Alignment.center,
            children: [
              if (_glowVisible)
                Opacity(
                  opacity: pulseOpacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: pulseScale,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: widget.pulseColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _pressed ? 0.88 : 1.0,
                  duration: const Duration(milliseconds: 90),
                  child: child,
                ),
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}