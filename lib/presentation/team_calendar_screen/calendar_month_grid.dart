import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'dart:math' as math;
import 'team_calendar_models.dart';

// Глобальная функция для получения цвета типа события
Color getEventTypeColor(TeamEventType type) {
  switch (type) {
    case TeamEventType.leagueMatch:
      return const Color(0xFFEF4444); // Красный - чемпионат
    case TeamEventType.friendlyMatch:
      return const Color(0xFF3B82F6); // Синий - товарищеские игры (более насыщенный синий)
    case TeamEventType.training:
      return const Color(0xFF10B981); // Зеленый - тренировка
    case TeamEventType.theory:
      return const Color(0xFFF97316); // Оранжевый - теоретические занятия
    case TeamEventType.gym:
      return const Color(0xFF8B5CF6); // Фиолетовый - ОФП/зал
    case TeamEventType.dayOff:
      return const Color(0xFF9CA3AF); // Серый - выходной
  }
}

// Глобальная функция для получения цвета заливки (с прозрачностью)
Color getEventTypeFillColor(TeamEventType type) {
  switch (type) {
    case TeamEventType.training:
      return getEventTypeColor(type).withOpacity(0.35); // Для тренировки 35%
    default:
      return getEventTypeColor(type).withOpacity(0.25); // Для остальных 25%
  }
}

class CalendarMonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, List<TeamEvent>> eventsByDay;
  final DateTime selectedDay;

  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onDayLongPress;

  const CalendarMonthGrid({
    super.key,
    required this.month,
    required this.eventsByDay,
    required this.selectedDay,
    required this.onDayTap,
    required this.onDayLongPress,
  });

  DateTime _firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  DateTime _startGridMonday(DateTime monthAnyDay) {
    final first = _firstDayOfMonth(monthAnyDay);
    final diff = first.weekday - DateTime.monday;
    return first.subtract(Duration(days: diff));
  }

  bool _sameDay(DateTime a, DateTime b) => dateOnly(a) == dateOnly(b);
  bool _isToday(DateTime d) => _sameDay(d, DateTime.now());

  List<TeamEvent> _eventsFor(DateTime day) {
    final key = dateOnly(day);
    final list = (eventsByDay[key] ?? const <TeamEvent>[]).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return list;
  }

  // Получаем уникальные типы событий в порядке приоритета
  List<TeamEventType> _getUniqueTypes(List<TeamEvent> list) {
    if (list.isEmpty) return [];
    
    final types = <TeamEventType>{};
    for (final e in list) {
      types.add(e.type);
    }

    final priorityOrder = <TeamEventType>[
      TeamEventType.leagueMatch,      // Красный - чемпионат
      TeamEventType.friendlyMatch,    // Синий - товарищеские
      TeamEventType.training,         // Зеленый - тренировка
      TeamEventType.theory,           // Оранжевый - теория
      TeamEventType.gym,              // Фиолетовый - ОФП
      TeamEventType.dayOff,           // Серый - выходной
    ];

    return [
      ...priorityOrder.where(types.contains),
      ...types.where((t) => !priorityOrder.contains(t)).toList()
        ..sort((a, b) => a.index.compareTo(b.index)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final card = Colors.white;
    final primary = Theme.of(context).colorScheme.primary;

    final m = DateTime(month.year, month.month, 1);
    final firstGrid = _startGridMonday(m);
    final days = List.generate(42, (i) => firstGrid.add(Duration(days: i)));

    const weekNames = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          // Заголовки дней недели
          Row(
            children: List.generate(7, (i) {
              final isWeekend = i >= 5;
              return Expanded(
                child: Center(
                  child: Text(
                    weekNames[i],
                    style: AppTypography.menuTitle(
                      color: isWeekend
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Сетка дней
          LayoutBuilder(
            builder: (context, c) {
              const crossAxisSpacing = 8.0;
              const mainAxisSpacing = 6.0;
            

              final gridW = c.maxWidth;
              final cellW = (gridW - crossAxisSpacing * 6) / 7;

              // Адаптивная высота
              final cellH = (cellW * 0.82).clamp(56.0, 74.0);
              final pad = (cellW * 0.14).clamp(6.0, 10.0);

              final dayPill = (cellW * 0.45).clamp(18.0, 24.0);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 42,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: mainAxisSpacing,
                  childAspectRatio: cellW / cellH,
                ),
                itemBuilder: (context, idx) {
                  final day = days[idx];
                  final inMonth = day.month == m.month;

                  final isSelected = _sameDay(day, selectedDay);
                  final isToday = _isToday(day);

                  final dayEvents = _eventsFor(day);
                  final uniqueTypes = _getUniqueTypes(dayEvents);

                  final borderColor = isSelected
                      ? primary.withOpacity(0.9)
                      : (isToday
                          ? primary.withOpacity(0.28)
                          : const Color(0xFFF1F5F9));

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onDayTap(day),
                      onLongPress: () => onDayLongPress(day),
                      splashColor: primary.withOpacity(0.10),
                      highlightColor: primary.withOpacity(0.06),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // ОСНОВНАЯ КАРТОЧКА
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: borderColor,
                                  width: isSelected ? 2 : 1.5,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Stack(
                                children: [
                                  // Разделенная заливка под наклоном
                                  if (uniqueTypes.isNotEmpty)
                                    _buildSplitBackground(uniqueTypes, cellW, cellH),
                                  
                                  // Контент поверх заливки
                                  Padding(
                                    padding: EdgeInsets.all(pad),
                                    child: Stack(
                                      children: [
                                        // Верхний левый: дата
                                        Align(
                                          alignment: Alignment.topLeft,
                                          child: Container(
                                            width: dayPill,
                                            height: dayPill,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: isToday && !isSelected
                                                  ? primary.withOpacity(0.10)
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(dayPill / 2),
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                "${day.day}",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  height: 1.0,
                                                  color: inMonth
                                                      ? (isToday ? primary : const Color(0xFF1F2937))
                                                      : const Color(0xFF9CA3AF),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Низ: точки событий
                                        Align(
                                          alignment: Alignment.bottomCenter,
                                          child: SizedBox(
                                            height: 12,
                                            child: _DayDotsAdaptive(
                                              events: dayEvents,
                                              maxDots: 3,
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

                          // Бейдж количества событий
                          if (dayEvents.length >= 3)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: _CountCircleBadge(
                                count: dayEvents.length,
                                filled: isSelected,
                                primary: primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // Создает разделенный фон под наклоном
  Widget _buildSplitBackground(List<TeamEventType> types, double width, double height) {
    if (types.isEmpty) return const SizedBox.shrink();
    
    if (types.length == 1) {
      // Если одно событие - просто заливка
      return Container(
        color: getEventTypeFillColor(types.first),
      );
    }

    if (types.length == 2) {
      // Два цвета - диагональное разделение
      return CustomPaint(
        painter: _TwoColorDiagonalPainter(
          color1: getEventTypeFillColor(types[0]),
          color2: getEventTypeFillColor(types[1]),
        ),
        size: Size(width, height),
        child: Container(),
      );
    }

    if (types.length == 3) {
      // Три цвета - равномерное разделение
      return CustomPaint(
        painter: _ThreeColorEqualPainter(
          color1: getEventTypeFillColor(types[0]),
          color2: getEventTypeFillColor(types[1]),
          color3: getEventTypeFillColor(types[2]),
        ),
        size: Size(width, height),
        child: Container(),
      );
    }

    // 4+ цвета - берем первые 4 и делаем четверное разделение
    return CustomPaint(
      painter: _FourColorEqualPainter(
        color1: getEventTypeFillColor(types[0]),
        color2: getEventTypeFillColor(types[1]),
        color3: getEventTypeFillColor(types[2]),
        color4: getEventTypeFillColor(types[3]),
      ),
      size: Size(width, height),
      child: Container(),
    );
  }
}

// Painter для двух цветов (диагональ)
class _TwoColorDiagonalPainter extends CustomPainter {
  final Color color1;
  final Color color2;

  _TwoColorDiagonalPainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Первый цвет - верхний треугольник
    paint.color = color1;
    Path path1 = Path();
    path1.moveTo(0, 0);
    path1.lineTo(size.width, 0);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint);

    // Второй цвет - нижний треугольник
    paint.color = color2;
    Path path2 = Path();
    path2.moveTo(size.width, 0);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _TwoColorDiagonalPainter oldDelegate) {
    return oldDelegate.color1 != color1 || oldDelegate.color2 != color2;
  }
}

// Painter для трех цветов - равномерное разделение
class _ThreeColorEqualPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final Color color3;

  _ThreeColorEqualPainter({
    required this.color1,
    required this.color2,
    required this.color3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final double w = size.width;
    final double h = size.height;

    // Первая часть (верхний левый угол) - примерно 1/3
    paint.color = color1;
    Path path1 = Path();
    path1.moveTo(0, 0);
    path1.lineTo(w * 0.4, 0);
    path1.lineTo(0, h * 0.4);
    path1.close();
    canvas.drawPath(path1, paint);

    // Вторая часть (центр) - примерно 1/3
    paint.color = color2;
    Path path2 = Path();
    path2.moveTo(w * 0.4, 0);
    path2.lineTo(w, 0);
    path2.lineTo(w, h * 0.4);
    path2.lineTo(w * 0.7, h * 0.7);
    path2.lineTo(0, h * 0.7);
    path2.lineTo(0, h * 0.4);
    path2.lineTo(w * 0.4, 0);
    path2.close();
    canvas.drawPath(path2, paint);

    // Третья часть (нижний правый угол) - примерно 1/3
    paint.color = color3;
    Path path3 = Path();
    path3.moveTo(w * 0.7, h * 0.7);
    path3.lineTo(w, h * 0.4);
    path3.lineTo(w, h);
    path3.lineTo(0, h);
    path3.lineTo(0, h * 0.7);
    path3.lineTo(w * 0.7, h * 0.7);
    path3.close();
    canvas.drawPath(path3, paint);
  }

  @override
  bool shouldRepaint(covariant _ThreeColorEqualPainter oldDelegate) {
    return oldDelegate.color1 != color1 || 
           oldDelegate.color2 != color2 || 
           oldDelegate.color3 != color3;
  }
}

// Painter для четырех цветов - равномерное разделение
class _FourColorEqualPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final Color color3;
  final Color color4;

  _FourColorEqualPainter({
    required this.color1,
    required this.color2,
    required this.color3,
    required this.color4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final double w = size.width;
    final double h = size.height;

    // Первый цвет - верхний левый угол
    paint.color = color1;
    Path path1 = Path();
    path1.moveTo(0, 0);
    path1.lineTo(w * 0.5, 0);
    path1.lineTo(0, h * 0.5);
    path1.close();
    canvas.drawPath(path1, paint);

    // Второй цвет - верхний правый угол
    paint.color = color2;
    Path path2 = Path();
    path2.moveTo(w * 0.5, 0);
    path2.lineTo(w, 0);
    path2.lineTo(w, h * 0.5);
    path2.lineTo(w * 0.5, h * 0.5);
    path2.close();
    canvas.drawPath(path2, paint);

    // Третий цвет - нижний левый угол
    paint.color = color3;
    Path path3 = Path();
    path3.moveTo(0, h * 0.5);
    path3.lineTo(w * 0.5, h * 0.5);
    path3.lineTo(w * 0.5, h);
    path3.lineTo(0, h);
    path3.close();
    canvas.drawPath(path3, paint);

    // Четвертый цвет - нижний правый угол
    paint.color = color4;
    Path path4 = Path();
    path4.moveTo(w * 0.5, h * 0.5);
    path4.lineTo(w, h * 0.5);
    path4.lineTo(w, h);
    path4.lineTo(w * 0.5, h);
    path4.close();
    canvas.drawPath(path4, paint);
  }

  @override
  bool shouldRepaint(covariant _FourColorEqualPainter oldDelegate) {
    return oldDelegate.color1 != color1 || 
           oldDelegate.color2 != color2 || 
           oldDelegate.color3 != color3 ||
           oldDelegate.color4 != color4;
  }
}

/// Адаптивные точки
class _DayDotsAdaptive extends StatelessWidget {
  final List<TeamEvent> events;
  final int maxDots;

  const _DayDotsAdaptive({
    required this.events,
    this.maxDots = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final types = <TeamEventType>{};
    for (final e in events) {
      types.add(e.type);
    }

    final priorityOrder = <TeamEventType>[
      TeamEventType.leagueMatch,      // Красный - чемпионат
      TeamEventType.friendlyMatch,    // Синий - товарищеские
      TeamEventType.training,         // Зеленый - тренировка
      TeamEventType.theory,           // Оранжевый - теория
      TeamEventType.gym,              // Фиолетовый - ОФП
      TeamEventType.dayOff,           // Серый - выходной
    ];

    final ordered = <TeamEventType>[
      ...priorityOrder.where(types.contains),
      ...types.where((t) => !priorityOrder.contains(t)).toList()
        ..sort((a, b) => a.index.compareTo(b.index)),
    ];

    final shown = ordered.take(maxDots).toList();
    final hidden = ordered.length - shown.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < shown.length; i++) ...[
          _EventDot(color: getEventTypeColor(shown[i])),
          if (i != shown.length - 1) const SizedBox(width: 4),
        ],
        if (hidden > 0) ...[
          const SizedBox(width: 6),
          _ExtraEventsBadge(count: hidden),
        ],
      ],
    );
  }
}

/// Точка события
class _EventDot extends StatelessWidget {
  final Color color;
  const _EventDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// Кружок количества событий
class _CountCircleBadge extends StatelessWidget {
  final int count;
  final bool filled;
  final Color primary;

  const _CountCircleBadge({
    required this.count,
    required this.filled,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? "99+" : "$count";

    final bg = filled ? primary : Colors.white;
    final fg = filled ? Colors.white : const Color(0xFF111827);
    final border = filled ? Colors.transparent : const Color(0xFFE5E7EB);

    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            height: 1.0,
            letterSpacing: -0.2,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// Бейдж дополнительных типов событий
class _ExtraEventsBadge extends StatelessWidget {
  final int count;
  const _ExtraEventsBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.90),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        "+$count",
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          height: 1.0,
          color: Colors.white,
        ),
      ),
    );
  }
}