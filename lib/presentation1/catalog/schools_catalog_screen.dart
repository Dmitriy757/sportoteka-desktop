import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const String apiBaseUrl = 'https://sportotekaapp.ru/api/';

enum CatalogView { list, grid, map }

class SchoolsCatalogScreen extends StatefulWidget {
  const SchoolsCatalogScreen({super.key});

  @override
  State<SchoolsCatalogScreen> createState() => _SchoolsCatalogScreenState();
}

class _SchoolsCatalogScreenState extends State<SchoolsCatalogScreen> {
  // --- Networking
  final _dio = Dio()
    ..options.baseUrl = apiBaseUrl
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 8);

  // --- State
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String _sport = '';
  String _region = '';
  String _city = '';

  bool _loading = true;
  bool _err = false;
  String? _errMsg;

  List<Map<String, dynamic>> _items = [];
  List<String> _sports = [];
  List<String> _regions = [];
  List<String> _cities = [];

  int _limit = 50;
  int _offset = 0;
  bool _canLoadMore = true;
  bool _loadingMore = false;

  CatalogView _view = CatalogView.list; // режим: список/сетка/карта
  bool _grid = false; // быстрый переключатель список/сетка (используется, когда _view != map)

  // --- Map
  GoogleMapController? _mapCtrl;
  CameraPosition _initialCamera = const CameraPosition(
    target: LatLng(53.9, 27.56), // дефолт: Минск
    zoom: 11,
  );

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
    _mapCtrl?.dispose();
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
      if (_view == CatalogView.map) {
        // подвинем камеру под метки, когда карта уже создана
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitAllMarkers());
      }
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
    final params = <String, dynamic>{
      'q': _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      'sport': _sport.isEmpty ? null : _sport,
      'region': _region.isEmpty ? null : _region,
      'city': _city.isEmpty ? null : _city,
      'limit': _limit,
      'offset': _offset,
    }..removeWhere((k, v) => v == null);

    final res = await _dio.get('get_schools.php', queryParameters: params);

    List<Map<String, dynamic>> list;
    if (res.data is Map && res.data['items'] is List) {
      list = List<Map<String, dynamic>>.from(res.data['items']);
    } else if (res.data is List) {
      list = List<Map<String, dynamic>>.from(res.data);
    } else {
      list = const [];
    }

    if (list.length < _limit) _canLoadMore = false;
    _offset += list.length;
    return list;
  }

  void _prepareFiltersFrom(List<Map<String, dynamic>> data) {
    final sports = <String>{};
    final regions = <String>{};
    final cities = <String>{};

    for (final m in data) {
      final st = (m['sports'] ?? []) as List?;
      if (st != null) {
        for (final s in st) {
          if (s is String && s.trim().isNotEmpty) sports.add(s.trim());
        }
      } else {
        final text = (m['sports_text'] ?? '').toString();
        for (final s in text.split(',')) {
          final v = s.trim();
          if (v.isNotEmpty) sports.add(v);
        }
      }
      final r = (m['region'] ?? '').toString().trim();
      final c = (m['city'] ?? '').toString().trim();
      if (r.isNotEmpty) regions.add(r);
      if (c.isNotEmpty) cities.add(c);
    }

    _sports = sports.toList()..sort();
    _regions = regions.toList()..sort();
    _cities = cities.toList()..sort();
  }

  Future<void> _loadMore() async {
    if (!_canLoadMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await _fetch();
      setState(() => _items.addAll(next));
      if (_view == CatalogView.map) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitAllMarkers());
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ------------------- MAP HELPERS -------------------

  LatLng? _toLatLng(Map<String, dynamic> m) {
    // поддержка разных ключей: lat/lng или latitude/longitude
    double? lat = double.tryParse((m['lat'] ?? m['latitude'] ?? '').toString());
    double? lng = double.tryParse((m['lng'] ?? m['lon'] ?? m['longitude'] ?? '').toString());
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return LatLng(lat, lng);
  }

  Set<Marker> _markersFromItems() {
    final markers = <Marker>{};
    for (final m in _items) {
      final pos = _toLatLng(m);
      if (pos == null) continue;
      final id = (m['id'] ?? m['name'] ?? '${pos.latitude},${pos.longitude}').toString();
      markers.add(
        Marker(
          markerId: MarkerId(id),
          position: pos,
          infoWindow: InfoWindow(
            title: (m['name'] ?? 'Школа').toString(),
            snippet: ([m['city'], m['region']].where((e) => (e ?? '').toString().isNotEmpty).join(', ')).toString(),
            onTap: () {
              // TODO: навигация на детали школы при тапе по инфоокну, если нужно
            },
          ),
          onTap: () {
            // Можно подсветить школу или показать снизу сниппет
          },
        ),
      );
    }
    return markers;
  }

  Future<void> _fitAllMarkers() async {
    if (_mapCtrl == null) return;
    final markers = _markersFromItems().toList();
    if (markers.isEmpty) {
      await _mapCtrl!.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
      return;
    }
    if (markers.length == 1) {
      await _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(markers.first.position, 13));
      return;
    }
    double? x0, x1, y0, y1;
    for (final m in markers) {
      final lat = m.position.latitude;
      final lng = m.position.longitude;
      if (x0 == null) {
        x0 = x1 = lat;
        y0 = y1 = lng;
      } else {
        if (lat > x1!) x1 = lat;
        if (lat < x0) x0 = lat;
        if (lng > y1!) y1 = lng;
        if (lng < y0!) y0 = lng;
      }
    }
    if (x0 == null || y0 == null || x1 == null || y1 == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(x0, y0),
      northeast: LatLng(x1, y1),
    );
    // padding чтобы карточки не прилипали к краям
    await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
  }

  // ------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF3F5F8); // матовый фон
    final inMap = _view == CatalogView.map;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: const Text('Спортивные учреждения', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (!inMap)
            IconButton(
              tooltip: _grid ? 'Режим списка' : 'Режим сетки',
              onPressed: () => setState(() {
                _grid = !_grid;
                _view = _grid ? CatalogView.grid : CatalogView.list;
              }),
              icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            ),
          IconButton(
            tooltip: inMap ? 'Показать список' : 'Показать карту',
            onPressed: () => setState(() {
              _view = inMap ? ( _grid ? CatalogView.grid : CatalogView.list ) : CatalogView.map;
              // подстроить камеру после переключения
              if (!inMap) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _fitAllMarkers());
              }
            }),
            icon: Icon(inMap ? Icons.view_list_rounded : Icons.map_rounded),
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
            ] else if (_view == CatalogView.map) ...[
              SliverFillRemaining(
                hasScrollBody: true,
                child: Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: (c) {
                        _mapCtrl = c;
                        // маленькая задержка, чтобы карта успела «схлопнуться», а затем fit bounds
                        Future.delayed(const Duration(milliseconds: 200), _fitAllMarkers);
                      },
                      initialCameraPosition: _initialCamera,
                      markers: _markersFromItems(),
                      // включи это, если у тебя настроены пермишены
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: true,
                    ),
                    // кнопки управления поверх карты
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Column(
                        children: [
                          _MapFab(
                            icon: Icons.center_focus_strong_rounded,
                            tooltip: 'Показать все',
                            onTap: _fitAllMarkers,
                          ),
                          const SizedBox(height: 12),
                          _MapFab(
                            icon: Icons.my_location_rounded,
                            tooltip: 'Моё местоположение (UI)',
                            onTap: () async {
                              // Если добавишь геолокацию — тут можно центрироваться на user location
                              // Пока просто прыжок к дефолтной точке
                              await _mapCtrl?.animateCamera(
                                CameraUpdate.newCameraPosition(_initialCamera),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_view == CatalogView.grid) ...[
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
                  icon: Icons.sports_soccer_rounded,
                  onTap: () => _pickFilter('Вид спорта', _sport, _sports, (v) {
                    setState(() => _sport = v);
                    _loadFirst();
                  }),
                  selected: _sport.isNotEmpty,
                ),
                _FilterChipMatte(
                  label: _region.isEmpty ? 'Область' : _region,
                  icon: Icons.public_rounded,
                  onTap: () => _pickFilter('Область', _region, _regions, (v) {
                    setState(() => _region = v);
                    _loadFirst();
                  }),
                  selected: _region.isNotEmpty,
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
                if (_sport.isNotEmpty || _region.isNotEmpty || _city.isNotEmpty)
                  _FilterChipMatte(
                    label: 'Сбросить',
                    icon: Icons.filter_alt_off_rounded,
                    onTap: () {
                      setState(() {
                        _sport = '';
                        _region = '';
                        _city = '';
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
        final all = ['Все', ...items];
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
                    itemCount: all.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = all[i] == 'Все' ? '' : all[i];
                      final selected = v == current;
                      return ListTile(
                        title: Text(all[i]),
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

  // --- Список (sliver) ---
  Widget _listSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      sliver: SliverList.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _schoolTile(_items[i]),
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
          childAspectRatio: 1.15,
        ),
        itemBuilder: (_, i) => _schoolCardGrid(_items[i]),
      ),
    );
  }

  // --- Карточка в списке (матовая) ---
  Widget _schoolTile(Map<String, dynamic> m) {
    final name = (m['name'] ?? 'Школа').toString();
    final region = (m['region'] ?? '').toString();
    final city = (m['city'] ?? '').toString();
    final address = (m['address'] ?? '').toString();
    final sports = (m['sports'] is List && (m['sports'] as List).isNotEmpty)
        ? (m['sports'] as List).join(', ')
        : (m['sports_text'] ?? '').toString();

    return _MatteSurface(
      onTap: () {
        // Navigator.push(context, MaterialPageRoute(builder: (_) => SchoolDetailScreen(...)));
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MatteIconBadge(icon: Icons.school_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if (city.isNotEmpty || region.isNotEmpty)
                    Text(
                      [city, region].where((e) => e.isNotEmpty).join(', '),
                      style: const TextStyle(color: Color(0xFF475569)),
                    ),
                  if (address.isNotEmpty)
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  if (sports.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      sports,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
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

  // --- Карточка в сетке (матовая) ---
  Widget _schoolCardGrid(Map<String, dynamic> m) {
  final name = (m['name'] ?? 'Школа').toString();
  final region = (m['region'] ?? '').toString();
  final city = (m['city'] ?? '').toString();
  final sports = (m['sports'] is List && (m['sports'] as List).isNotEmpty)
      ? (m['sports'] as List).take(3).join(', ')
      : (m['sports_text'] ?? '').toString();

  return _MatteSurface(
    padding: const EdgeInsets.all(12),
    onTap: () {
      // Navigator.push(context, MaterialPageRoute(builder: (_) => SchoolDetailScreen(...)));
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MatteIconBadge(icon: Icons.school_rounded, size: 48),
        const SizedBox(height: 10),

        // название школы
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          maxLines: 3, // теперь до 3 строк
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // город + область
        Text(
          [city, region].where((e) => e.isNotEmpty).join(', '),
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        if (sports.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            sports,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const Spacer(), // всё, что выше — прижмётся к верху

        // кнопка "Открыть" внизу
        Row(
          children: const [
            Text(
              "Открыть",
              style: TextStyle(
                color: Color(0xFF0EA5E9),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Color(0xFF0EA5E9)),
          ],
        ),
      ],
    ),
  );
}

  // --- Footer с автоподгрузкой ---
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
              ? const SizedBox(
                  height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2.8))
              : _canLoadMore
                  ? const Text('Прокрутите вниз, чтобы загрузить ещё',
                      style: TextStyle(color: Color(0xFF94A3B8)))
                  : const Text('Больше результатов нет',
                      style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      ),
    );
  }

  // --- Скелетоны ---
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
                  const _MatteIconBadge(icon: Icons.school_rounded),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      children: [
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

  // --- Empty & Error ---
  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 56, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text('Ничего не найдено',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Попробуйте изменить фильтры или запрос',
                style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _sport = '';
                  _region = '';
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
            const Text('Ошибка загрузки',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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

// ===================== MATTE UI ATOMS =====================

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

class _MatteIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;

  const _MatteIconBadge({required this.icon, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Icon(icon, color: const Color(0xFF0EA5E9)),
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

class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _MapFab({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Center(child: Icon(Icons.my_location_rounded)),
          ),
        ),
      ),
    );
  }
}
