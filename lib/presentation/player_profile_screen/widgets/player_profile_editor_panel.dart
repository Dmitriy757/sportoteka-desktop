import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/player_profile_models.dart';
import 'player_profile_ui.dart';

enum PlayerProfileEditorMode { metrics, medical }

class PlayerProfileEditorPanel extends StatefulWidget {
  final PlayerProfileEditorMode mode;
  final PlayerProfileSnapshot data;
  final Map<String, dynamic>? medicalRecord;
  final VoidCallback onClose;
  final Future<void> Function(Map<String, dynamic>) onSaveMetrics;
  final Future<void> Function(Map<String, dynamic>, PlatformFile?) onSaveMedical;

  const PlayerProfileEditorPanel({
    super.key,
    required this.mode,
    required this.data,
    required this.onClose,
    required this.onSaveMetrics,
    required this.onSaveMedical,
    this.medicalRecord,
  });

  @override
  State<PlayerProfileEditorPanel> createState() => _PlayerProfileEditorPanelState();
}

class _PlayerProfileEditorPanelState extends State<PlayerProfileEditorPanel> {
  late final TextEditingController height;
  late final TextEditingController weight;
  late final TextEditingController title;
  late final TextEditingController note;
  late DateTime date;
  bool saving = false;
  bool _dateCalendarOpen = false;
  PlatformFile? attachment;
  bool removeExistingFile = false;

  String _s(dynamic v) => '${v ?? ''}'.trim();

  @override
  void initState() {
    super.initState();
    final p = widget.data.player;
    final r = widget.medicalRecord;
    height = TextEditingController(
      text: _s(p['height'] ?? p['height_cm']),
    );
    weight = TextEditingController(
      text: _s(p['weight'] ?? p['weight_kg']),
    );
    title = TextEditingController(text: _s(r?['title'] ?? r?['diagnosis'] ?? r?['type']));
    note = TextEditingController(text: _s(r?['note'] ?? r?['description'] ?? r?['comment']));
    date = DateTime.tryParse(_s(r?['record_date'] ?? r?['date'] ?? p['metrics_date']).replaceAll(' ', 'T')) ?? DateTime.now();
  }

