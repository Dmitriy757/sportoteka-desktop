// lib/presentation/catalog/school_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sportoteka/presentation/school_detail_screen/school_detail_screen.dart';

const String apiBaseUrl = 'https://sportotekaapp.ru/api/';

enum SchoolCatalogView { list, grid, map }

class SchoolListScreen extends StatefulWidget {
  /// Вид спорта обязателен для get_schools_by_sport.php.
  /// Если не передан, экран покажет подсказку выбрать спорт.
  final String initialSport;

  const SchoolListScreen({
    super.key,
    this.initialSport = '',
  });

  @override
  State<SchoolListScreen> createState() => _SchoolListScreenState();
}

class _SchoolListScreenState extends State<SchoolListScreen> {
  // --- Networking
  final _dio = Dio()
    ..options.baseUrl = apiBaseUrl
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 8);

  // --- State
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String _sport = '';
  bool _loading = true;
  bool _err = false;
  String? _errMsg;

  List<Map<String, dynamic>> _raw = [];   // как пришло с бэка (id, name)
  List<Map<String, dynamic>> _items = []; // после клиентского поиска
  List<String> _sports = [];              // список видов из текущей выборки

  SchoolCatalogView _view = SchoolCatalogView.list;
  bool _grid = false;

  // Пагинация отсутствует на бэке этого метода — отключаем "дозагрузку"
  bool get _canLoadMore => false;
  bool get _loadingMore => false;

  // --- Map
  GoogleMapController? _mapCtrl;
  final CameraPosition _initialCamera = const CameraPosition(
    target: LatLng(53.9, 27.56), // Минск
    zoom: 11,
  );

  @override
  void initState() {
    super.initState();
    _sport = widget.initialSport;
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
    _searchDebounce = Timer(const Duration(milliseconds: 300), _applyClientSearch);
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _err = false;
      _errMsg = null;
      _raw = [];
      _items = [];
      _sports = [];
    });

    try {
      if (_sport.trim().isEmpty) {
        // Нечего грузить — попросим выбрать вид спорта
        setState(() {
          _raw = [];
          _items = [];
          _sports = [];
        });
        return;
      }

      final list = await _fetchBySport(_sport.trim());
      setState(() {
        _raw = list;
        _prepareFiltersFrom(list);
        _applyClientSearch();
      });

      if (_view == SchoolCatalogView.map) {
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

  Future<List<Map<String, dynamic>>> _fetchBySport(String sport) async {
    // Только get_schools_by_sport.php
    final res = await _dio.get('get_schools_by_sport.php', queryParameters: {
      'sport': sport,
    });

    // Ожидаем массив: [{id, name}]
    final data = res.data;
    List<Map<String, dynamic>> list;
    if (data is List) {
      list = List<Map<String, dynamic>>.from(data);
    } else {
      list = const [];
    }

    // Нормализуем под UI (добавим поля, которых нет в ответе)
    // logo/city/region пустые; sport проставим из выбранного
    return list.map<Map<String, dynamic>>((m) {
      final id = int.tryParse('${m['id']}') ?? 0;
      final name = (m['name'] ?? 'Школа').toString();
      return {
        'id': id,
        'name': name,
        'sport': _sport,   // чтобы на карточке было видно вид спорта
        'city': '',
        'region': '',
        'logo': '',
        // координат нет — карта будет без маркеров
        'lat': null,
        'lng': null,
      };
    }).toList();
  }

  void _prepareFiltersFrom(List<Map<String, dynamic>> data) {
    // Здесь источником спортов служит текущий выбранный (_sport),
    // но на всякий случай соберём уникальные из самих элементов.
    final s = <String>{};
    for (final m in data) {
      final v = (m['sport'] ?? _sport).toString().trim();
      if (v.isNotEmpty) s.add(v);
    }
    _sports = (s.isEmpty && _sport.isNotEmpty) ? [_sport] : s.toList()..sort();
  }

  void _applyClientSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      _items = List<Map<String, dynamic>>.from(_raw);
    } else {
      _items = _raw.where((e) {
        final name = (e['name'] ?? '').toString().toLowerCase();
        return name.contains(q);
      }).toList();
    }
    setState(() {});
  }

  // ------------------- MAP HELPERS -------------------

  LatLng? _toLatLng(Map<String, dynamic> m) {
    final lat = double.tryParse((m['lat'] ?? '').toString());
    final lng = double.tryParse((m['lng'] ?? m['lon'] ?? '').toString());
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return LatLng(lat, lng);
  }

  Set<Marker> _markersFromItems() {
    final markers = <Marker>{};
    for (final m in _items) {
      final pos = _toLatLng(m);
      if (pos == null) continue; // у нас координат нет
      final id = (m['id'] ?? m['name'] ?? '${pos.latitude},${pos.longitude}').toString();
      final city = (m['city'] ?? '').toString();
      final region = (m['region'] ?? '').toString();
      markers.add(
        Marker(
          markerId: MarkerId(id),
          position: pos,
          infoWindow: InfoWindow(
            title: (m['name'] ?? 'Школа').toString(),
            snippet: [city, region].where((e) => e.isNotEmpty).join(', '),
            onTap: () => _openDetails(m),
          ),
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
      x0 = x0 == null ? lat : (lat < x0 ? lat : x0);
      x1 = x1 == null ? lat : (lat > x1 ? lat : x1);
      y0 = y0 == null ? lng : (lng < y0 ? lng : y0);
      y1 = y1 == null ? lng : (lng > y1 ? lng : y1);
    }
    if (x0 == null || y0 == null || x1 == null || y1 == null) return;
    final bounds = LatLngBounds(southwest: LatLng(x0, y0), northeast: LatLng(x1, y1));
    await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
  }

  void _openDetails(Map<String, dynamic> s) {
    final id = int.tryParse((s['id'] ?? '0').toString()) ?? 0;
    final name = (s['name'] ?? 'Школа').toString();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SchoolDetailScreen(schoolId: id, name: name)),
    );
  }

  // ------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF3F5F8);
    final inMap = _view == SchoolCatalogView.map;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: const Text('Каталог школ', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (!inMap)
            IconButton(
              tooltip: _grid ? 'Режим списка' : 'Режим сетки',
              onPressed: () => setState(() {
                _grid = !_grid;
                _view = _grid ? SchoolCatalogView.grid : SchoolCatalogView.list;
              }),
              icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            ),
          IconButton(
            tooltip: inMap ? 'Показать список' : 'Показать карту',
            onPressed: () => setState(() {
              _view = inMap ? (_grid ? SchoolCatalogView.grid : SchoolCatalogView.list) : SchoolCatalogView.map;
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
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (_loading) ...[
              SliverToBoxAdapter(child: _skeletonList()),
            ] else if (_err) ...[
              SliverFillRemaining(hasScrollBody: false, child: _error()),
            ] else if (_sport.isEmpty) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: _hintPickSport(),
              ),
            ] else if (_items.isEmpty) ...[
              SliverFillRemaining(hasScrollBody: false, child: _empty()),
            ] else if (_view == SchoolCatalogView.map) ...[
              SliverFillRemaining(
                hasScrollBody: true,
                child: Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: (c) {
                        _mapCtrl = c;
                        Future.delayed(const Duration(milliseconds: 200), _fitAllMarkers);
                      },
                      initialCameraPosition: _initialCamera,
                      markers: _markersFromItems(),
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: true,
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: _MapFab(
                        icon: Icons.center_focus_strong_rounded,
                        tooltip: 'Показать все',
                        onTap: _fitAllMarkers,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_view == SchoolCatalogView.grid) ...[
              _gridSliver(),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ] else ...[
              _listSliver(),
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
                      hintText: 'Поиск по названию школы',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applyClientSearch(),
                  ),
                ),
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      _searchCtrl.clear();
                      _applyClientSearch();
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
                  onTap: () => _pickSport(),
                  selected: _sport.isNotEmpty,
                ),
                // region / city чипы убраны, т.к. бэк их не поддерживает на этом эндпоинте
                if (_sport.isNotEmpty || _searchCtrl.text.isNotEmpty)
                  _FilterChipMatte(
                    label: 'Сбросить',
                    icon: Icons.filter_alt_off_rounded,
                    onTap: () {
                      setState(() {
                        _searchCtrl.clear();
                        _sport = '';
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

  Future<void> _pickSport() async {
    // список спортов — из текущей выборки (если пусто — предложим ввести вручную)
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final all = (_sports.isEmpty ? <String>[] : _sports);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Вид спорта', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (all.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Список пуст. Укажите стартовый спорт при переходе с главной.',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: ListView.separated(
                    itemCount: all.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = all[i];
                      final selected = v == _sport;
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

    if (value != null) {
      setState(() => _sport = value);
      _loadFirst();
    }
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
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.15,
        ),
        itemBuilder: (_, i) => _schoolCardGrid(_items[i]),
      ),
    );
  }

  // --- Карточка школы в списке
  Widget _schoolTile(Map<String, dynamic> s) {
    final name   = (s['name'] ?? 'Школа').toString();
    final sport  = (s['sport'] ?? '').toString();
    final region = (s['region'] ?? '').toString();
    final city   = (s['city'] ?? '').toString();
    final logo   = (s['logo'] ?? '').toString();

    return _MatteSurface(
      onTap: () => _openDetails(s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MatteLogoBadge(logo: logo, fallbackIcon: Icons.school_rounded),
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
                  if (sport.isNotEmpty)
                    Text(
                      sport,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF64748B)),
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

  // --- Карточка школы в сетке
  Widget _schoolCardGrid(Map<String, dynamic> s) {
    final name   = (s['name'] ?? 'Школа').toString();
    final sport  = (s['sport'] ?? '').toString();
    final region = (s['region'] ?? '').toString();
    final city   = (s['city'] ?? '').toString();
    final logo   = (s['logo'] ?? '').toString();

    return _MatteSurface(
      padding: const EdgeInsets.all(12),
      onTap: () => _openDetails(s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MatteLogoBadge(logo: logo, fallbackIcon: Icons.school_rounded, size: 48),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            [city, region].where((e) => e.isNotEmpty).join(', '),
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sport.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sport,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Spacer(),
          Row(
            children: const [
              Text(
                "Открыть",
                style: TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF0EA5E9)),
            ],
          ),
        ],
      ),
    );
  }

  // --- Заглушка вместо пагинации
  Widget _loadMoreFooter() => const SizedBox.shrink();

  // --- Скелетоны / Empty / Error / Hint
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
                children: const [
                  _MatteLogoBadge(logo: '', fallbackIcon: Icons.school_rounded),
                  SizedBox(width: 12),
                  Expanded(
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

  Widget _hintPickSport() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.sports_rounded, size: 56, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text('Выберите вид спорта',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            SizedBox(height: 6),
            Text('Откройте чип “Вид спорта” и укажите спорт для загрузки школ.',
                style: TextStyle(color: Color(0xFF64748B))),
          ],
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
            const Text('Ничего не найдено',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Попробуйте изменить запрос',
                style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _searchCtrl.clear();
                });
                _applyClientSearch();
              },
              child: const Text('Сбросить поиск'),
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

// ===================== MATTE UI ATOMS (локальная копия) =====================

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

class _MatteLogoBadge extends StatelessWidget {
  final String logo;
  final IconData fallbackIcon;
  final double size;

  const _MatteLogoBadge({
    required this.logo,
    required this.fallbackIcon,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: logo.isNotEmpty
          ? Image.network(
              logo,
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
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: Icon(icon)),
          ),
        ),
      ),
    );
  }
}
