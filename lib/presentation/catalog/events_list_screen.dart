// lib/presentation/events_list_screen/events_list_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:sportoteka/presentation/service_screens/event_detail_screen.dart';

const String apiBaseUrl = 'https://sportotekaapp.ru/api/';

enum EventCatalogView { list, grid, calendar }

class EventsListScreen extends StatefulWidget {
  final String? initialSport;

  const EventsListScreen({super.key, this.initialSport});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  // --- Networking
  late final Dio _dio;

  // --- State
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String _sport = '';
  String _city = '';
  String _status = ''; // upcoming, past, all

  bool _loading = true;
  bool _err = false;
  String? _errMsg;

  List<Map<String, dynamic>> _items = [];
  List<String> _sports = [];
  List<String> _cities = [];

  int _limit = 50;
  int _offset = 0;
  bool _canLoadMore = true;
  bool _loadingMore = false;

  EventCatalogView _view = EventCatalogView.list;

  // ====== Calendar state
  DateTime _calMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  bool _calLoading = false;
  final Map<String, int> _monthMarks = {}; // yyyy-mm-dd -> count

  @override
  void initState() {
    super.initState();

    _dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 12),
        responseType: ResponseType.json,
        headers: const {'Accept': 'application/json'},
      ),
    );

    _searchCtrl.addListener(_onSearchChanged);

    if (widget.initialSport != null && widget.initialSport!.isNotEmpty) {
      _sport = widget.initialSport!;
    }

    _loadFirst();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _dio.close(force: true);
    super.dispose();
  }

  // ------------------- DATA -------------------

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _loadFirst();
    });
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _err = false;
      _errMsg = null;
      _offset = 0;
      _canLoadMore = true;
      _items = [];
    });

    try {
      final data = await _fetch(pageReset: true);
      if (!mounted) return;

      setState(() {
        _items = data;
        _prepareFiltersFrom(data);
      });

      // ✅ если сейчас в режиме календаря — обновим маркеры месяца и список дня
      if (_view == EventCatalogView.calendar) {
        await _loadMonthMarks(_calMonth);
        await _loadDayEvents(_selectedDay);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = true;
        _errMsg = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetch({
    bool pageReset = false,
    String? date, // ✅ для календаря
    int? limitOverride,
    int? offsetOverride,
  }) async {
    if (pageReset) {
      _offset = 0;
      _canLoadMore = true;
    }

    final params = <String, dynamic>{
      'q': _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      'sport': _sport.isEmpty ? null : _sport,
      'city': _city.isEmpty ? null : _city,
      'status': _status.isEmpty ? 'upcoming' : _status,
      'date': date, // ✅ календарь
      'limit': limitOverride ?? _limit,
      'offset': offsetOverride ?? _offset,
    }..removeWhere((k, v) => v == null);

    Response res;

    try {
      res = await _dio.get('get_events.php', queryParameters: params);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        res = await _dio.get(
          'get_week_events.php',
          queryParameters: {if (_sport.isNotEmpty) 'sport': _sport},
          options: Options(responseType: ResponseType.plain),
        );
      } else {
        rethrow;
      }
    }

    dynamic data = res.data;

    if (data is String) {
      final s = data.trim();
      if (s.isEmpty) {
        data = [];
      } else {
        if (s.startsWith('<') || s.contains('Notice') || s.contains('Warning') || s.contains('Fatal error')) {
          throw Exception("API вернул не JSON (похоже PHP/HTML ошибка): ${s.substring(0, s.length > 220 ? 220 : s.length)}");
        }
        try {
          data = jsonDecode(s);
        } catch (_) {
          throw Exception("API вернул не JSON: ${s.substring(0, s.length > 220 ? 220 : s.length)}");
        }
      }
    }

    List<Map<String, dynamic>> list = [];

    if (data is Map) {
      final maybe = data['events'] ?? data['items'] ?? data['data'] ?? data['result'];

      if (maybe is List) {
        list = maybe
            .where((e) => e is Map)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (data['success'] == false && data['message'] != null) {
        throw Exception(data['message'].toString());
      } else {
        if (data.containsKey('id') || data.containsKey('title')) {
          list = [Map<String, dynamic>.from(data)];
        } else {
          list = [];
        }
      }
    } else if (data is List) {
      list = data
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      list = [];
    }

    // пагинация только для обычного списка/сетки (не для календарной подгрузки)
    if (date == null && (limitOverride == null && offsetOverride == null)) {
      if (list.length < _limit) _canLoadMore = false;
      _offset += list.length;
    }

    return list;
  }

  void _prepareFiltersFrom(List<Map<String, dynamic>> data) {
    final sports = <String>{};
    final cities = <String>{};

    for (final m in data) {
      final s = (m['sport'] ?? '').toString().trim();
      if (s.isNotEmpty) sports.add(s);

      final city = (m['city'] ?? '').toString().trim();
      if (city.isNotEmpty) cities.add(city);
    }

    _sports = sports.toList()..sort();
    _cities = cities.toList()..sort();
  }

  Future<void> _loadMore() async {
    if (!_canLoadMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await _fetch();
      if (!mounted) return;
      setState(() => _items.addAll(next));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ------------------- Calendar helpers -------------------

  String _k(DateTime d) => "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> _loadMonthMarks(DateTime month) async {
    setState(() => _calLoading = true);
    try {
      // Берём “сырой” список событий за месяц (лимит большой)
      final from = DateTime(month.year, month.month, 1);
      final to = DateTime(month.year, month.month + 1, 0);

      final tmp = <String, int>{};

      // Чтобы не писать новый API, делаем так:
      // 1) просим "all" и огромный limit
      // 2) фильтруем по датам на клиенте
      final all = await _fetch(
        pageReset: true,
        limitOverride: 500,
        offsetOverride: 0,
      );

      for (final e in all) {
        final raw = (e['event_date'] ?? e['date'] ?? '').toString();
        final dt = _tryParseDate(raw);
        if (dt == null) continue;

        final day = DateTime(dt.year, dt.month, dt.day);
        if (day.isBefore(from) || day.isAfter(to)) continue;

        final key = _k(day);
        tmp[key] = (tmp[key] ?? 0) + 1;
      }

      if (!mounted) return;
      setState(() {
        _monthMarks
          ..clear()
          ..addAll(tmp);
      });
    } finally {
      if (mounted) setState(() => _calLoading = false);
    }
  }

  Future<void> _loadDayEvents(DateTime day) async {
    // ✅ используем серверный date-фильтр (мы его добавляли в get_events.php)
    final date = _k(day);
    setState(() {
      _loading = true;
      _err = false;
      _errMsg = null;
      _items = [];
      _canLoadMore = false; // для дня пагинация не нужна
    });

    try {
      final list = await _fetch(date: date, limitOverride: 200, offsetOverride: 0);
      if (!mounted) return;
      setState(() {
        _items = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = true;
        _errMsg = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _tryParseDate(String s) {
    if (s.trim().isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  void _openDetails(Map<String, dynamic> event) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)));
  }

  // ------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF3F5F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: const Text('Каталог мероприятий', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          // ✅ переключатель режимов
          IconButton(
            tooltip: _view == EventCatalogView.list
                ? 'Сетка'
                : _view == EventCatalogView.grid
                    ? 'Календарь'
                    : 'Список',
            onPressed: () async {
              if (_view == EventCatalogView.list) {
                setState(() => _view = EventCatalogView.grid);
              } else if (_view == EventCatalogView.grid) {
                setState(() => _view = EventCatalogView.calendar);
                await _loadMonthMarks(_calMonth);
                await _loadDayEvents(_selectedDay);
              } else {
                setState(() => _view = EventCatalogView.list);
                _loadFirst();
              }
            },
            icon: Icon(
              _view == EventCatalogView.list
                  ? Icons.grid_view_rounded
                  : _view == EventCatalogView.grid
                      ? Icons.calendar_month_rounded
                      : Icons.view_list_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: () async {
              if (_view == EventCatalogView.calendar) {
                await _loadMonthMarks(_calMonth);
                await _loadDayEvents(_selectedDay);
              } else {
                _loadFirst();
              }
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_view == EventCatalogView.calendar) {
            await _loadMonthMarks(_calMonth);
            await _loadDayEvents(_selectedDay);
          } else {
            await _loadFirst();
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _searchAndChips(bg)),
            SliverToBoxAdapter(child: const SizedBox(height: 8)),

            // ✅ КАЛЕНДАРЬ режим
            if (_view == EventCatalogView.calendar) ...[
              SliverToBoxAdapter(child: _calendarBlock(bg)),
              SliverToBoxAdapter(child: const SizedBox(height: 10)),
              SliverToBoxAdapter(child: _dayHeader()),
            ],

            if (_loading) ...[
              SliverToBoxAdapter(child: _skeletonList()),
            ] else if (_err) ...[
              SliverFillRemaining(hasScrollBody: false, child: _error()),
            ] else if (_items.isEmpty) ...[
              SliverFillRemaining(hasScrollBody: false, child: _empty()),
            ] else if (_view == EventCatalogView.grid) ...[
              _gridSliver(),
              SliverToBoxAdapter(child: _loadMoreFooter()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ] else ...[
              // list + calendar используют один list
              _listSliver(),
              if (_view == EventCatalogView.list) SliverToBoxAdapter(child: _loadMoreFooter()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ],
        ),
      ),
    );
  }

  // --- Top search + chips ---
  Widget _searchAndChips(Color bg) {
    return Container(
      decoration: BoxDecoration(color: bg),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        children: [
          _MatteSurface(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 22, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Поиск по названию мероприятия',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _loadFirst(),
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      _loadFirst();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChipMatte(
                  label: _sport.isEmpty ? 'Вид спорта' : _sport,
                  icon: Icons.sports_soccer_rounded,
                  onTap: () => _pickFilter('Вид спорта', _sport, _sports, (v) async {
                    setState(() => _sport = v);
                    await _loadFirst();
                    if (_view == EventCatalogView.calendar) {
                      await _loadMonthMarks(_calMonth);
                      await _loadDayEvents(_selectedDay);
                    }
                  }),
                  selected: _sport.isNotEmpty,
                ),
                _FilterChipMatte(
                  label: _city.isEmpty ? 'Город' : _city,
                  icon: Icons.location_city_rounded,
                  onTap: () => _pickFilter('Город', _city, _cities, (v) async {
                    setState(() => _city = v);
                    await _loadFirst();
                    if (_view == EventCatalogView.calendar) {
                      await _loadMonthMarks(_calMonth);
                      await _loadDayEvents(_selectedDay);
                    }
                  }),
                  selected: _city.isNotEmpty,
                ),
                _FilterChipMatte(
                  label: _getStatusLabel(),
                  icon: Icons.event_available_rounded,
                  onTap: () => _pickFilter('Статус', _status, const ['Предстоящие', 'Прошедшие', 'Все'], (v) async {
                    setState(() => _status = _getStatusValue(v));
                    await _loadFirst();
                    if (_view == EventCatalogView.calendar) {
                      await _loadMonthMarks(_calMonth);
                      await _loadDayEvents(_selectedDay);
                    }
                  }),
                  selected: _status.isNotEmpty,
                ),
                if (_sport.isNotEmpty || _city.isNotEmpty || _status.isNotEmpty)
                  _FilterChipMatte(
                    label: 'Сбросить',
                    icon: Icons.filter_alt_off_rounded,
                    onTap: () async {
                      setState(() {
                        _sport = '';
                        _city = '';
                        _status = '';
                      });
                      await _loadFirst();
                      if (_view == EventCatalogView.calendar) {
                        await _loadMonthMarks(_calMonth);
                        await _loadDayEvents(_selectedDay);
                      }
                    },
                    selected: true,
                  ),
              ].expand((w) sync* {
                yield w;
                yield const SizedBox(width: 8);
              }).toList()
                ..removeLast(),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel() {
    if (_status == 'upcoming') return 'Предстоящие';
    if (_status == 'past') return 'Прошедшие';
    if (_status == 'all') return 'Все';
    return 'Статус';
  }

  String _getStatusValue(String label) {
    if (label == 'Предстоящие') return 'upcoming';
    if (label == 'Прошедшие') return 'past';
    if (label == 'Все') return 'all';
    return '';
  }

  // --- BottomSheet выбора фильтра ---
  Future<void> _pickFilter(
    String title,
    String current,
    List<String> items,
    void Function(String) onPick,
  ) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: items.isEmpty
                      ? const Center(child: Text('Нет вариантов'))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final v = items[i];
                            final selected = v == current || (title == 'Статус' && v == _getStatusLabel());
                            return ListTile(
                              title: Text(v),
                              trailing: selected ? const Icon(Icons.check_rounded) : null,
                              onTap: () => Navigator.pop(context, v),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (value != null) onPick(value);
  }

  // ================== CALENDAR UI ==================

  Widget _calendarBlock(Color bg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: _MatteSurface(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () async {
                    setState(() => _calMonth = DateTime(_calMonth.year, _calMonth.month - 1, 1));
                    await _loadMonthMarks(_calMonth);
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _monthTitle(_calMonth),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    setState(() => _calMonth = DateTime(_calMonth.year, _calMonth.month + 1, 1));
                    await _loadMonthMarks(_calMonth);
                  },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _weekHeader(),
            const SizedBox(height: 6),
            if (_calLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.6)),
              )
            else
              _monthGrid(),
          ],
        ),
      ),
    );
  }

  Widget _weekHeader() {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return Row(
      children: days
          .map((d) => Expanded(
                child: Center(
                  child: Text(d, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                ),
              ))
          .toList(),
    );
  }

  Widget _monthGrid() {
    final first = DateTime(_calMonth.year, _calMonth.month, 1);
    final last = DateTime(_calMonth.year, _calMonth.month + 1, 0);

    // weekday: Mon=1..Sun=7
    final startPad = first.weekday - 1;
    final totalDays = last.day;

    final cells = <DateTime?>[];

    for (int i = 0; i < startPad; i++) {
      cells.add(null);
    }
    for (int d = 1; d <= totalDays; d++) {
      cells.add(DateTime(_calMonth.year, _calMonth.month, d));
    }

    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      children: List.generate(cells.length ~/ 7, (row) {
        final rowCells = cells.skip(row * 7).take(7).toList();
        return Row(
          children: rowCells.map((date) => Expanded(child: _dayCell(date))).toList(),
        );
      }),
    );
  }

  Widget _dayCell(DateTime? date) {
    if (date == null) return const SizedBox(height: 44);

    final isSelected = date.year == _selectedDay.year && date.month == _selectedDay.month && date.day == _selectedDay.day;
    final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;

    final key = _k(date);
    final count = _monthMarks[key] ?? 0;

    final bg = isSelected ? const Color(0xFFEFF6FF) : Colors.transparent;
    final border = isSelected ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB);
    final text = isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        setState(() => _selectedDay = date);
        await _loadDayEvents(date);
      },
      child: Container(
        height: 44,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? border : Colors.transparent),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isToday && !isSelected ? const Color(0xFF0EA5E9) : text,
              ),
            ),
            if (count > 0)
              Positioned(
                bottom: 6,
                child: _dots(count),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dots(int count) {
    // максимум 3 точки как в гугле
    final dots = count >= 3 ? 3 : count;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(dots, (_) {
        return Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0EA5E9),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  String _monthTitle(DateTime m) {
    const names = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь'
    ];
    return "${names[m.month - 1]} ${m.year}";
  }

  Widget _dayHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.event_available_rounded, color: Color(0xFF0EA5E9)),
          const SizedBox(width: 8),
          Text(
            "События: ${_k(_selectedDay)}",
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // --- Список (sliver) ---
  Widget _listSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverList.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _eventTile(_items[i]),
      ),
    );
  }

  // --- Сетка (sliver) ---
  Widget _gridSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverGrid.builder(
        itemCount: _items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemBuilder: (_, i) => _eventCardGrid(_items[i]),
      ),
    );
  }

  // --- Карточка события в списке ---
  Widget _eventTile(Map<String, dynamic> event) {
    final title = (event['title'] ?? 'Мероприятие').toString();
    final date = (event['event_date'] ?? event['date'] ?? '').toString();
    final location = (event['location'] ?? event['address'] ?? '').toString();
    final image = (event['image'] ?? event['thumbnail'] ?? event['banner'] ?? '').toString();
    final sport = (event['sport'] ?? '').toString();

    return _MatteSurface(
      onTap: () => _openDetails(event),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EventImage(image: image, fallbackIcon: Icons.event_available_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if (date.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(_formatDate(date), style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                      ],
                    ),
                  if (location.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(location,
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  if (sport.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.sports_soccer_rounded, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(sport, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  // --- Карточка события в сетке ---
  Widget _eventCardGrid(Map<String, dynamic> event) {
    final title = (event['title'] ?? 'Мероприятие').toString();
    final date = (event['event_date'] ?? event['date'] ?? '').toString();
    final image = (event['image'] ?? event['thumbnail'] ?? event['banner'] ?? '').toString();

    return _MatteSurface(
      padding: const EdgeInsets.all(12),
      onTap: () => _openDetails(event),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EventImage(image: image, fallbackIcon: Icons.event_available_rounded, height: 100, borderRadius: 8),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          if (date.isNotEmpty)
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(_formatDate(date),
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          const Spacer(),
          Row(
            children: const [
              Text("Открыть", style: TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold, fontSize: 12)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF0EA5E9)),
            ],
          ),
        ],
      ),
    );
  }

  // --- Footer c автоподгрузкой ---
  Widget _loadMoreFooter() {
    return NotificationListener<ScrollNotification>(
      onNotification: (sn) {
        if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 240) {
          _loadMore();
        }
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: _loadingMore
              ? const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2.8))
              : _canLoadMore
                  ? const Text('Прокрутите вниз, чтобы загрузить ещё', style: TextStyle(color: Color(0xFF94A3B8)))
                  : const Text('Больше результатов нет', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      ),
    );
  }

  // --- Скелетоны / Empty / Error ---
  Widget _skeletonList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: List.generate(
          6,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MatteSurface(
              child: Row(
                children: [
                  const _EventImage(image: '', fallbackIcon: Icons.event_available_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _SkeletonLine(widthFactor: 1.0),
                        SizedBox(height: 8),
                        _SkeletonLine(widthFactor: 0.6),
                        SizedBox(height: 6),
                        _SkeletonLine(widthFactor: 0.4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 56, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text('Мероприятий не найдено', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Попробуйте изменить фильтры или запрос', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () async {
                setState(() {
                  _sport = '';
                  _city = '';
                  _status = '';
                  _searchCtrl.clear();
                });
                await _loadFirst();
                if (_view == EventCatalogView.calendar) {
                  await _loadMonthMarks(_calMonth);
                  await _loadDayEvents(_selectedDay);
                }
              },
              child: const Text('Сбросить фильтры'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _error() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('Ошибка загрузки', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text(_errMsg ?? 'Попробуйте ещё раз', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadFirst, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }

  // --- Форматирование даты ---
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();

      final d0 = DateTime(now.year, now.month, now.day);
      final d1 = DateTime(date.year, date.month, date.day);
      final dayDiff = d1.difference(d0).inDays;

      if (dayDiff == 0) return 'Сегодня, ${_formatTime(date)}';
      if (dayDiff == 1) return 'Завтра, ${_formatTime(date)}';
      if (dayDiff == -1) return 'Вчера, ${_formatTime(date)}';

      if (dayDiff.abs() < 7) {
        if (dayDiff > 0) return 'Через $dayDiff дн., ${_formatTime(date)}';
        return '${dayDiff.abs()} дн. назад, ${_formatTime(date)}';
      }

      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${_formatTime(date)}';
    } catch (_) {
      return dateString;
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ===================== MATTE UI COMPONENTS =====================

class _MatteSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const _MatteSurface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }
}

class _EventImage extends StatelessWidget {
  final String image;
  final IconData fallbackIcon;
  final double? height;
  final double borderRadius;

  const _EventImage({
    required this.image,
    required this.fallbackIcon,
    this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final size = height ?? 44;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: image.isNotEmpty
          ? Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: const Color(0xFF0EA5E9)),
            )
          : Icon(fallbackIcon, color: const Color(0xFF0EA5E9)),
    );
  }
}

class _FilterChipMatte extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipMatte({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFEFF6FF) : Colors.white;
    final border = selected ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB);
    final text = selected ? const Color(0xFF1D4ED8) : const Color(0xFF334155);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: text),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: text, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  const _SkeletonLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