  @override
  void dispose() {
    height.dispose();
    weight.dispose();
    title.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.mode == PlayerProfileEditorMode.metrics;
    final content = Material(
      color: Colors.white,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: const BoxDecoration(color: Colors.white),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: PpColors.greenSoft, borderRadius: BorderRadius.circular(10)),
                  child: Icon(metrics ? Icons.straighten_rounded : Icons.medical_information_rounded, color: PpColors.green, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(metrics ? 'Физические метрики' : widget.medicalRecord == null ? 'Новая медицинская запись' : 'Редактирование записи', style: PpText.title(16)),
                  const SizedBox(height: 2),
                  Text(metrics ? 'Рост и вес игрока' : 'Медицинская история по датам', style: PpText.body(10.8)),
                ])),
                _HeaderAction(icon: Icons.close_rounded, tooltip: 'Закрыть', onTap: saving ? null : widget.onClose),
                const SizedBox(width: 7),
                _HeaderAction(icon: Icons.save_rounded, tooltip: 'Сохранить', primary: true, loading: saving, onTap: saving ? null : _save),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                child: metrics ? _metricsForm() : _medicalForm(),
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        content,
        if (_dateCalendarOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _dateCalendarOpen = false),
              child: Container(color: Colors.black.withOpacity(.05)),
            ),
          ),
          Positioned.fill(
            child: Material(
              elevation: 10,
              color: Colors.white,
              shadowColor: Colors.black26,
              child: _InlineMedicalDateCalendar(
                initialDate: date,
                onCancel: () => setState(() => _dateCalendarOpen = false),
                onSelected: (value) => setState(() {
                  date = value;
                  _dateCalendarOpen = false;
                }),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _metricsForm() {
    final maxSession = widget.data.trackerMaxHrSession;
    final restSession = widget.data.trackerRestHrSession;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _field(height, 'Рост, см'),
      const SizedBox(height: 12),
      _field(weight, 'Вес, кг'),
      const SizedBox(height: 18),
      PpSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PpSectionTitle(title: 'Данные трекера', subtitle: 'Рассчитываются автоматически по сохранённым сессиям'),
        const SizedBox(height: 12),
        _readonly('Максимальный пульс', maxSession == null ? 'Нет данных' : '${maxSession.maxHr.round()} уд/мин · ${_date(maxSession.date)}'),
        _readonly('Пульс покоя', restSession == null ? 'Нет данных min_hr' : '${restSession.minHr.round()} уд/мин · ${_date(restSession.date)}'),
        const SizedBox(height: 8),
        Text('Эти значения нельзя вводить вручную. HR max берётся как максимум по сессиям, пульс покоя — как минимальный достоверный min_hr.', style: PpText.body(10.5)),
      ])),
    ]);
  }

  Widget _medicalForm() {
    final existingName = _s(widget.medicalRecord?['file_name']);
    final existingUrl = _s(widget.medicalRecord?['file_url'] ?? widget.medicalRecord?['file_path']);
    final shownName = attachment?.name ?? (!removeExistingFile ? existingName : '');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: title,
        cursorColor: PpColors.greenDark,
        style: PpText.body(
          11,
          color: PpColors.text,
          weight: FontWeight.w500,
        ),
        decoration: _decoration('Название / диагноз'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: note,
        minLines: 6,
        maxLines: 12,
        cursorColor: PpColors.greenDark,
        style: PpText.body(
          11,
          color: PpColors.text,
          weight: FontWeight.w500,
        ),
        decoration: _decoration('Пояснение, ограничения, рекомендации'),
      ),
      const SizedBox(height: 12),
      Material(
        color: PpColors.soft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: PpColors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Дата записи',
                        style: PpText.body(
                          11,
                          color: PpColors.text,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('dd.MM.yyyy').format(date),
                        style: PpText.body(10.6),
                      ),
                    ],
                  ),
                ),
                Text(
                  _dateCalendarOpen ? 'Закрыть' : 'Изменить',
                  style: PpText.body(
                    10.2,
                    color: PpColors.greenDark,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PpColors.soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.attach_file_rounded, size: 18, color: PpColors.green),
            const SizedBox(width: 8),
            Expanded(child: Text('Медицинский файл', style: PpText.body(11.2, color: PpColors.text, weight: FontWeight.w600))),
            TextButton.icon(
              onPressed: saving ? null : _pickAttachment,
              icon: const Icon(Icons.upload_file_rounded, size: 16),
              label: Text(shownName.isEmpty ? 'Прикрепить' : 'Заменить'),
            ),
          ]),
          Text('PDF, DOC, DOCX или фотография. Максимальный размер — 20 МБ.', style: PpText.body(10.2)),
          if (shownName.isNotEmpty) ...[
            const SizedBox(height: 9),
            Row(children: [
              _attachmentIcon(shownName),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(shownName, maxLines: 2, overflow: TextOverflow.ellipsis, style: PpText.body(10.8, color: PpColors.text, weight: FontWeight.w600)),
                if (attachment != null) Text(_fileSize(attachment!.size), style: PpText.body(9.8)),
                if (attachment == null && existingUrl.isNotEmpty) Text('Файл уже сохранён на сервере', style: PpText.body(9.8)),
              ])),
              IconButton(
                tooltip: 'Убрать файл',
                onPressed: saving ? null : () => setState(() {
                  attachment = null;
                  removeExistingFile = existingName.isNotEmpty || existingUrl.isNotEmpty;
                }),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ]),
          ] else ...[
            const SizedBox(height: 8),
            Text('Файл не выбран', style: PpText.body(10.2)),
          ],
        ]),
      ),
    ]);
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.size > 20 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Файл больше 20 МБ')));
      return;
    }
    setState(() {
      attachment = file;
      removeExistingFile = false;
    });
  }

  Widget _attachmentIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    final icon = ext == 'pdf'
        ? Icons.picture_as_pdf_rounded
        : (ext == 'doc' || ext == 'docx')
            ? Icons.description_rounded
            : Icons.image_rounded;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, size: 18, color: PpColors.greenDark),
    );
  }

  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  Widget _field(TextEditingController controller, String label) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        cursorColor: PpColors.greenDark,
        style: PpText.body(
          11,
          color: PpColors.text,
          weight: FontWeight.w500,
        ),
        decoration: _decoration(label),
      );
  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: PpText.body(10.6, color: PpColors.muted2),
        floatingLabelStyle: PpText.caption(
          size: 9.5,
          color: PpColors.greenDark,
        ),
        hintStyle: PpText.body(10.6, color: PpColors.muted2),
        filled: true,
        fillColor: PpColors.soft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PpColors.green),
        ),
      );
  Widget _readonly(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(label, style: PpText.body(11))), Flexible(child: Text(value, textAlign: TextAlign.right, style: PpText.body(11.2, color: PpColors.text, weight: FontWeight.w600)))]));
  String _date(DateTime? value) => value == null ? 'без даты' : DateFormat('dd.MM.yyyy').format(value);

  Future<void> _pickDate() async {
    setState(() => _dateCalendarOpen = true);
  }

  Future<void> _save() async {
    if (widget.mode == PlayerProfileEditorMode.metrics) {
      final heightValue =
          double.tryParse(height.text.trim().replaceAll(',', '.'));
      final weightValue =
          double.tryParse(weight.text.trim().replaceAll(',', '.'));
      if (heightValue == null || heightValue < 70 || heightValue > 230) {
        _message('Проверьте рост: допустимо от 70 до 230 см');
        return;
      }
      if (weightValue == null || weightValue < 15 || weightValue > 200) {
        _message('Проверьте вес: допустимо от 15 до 200 кг');
        return;
      }
    }
    setState(() => saving = true);
    try {
      if (widget.mode == PlayerProfileEditorMode.metrics) {
        final heightValue =
            double.parse(height.text.trim().replaceAll(',', '.'));
        final weightValue =
            double.parse(weight.text.trim().replaceAll(',', '.'));
        await widget.onSaveMetrics({
          'height': heightValue,
          'height_cm': heightValue,
          'weight': weightValue,
          'weight_kg': weightValue,
          'metrics_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        });
      } else {
        await widget.onSaveMedical({
          ...?widget.medicalRecord,
          'title': title.text.trim(),
          'note': note.text.trim(),
          'record_date': DateFormat('yyyy-MM-dd').format(date),
          'remove_file': removeExistingFile,
        }, attachment);
      }
      if (mounted) {
        _message(
          widget.mode == PlayerProfileEditorMode.metrics
              ? 'Рост и вес сохранены'
              : 'Медицинская запись сохранена',
        );
        widget.onClose();
      }
    } catch (error) {
      if (mounted) _message('Не удалось сохранить: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}


class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool primary;
  final bool loading;

  const _HeaderAction({required this.icon, required this.tooltip, required this.onTap, this.primary = false, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary ? PpColors.greenSoft : PpColors.soft2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: loading
                ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: PpColors.greenDark))
                : Icon(icon, size: 19, color: primary ? PpColors.greenDark : PpColors.text),
          ),
        ),
      ),
    );
  }
}



