import 'package:flutter/material.dart';

import '../models/player_profile_models.dart';
import 'player_profile_ui.dart';

class PlayerSchoolProfileEditorPanel extends StatefulWidget {
  final PlayerProfileSnapshot data;
  final VoidCallback onClose;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const PlayerSchoolProfileEditorPanel({
    super.key,
    required this.data,
    required this.onClose,
    required this.onSave,
  });

  @override
  State<PlayerSchoolProfileEditorPanel> createState() =>
      _PlayerSchoolProfileEditorPanelState();
}

class _PlayerSchoolProfileEditorPanelState
    extends State<PlayerSchoolProfileEditorPanel> {
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  static const _groups = <_FieldGroup>[
    _FieldGroup(
      'Личные данные',
      'Анкета игрока для школы',
      PpColors.green,
      <_FieldSpec>[
        _FieldSpec('birth_date', 'Дата рождения', hint: 'ГГГГ-ММ-ДД'),
        _FieldSpec('gender', 'Пол'),
        _FieldSpec('citizenship', 'Гражданство'),
        _FieldSpec('city', 'Город'),
        _FieldSpec('address', 'Адрес проживания', lines: 2),
      ],
    ),
    _FieldGroup(
      'Футбольные данные',
      'Роль, группа и спортивная история',
      PpColors.greenDark,
      <_FieldSpec>[
        _FieldSpec('position', 'Основное амплуа'),
        _FieldSpec('secondary_position', 'Дополнительное амплуа'),
        _FieldSpec('dominant_foot', 'Ведущая нога'),
        _FieldSpec('jersey_number', 'Игровой номер', number: true),
        _FieldSpec('sport_rank', 'Разряд / уровень'),
        _FieldSpec('previous_club', 'Предыдущий клуб / школа'),
        _FieldSpec('enrollment_date', 'Дата зачисления', hint: 'ГГГГ-ММ-ДД'),
        _FieldSpec('player_status', 'Статус в школе'),
        _FieldSpec('federation_id', 'ID федерации / реестра'),
      ],
    ),
    _FieldGroup(
      'Обучение',
      'Данные общеобразовательной школы',
      PpColors.amber,
      <_FieldSpec>[
        _FieldSpec('school_name', 'Школа'),
        _FieldSpec('school_class', 'Класс'),
        _FieldSpec('school_shift', 'Смена'),
        _FieldSpec('education_note', 'Особенности расписания', lines: 2),
      ],
    ),
    _FieldGroup(
      'Родитель и экстренная связь',
      'Контакты для школы и тренера',
      PpColors.green,
      <_FieldSpec>[
        _FieldSpec('parent_name', 'ФИО родителя / представителя'),
        _FieldSpec('parent_relation', 'Кем приходится'),
        _FieldSpec('parent_phone', 'Телефон'),
        _FieldSpec('parent_email', 'Электронная почта'),
        _FieldSpec('emergency_contact', 'Экстренный контакт'),
      ],
    ),
    _FieldGroup(
      'Документы и учёт',
      'Реквизиты без загрузки файлов',
      PpColors.amber,
      <_FieldSpec>[
        _FieldSpec('contract_number', 'Номер договора'),
        _FieldSpec('contract_date', 'Дата договора', hint: 'ГГГГ-ММ-ДД'),
        _FieldSpec('admission_order', 'Приказ о зачислении'),
        _FieldSpec('insurance_number', 'Номер страховки'),
        _FieldSpec('medical_clearance_until', 'Допуск действителен до', hint: 'ГГГГ-ММ-ДД'),
      ],
    ),
    _FieldGroup(
      'Экипировка и логистика',
      'Размеры и организационные заметки',
      PpColors.greenDark,
      <_FieldSpec>[
        _FieldSpec('equipment_size', 'Размер формы'),
        _FieldSpec('shoe_size', 'Размер обуви', number: true),
        _FieldSpec('transport_note', 'Трансфер / кто забирает', lines: 2),
        _FieldSpec('profile_note', 'Дополнительная информация', lines: 3),
      ],
    ),
  ];

  String _s(dynamic value) => '${value ?? ''}'.trim();

  @override
  void initState() {
    super.initState();
    final source = <String, dynamic>{
      ...widget.data.player,
      ...widget.data.schoolProfile,
    };
    for (final group in _groups) {
      for (final field in group.fields) {
        dynamic value = source[field.key];
        if (field.key == 'jersey_number') {
          value ??= source['number'] ?? source['shirt_number'];
        }
        _controllers[field.key] = TextEditingController(text: _s(value));
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                itemCount: _groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _group(_groups[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PpColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: PpColors.greenDark,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Анкета футбольной школы', style: PpText.title(16)),
                const SizedBox(height: 2),
                Text('Спортивные, учебные и контактные данные', style: PpText.body(10.8)),
              ],
            ),
          ),
          _action(Icons.close_rounded, 'Закрыть', widget.onClose),
          const SizedBox(width: 7),
          _action(
            Icons.save_rounded,
            'Сохранить',
            _saving ? null : _save,
            primary: true,
          ),
        ],
      ),
    );
  }

  Widget _group(_FieldGroup group) {
    return PpSurface(
      color: PpColors.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PpSectionTitle(
            title: group.title,
            subtitle: group.subtitle,
            dotColor: group.color,
          ),
          const SizedBox(height: 12),
          ...group.fields.asMap().entries.map((entry) {
            final field = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == group.fields.length - 1 ? 0 : 10,
              ),
              child: TextField(
                controller: _controllers[field.key],
                minLines: field.lines,
                maxLines: field.lines,
                cursorColor: PpColors.greenDark,
                style: PpText.body(
                  11,
                  color: PpColors.text,
                  weight: FontWeight.w500,
                ),
                keyboardType: field.number
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: field.label,
                  hintText: field.hint,
                  labelStyle: PpText.body(10.6, color: PpColors.muted2),
                  floatingLabelStyle: PpText.caption(
                    size: 9.5,
                    color: PpColors.greenDark,
                  ),
                  hintStyle: PpText.body(10.6, color: PpColors.muted2),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: PpColors.green),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _action(
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    bool primary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: primary ? PpColors.greenSoft : PpColors.soft2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 38,
            height: 38,
            child: _saving && primary
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PpColors.greenDark,
                    ),
                  )
                : Icon(
                    icon,
                    size: 19,
                    color: primary ? PpColors.greenDark : PpColors.text,
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final values = <String, dynamic>{};
    _controllers.forEach((key, controller) {
      values[key] = controller.text.trim();
    });
    values['number'] = values['jersey_number'];
    values['shirt_number'] = values['jersey_number'];

    setState(() => _saving = true);
    try {
      await widget.onSave(values);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Анкета игрока сохранена')),
      );
      widget.onClose();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить анкету: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _FieldGroup {
  final String title;
  final String subtitle;
  final Color color;
  final List<_FieldSpec> fields;

  const _FieldGroup(this.title, this.subtitle, this.color, this.fields);
}

class _FieldSpec {
  final String key;
  final String label;
  final String? hint;
  final int lines;
  final bool number;

  const _FieldSpec(
    this.key,
    this.label, {
    this.hint,
    this.lines = 1,
    this.number = false,
  });
}
