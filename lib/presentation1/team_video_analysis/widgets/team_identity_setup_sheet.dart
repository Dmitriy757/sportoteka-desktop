import 'package:flutter/material.dart';
import '../models/team_visual_config.dart';

class TeamIdentitySetupSheet extends StatefulWidget {
  final TeamVisualConfig myTeamConfig;
  final TeamVisualConfig opponentTeamConfig;
  final void Function(
    TeamVisualConfig myConfig,
    TeamVisualConfig opponentConfig,
  ) onApply;

  const TeamIdentitySetupSheet({
    super.key,
    required this.myTeamConfig,
    required this.opponentTeamConfig,
    required this.onApply,
  });

  @override
  State<TeamIdentitySetupSheet> createState() => _TeamIdentitySetupSheetState();
}

class _TeamIdentitySetupSheetState extends State<TeamIdentitySetupSheet> {
  late TeamVisualConfig _myConfig;
  late TeamVisualConfig _opponentConfig;

  final _myNameCtrl = TextEditingController();
  final _oppNameCtrl = TextEditingController();

  static const List<Color> _palette = [
    Color(0xFF16A34A),
    Color(0xFF2563EB),
    Color(0xFFDC2626),
    Color(0xFFF59E0B),
    Color(0xFF7C3AED),
    Color(0xFF0F172A),
    Color(0xFFFFFFFF),
    Color(0xFF14B8A6),
  ];

  @override
  void initState() {
    super.initState();
    _myConfig = widget.myTeamConfig;
    _opponentConfig = widget.opponentTeamConfig;
    _myNameCtrl.text = _myConfig.displayName;
    _oppNameCtrl.text = _opponentConfig.displayName;
  }

  @override
  void dispose() {
    _myNameCtrl.dispose();
    _oppNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Настройка команд',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              _buildSidePicker(),
              const SizedBox(height: 16),
              _buildTeamCard(
                title: 'Моя команда',
                controller: _myNameCtrl,
                config: _myConfig,
                onPrimaryChanged: (c) {
                  setState(() {
                    _myConfig = _myConfig.copyWith(primaryColor: c);
                  });
                },
                onSecondaryChanged: (c) {
                  setState(() {
                    _myConfig = _myConfig.copyWith(secondaryColor: c);
                  });
                },
                onTextChanged: (c) {
                  setState(() {
                    _myConfig = _myConfig.copyWith(textColor: c);
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildTeamCard(
                title: 'Соперник',
                controller: _oppNameCtrl,
                config: _opponentConfig,
                onPrimaryChanged: (c) {
                  setState(() {
                    _opponentConfig = _opponentConfig.copyWith(primaryColor: c);
                  });
                },
                onSecondaryChanged: (c) {
                  setState(() {
                    _opponentConfig =
                        _opponentConfig.copyWith(secondaryColor: c);
                  });
                },
                onTextChanged: (c) {
                  setState(() {
                    _opponentConfig = _opponentConfig.copyWith(textColor: c);
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildPreview(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(
                      _myConfig.copyWith(displayName: _myNameCtrl.text.trim()),
                      _opponentConfig.copyWith(
                        displayName: _oppNameCtrl.text.trim(),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Применить',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidePicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Какая сторона — моя команда',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<AnalysisSideTag>(
            segments: const [
              ButtonSegment(
                value: AnalysisSideTag.home,
                label: Text('home'),
              ),
              ButtonSegment(
                value: AnalysisSideTag.away,
                label: Text('away'),
              ),
            ],
            selected: {_myConfig.sideTag},
            onSelectionChanged: (value) {
              final mySide = value.first;
              final oppSide = mySide == AnalysisSideTag.home
                  ? AnalysisSideTag.away
                  : AnalysisSideTag.home;

              setState(() {
                _myConfig = _myConfig.copyWith(sideTag: mySide);
                _opponentConfig = _opponentConfig.copyWith(sideTag: oppSide);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard({
    required String title,
    required TextEditingController controller,
    required TeamVisualConfig config,
    required ValueChanged<Color> onPrimaryChanged,
    required ValueChanged<Color> onSecondaryChanged,
    required ValueChanged<Color> onTextChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              )),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Основной цвет'),
          const SizedBox(height: 8),
          _buildColorRow(config.primaryColor, onPrimaryChanged),
          const SizedBox(height: 10),
          const Text('Доп. цвет'),
          const SizedBox(height: 8),
          _buildColorRow(config.secondaryColor, onSecondaryChanged),
          const SizedBox(height: 10),
          const Text('Цвет текста'),
          const SizedBox(height: 8),
          _buildColorRow(config.textColor, onTextChanged),
        ],
      ),
    );
  }

  Widget _buildColorRow(Color selected, ValueChanged<Color> onChanged) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _palette.map((color) {
        final isSelected = color.value == selected.value;
        return GestureDetector(
          onTap: () => onChanged(color),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade300,
                width: isSelected ? 3 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Превью',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _previewBadge(_myConfig),
          const SizedBox(height: 8),
          _previewBadge(_opponentConfig),
        ],
      ),
    );
  }

  Widget _previewBadge(TeamVisualConfig cfg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cfg.primaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cfg.secondaryColor, width: 2),
      ),
      child: Text(
        cfg.displayName.isEmpty ? 'Без названия' : cfg.displayName,
        style: TextStyle(
          color: cfg.textColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}