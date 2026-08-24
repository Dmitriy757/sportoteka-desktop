// lib/presentation/booking_screen/booking_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

import 'package:sportoteka/presentation/booking_screen/add_venue_screen.dart';
import 'package:sportoteka/presentation/booking_screen/my_bookings_screen.dart';
import 'package:sportoteka/presentation/booking_screen/venue_booking_screen.dart';

const String apiBaseUrl = 'https://sportotekaapp.ru/api/';

enum VenueCatalogView { list, grid }

class BookingScreen extends StatefulWidget {
  final int userId;

  const BookingScreen({super.key, required this.userId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // --- Networking (как в EventsListScreen)
  final _dio = Dio()
    ..options.baseUrl = apiBaseUrl
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 8);

  // --- UI state
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String _sport = 'Все';
  String _city = '';

  bool _loading = true;
  bool _err = false;
  String? _errMsg;

  List<Map<String, dynamic>> _items = [];
  List<String> _sports = const ['Все', 'Футбол', 'Баскетбол', 'Теннис', 'Волейбол', 'Хоккей', 'Прочее'];
  List<String> _cities = [];

  int _limit = 40;
  int _offset = 0;
  bool _canLoadMore = true;
  bool _loadingMore = false;

  VenueCatalogView _view = VenueCatalogView.grid;
  bool _grid = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadFirst();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  // ------------------- DATA -------------------

  void _onSearchChanged() {
    if (mounted) setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _loadFirst();
    });
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _err = false;
      _offset = 0;
      _canLoadMore = true;
      _items = [];
    });

    try {
      final data = await _fetch(pageReset: true);
      setState(() {
        _items = data;
        _prepareFiltersFrom(data);
      });
    } catch (e) {
      setState(() {
        _err = true;
        _errMsg = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetch({bool pageReset = false}) async {
    if (pageReset) {
      _offset = 0;
      _canLoadMore = true;
    }

    // get_venues.php у тебя принимает sport (опционально).
    // Поиск/город могут быть не реализованы на сервере — я делаю safe:
    // 1) передаю q/city если сервер поддержит
    // 2) дополнительно фильтрую локально, если сервер игнорирует.
    final params = <String, dynamic>{
      if (_sport != 'Все') 'sport': _sport,
      if (_searchCtrl.text.trim().isNotEmpty) 'q': _searchCtrl.text.trim(),
      if (_city.isNotEmpty) 'city': _city,
      'limit': _limit,
      'offset': _offset,
    };

    final res = await _dio.get('get_venues.php', queryParameters: params);

    final data = res.data;

    List raw = [];
    if (data is Map && data['venues'] is List) {
      raw = data['venues'] as List;
    } else if (data is Map && data['items'] is List) {
      raw = data['items'] as List;
    } else if (data is List) {
      raw = data;
    }

    var list = raw.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();

    // --- Локальная фильтрация (на случай если сервер не фильтрует)
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((m) {
        final title = (m['title'] ?? m['name'] ?? '').toString().toLowerCase();
        final addr  = (m['address'] ?? m['location'] ?? '').toString().toLowerCase();
        return title.contains(q) || addr.contains(q);
      }).toList();
    }

    if (_city.isNotEmpty) {
      final cityLc = _city.toLowerCase();
      list = list.where((m) {
        final c = (m['city'] ?? '').toString().toLowerCase();
        return c.contains(cityLc);
      }).toList();
    }

    // пагинация
    if (list.length < _limit) _canLoadMore = false;
    _offset += list.length;

    return list;
  }

  void _prepareFiltersFrom(List<Map<String, dynamic>> data) {
    // Город попробуем собрать из "city" либо вытащить из address
    final cities = <String>{};
    for (final m in data) {
      final city = (m['city'] ?? '').toString().trim();
      if (city.isNotEmpty) cities.add(city);
    }
    _cities = cities.toList()..sort();
  }

  Future<void> _loadMore() async {
    if (!_canLoadMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await _fetch();
      setState(() => _items.addAll(next));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ------------------- ACTIONS -------------------

  Future<void> _openAddVenue() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddVenueScreen(userId: widget.userId)),
    );
    if (result == true) _loadFirst();
  }

  void _openMyBookings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
  }

  void _openVenue(Map<String, dynamic> v) {
    final id = int.tryParse('${v['id']}') ?? 0;
    final title = (v['title'] ?? v['name'] ?? '').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueBookingScreen(
          venueId: id,
          venueTitle: title,
          userId: widget.userId,
        ),
      ),
    );
  }

  // ------------------- CMR / TRACKER UI -------------------

  TextStyle _t(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = _BookingUi.text,
    double height = 1.2,
  }) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: height,
      letterSpacing: 0,
    );
  }

  Widget _brandDots({Color color = _BookingUi.green}) {
    const sizes = <double>[3.5, 4.5, 5.5, 6.5];
    const opacities = <double>[.34, .48, .68, 1];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < sizes.length; i++) ...[
          Container(
            width: sizes[i],
            height: sizes[i],
            decoration: BoxDecoration(
              color: color.withOpacity(opacities[i]),
              shape: BoxShape.circle,
              boxShadow: i == sizes.length - 1
                  ? [
                      BoxShadow(
                        color: color.withOpacity(.14),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          if (i != sizes.length - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }

  Widget _dot(
    Color color, {
    double size = 5,
    bool glow = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withOpacity(.18),
                  blurRadius: size * 2,
                ),
              ]
            : null,
      ),
    );
  }

  bool get _hasFilters =>
      _sport != 'Все' ||
      _city.isNotEmpty ||
      _searchCtrl.text.trim().isNotEmpty;

  List<String> get _cityItems => _cities.isEmpty
      ? const ['Минск', 'Брест', 'Гомель', 'Витебск', 'Гродно', 'Могилёв']
      : _cities;

  void _resetFilters() {
    setState(() {
      _sport = 'Все';
      _city = '';
      _searchCtrl.clear();
    });
    _loadFirst();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: Colors.white,
        textTheme: base.textTheme.apply(
          fontFamily: AppTypography.fontFamily,
          bodyColor: _BookingUi.text,
          displayColor: _BookingUi.text,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 980;
              final compact = constraints.maxWidth < 720;

              return Column(
                children: [
                  _topBar(compact: compact, desktop: desktop),
                  const Divider(
                    height: 1,
                    thickness: .6,
                    color: _BookingUi.line,
                  ),
                  Expanded(
                    child: desktop
                        ? Row(
                            children: [
                              SizedBox(
                                width: 258,
                                child: _desktopFilters(),
                              ),
                              const VerticalDivider(
                                width: 1,
                                thickness: .6,
                                color: _BookingUi.line,
                              ),
                              Expanded(child: _catalog()),
                            ],
                          )
                        : Column(
                            children: [
                              _mobileFilters(compact: compact),
                              const Divider(
                                height: 1,
                                thickness: .6,
                                color: _BookingUi.line,
                              ),
                              Expanded(child: _catalog()),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar({required bool compact, required bool desktop}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        9,
        compact ? 10 : 14,
        9,
      ),
      child: Row(
        children: [
          _brandDots(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Площадки',
                  style: _t(
                    compact ? 15.5 : 17,
                    weight: FontWeight.w600,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Каталог спортивных объектов и бронирование',
                    style: _t(9.8, color: _BookingUi.muted),
                  ),
                ],
              ],
            ),
          ),
          if (!compact) ...[
            _headerAction(
              icon: Icons.book_online_outlined,
              label: 'Мои брони',
              onTap: _openMyBookings,
            ),
            const SizedBox(width: 6),
            _headerAction(
              icon: Icons.add_location_alt_outlined,
              label: desktop ? 'Добавить площадку' : 'Добавить',
              onTap: _openAddVenue,
              primary: true,
            ),
            const SizedBox(width: 6),
          ] else ...[
            _iconAction(
              icon: Icons.book_online_outlined,
              tooltip: 'Мои брони',
              onTap: _openMyBookings,
            ),
            const SizedBox(width: 5),
            _iconAction(
              icon: Icons.add_rounded,
              tooltip: 'Добавить площадку',
              onTap: _openAddVenue,
              primary: true,
            ),
            const SizedBox(width: 5),
          ],
          _iconAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Обновить',
            onTap: _loadFirst,
          ),
        ],
      ),
    );
  }

  Widget _headerAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return Material(
      color: primary ? _BookingUi.green : _BookingUi.soft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: primary ? Colors.white : _BookingUi.greenDark,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: _t(
                  9.8,
                  weight: FontWeight.w600,
                  color: primary ? Colors.white : _BookingUi.greenDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: primary ? _BookingUi.green : _BookingUi.soft,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 17,
              color: primary ? Colors.white : _BookingUi.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      child: ListView(
        children: [
          Row(
            children: [
              _brandDots(color: _BookingUi.greenDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Поиск и фильтры',
                  style: _t(11.4, weight: FontWeight.w600),
                ),
              ),
              if (_hasFilters)
                InkWell(
                  onTap: _resetFilters,
                  borderRadius: BorderRadius.circular(7),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'Сбросить',
                      style: _t(
                        8.9,
                        weight: FontWeight.w600,
                        color: _BookingUi.red,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _searchField(),
          const SizedBox(height: 14),
          _sectionLabel('Вид спорта', _BookingUi.green),
          const SizedBox(height: 7),
          ..._sports.map(
            (sport) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: _sportRow(sport),
            ),
          ),
          const SizedBox(height: 10),
          _sectionLabel('Город', _BookingUi.amber),
          const SizedBox(height: 7),
          _popupFilter(
            label: _city.isEmpty ? 'Все города' : _city,
            items: _cityItems,
            current: _city,
            dotColor: _BookingUi.amber,
            allowEmpty: true,
            fullWidth: true,
            onSelected: (value) {
              setState(() => _city = value);
              _loadFirst();
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _BookingUi.soft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _brandDots(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Выберите площадку — расписание и бронирование откроются в карточке объекта.',
                    style: _t(9.3, color: _BookingUi.muted, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileFilters({required bool compact}) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 9, compact ? 10 : 14, 9),
      child: Column(
        children: [
          _searchField(),
          const SizedBox(height: 7),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _popupFilter(
                  label: _sport == 'Все' ? 'Вид спорта' : _sport,
                  items: _sports,
                  current: _sport,
                  dotColor: _BookingUi.green,
                  onSelected: (value) {
                    setState(() => _sport = value);
                    _loadFirst();
                  },
                ),
                const SizedBox(width: 6),
                _popupFilter(
                  label: _city.isEmpty ? 'Город' : _city,
                  items: _cityItems,
                  current: _city,
                  dotColor: _BookingUi.amber,
                  allowEmpty: true,
                  onSelected: (value) {
                    setState(() => _city = value);
                    _loadFirst();
                  },
                ),
                if (_hasFilters) ...[
                  const SizedBox(width: 6),
                  Material(
                    color: _BookingUi.redSoft,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: _resetFilters,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                        child: Row(
                          children: [
                            _dot(_BookingUi.red, size: 4.5),
                            const SizedBox(width: 6),
                            Text(
                              'Сбросить',
                              style: _t(
                                9.4,
                                weight: FontWeight.w600,
                                color: _BookingUi.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _BookingUi.soft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 17, color: _BookingUi.muted2),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              style: _t(10.4),
              decoration: InputDecoration(
                hintText: 'Название или адрес',
                hintStyle: _t(10.2, color: _BookingUi.muted2),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (_) => _loadFirst(),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            InkWell(
              onTap: () {
                _searchCtrl.clear();
                _loadFirst();
              },
              borderRadius: BorderRadius.circular(7),
              child: const SizedBox(
                width: 26,
                height: 26,
                child: Icon(Icons.close_rounded, size: 15, color: _BookingUi.muted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Row(
      children: [
        _dot(color, size: 5, glow: true),
        const SizedBox(width: 7),
        Text(text, style: _t(9.8, weight: FontWeight.w600)),
      ],
    );
  }

  Widget _sportRow(String sport) {
    final selected = _sport == sport;
    return Material(
      color: selected ? _BookingUi.greenSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          setState(() => _sport = sport);
          _loadFirst();
        },
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(
              children: [
                _dot(
                  selected ? _BookingUi.green : _BookingUi.muted2,
                  size: selected ? 5.5 : 4,
                  glow: selected,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    sport,
                    style: _t(
                      9.7,
                      weight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? _BookingUi.greenDark : _BookingUi.text,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_rounded, size: 14, color: _BookingUi.greenDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _popupFilter({
    required String label,
    required List<String> items,
    required String current,
    required Color dotColor,
    required ValueChanged<String> onSelected,
    bool allowEmpty = false,
    bool fullWidth = false,
  }) {
    final selected = allowEmpty ? current.isNotEmpty : current != 'Все';

    return PopupMenuButton<String>(
      tooltip: '',
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: onSelected,
      itemBuilder: (context) {
        final result = <PopupMenuEntry<String>>[];

        if (allowEmpty) {
          result.add(
            PopupMenuItem<String>(
              value: '',
              child: Row(
                children: [
                  _dot(current.isEmpty ? _BookingUi.green : _BookingUi.muted2, size: 4.5),
                  const SizedBox(width: 8),
                  Text(
                    'Все города',
                    style: _t(
                      10.2,
                      weight: current.isEmpty ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        for (final item in items) {
          result.add(
            PopupMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  _dot(item == current ? dotColor : _BookingUi.muted2, size: 4.5),
                  const SizedBox(width: 8),
                  Text(
                    item,
                    style: _t(
                      10.2,
                      weight: item == current ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return result;
      },
      child: Container(
        width: fullWidth ? double.infinity : null,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: selected ? _BookingUi.greenSoft : _BookingUi.soft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            _dot(selected ? dotColor : _BookingUi.muted2, size: selected ? 5 : 4, glow: selected),
            const SizedBox(width: 7),
            if (fullWidth)
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(
                    9.7,
                    weight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? _BookingUi.greenDark : _BookingUi.text,
                  ),
                ),
              )
            else
              Text(
                label,
                style: _t(
                  9.7,
                  weight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? _BookingUi.greenDark : _BookingUi.text,
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, size: 15, color: _BookingUi.muted),
          ],
        ),
      ),
    );
  }

  Widget _catalog() {
    return RefreshIndicator(
      color: _BookingUi.green,
      onRefresh: _loadFirst,
      child: NotificationListener<ScrollNotification>(
        onNotification: (sn) {
          if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 320) {
            _loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverToBoxAdapter(child: _catalogHeader()),
          if (_loading)
            SliverToBoxAdapter(child: _skeletonList())
          else if (_err)
            SliverFillRemaining(hasScrollBody: false, child: _error())
          else if (_items.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _empty())
          else if (_view == VenueCatalogView.grid)
            _gridSliver()
          else
            _listSliver(),
          if (!_loading && !_err && _items.isNotEmpty)
            SliverToBoxAdapter(child: _loadMoreFooter()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _catalogHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          return Row(
            children: [
              _dot(_BookingUi.green, size: 6, glow: true),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loading ? 'Загрузка площадок' : '${_items.length} ${_venueWord(_items.length)}',
                      style: _t(11.8, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _filterSummary(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(9.4, color: _BookingUi.muted),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: _BookingUi.soft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _dot(_BookingUi.amber, size: 4.5),
                      const SizedBox(width: 6),
                      Text(
                        'Нажмите на площадку для бронирования',
                        style: _t(9.1, color: _BookingUi.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _viewToggle(),
            ],
          );
        },
      ),
    );
  }

  String _filterSummary() {
    final parts = <String>[];
    if (_sport != 'Все') parts.add(_sport);
    if (_city.isNotEmpty) parts.add(_city);
    if (_searchCtrl.text.trim().isNotEmpty) parts.add('«${_searchCtrl.text.trim()}»');
    return parts.isEmpty ? 'Все доступные спортивные объекты' : parts.join(' · ');
  }

  String _venueWord(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'площадок';
    if (mod10 == 1) return 'площадка';
    if (mod10 >= 2 && mod10 <= 4) return 'площадки';
    return 'площадок';
  }

  Widget _viewToggle() {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _BookingUi.soft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewButton(
            Icons.grid_view_rounded,
            selected: _view == VenueCatalogView.grid,
            onTap: () => setState(() {
              _grid = true;
              _view = VenueCatalogView.grid;
            }),
          ),
          _viewButton(
            Icons.view_list_rounded,
            selected: _view == VenueCatalogView.list,
            onTap: () => setState(() {
              _grid = false;
              _view = VenueCatalogView.list;
            }),
          ),
        ],
      ),
    );
  }

  Widget _viewButton(IconData icon, {required bool selected, required VoidCallback onTap}) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          width: 29,
          height: 28,
          child: Icon(
            icon,
            size: 15,
            color: selected ? _BookingUi.greenDark : _BookingUi.muted2,
          ),
        ),
      ),
    );
  }

  Widget _gridSliver() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      sliver: SliverGrid.builder(
        itemCount: _items.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.12,
        ),
        itemBuilder: (_, i) => _venueGridCard(_items[i]),
      ),
    );
  }

  Widget _listSliver() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      sliver: SliverList.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 7),
        itemBuilder: (_, i) => _venueListTile(_items[i]),
      ),
    );
  }

  Widget _venueGridCard(Map<String, dynamic> v) {
    final title = (v['title'] ?? v['name'] ?? 'Площадка').toString();
    final address = (v['address'] ?? v['location'] ?? '').toString();
    final sport = (v['sport'] ?? v['category'] ?? '').toString();
    final city = (v['city'] ?? '').toString();
    final image = _normalizeImage(v);

    return Material(
      color: _BookingUi.soft,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openVenue(v),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: _VenueImage(
                image: image,
                fallbackIcon: Icons.location_on_outlined,
                radius: 0,
              ),
            ),
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _dot(_BookingUi.green, size: 5, glow: true),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sport.isEmpty ? 'Спортивная площадка' : sport,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _t(
                              8.9,
                              weight: FontWeight.w600,
                              color: _BookingUi.greenDark,
                            ),
                          ),
                        ),
                        if (city.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _dot(_BookingUi.amber, size: 4),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _t(8.7, color: _BookingUi.muted),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _t(11.6, weight: FontWeight.w600),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(9.2, color: _BookingUi.muted),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        _brandDots(color: _BookingUi.greenDark),
                        const Spacer(),
                        Text(
                          'Забронировать',
                          style: _t(
                            9.3,
                            weight: FontWeight.w600,
                            color: _BookingUi.greenDark,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: _BookingUi.greenDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _venueListTile(Map<String, dynamic> v) {
    final title = (v['title'] ?? v['name'] ?? 'Площадка').toString();
    final address = (v['address'] ?? v['location'] ?? '').toString();
    final sport = (v['sport'] ?? v['category'] ?? '').toString();
    final city = (v['city'] ?? '').toString();
    final image = _normalizeImage(v);

    return Material(
      color: _BookingUi.soft,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openVenue(v),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 82,
                child: _VenueImage(
                  image: image,
                  fallbackIcon: Icons.location_on_outlined,
                  radius: 9,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _dot(_BookingUi.green, size: 5),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sport.isEmpty ? 'Спортивная площадка' : sport,
                            style: _t(
                              8.9,
                              weight: FontWeight.w600,
                              color: _BookingUi.greenDark,
                            ),
                          ),
                        ),
                        if (city.isNotEmpty) ...[
                          _dot(_BookingUi.amber, size: 4),
                          const SizedBox(width: 5),
                          Text(city, style: _t(8.8, color: _BookingUi.muted)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(11.5, weight: FontWeight.w600),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(9.2, color: _BookingUi.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: _BookingUi.greenSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dot(_BookingUi.green, size: 4.5),
                    const SizedBox(width: 6),
                    Text(
                      'Забронировать',
                      style: _t(
                        9.2,
                        weight: FontWeight.w600,
                        color: _BookingUi.greenDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeImage(Map<String, dynamic> v) {
    final raw = (v['image_path'] ?? v['image'] ?? v['imageUrl'] ?? v['photo'] ?? v['logo'] ?? '')
        .toString()
        .trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final clean = raw.startsWith('/') ? raw.substring(1) : raw;
    return 'https://sportotekaapp.ru/$clean';
  }

  Widget _loadMoreFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: _loadingMore
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _BookingUi.green,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(
                    _canLoadMore
                        ? _BookingUi.green
                        : _BookingUi.muted2,
                    size: 4.5,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _canLoadMore
                        ? 'Прокрутите ниже — загрузим ещё'
                        : 'Все площадки загружены',
                    style: _t(
                      9.2,
                      color: _BookingUi.muted,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _skeletonList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 980
              ? 3
              : constraints.maxWidth >= 620
                  ? 2
                  : 1;
          final width = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(
              6,
              (_) => SizedBox(width: width, child: const _VenueSkeleton()),
            ),
          );
        },
      ),
    );
  }

  Widget _empty() {
    return _stateBlock(
      color: _BookingUi.amber,
      icon: Icons.search_off_rounded,
      title: 'Площадки не найдены',
      text: 'Измените запрос или сбросьте выбранные фильтры.',
      actionLabel: 'Сбросить фильтры',
      onAction: _resetFilters,
    );
  }

  Widget _error() {
    return _stateBlock(
      color: _BookingUi.red,
      icon: Icons.error_outline_rounded,
      title: 'Не удалось загрузить площадки',
      text: _errMsg ?? 'Проверьте соединение и попробуйте ещё раз.',
      actionLabel: 'Повторить',
      onAction: _loadFirst,
    );
  }

  Widget _stateBlock({
    required Color color,
    required IconData icon,
    required String title,
    required String text,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _BookingUi.soft,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(color, size: 7, glow: true),
                const SizedBox(width: 8),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _t(12.4, weight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              text,
              textAlign: TextAlign.center,
              style: _t(9.8, color: _BookingUi.muted, height: 1.35),
            ),
            const SizedBox(height: 11),
            Material(
              color: color == _BookingUi.red ? _BookingUi.redSoft : _BookingUi.greenSoft,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  child: Text(
                    actionLabel,
                    style: _t(
                      9.6,
                      weight: FontWeight.w600,
                      color: color == _BookingUi.red ? _BookingUi.red : _BookingUi.greenDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingUi {
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFD92D20);
  static const redSoft = Color(0xFFFFF1F1);
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF667085);
  static const muted2 = Color(0xFF98A2B3);
  static const soft = Color(0xFFF7F9F8);
  static const line = Color(0xFFEEF1EF);
}

class _VenueImage extends StatelessWidget {
  final String image;
  final IconData fallbackIcon;
  final double radius;

  const _VenueImage({
    required this.image,
    required this.fallbackIcon,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFF0F4F1),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: _BookingUi.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 7),
          Icon(fallbackIcon, size: 22, color: _BookingUi.greenDark),
        ],
      ),
    );

    if (image.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: fallback,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        image,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

class _VenueSkeleton extends StatelessWidget {
  const _VenueSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 238,
      decoration: BoxDecoration(
        color: _BookingUi.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(child: Container(color: const Color(0xFFEDF1EF))),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                _SkeletonLine(widthFactor: .38),
                SizedBox(height: 8),
                _SkeletonLine(widthFactor: .84),
                SizedBox(height: 7),
                _SkeletonLine(widthFactor: .58),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  const _SkeletonLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E7E4),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
