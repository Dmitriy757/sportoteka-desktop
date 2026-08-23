import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

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
  String _selectedSchoolKey = '';

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
        _syncSelectedSchool(data);
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

  String _schoolKey(Map<String, dynamic> school) {
    final id = (school['id'] ?? school['school_id'] ?? '').toString().trim();
    if (id.isNotEmpty) return id;
    return '${school['name'] ?? ''}|${school['city'] ?? ''}';
  }

  void _syncSelectedSchool(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      _selectedSchoolKey = '';
      return;
    }
    if (!items.any((school) => _schoolKey(school) == _selectedSchoolKey)) {
      _selectedSchoolKey = _schoolKey(items.first);
    }
  }

  Map<String, dynamic>? get _selectedSchool {
    for (final school in _items) {
      if (_schoolKey(school) == _selectedSchoolKey) return school;
    }
    return _items.isEmpty ? null : _items.first;
  }

  void _selectSchool(Map<String, dynamic> school) {
    setState(() => _selectedSchoolKey = _schoolKey(school));
    if (MediaQuery.sizeOf(context).width >= 720) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: .86,
        child: _schoolDetailPane(school),
      ),
    );
  }

  // ------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    final inMap = _view == CatalogView.map;

    void toggleMap() {
      setState(() {
        _view = inMap ? CatalogView.list : CatalogView.map;
        if (!inMap) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitAllMarkers());
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final paneWidth = math.min(460.0, constraints.maxWidth * .43);
        final canClose = Navigator.of(context).canPop();
        final listPane = _buildListPane(compact: compact);

        return Scaffold(
          backgroundColor: _CatalogColors.workspace,
          body: SafeArea(
            child: Container(
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
                      _CatalogHeader(
                        icon: Icons.apartment_rounded,
                        title: 'Спортивные учреждения',
                        subtitle: '${_items.length} организаций · школы и академии',
                        onClose: canClose
                            ? () => Navigator.of(context).maybePop()
                            : null,
                        actions: [
                          _CatalogIconButton(
                            icon: inMap ? Icons.view_list_rounded : Icons.map_rounded,
                            tooltip: inMap ? 'Показать список' : 'Показать карту',
                            active: inMap,
                            onTap: toggleMap,
                          ),
                          _CatalogIconButton(
                            icon: Icons.refresh_rounded,
                            tooltip: 'Обновить',
                            onTap: _loadFirst,
                          ),
                        ],
                      ),
                      const Divider(height: 1, thickness: .7, color: _CatalogColors.line),
                      Expanded(
                        child: compact
                            ? (inMap ? _buildMapPane() : listPane)
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
                                    child: inMap
                                        ? _buildMapPane()
                                        : _schoolDetailPane(_selectedSchool),
                                  ),
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
      },
    );
  }

  Widget _buildListPane({required bool compact}) {
    return RefreshIndicator(
      color: _CatalogColors.green,
      onRefresh: _loadFirst,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _searchAndChips(_CatalogColors.panel)),
          if (_loading)
            SliverToBoxAdapter(child: _skeletonList())
          else if (_err)
            SliverFillRemaining(hasScrollBody: false, child: _error())
          else if (_items.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _empty())
          else ...[
            _listSliver(compact: compact),
            SliverToBoxAdapter(child: _loadMoreFooter()),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
          ],
        ],
      ),
    );
  }

  Widget _buildMapPane() {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            _mapCtrl = controller;
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
          right: 14,
          bottom: 14,
          child: Column(
            children: [
              _MapFab(
                icon: Icons.center_focus_strong_rounded,
                tooltip: 'Показать все',
                onTap: _fitAllMarkers,
              ),
              const SizedBox(height: 8),
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
    );
  }

  Widget _schoolDetailPane(Map<String, dynamic>? school) {
    if (school == null) {
      return const _CatalogEmptyDetail(
        icon: Icons.apartment_outlined,
        title: 'Выберите учреждение',
        subtitle: 'Информация появится в правом блоке.',
      );
    }

    final name = (school['name'] ?? 'Спортивная школа').toString();
    final region = (school['region'] ?? '').toString();
    final city = (school['city'] ?? '').toString();
    final address = (school['address'] ?? '').toString();
    final phone = (school['phone'] ?? school['telephone'] ?? '').toString();
    final site = (school['website'] ?? school['site'] ?? '').toString();
    final description =
        (school['description'] ?? school['about'] ?? '').toString();
    final sports = (school['sports'] is List && (school['sports'] as List).isNotEmpty)
        ? (school['sports'] as List).join(', ')
        : (school['sports_text'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        _CatalogDetailHero(
          icon: Icons.apartment_rounded,
          eyebrow: sports.isEmpty ? 'СПОРТИВНОЕ УЧРЕЖДЕНИЕ' : sports.toUpperCase(),
          title: name,
          subtitle: [city, region].where((value) => value.trim().isNotEmpty).join(', ').isEmpty
              ? 'Местоположение не указано'
              : [city, region].where((value) => value.trim().isNotEmpty).join(', '),
        ),
        const SizedBox(height: 18),
        _CatalogMetrics(
          items: [
            _CatalogMetricData(
              icon: Icons.sports_rounded,
              value: sports.isEmpty ? '—' : sports.split(',').first.trim(),
              label: 'Направление',
            ),
            _CatalogMetricData(
              icon: Icons.location_city_rounded,
              value: city.isEmpty ? '—' : city,
              label: 'Город',
            ),
            _CatalogMetricData(
              icon: Icons.map_outlined,
              value: region.isEmpty ? '—' : region,
              label: 'Регион',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _CatalogInfoSection(
          title: 'Данные учреждения',
          children: [
            _CatalogInfoRow(
              icon: Icons.sports_rounded,
              label: 'Направления',
              value: sports.isEmpty ? 'Не указаны' : sports,
            ),
            _CatalogInfoRow(
              icon: Icons.place_outlined,
              label: 'Адрес',
              value: address.isEmpty ? 'Не указан' : address,
            ),
            _CatalogInfoRow(
              icon: Icons.phone_outlined,
              label: 'Телефон',
              value: phone.isEmpty ? 'Не указан' : phone,
            ),
            _CatalogInfoRow(
              icon: Icons.language_rounded,
              label: 'Сайт',
              value: site.isEmpty ? 'Не указан' : site,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _CatalogDescription(
          title: 'Об учреждении',
          text: description.trim().isEmpty
              ? 'Описание учреждения пока не заполнено.'
              : description,
        ),
      ],
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
                      hintText: 'Поиск по названию или адресу',
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
                Text(title, style: _CatalogText.title(16)),
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
  Widget _listSliver({required bool compact}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      sliver: SliverList.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (_, i) => _schoolTile(_items[i], compact: compact),
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
  Widget _schoolTile(Map<String, dynamic> m, {bool compact = true}) {
    final name = (m['name'] ?? 'Школа').toString();
    final region = (m['region'] ?? '').toString();
    final city = (m['city'] ?? '').toString();
    final address = (m['address'] ?? '').toString();
    final sports = (m['sports'] is List && (m['sports'] as List).isNotEmpty)
        ? (m['sports'] as List).join(', ')
        : (m['sports_text'] ?? '').toString();
    final active = _schoolKey(m) == _selectedSchoolKey;

    return _MatteSurface(
      selected: active,
      onTap: () => _selectSchool(m),
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
          const _MatteIconBadge(icon: Icons.school_rounded, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: _CatalogText.title(compact ? 13.8 : 14.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    if (city.isNotEmpty) city,
                    if (region.isNotEmpty) region,
                    if (sports.isNotEmpty) sports,
                    if (address.isNotEmpty && compact) address,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CatalogText.muted(10.7),
                ),
              ],
            ),
          ),
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
                      style: _CatalogText.title(13.5),
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
          children: [
            Text(
              'Открыть',
              style: _CatalogText.action(color: _CatalogColors.green),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: _CatalogColors.green,
            ),
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
                  ? Text('Прокрутите вниз, чтобы загрузить ещё',
                      style: _CatalogText.muted(10.5))
                  : Text('Больше результатов нет',
                      style: _CatalogText.muted(10.5)),
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
            Text('Ничего не найдено',
                style: _CatalogText.title(15)),
            const SizedBox(height: 6),
            Text('Попробуйте изменить фильтры или запрос',
                style: _CatalogText.muted(11)),
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
            Text('Ошибка загрузки',
                style: _CatalogText.title(15)),
            const SizedBox(height: 6),
            Text(
              _errMsg ?? 'Попробуйте ещё раз',
              textAlign: TextAlign.center,
              style: _CatalogText.muted(11),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadFirst, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

class _CatalogColors {
  static const workspace = Color(0xFFF6F7F6);
  static const panel = Colors.white;
  static const soft = Color(0xFFFAFBFA);
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE9ECEA);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
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

class _CatalogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onClose;
  final List<Widget> actions;

  const _CatalogHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 11 : 13,
        compact ? 12 : 16,
        compact ? 11 : 13,
      ),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            decoration: BoxDecoration(
              color: _CatalogColors.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _CatalogColors.green, size: compact ? 18 : 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CatalogText.title(compact ? 15.5 : 16.5)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CatalogText.muted(compact ? 10.6 : 11.2)),
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
            Text(subtitle, textAlign: TextAlign.center, style: _CatalogText.muted(11.2)),
          ],
        ),
      ),
    );
  }
}

class _CatalogDetailHero extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;

  const _CatalogDetailHero({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: _CatalogColors.greenSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: _CatalogColors.green, size: 30),
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
              Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: _CatalogText.title(19)),
              const SizedBox(height: 5),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CatalogText.muted(11.3)),
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
        final width =
            math.max(108.0, (constraints.maxWidth - 16) / items.length).toDouble();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => Container(
                  width: width,
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
                      Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CatalogText.title(13)),
                      const SizedBox(height: 3),
                      Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CatalogText.muted(9.8)),
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
          Expanded(child: Text(value, textAlign: TextAlign.right, style: _CatalogText.title(11.2))),
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

// ===================== MATTE UI ATOMS =====================

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
        color: _CatalogColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: _CatalogColors.green),
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

class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _MapFab({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CatalogColors.greenSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(child: Icon(icon, color: _CatalogColors.green, size: 19)),
          ),
        ),
      ),
    );
  }
}
