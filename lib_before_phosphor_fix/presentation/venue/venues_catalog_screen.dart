import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/booking_screen/venue_booking_screen.dart';

const String apiBaseUrl = 'https://sportotekaapp.ru/api/';

enum VenueCatalogView { list, grid }

class VenuesCatalogScreen extends StatefulWidget {
  final String? initialSport;
  final String? initialCity;

  const VenuesCatalogScreen({
    super.key,
    this.initialSport,
    this.initialCity,
  });

  @override
  State<VenuesCatalogScreen> createState() => _VenuesCatalogScreenState();
}

class _VenuesCatalogScreenState extends State<VenuesCatalogScreen> {
  // --- Networking
  final _dio = Dio()
    ..options.baseUrl = apiBaseUrl
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 10);

  // --- State
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String _sport = '';
  String _city = '';
  String _type = ''; // например: "Футбол", "Манеж", "Зал" и т.п. (если есть)

  bool _loading = true;
  bool _err = false;
  String? _errMsg;

  List<Map<String, dynamic>> _items = [];
  List<String> _sports = [];
  List<String> _cities = [];
  List<String> _types = [];

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

    if (widget.initialSport != null && widget.initialSport!.isNotEmpty) {
      _sport = widget.initialSport!;
    }
    if (widget.initialCity != null && widget.initialCity!.isNotEmpty) {
      _city = widget.initialCity!;
    }

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

    // ПОДДЕРЖКА РАЗНЫХ API:
    // 1) get_venues.php (рекомендуется)
    // 2) init_home_data.php (если там есть venues)
    final params = <String, dynamic>{
      'q': _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      'sport': _sport.isEmpty ? null : _sport,
      'city': _city.isEmpty ? null : _city,
      'type': _type.isEmpty ? null : _type,
      'limit': _limit,
      'offset': _offset,
    }..removeWhere((k, v) => v == null);

    Response res;
    try {
      res = await _dio.get('get_venues.php', queryParameters: params);
    } on DioException catch (e) {
      // fallback: если нет get_venues.php
      if (e.response?.statusCode == 404) {
        res = await _dio.get('init_home_data.php', queryParameters: {
          if (_sport.isNotEmpty) 'sport': _sport,
          if (_city.isNotEmpty) 'city': _city,
        });
      } else {
        rethrow;
      }
    }

    final data = res.data;

    List<Map<String, dynamic>> list = [];

    // Нормализуем возможные форматы
    if (data is Map && data['venues'] is List) {
      list = List<Map<String, dynamic>>.from(data['venues']);
    } else if (data is Map && data['items'] is List) {
      list = List<Map<String, dynamic>>.from(data['items']);
    } else if (data is List) {
      list = List<Map<String, dynamic>>.from(data);
    } else if (data is Map && data['data'] is List) {
      list = List<Map<String, dynamic>>.from(data['data']);
    }

    // Фильтрация на клиенте, если fallback API не принимает параметры (например init_home_data)
    if (_searchCtrl.text.trim().isNotEmpty) {
      final q = _searchCtrl.text.trim().toLowerCase();
      list = list.where((v) {
        final t = (v['title'] ?? '').toString().toLowerCase();
        final a = (v['address'] ?? '').toString().toLowerCase();
        return t.contains(q) || a.contains(q);
      }).toList();
    }
    if (_sport.isNotEmpty) {
      list = list.where((v) => (v['sport'] ?? '').toString() == _sport).toList();
    }
    if (_city.isNotEmpty) {
      list = list.where((v) => (v['city'] ?? '').toString() == _city).toList();
    }
    if (_type.isNotEmpty) {
      list = list.where((v) => (v['type'] ?? '').toString() == _type).toList();
    }

    // Пагинация (только если это реальный get_venues.php, иначе может быть false-пагинация)
    if (list.length < _limit) _canLoadMore = false;
    _offset += list.length;

    return list;
  }

  void _prepareFiltersFrom(List<Map<String, dynamic>> data) {
    final sports = <String>{};
    final cities = <String>{};
    final types = <String>{};

    for (final m in data) {
      final s = (m['sport'] ?? '').toString().trim();
      if (s.isNotEmpty) sports.add(s);

      final c = (m['city'] ?? '').toString().trim();
      if (c.isNotEmpty) cities.add(c);

      final t = (m['type'] ?? '').toString().trim();
      if (t.isNotEmpty) types.add(t);
    }

    _sports = sports.toList()..sort();
    _cities = cities.toList()..sort();
    _types = types.toList()..sort();
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

  Future<void> _openBooking(Map<String, dynamic> venue) async {
    final userId = await PrefUtils.getUserId();
    if (!mounted) return;
    if (userId == null) return;

    final idStr = (venue['id'] ?? '').toString();
    final venueId = int.tryParse(idStr) ?? 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueBookingScreen(
          venueId: venueId,
          venueTitle: (venue['title'] ?? '').toString(),
          userId: userId,
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
        title: const Text('Каталог площадок', style: TextStyle(fontWeight: FontWeight.w800)),
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
    );
  }

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
                      hintText: 'Поиск по названию или адресу',
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
                  icon: Icons.sports_rounded,
                  onTap: () => _pickFilter('Вид спорта', _sport, _sports, (v) {
                    setState(() => _sport = v);
                    _loadFirst();
                  }),
                  selected: _sport.isNotEmpty,
                ),
                _FilterChipMatte(
                  label: _city.isEmpty ? 'Город' : _city,
                  icon: Icons.location_city_rounded,
                  onTap: () => _pickFilter('Город', _city, _cities, (v) {
                    setState(() => _city = v);
                    _loadFirst();
                  }),
                  selected: _city.isNotEmpty,
                ),
                _FilterChipMatte(
                  label: _type.isEmpty ? 'Тип' : _type,
                  icon: Icons.category_rounded,
                  onTap: () => _pickFilter('Тип', _type, _types, (v) {
                    setState(() => _type = v);
                    _loadFirst();
                  }),
                  selected: _type.isNotEmpty,
                ),
                if (_sport.isNotEmpty || _city.isNotEmpty || _type.isNotEmpty)
                  _FilterChipMatte(
                    label: 'Сбросить',
                    icon: Icons.filter_alt_off_rounded,
                    onTap: () {
                      setState(() {
                        _sport = '';
                        _city = '';
                        _type = '';
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
                  child: items.isEmpty
                      ? const Center(
                          child: Text('Нет вариантов для выбора',
                              style: TextStyle(color: Color(0xFF64748B))),
                        )
                      : ListView.separated(
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

  // --- LIST ---
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

  // --- GRID ---
  Widget _gridSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverGrid.builder(
        itemCount: _items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        itemBuilder: (_, i) => _venueCardGrid(_items[i]),
      ),
    );
  }

  // --- TILE ---
  Widget _venueTile(Map<String, dynamic> venue) {
    final title = (venue['title'] ?? 'Площадка').toString();
    final address = (venue['address'] ?? '').toString();
    final city = (venue['city'] ?? '').toString();
    final sport = (venue['sport'] ?? '').toString();
    final type = (venue['type'] ?? '').toString();
    final image = (venue['image'] ?? venue['photo'] ?? '').toString();
    final price = (venue['price'] ?? venue['hour_price'] ?? '').toString();

    return _MatteSurface(
      onTap: () => _openBooking(venue),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VenueImage(image: image, fallbackIcon: Icons.stadium_rounded),
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
                  if (address.isNotEmpty || city.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            [city, address].where((e) => e.trim().isNotEmpty).join(' • '),
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (sport.isNotEmpty || type.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (sport.isNotEmpty)
                            _MiniTag(icon: Icons.sports_rounded, text: sport),
                          if (type.isNotEmpty)
                            _MiniTag(icon: Icons.category_rounded, text: type),
                          if (price.isNotEmpty)
                            _MiniTag(icon: Icons.payments_rounded, text: price),
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

  // --- GRID CARD ---
  Widget _venueCardGrid(Map<String, dynamic> venue) {
    final title = (venue['title'] ?? 'Площадка').toString();
    final city = (venue['city'] ?? '').toString();
    final sport = (venue['sport'] ?? '').toString();
    final image = (venue['image'] ?? venue['photo'] ?? '').toString();

    return _MatteSurface(
      padding: const EdgeInsets.all(12),
      onTap: () => _openBooking(venue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VenueImage(
            image: image,
            fallbackIcon: Icons.stadium_rounded,
            height: 105,
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
          if (city.isNotEmpty)
            Row(
              children: [
                Icon(Icons.location_city_rounded, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    city,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
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
                  Icon(Icons.sports_rounded, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      sport,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Row(
            children: const [
              Text(
                "Забронировать",
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

  // --- Footer ---
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
                  const _VenueImage(image: '', fallbackIcon: Icons.stadium_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _SkeletonLine(widthFactor: 1.0),
                        SizedBox(height: 8),
                        _SkeletonLine(widthFactor: 0.7),
                        SizedBox(height: 6),
                        _SkeletonLine(widthFactor: 0.5),
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
                  _sport = '';
                  _city = '';
                  _type = '';
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

class _MiniTag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
