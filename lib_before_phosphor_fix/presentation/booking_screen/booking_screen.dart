// lib/presentation/booking_screen/booking_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

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

  VenueCatalogView _view = VenueCatalogView.list;
  bool _grid = false;

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
        title: const Text('Площадки', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: _grid ? 'Режим списка' : 'Режим сетки',
            onPressed: () => setState(() {
              _grid = !_grid;
              _view = _grid ? VenueCatalogView.grid : VenueCatalogView.list;
            }),
            icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
          ),
          IconButton(
            tooltip: 'Мои брони',
            onPressed: _openMyBookings,
            icon: const Icon(Icons.book_online_rounded),
          ),
          IconButton(
            tooltip: 'Добавить площадку',
            onPressed: _openAddVenue,
            icon: const Icon(Icons.add_location_alt_rounded),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loadFirst,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFirst,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _searchAndChips(bg)),
            SliverToBoxAdapter(child: const SizedBox(height: 8)),

            if (_loading) ...[
              SliverToBoxAdapter(child: _skeletonList()),
            ] else if (_err) ...[
              SliverFillRemaining(hasScrollBody: false, child: _error()),
            ] else if (_items.isEmpty) ...[
              SliverFillRemaining(hasScrollBody: false, child: _empty()),
            ] else if (_view == VenueCatalogView.grid) ...[
              _gridSliver(),
              SliverToBoxAdapter(child: _loadMoreFooter()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ] else ...[
              _listSliver(),
              SliverToBoxAdapter(child: _loadMoreFooter()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E74C4),
        onPressed: _openAddVenue,
        child: const Icon(Icons.add, color: Colors.white),
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
                      hintText: 'Поиск по названию / адресу',
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
                  label: _sport == 'Все' ? 'Вид спорта' : _sport,
                  icon: Icons.sports_soccer_rounded,
                  onTap: () => _pickFilter('Вид спорта', _sport, _sports, (v) {
                    setState(() => _sport = v);
                    _loadFirst();
                  }),
                  selected: _sport != 'Все',
                ),
                _FilterChipMatte(
                  label: _city.isEmpty ? 'Город' : _city,
                  icon: Icons.location_city_rounded,
                  onTap: () => _pickFilter('Город', _city, _cities.isEmpty ? ['Минск', 'Брест', 'Гомель', 'Витебск', 'Гродно', 'Могилёв'] : _cities, (v) {
                    setState(() => _city = v);
                    _loadFirst();
                  }),
                  selected: _city.isNotEmpty,
                ),
                if (_sport != 'Все' || _city.isNotEmpty || _searchCtrl.text.isNotEmpty)
                  _FilterChipMatte(
                    label: 'Сбросить',
                    icon: Icons.filter_alt_off_rounded,
                    onTap: () {
                      setState(() {
                        _sport = 'Все';
                        _city = '';
                        _searchCtrl.clear();
                      });
                      _loadFirst();
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
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = items[i];
                      final selected = v == current;
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

  // --- Slivers ---
  Widget _listSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverList.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _venueTile(_items[i]),
      ),
    );
  }

  Widget _gridSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverGrid.builder(
        itemCount: _items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.86,
        ),
        itemBuilder: (_, i) => _venueCardGrid(_items[i]),
      ),
    );
  }

  // --- Tiles ---
  Widget _venueTile(Map<String, dynamic> v) {
    final title = (v['title'] ?? v['name'] ?? 'Площадка').toString();
    final address = (v['address'] ?? v['location'] ?? '').toString();
    final sport = (v['sport'] ?? v['category'] ?? '').toString();
    final image = _normalizeImage(v);

    return _MatteSurface(
      onTap: () => _openVenue(v),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VenueImage(image: image, fallbackIcon: Icons.location_on_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (address.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.place_rounded, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (sport.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.sports_rounded, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(sport, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: () => _openVenue(v),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEFF6FF),
                        foregroundColor: const Color(0xFF1D4ED8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      child: const Text('Забронировать'),
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

  Widget _venueCardGrid(Map<String, dynamic> v) {
    final title = (v['title'] ?? v['name'] ?? 'Площадка').toString();
    final address = (v['address'] ?? v['location'] ?? '').toString();
    final image = _normalizeImage(v);

    return _MatteSurface(
      padding: const EdgeInsets.all(12),
      onTap: () => _openVenue(v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VenueImage(
            image: image,
            fallbackIcon: Icons.location_on_rounded,
            height: 110,
            borderRadius: 10,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (address.isNotEmpty)
            Row(
              children: [
                Icon(Icons.place_rounded, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const Spacer(),
          Row(
            children: const [
              Text(
                "Открыть",
                style: TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold, fontSize: 12),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF0EA5E9)),
            ],
          ),
        ],
      ),
    );
  }

  String _normalizeImage(Map<String, dynamic> v) {
    final raw = (v['image_path'] ?? v['image'] ?? v['imageUrl'] ?? v['photo'] ?? v['logo'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    // если сервер возвращает относительный путь
    return 'https://sportotekaapp.ru/$raw';
  }

  // --- Footer автоподгрузки ---
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

  // --- Skeleton / Empty / Error ---
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
                  const _VenueImageSkeleton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _SkeletonLine(widthFactor: 1.0),
                        SizedBox(height: 8),
                        _SkeletonLine(widthFactor: 0.7),
                        SizedBox(height: 6),
                        _SkeletonLine(widthFactor: 0.45),
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
            const Text('Площадок не найдено', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Попробуйте изменить фильтры или запрос', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _sport = 'Все';
                  _city = '';
                  _searchCtrl.clear();
                });
                _loadFirst();
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
            Text(
              _errMsg ?? 'Попробуйте ещё раз',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadFirst, child: const Text('Повторить')),
          ],
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

class _VenueImage extends StatelessWidget {
  final String image;
  final IconData fallbackIcon;
  final double? height;
  final double borderRadius;

  const _VenueImage({
    required this.image,
    required this.fallbackIcon,
    this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final size = height ?? 56;
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

class _VenueImageSkeleton extends StatelessWidget {
  const _VenueImageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
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
