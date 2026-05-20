// lib/presentation/catalog/team_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sportoteka/presentation/team_screen/team_detail_screen.dart';

const String apiBaseUrl = 'https://sportotekaapp.ru/api/';

enum TeamCatalogView { list, grid, map }

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  // --- Networking
  final _dio = Dio()
    ..options.baseUrl = apiBaseUrl
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 8)
    ..options.headers = {'Connection': 'keep-alive'};

  // --- State
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String _sport = ''; // фильтр по виду спорта (на бэке это category)
  String _region = ''; // если есть у команды регион
  String _city = ''; // если есть у команды город

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

  TeamCatalogView _view = TeamCatalogView.list;
  bool _grid = false;

  // --- Map
  GoogleMapController? _mapCtrl;
  final CameraPosition _initialCamera = const CameraPosition(
    target: LatLng(53.9, 27.56), // Минск по умолчанию
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

  // ===================== HELPERS =====================

  // ✅ безопасно превращаем любой List<dynamic> -> List<Map<String,dynamic>>
  List<Map<String, dynamic>> _asListOfMaps(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  // ✅ нормализация медиа (logo)
  String _normalizeMediaUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('/')) return 'https://sportotekaapp.ru$s';
    return 'https://sportotekaapp.ru/$s';
  }

  // ✅ "sport" в приложении = category в БД/бэке
  String _readTeamSport(Map<String, dynamic> m) {
    final s = (m['category'] ?? m['sport'] ?? m['sports'] ?? '').toString().trim();
    return s;
  }

  // ===================== DATA =====================

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

      if (_view == TeamCatalogView.map) {
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

    // Универсальный эндпоинт (если есть): get_teams.php
    // Параметры: q, sport, region, city, limit, offset
    final params = <String, dynamic>{
      'q': _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      'sport': _sport.isEmpty ? null : _sport, // на бэке это category
      'region': _region.isEmpty ? null : _region,
      'city': _city.isEmpty ? null : _city,
      'limit': _limit,
      'offset': _offset,
    }..removeWhere((k, v) => v == null);

    Response res;

    try {
      // если есть get_teams.php — используем его
      res = await _dio.get('get_teams.php', queryParameters: params);
    } on DioException {
      // иначе — fallback на get_teams_by_sport.php (обычно только sport/category)
      final qp = <String, dynamic>{};
      if (_sport.isNotEmpty) qp['sport'] = _sport;

      // ❗ важно: если фильтры region/city есть в UI, но бэк их не поддерживает — они будут проигнорированы
      res = await _dio.get('get_teams_by_sport.php', queryParameters: qp);
    }

    final data = res.data;

    // Нормализуем возможные форматы:
    // 1) { status: success, teams: [...] }
    // 2) { items: [...] }
    // 3) просто [...]
    List<Map<String, dynamic>> list;
    if (data is Map && data['teams'] is List) {
      list = _asListOfMaps(data['teams']);
    } else if (data is Map && data['items'] is List) {
      list = _asListOfMaps(data['items']);
    } else if (data is Map && data['data'] is List) {
      list = _asListOfMaps(data['data']);
    } else if (data is List) {
      list = _asListOfMaps(data);
    } else {
      list = <Map<String, dynamic>>[];
    }

    // ✅ нормализуем ключи и url прямо здесь (чтобы UI был стабильный)
    list = list.map((m) {
      final mm = Map<String, dynamic>.from(m);

      // если бэк отдаёт category — дублируем в sport для совместимости UI
      final cat = (mm['category'] ?? '').toString().trim();
      if (cat.isNotEmpty && (mm['sport'] ?? '').toString().trim().isEmpty) {
        mm['sport'] = cat;
      }

      // logo -> абсолютный url
      final logoRaw = (mm['logo'] ?? mm['logo_url'] ?? mm['image'] ?? '').toString();
      final logo = _normalizeMediaUrl(logoRaw);
      mm['logo'] = logo;

      return mm;
    }).toList();

    // пагинация
    if (list.length < _limit) _canLoadMore = false;
    _offset += list.length;

    return list;
  }

  void _prepareFiltersFrom(List<Map<String, dynamic>> data) {
    final sports = <String>{};
    final regions = <String>{};
    final cities = <String>{};

    for (final m in data) {
      final s = _readTeamSport(m);
      if (s.isNotEmpty) sports.add(s);

      final region = (m['region'] ?? '').toString().trim();
      final city = (m['city'] ?? '').toString().trim();
      if (region.isNotEmpty) regions.add(region);
      if (city.isNotEmpty) cities.add(city);
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

      if (_view == TeamCatalogView.map) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitAllMarkers());
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ===================== MAP HELPERS =====================

  LatLng? _toLatLng(Map<String, dynamic> m) {
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
            title: (m['name'] ?? 'Клуб').toString(),
            snippet: ([m['city'], m['region']]
                    .where((e) => (e ?? '').toString().trim().isNotEmpty)
                    .join(', '))
                .toString(),
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

    await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
  }

  void _openDetails(Map<String, dynamic> t) {
    final id = int.tryParse((t['id'] ?? '0').toString()) ?? 0;
    final name = (t['name'] ?? 'Клуб').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamDetailScreen(teamId: id, teamName: name),
      ),
    );
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF3F5F8);
    final inMap = _view == TeamCatalogView.map;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: const Text('Каталог клубов', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (!inMap)
            IconButton(
              tooltip: _grid ? 'Режим списка' : 'Режим сетки',
              onPressed: () => setState(() {
                _grid = !_grid;
                _view = _grid ? TeamCatalogView.grid : TeamCatalogView.list;
              }),
              icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            ),
          IconButton(
            tooltip: inMap ? 'Показать список' : 'Показать карту',
            onPressed: () => setState(() {
              _view = inMap ? (_grid ? TeamCatalogView.grid : TeamCatalogView.list) : TeamCatalogView.map;
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
            ] else if (_items.isEmpty) ...[
              SliverFillRemaining(hasScrollBody: false, child: _empty()),
            ] else if (_view == TeamCatalogView.map) ...[
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
                            tooltip: 'К Минску',
                            onTap: () async {
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
            ] else if (_view == TeamCatalogView.grid) ...[
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
                      hintText: 'Поиск по названию клуба',
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
              ]
                  .expand((w) sync* {
                    yield w;
                    yield const SizedBox(width: 8);
                  })
                  .toList()
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
        itemBuilder: (_, i) => _teamTile(_items[i]),
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
        itemBuilder: (_, i) => _teamCardGrid(_items[i]),
      ),
    );
  }

  // --- Карточка команды в списке
  Widget _teamTile(Map<String, dynamic> t) {
    final name = (t['name'] ?? 'Клуб').toString();
    final sport = _readTeamSport(t);
    final region = (t['region'] ?? '').toString();
    final city = (t['city'] ?? '').toString();
    final logo = _normalizeMediaUrl((t['logo'] ?? '').toString());

    return _MatteSurface(
      onTap: () => _openDetails(t),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MatteLogoBadge(logo: logo, fallbackIcon: Icons.shield_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (city.trim().isNotEmpty || region.trim().isNotEmpty)
                    Text(
                      [city, region].where((e) => e.trim().isNotEmpty).join(', '),
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

  // --- Карточка команды в сетке
  Widget _teamCardGrid(Map<String, dynamic> t) {
    final name = (t['name'] ?? 'Клуб').toString();
    final sport = _readTeamSport(t);
    final region = (t['region'] ?? '').toString();
    final city = (t['city'] ?? '').toString();
    final logo = _normalizeMediaUrl((t['logo'] ?? '').toString());

    return _MatteSurface(
      padding: const EdgeInsets.all(12),
      onTap: () => _openDetails(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MatteLogoBadge(logo: logo, fallbackIcon: Icons.shield_rounded, size: 48),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            [city, region].where((e) => e.trim().isNotEmpty).join(', '),
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

  // --- Footer c автоподгрузкой
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

  // --- Скелетоны / Empty / Error
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
                  _MatteLogoBadge(logo: '', fallbackIcon: Icons.shield_rounded),
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

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 56, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text('Ничего не найдено', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Попробуйте изменить фильтры или запрос', style: TextStyle(color: Color(0xFF64748B))),
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
