// lib/presentation/events_list_screen/events_list_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/service_screens/event_detail_screen.dart';

const String apiBaseUrl = 'https://sportotekaapp.ru/api/';

enum EventCatalogView { list, grid, calendar }

class EventsListScreen extends StatefulWidget {
  final String? initialSport;
  final bool embedded;
  final VoidCallback? onClose;

  const EventsListScreen({
    super.key,
    this.initialSport,
    this.embedded = false,
    this.onClose,
  });

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
  String _selectedEventKey = '';

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
        _syncSelectedEvent(data);
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
        _syncSelectedEvent(list);
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

  String _eventKey(Map<String, dynamic> event) {
    final id = (event['id'] ?? event['event_id'] ?? '').toString().trim();
    if (id.isNotEmpty) return id;
    return '${event['title'] ?? ''}|${event['event_date'] ?? event['date'] ?? ''}';
  }

  void _syncSelectedEvent(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      _selectedEventKey = '';
      return;
    }
    final exists = items.any((event) => _eventKey(event) == _selectedEventKey);
    if (!exists) _selectedEventKey = _eventKey(items.first);
  }

  Map<String, dynamic>? get _selectedEvent {
    for (final event in _items) {
      if (_eventKey(event) == _selectedEventKey) return event;
    }
    return _items.isEmpty ? null : _items.first;
  }

  void _selectEvent(Map<String, dynamic> event, {required bool compact}) {
    if (compact) {
      _openDetails(event);
      return;
    }
    setState(() => _selectedEventKey = _eventKey(event));
  }

  // ------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    Future<void> refresh() async {
      if (_view == EventCatalogView.calendar) {
        await _loadMonthMarks(_calMonth);
        await _loadDayEvents(_selectedDay);
      } else {
        await _loadFirst();
      }
    }

    Future<void> toggleCalendar() async {
      if (_view != EventCatalogView.calendar) {
        setState(() => _view = EventCatalogView.calendar);
        await _loadMonthMarks(_calMonth);
        await _loadDayEvents(_selectedDay);
      } else {
        setState(() => _view = EventCatalogView.list);
        await _loadFirst();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final paneWidth = math.min(460.0, constraints.maxWidth * .43);
        final canClose = widget.onClose != null || Navigator.of(context).canPop();

        final header = _EmbeddedCatalogHeader(
          icon: Icons.event_available_rounded,
          title: 'Мероприятия',
          subtitle: '${_items.length} событий · сборы, турниры и активности',
          onClose: canClose
              ? (widget.onClose ?? () => Navigator.of(context).maybePop())
              : null,
          actions: [
            _CatalogIconButton(
              icon: _view == EventCatalogView.calendar
                  ? Icons.view_list_rounded
                  : Icons.calendar_month_rounded,
              tooltip: _view == EventCatalogView.calendar
                  ? 'Вернуться к списку'
                  : 'Открыть календарь',
              active: _view == EventCatalogView.calendar,
              onTap: toggleCalendar,
            ),
            _CatalogIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Обновить',
              onTap: refresh,
            ),
          ],
        );

        final listPane = _buildListPane(
          compact: compact,
          onRefresh: refresh,
          showCalendar: compact && _view == EventCatalogView.calendar,
        );

        final workspace = Container(
          color: _CatalogColors.workspace,
          padding: EdgeInsets.all(compact ? 6 : 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 18 : 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(compact ? 18 : 20),
                boxShadow: _CatalogDecor.windowShadow,
              ),
              child: Column(
                children: [
                  header,
                  const Divider(height: 1, thickness: .7, color: _CatalogColors.line),
                  Expanded(
                    child: compact
                        ? listPane
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: paneWidth, child: listPane),
                              const VerticalDivider(
                                width: 1,
                                thickness: .7,
                                color: _CatalogColors.line,
                              ),
                              Expanded(
                                child: _view == EventCatalogView.calendar
                                    ? _calendarDetailPane()
                                    : _eventDetailPane(_selectedEvent),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );

        if (widget.embedded) return workspace;
        return Scaffold(
          backgroundColor: _CatalogColors.workspace,
          body: SafeArea(child: workspace),
        );
      },
    );
  }

  Widget _buildListPane({
    required bool compact,
    required Future<void> Function() onRefresh,
    required bool showCalendar,
  }) {
    return RefreshIndicator(
      color: _CatalogColors.green,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _searchAndChips(_CatalogColors.panel)),
          if (showCalendar) ...[
            SliverToBoxAdapter(child: _calendarBlock(_CatalogColors.panel)),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(child: _dayHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ],
          if (_loading)
            SliverToBoxAdapter(child: _skeletonList())
          else if (_err)
            SliverFillRemaining(hasScrollBody: false, child: _error())
          else if (_items.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _empty())
          else ...[
            _listSliver(compact: compact),
            if (_view != EventCatalogView.calendar)
              SliverToBoxAdapter(child: _loadMoreFooter()),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
          ],
        ],
      ),
    );
  }

  Widget _calendarDetailPane() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 18),
      children: [
        _calendarBlock(_CatalogColors.panel),
        const SizedBox(height: 14),
        _dayHeader(),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _eventDetailPane(_selectedEvent, embeddedInScroll: true),
        ),
      ],
    );
  }

  Widget _eventDetailPane(
    Map<String, dynamic>? event, {
    bool embeddedInScroll = false,
  }) {
    if (event == null) {
      return const _CatalogEmptyDetail(
        icon: Icons.event_busy_rounded,
        title: 'Выберите мероприятие',
        subtitle: 'Информация о событии появится в этом блоке.',
      );
    }

    final title = (event['title'] ?? 'Мероприятие').toString();
    final date = (event['event_date'] ?? event['date'] ?? '').toString();
    final location = (event['location'] ?? event['address'] ?? '').toString();
    final city = (event['city'] ?? '').toString();
    final sport = (event['sport'] ?? '').toString();
    final description =
        (event['description'] ?? event['about'] ?? event['details'] ?? '').toString();
    final image =
        (event['image'] ?? event['thumbnail'] ?? event['banner'] ?? '').toString();

    final content = ListView(
      shrinkWrap: embeddedInScroll,
      physics: embeddedInScroll
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      padding: embeddedInScroll
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        _CatalogDetailHero(
          image: image,
          icon: Icons.event_available_rounded,
          eyebrow: sport.isEmpty ? 'МЕРОПРИЯТИЕ' : sport.toUpperCase(),
          title: title,
          subtitle: date.isEmpty ? 'Дата уточняется' : _formatDate(date),
        ),
        const SizedBox(height: 18),
        _CatalogMetrics(
          items: [
            _CatalogMetricData(
              icon: Icons.calendar_today_rounded,
              value: date.isEmpty ? '—' : _shortDate(date),
              label: 'Дата',
            ),
            _CatalogMetricData(
              icon: Icons.location_on_outlined,
              value: city.isEmpty ? '—' : city,
              label: 'Город',
            ),
            _CatalogMetricData(
              icon: Icons.sports_soccer_rounded,
              value: sport.isEmpty ? '—' : sport,
              label: 'Спорт',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _CatalogInfoSection(
          title: 'Данные мероприятия',
          children: [
            _CatalogInfoRow(
              icon: Icons.schedule_rounded,
              label: 'Дата и время',
              value: date.isEmpty ? 'Не указаны' : _formatDate(date),
            ),
            _CatalogInfoRow(
              icon: Icons.place_outlined,
              label: 'Место',
              value: location.isEmpty ? 'Не указано' : location,
            ),
            _CatalogInfoRow(
              icon: Icons.location_city_rounded,
              label: 'Город',
              value: city.isEmpty ? 'Не указан' : city,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _CatalogDescription(
          title: 'О мероприятии',
          text: description.trim().isEmpty
              ? 'Организатор пока не добавил подробное описание.'
              : description,
        ),
        const SizedBox(height: 18),
        _CatalogPrimaryButton(
          title: 'Открыть мероприятие',
          icon: Icons.arrow_forward_rounded,
          onTap: () => _openDetails(event),
        ),
      ],
    );

    return embeddedInScroll ? content : content;
  }

  String _shortDate(String raw) {
    final parsed = _tryParseDate(raw);
    if (parsed == null) return raw;
    return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}';
  }

  // --- Top search + chips ---
  Widget _searchAndChips(Color bg) {
    return Container(
      decoration: BoxDecoration(color: bg),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        children: [
          _MatteSurface(
            soft: true,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 18, color: _CatalogColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Поиск по названию мероприятия',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: _CatalogText.title(12.4),
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
                Text(title, style: _CatalogText.title(16)),
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
                      style: _CatalogText.title(14.5),
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
                  child: Text(d, style: _CatalogText.muted(10.5)),
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

    final bg = isSelected ? _CatalogColors.greenSoft : Colors.transparent;
    final border = isSelected ? _CatalogColors.greenBorder : Colors.transparent;
    final text = isSelected ? _CatalogColors.greenDark : _CatalogColors.text;

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
              style: _CatalogText.title(11.5).copyWith(
                color: isToday && !isSelected ? _CatalogColors.green : text,
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
            color: _CatalogColors.green,
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
          const Icon(Icons.event_available_rounded, color: _CatalogColors.green),
          const SizedBox(width: 8),
          Text(
            "События: ${_k(_selectedDay)}",
            style: _CatalogText.title(12.5),
          ),
        ],
      ),
    );
  }

  // --- Список (sliver) ---
  Widget _listSliver({required bool compact}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      sliver: SliverList.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (_, i) => _eventTile(_items[i], compact: compact),
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
  Widget _eventTile(Map<String, dynamic> event, {bool compact = true}) {
    final title = (event['title'] ?? 'Мероприятие').toString();
    final date = (event['event_date'] ?? event['date'] ?? '').toString();
    final location = (event['location'] ?? event['address'] ?? '').toString();
    final image = (event['image'] ?? event['thumbnail'] ?? event['banner'] ?? '').toString();
    final sport = (event['sport'] ?? '').toString();
    final active = _eventKey(event) == _selectedEventKey;

    return _MatteSurface(
      selected: active,
      onTap: () => _selectEvent(event, compact: compact),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 3,
            height: 48,
            decoration: BoxDecoration(
              color: active ? _CatalogColors.green : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 9),
          _EventImage(
            image: image,
            fallbackIcon: Icons.event_available_rounded,
            height: 50,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: _CatalogText.title(compact ? 13.8 : 14.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    if (date.isNotEmpty) _formatDate(date),
                    if (location.isNotEmpty) location,
                    if (sport.isNotEmpty) sport,
                  ].join('  ·  '),
                  style: _CatalogText.muted(10.7),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
              style: _CatalogText.title(13.5),
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
                      style: _CatalogText.muted(10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          const Spacer(),
          Row(
            children: [
              Text('Открыть', style: _CatalogText.action(color: _CatalogColors.green)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _CatalogColors.green),
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
                  ? Text('Прокрутите вниз, чтобы загрузить ещё', style: _CatalogText.muted(10.5))
                  : Text('Больше результатов нет', style: _CatalogText.muted(10.5)),
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
            Text('Мероприятий не найдено', style: _CatalogText.title(15)),
            const SizedBox(height: 6),
            Text('Попробуйте изменить фильтры или запрос', style: _CatalogText.muted(11)),
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
            Text('Ошибка загрузки', style: _CatalogText.title(15)),
            const SizedBox(height: 6),
            Text(_errMsg ?? 'Попробуйте ещё раз', textAlign: TextAlign.center, style: _CatalogText.muted(11)),
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

class _CatalogColors {
  static const workspace = Color(0xFFF6F7F6);
  static const panel = Colors.white;
  static const soft = Color(0xFFFAFBFA);
  static const soft2 = Color(0xFFF4F6F4);
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE9ECEA);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
  static const greenBorder = Color(0xFFD7F0E2);
  static const red = Color(0xFFD92D20);
}

class _CatalogText {
  static TextStyle title(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _CatalogColors.text,
        height: 1.18,
        letterSpacing: 0,
        features: const [FontFeature.tabularFigures()],
      );

  static TextStyle section() => AppTypography.custom(
        size: 12.2,
        weight: FontWeight.w600,
        color: _CatalogColors.text,
        height: 1.18,
        letterSpacing: 0,
      );

  static TextStyle muted(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w400,
        color: _CatalogColors.muted,
        height: 1.32,
        letterSpacing: 0,
      );

  static TextStyle action({Color color = _CatalogColors.text}) =>
      AppTypography.custom(
        size: 11.8,
        weight: FontWeight.w600,
        color: color,
        height: 1.16,
        letterSpacing: 0,
      );
}

class _CatalogDecor {
  static List<BoxShadow> get windowShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 28,
          spreadRadius: -18,
          offset: const Offset(0, 16),
        ),
      ];
}

class _CatalogIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _CatalogIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? _CatalogColors.greenSoft : _CatalogColors.soft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              icon,
              size: 16,
              color: active ? _CatalogColors.green : _CatalogColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogEmptyDetail extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CatalogEmptyDetail({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _CatalogColors.greenSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: _CatalogColors.green, size: 25),
            ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: _CatalogText.title(15)),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: _CatalogText.muted(11.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogDetailHero extends StatelessWidget {
  final String image;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;

  const _CatalogDetailHero({
    required this.image,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: _CatalogColors.greenSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: image.trim().isEmpty
              ? Icon(icon, color: _CatalogColors.green, size: 30)
              : Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(icon, color: _CatalogColors.green, size: 30),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.custom(
                  size: 9,
                  weight: FontWeight.w700,
                  color: _CatalogColors.greenDark,
                  height: 1.1,
                  letterSpacing: .35,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _CatalogText.title(19),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _CatalogText.muted(11.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogMetricData {
  final IconData icon;
  final String value;
  final String label;

  const _CatalogMetricData({
    required this.icon,
    required this.value,
    required this.label,
  });
}

class _CatalogMetrics extends StatelessWidget {
  final List<_CatalogMetricData> items;
  const _CatalogMetrics({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 16) / items.length;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => Container(
                  width: itemWidth,
                  constraints: const BoxConstraints(minWidth: 108),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: _CatalogColors.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.icon, size: 16, color: _CatalogColors.green),
                      const SizedBox(height: 9),
                      Text(
                        item.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CatalogText.title(13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CatalogText.muted(9.8),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _CatalogInfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CatalogInfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 4),
      decoration: BoxDecoration(
        color: _CatalogColors.soft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _CatalogText.section()),
          const SizedBox(height: 7),
          ...children,
        ],
      ),
    );
  }
}

class _CatalogInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CatalogInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _CatalogColors.green),
          const SizedBox(width: 10),
          SizedBox(width: 92, child: Text(label, style: _CatalogText.muted(10.5))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: _CatalogText.title(11.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogDescription extends StatelessWidget {
  final String title;
  final String text;

  const _CatalogDescription({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _CatalogColors.greenSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _CatalogText.section()),
          const SizedBox(height: 7),
          Text(text, style: _CatalogText.muted(11.1)),
        ],
      ),
    );
  }
}

class _CatalogPrimaryButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _CatalogPrimaryButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CatalogColors.green,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: _CatalogText.action(color: Colors.white)),
              const SizedBox(width: 8),
              Icon(icon, size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== MATTE UI COMPONENTS =====================

class _MatteSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;
  final bool soft;

  const _MatteSurface({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.selected = false,
    this.soft = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: selected
            ? _CatalogColors.greenSoft
            : soft
                ? _CatalogColors.soft
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
        color: _CatalogColors.greenSoft,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: image.isNotEmpty
          ? Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(fallbackIcon, color: _CatalogColors.green),
            )
          : Icon(fallbackIcon, color: _CatalogColors.green),
    );
  }
}



class _EmbeddedCatalogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onClose;
  final List<Widget> actions;

  const _EmbeddedCatalogHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onClose,
    this.actions = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 720;
    return Container(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 12 : 16,
        isCompact ? 11 : 13,
        isCompact ? 12 : 16,
        isCompact ? 11 : 13,
      ),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: isCompact ? 36 : 40,
            height: isCompact ? 36 : 40,
            decoration: BoxDecoration(
              color: _CatalogColors.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: _CatalogColors.green,
              size: isCompact ? 18 : 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CatalogText.title(isCompact ? 15.5 : 16.5),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CatalogText.muted(isCompact ? 10.6 : 11.2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ...actions.expand((action) => [action, const SizedBox(width: 6)]),
          if (onClose != null)
            _CatalogIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Закрыть',
              onTap: onClose!,
            ),
        ],
      ),
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
    final bg = selected ? _CatalogColors.greenSoft : _CatalogColors.soft;
    final text = selected ? _CatalogColors.greenDark : _CatalogColors.text;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: text),
            const SizedBox(width: 6),
            Text(label, style: _CatalogText.action(color: text)),
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
