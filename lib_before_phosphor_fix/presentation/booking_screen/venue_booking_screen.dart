import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VenueBookingScreen extends StatefulWidget {
  final int venueId;
  final String venueTitle;
  final int userId;

  const VenueBookingScreen({
    super.key,
    required this.venueId,
    required this.venueTitle,
    required this.userId,
  });

  @override
  State<VenueBookingScreen> createState() => _VenueBookingScreenState();
}

class _VenueBookingScreenState extends State<VenueBookingScreen> {
  // Цвета в стиле тренек-экрана
  final Color _primary = const Color(0xFF1E74C4);
  final Color _bg = const Color(0xFFF5F7FB);
  final Color _textDark = const Color(0xFF0E2440);

  // Данные площадки
  String? address;
  String? conditions;
  String? description;
  String? imageUrl;

  // Дата и слоты
  DateTime selectedDate = DateTime.now();
  final int startHour = 9;
  final int endHour = 22; // не включительно
  int slotStepMinutes = 60;

  // Состояния
  Set<String> bookedSlots = {};
  String? _selectedTimeSlot;
  bool isLoading = true;
  bool isBooking = false;

  @override
  void initState() {
    super.initState();
    _loadVenueDetails();
    _fetchBookedSlots();
  }

  // ---------- API ----------
 Future<void> _loadVenueDetails() async {
  try {
    final uri = Uri.parse(
      'https://sportotekaapp.ru/api/get_venue_details.php?venue_id=${widget.venueId}',
    );
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);

      if (data['status'] == 'success') {
        final v = data['venue'] ?? {};

        String? rawUrl = v['image_url']?.toString();

        // ✅ если бек отдает "null" строкой
        if (rawUrl != null && rawUrl.trim().toLowerCase() == 'null') {
          rawUrl = null;
        }

        // ✅ подчищаем
        rawUrl = rawUrl?.trim();

        // ✅ если относительная ссылка — добавляем домен
        if (rawUrl != null && rawUrl.isNotEmpty && !rawUrl.startsWith('http')) {
          if (!rawUrl.startsWith('/')) rawUrl = '/$rawUrl';
          rawUrl = 'https://sportotekaapp.ru$rawUrl';
        }

        // ✅ кодируем пробелы/кириллицу
        final normalizedUrl = (rawUrl != null && rawUrl.isNotEmpty)
            ? Uri.encodeFull(rawUrl)
            : null;

        if (mounted) {
          setState(() {
            address = v['address']?.toString();
            conditions = v['conditions']?.toString();
            description = v['description']?.toString();
            imageUrl = normalizedUrl;
          });
        }

        // ✅ отладка (посмотри в консоли, что реально пришло)
        // ignore: avoid_print
        print('VENUE image_url raw: ${v['image_url']} | normalized: $normalizedUrl');
      }
    }
  } catch (e) {
    // ignore: avoid_print
    print('load venue error: $e');
  }
}

  Future<void> _fetchBookedSlots() async {
    setState(() {
      isLoading = true;
      _selectedTimeSlot = null;
    });
    try {
      final dateStr = _formatYMD(selectedDate);
      final uri = Uri.parse(
        'https://sportotekaapp.ru/api/get_booked_slots.php?venue_id=${widget.venueId}&date=$dateStr',
      );
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success') {
          bookedSlots = Set<String>.from(data['booked_slots']);
        }
      }
    } catch (_) {
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _bookSlot(String timeSlot) async {
    if (isBooking) return;
    setState(() => isBooking = true);
    try {
      final uri = Uri.parse('https://sportotekaapp.ru/api/book_slot.php');
      final res = await http.post(uri, body: {
        'venue_id': widget.venueId.toString(),
        'user_id': widget.userId.toString(),
        'date': _formatYMD(selectedDate),
        'time_slot': timeSlot,
      });

      final data = json.decode(res.body);
      if (data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Бронирование успешно!')),
          );
        }
        await _fetchBookedSlots();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: ${data['message'] ?? 'Не удалось забронировать'}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сеть недоступна, повторите попытку')),
        );
      }
    } finally {
      if (mounted) setState(() => isBooking = false);
    }
  }

  // ---------- Утилиты ----------
  String _formatYMD(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  List<String> _generateTimeSlots() {
    final List<String> slots = [];
    final dt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    for (int h = startHour; h < endHour; h++) {
      final start = DateTime(dt.year, dt.month, dt.day, h, 0);
      DateTime end = start.add(Duration(minutes: slotStepMinutes));
      if (end.hour > endHour || (end.hour == endHour && end.minute > 0)) break;
      final startStr =
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      final endStr =
          '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
      slots.add('$startStr-$endStr');
    }
    return slots;
  }

  bool _isPastTodaySlot(String slot) {
    final now = DateTime.now();
    final isToday = now.year == selectedDate.year &&
        now.month == selectedDate.month &&
        now.day == selectedDate.day;
    if (!isToday) return false;

    final startPart = slot.split('-').first;
    final parts = startPart.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final slotStart =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day, h, m);
    return slotStart.isBefore(now);
  }

  String _weekdayShort(int weekday) {
    switch (weekday) {
      case 1:
        return 'Пн';
      case 2:
        return 'Вт';
      case 3:
        return 'Ср';
      case 4:
        return 'Чт';
      case 5:
        return 'Пт';
      case 6:
        return 'Сб';
      case 7:
        return 'Вс';
      default:
        return '';
    }
  }

  // ---------- Header как в AddPersonalTrainingScreen ----------
  Widget _buildCompactHeader() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: Colors.black87),
                splashRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.venueTitle, // заголовок по центру
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.event_available,
                    size: 18, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Части UI ----------
  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF334155))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, {Color? border}) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border ?? Colors.transparent),
      ),
    );
  }

  Widget _loadingGridSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 9,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.3),
      itemBuilder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final canBook = _selectedTimeSlot != null && !isBooking;
    final label = _selectedTimeSlot == null
        ? 'Выберите время'
        : 'Забронировать ${_selectedTimeSlot!}';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE6ECF5))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canBook ? () => _bookSlot(_selectedTimeSlot!) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 1,
            ),
            child: isBooking
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final formattedDate = _formatYMD(selectedDate);
    final timeSlots = _generateTimeSlots();

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildCompactHeader(), // <- header как в AddPersonalTrainingScreen
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchBookedSlots,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Бейдж даты под шапкой
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                              const SizedBox(width: 6),
                              Text(
                                'Дата: $formattedDate',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 90)),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedDate = picked);
                                    await _fetchBookedSlots();
                                  }
                                },
                                icon: const Icon(Icons.event, size: 18),
                                label: const Text('Календарь'),
                              ),
                            ],
                          ),

                          if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.network(imageUrl!, fit: BoxFit.cover),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Карточка инфо
                          if ((address ?? conditions ?? description) != null)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE3EEFF)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (address != null && address!.isNotEmpty)
                                    _infoRow(Icons.location_on, "Адрес", address!),
                                  if (conditions != null && conditions!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    _infoRow(Icons.rule, "Условия", conditions!),
                                  ],
                                  if (description != null && description!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    _infoRow(Icons.info_outline, "Описание", description!),
                                  ],
                                ],
                              ),
                            ),

                          const SizedBox(height: 16),

                          // «Длительность слота:» СТРОГО СВЕРХУ, затем выбор (исправляет overflow)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Длительность слота:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<int>(
                                segments: const [
                                  ButtonSegment(value: 30, label: Text('30м')),
                                  ButtonSegment(value: 60, label: Text('60м')),
                                  ButtonSegment(value: 90, label: Text('90м')),
                                ],
                                selected: {slotStepMinutes},
                                onSelectionChanged: (value) async {
                                  setState(() {
                                    slotStepMinutes = value.first;
                                    _selectedTimeSlot = null;
                                  });
                                  await _fetchBookedSlots();
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Легенда
                          Row(
                            children: [
                              _legendDot(Colors.white, border: Colors.blue),
                              const SizedBox(width: 6),
                              const Text('Свободно', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 12),
                              _legendDot(Colors.blue.shade50),
                              const SizedBox(width: 6),
                              const Text('Выбрано', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 12),
                              _legendDot(Colors.grey.shade300),
                              const SizedBox(width: 6),
                              const Text('Занято/прошло', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Сетка слотов
                  if (isLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _loadingGridSkeleton(),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.3,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final slot = timeSlots[index];
                            final isBooked = bookedSlots.contains(slot);
                            final isPast = _isPastTodaySlot(slot);
                            final disabled = isBooked || isPast;
                            final selected = _selectedTimeSlot == slot;

                            Color bg;
                            BoxBorder? border;
                            if (disabled) {
                              bg = Colors.grey.shade300;
                              border = null;
                            } else if (selected) {
                              bg = Colors.blue.shade50;
                              border = Border.all(color: _primary, width: 1.5);
                            } else {
                              bg = Colors.white;
                              border = Border.all(color: const Color(0xFFB9D9FF), width: 1);
                            }

                            return InkWell(
                              onTap: disabled
                                  ? null
                                  : () => setState(() => _selectedTimeSlot = slot),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: border,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  slot,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: disabled
                                        ? Colors.grey.shade600
                                        : _textDark,
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: timeSlots.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }
}