class _InlineMedicalDateCalendar extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onCancel;

  const _InlineMedicalDateCalendar({
    required this.initialDate,
    required this.onSelected,
    required this.onCancel,
  });

  @override
  State<_InlineMedicalDateCalendar> createState() => _InlineMedicalDateCalendarState();
}

class _InlineMedicalDateCalendarState extends State<_InlineMedicalDateCalendar> {
  late DateTime month;
  late DateTime selected;

  @override
  void initState() {
    super.initState();
    selected = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    month = DateTime(selected.year, selected.month);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: PpColors.greenSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: PpColors.green, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Дата медицинской записи', style: PpText.title(15.5)),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd.MM.yyyy').format(selected),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PpText.body(10.5),
                        ),
                      ],
                    ),
                  ),
                  _MedicalCalendarAction(
                    icon: Icons.close_rounded,
                    tooltip: 'Закрыть',
                    onTap: widget.onCancel,
                  ),
                  const SizedBox(width: 5),
                  _MedicalCalendarAction(
                    icon: Icons.check_rounded,
                    tooltip: 'Выбрать дату',
                    onTap: () => widget.onSelected(selected),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: PpColors.line),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_monthTitle(month), style: PpText.title(18)),
                              const SizedBox(height: 2),
                              Text('Выберите дату медицинской записи', style: PpText.body(10.5)),
                            ],
                          ),
                        ),
                        _MedicalCalendarAction(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Предыдущий месяц',
                          onTap: () => setState(() => month = DateTime(month.year, month.month - 1)),
                        ),
                        const SizedBox(width: 4),
                        _MedicalCalendarAction(
                          icon: Icons.chevron_right_rounded,
                          tooltip: 'Следующий месяц',
                          onTap: () => setState(() => month = DateTime(month.year, month.month + 1)),
                        ),
                        const SizedBox(width: 4),
                        _MedicalCalendarAction(
                          icon: Icons.calendar_today_rounded,
                          tooltip: 'Сегодня',
                          onTap: () {
                            final now = DateTime.now();
                            setState(() {
                              selected = DateTime(now.year, now.month, now.day);
                              month = DateTime(now.year, now.month);
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        _MedicalCalendarAction(
                          icon: Icons.refresh_rounded,
                          tooltip: 'Вернуть исходную дату',
                          onTap: () => setState(() {
                            selected = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
                            month = DateTime(selected.year, selected.month);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _MedicalSummaryCell(value: '${selected.day}', label: 'День', hint: _weekday(selected))),
                        const SizedBox(width: 6),
                        Expanded(child: _MedicalSummaryCell(value: '${selected.month}', label: 'Месяц', hint: _monthName(selected.month))),
                        const SizedBox(width: 6),
                        Expanded(child: _MedicalSummaryCell(value: '${selected.year}', label: 'Год', hint: 'дата записи')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _monthGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthGrid() {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1;
    final gridStart = first.subtract(Duration(days: leading));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                .map(
                  (e) => Expanded(
                    child: Center(
                      child: Text(e, style: PpText.body(10, weight: FontWeight.w600)),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellHeight = constraints.maxWidth < 520 ? 45.0 : 48.0;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                mainAxisExtent: cellHeight,
              ),
              itemCount: 42,
              itemBuilder: (_, index) {
                final day = gridStart.add(Duration(days: index));
                final currentMonth = day.month == month.month;
                final active = _sameDay(day, selected);
                final today = _sameDay(day, DateTime.now());

                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() {
                      selected = DateTime(day.year, day.month, day.day);
                      if (!currentMonth) month = DateTime(day.year, day.month);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: active ? PpColors.greenSoft : const Color(0xFFF7F8F7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active || today ? PpColors.greenBorder : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: PpText.body(
                            11.2,
                            color: currentMonth ? PpColors.text : const Color(0xFFB3B8C0),
                            weight: active || today ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthTitle(DateTime value) => '${_monthName(value.month)} ${value.year}';

  String _monthName(int month) {
    const months = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    return months[month - 1];
  }

  String _weekday(DateTime value) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[value.weekday - 1];
  }
}

class _MedicalCalendarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MedicalCalendarAction({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: PpColors.soft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: PpColors.text),
          ),
        ),
      ),
    );
  }
}

class _MedicalSummaryCell extends StatelessWidget {
  final String value;
  final String label;
  final String hint;

  const _MedicalSummaryCell({required this.value, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF7F8F7), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Text(value, style: PpText.value(13)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: PpText.body(9.5, color: PpColors.text, weight: FontWeight.w600)),
                Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: PpText.body(8.7)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalDateCalendar extends StatefulWidget {
  final DateTime initialDate;
  const _MedicalDateCalendar({required this.initialDate});
  @override State<_MedicalDateCalendar> createState() => _MedicalDateCalendarState();
}

class _MedicalDateCalendarState extends State<_MedicalDateCalendar> {
  late DateTime month;
  late DateTime selected;
  @override void initState() { super.initState(); selected = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day); month = DateTime(selected.year, selected.month); }

  @override Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday + 6) % 7;
    final total = ((leading + days + 6) ~/ 7) * 7;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: PpColors.greenSoft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_month_rounded, color: PpColors.green, size: 19)),
            const SizedBox(width: 10),
            Expanded(child: Text('Дата медицинской записи', style: PpText.title(15.5))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(child: Center(child: Text(DateFormat('LLLL yyyy', 'ru').format(month), style: PpText.title(13)))),
            IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
          ]),
          Row(children: ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'].map((e) => Expanded(child: Center(child: Text(e, style: PpText.body(9.5))))).toList()),
          const SizedBox(height: 5),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 5, crossAxisSpacing: 5),
            itemCount: total,
            itemBuilder: (_, i) {
              final day = i - leading + 1;
              if (day < 1 || day > days) return const SizedBox();
              final d = DateTime(month.year, month.month, day);
              final active = d.year == selected.year && d.month == selected.month && d.day == selected.day;
              return InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => setState(() => selected = d),
                child: Container(
                  decoration: BoxDecoration(color: active ? PpColors.green : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                  child: Center(child: Text('$day', style: PpText.body(11, color: active ? Colors.white : PpColors.text, weight: active ? FontWeight.w700 : FontWeight.w500))),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text(DateFormat('dd.MM.yyyy').format(selected), style: PpText.body(11.2, color: PpColors.text, weight: FontWeight.w600))),
            TextButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Выбрать')),
          ]),
        ]),
      ),
    );
  }
}
