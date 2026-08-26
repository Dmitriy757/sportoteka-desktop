// lib/presentation/catalog/school_list_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
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
  String _selectedSchoolKey = '';

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
      _raw = list;
      _prepareFiltersFrom(list);
      _applyClientSearch();

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
    _syncSelectedSchool(_items);
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

  void _selectSchool(Map<String, dynamic> school, {required bool compact}) {
    if (compact) {
      _openDetails(school);
      return;
    }
    setState(() => _selectedSchoolKey = _schoolKey(school));
  }

  // ------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    final inMap = _view == SchoolCatalogView.map;

    void toggleMap() {
      setState(() {
        _view = inMap ? SchoolCatalogView.list : SchoolCatalogView.map;
        if (!inMap) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitAllMarkers());
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final paneWidth = math.min(372.0, math.max(316.0, constraints.maxWidth * .34));
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
                        icon: Icons.school_rounded,
                        title: 'Каталог школ',
                        subtitle: '${_items.length} школ · $_sport',
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
          SliverToBoxAdapter(child: _CatalogPaneLabel(title: 'Школы', subtitle: 'Выберите школу', count: _items.length)),
          SliverToBoxAdapter(child: _searchAndChips(_CatalogColors.panel)),
          if (_loading)
            SliverToBoxAdapter(child: _skeletonList())
          else if (_err)
            SliverFillRemaining(hasScrollBody: false, child: _error())
          else if (_sport.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _hintPickSport())
          else if (_items.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _empty())
          else ...[
            _listSliver(compact: compact),
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
          child: _MapFab(
            icon: Icons.center_focus_strong_rounded,
            tooltip: 'Показать все',
            onTap: _fitAllMarkers,
          ),
        ),
      ],
    );
  }

  Widget _schoolDetailPane(Map<String, dynamic>? school) {
    if (school == null) {
      return const _CatalogEmptyDetail(
        icon: Icons.school_outlined,
        title: 'Выберите школу',
        subtitle: 'Карточка школы появится в правом блоке.',
      );
    }

    final name = (school['name'] ?? 'Школа').toString();
    final sport = (school['sport'] ?? _sport).toString();
    final region = (school['region'] ?? '').toString();
    final city = (school['city'] ?? '').toString();
    final address = (school['address'] ?? '').toString();
    final logo = (school['logo'] ?? '').toString();
    final description =
        (school['description'] ?? school['about'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        _CatalogDetailHero(
          image: logo,
          icon: Icons.school_rounded,
          eyebrow: sport.isEmpty ? 'СПОРТИВНАЯ ШКОЛА' : sport.toUpperCase(),
          title: name,
          subtitle: [city, region].where((value) => value.trim().isNotEmpty).join(', ').isEmpty
              ? 'Местоположение не указано'
              : [city, region].where((value) => value.trim().isNotEmpty).join(', '),
        ),
        const SizedBox(height: 12),
        _CatalogMetrics(
          items: [
            _CatalogMetricData(
              icon: Icons.sports_rounded,
              value: sport.isEmpty ? '—' : sport,
              label: 'Спорт',
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
        const SizedBox(height: 12),
        _CatalogInfoSection(
          title: 'Данные школы',
          children: [
            _CatalogInfoRow(
              icon: Icons.sports_rounded,
              label: 'Направление',
              value: sport.isEmpty ? 'Не указано' : sport,
            ),
            _CatalogInfoRow(
              icon: Icons.location_city_rounded,
              label: 'Город',
              value: city.isEmpty ? 'Не указан' : city,
            ),
            _CatalogInfoRow(
              icon: Icons.map_outlined,
              label: 'Регион',
              value: region.isEmpty ? 'Не указан' : region,
            ),
            _CatalogInfoRow(
              icon: Icons.place_outlined,
              label: 'Адрес',
              value: address.isEmpty ? 'Не указан' : address,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _CatalogDescription(
          title: 'О школе',
          text: description.trim().isEmpty
              ? 'Описание школы пока не заполнено.'
              : description,
        ),
        const SizedBox(height: 12),
        _CatalogPrimaryButton(
          title: 'Открыть полный профиль',
          icon: Icons.arrow_forward_rounded,
          onTap: () => _openDetails(school),
        ),
      ],
    );
  }

  // --- Top search + chips ---
  Widget _searchAndChips(Color bg) {
    return Container(
      decoration: BoxDecoration(color: bg),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
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
                      hintText: 'Поиск по названию школы',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: _CatalogText.title(12.4),
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
                Text('Вид спорта', style: _CatalogText.title(16)),
                const SizedBox(height: 12),
                if (all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Список пуст. Укажите стартовый спорт при переходе с главной.',
                      style: _CatalogText.muted(10.8),
                    ),
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
  Widget _listSliver({required bool compact}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      sliver: SliverList.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 1),
        itemBuilder: (_, i) => _schoolTile(_items[i], compact: compact),
      ),
    );
  }

  // --- Сетка (sliver) ---
  Widget _gridSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
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
  Widget _schoolTile(Map<String, dynamic> s, {bool compact = true}) {
    final name   = (s['name'] ?? 'Школа').toString();
    final sport  = (s['sport'] ?? '').toString();
    final region = (s['region'] ?? '').toString();
    final city   = (s['city'] ?? '').toString();
    final logo   = (s['logo'] ?? '').toString();
    final active = _schoolKey(s) == _selectedSchoolKey;

    return _MatteSurface(
      selected: active,
      onTap: () => _selectSchool(s, compact: compact),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: active ? _CatalogColors.green : _CatalogColors.line,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          _MatteLogoBadge(
            logo: logo,
            fallbackIcon: Icons.school_rounded,
            size: 38,
          ),
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
                    if (sport.isNotEmpty) sport,
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
                      style: _CatalogText.title(13.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            [city, region].where((e) => e.isNotEmpty).join(', '),
            style: _CatalogText.muted(10.6),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sport.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sport,
              style: _CatalogText.muted(10.6),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Spacer(),
          Row(
            children: [
              Text(
                'Открыть',
                style: _CatalogText.action(color: _CatalogColors.green),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _CatalogColors.green),
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
          children: [
            const Icon(Icons.sports_rounded, size: 56, color: _CatalogColors.green),
            const SizedBox(height: 12),
            Text('Выберите вид спорта',
                style: _CatalogText.title(15)),
            const SizedBox(height: 6),
            Text('Откройте чип “Вид спорта” и укажите спорт для загрузки школ.',
                style: _CatalogText.muted(11)),
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
            Text('Ничего не найдено',
                style: _CatalogText.title(15)),
            const SizedBox(height: 6),
            Text('Попробуйте изменить запрос',
                style: _CatalogText.muted(11)),
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
  static const soft = Color(0xFFF7F8F7);
  static const soft2 = Color(0xFFF2F4F2);
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF5F6670);
  static const line = Color(0xFFE9ECEA);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
  static const greenBorder = Color(0xFFD7F0E2);
}

class _CatalogText {
  static TextStyle title(double size) {
    if (size >= 16) {
      return AppTypography.screenTitle(color: _CatalogColors.text);
    }
    if (size >= 14.2) {
      return AppTypography.sectionTitle(color: _CatalogColors.text);
    }
    if (size >= 13.35) {
      return AppTypography.subsectionTitle(color: _CatalogColors.text);
    }
    if (size >= 12.7) {
      return AppTypography.itemTitle(color: _CatalogColors.text);
    }
    return AppTypography.menuTitle(color: _CatalogColors.text);
  }

  static TextStyle section() =>
      AppTypography.menuTitle(color: _CatalogColors.text);

  static TextStyle muted(double size) {
    if (size >= 11.5) {
      return AppTypography.secondary(color: _CatalogColors.muted);
    }
    if (size >= 10.3) {
      return AppTypography.caption(color: _CatalogColors.muted);
    }
    return AppTypography.commentMeta(color: _CatalogColors.muted);
  }

  static TextStyle action({Color color = _CatalogColors.text}) =>
      AppTypography.action(color: color);
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
    this.onClose,
    this.actions = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Container(
      height: compact ? 54 : 58,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
      color: Colors.white,
      child: Row(
        children: [
          const _CatalogDotCluster(),
          const SizedBox(width: 8),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _CatalogColors.soft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: _CatalogColors.greenDark, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CatalogText.title(compact ? 14.5 : 15.2)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CatalogText.muted(compact ? 10.1 : 10.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ...actions.expand((action) => [action, const SizedBox(width: 5)]),
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


class _CatalogPaneLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;

  const _CatalogPaneLabel({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          const _CatalogDotCluster(),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _CatalogText.title(13.5)),
                const SizedBox(height: 2),
                Text('$subtitle · $count', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CatalogText.muted(10.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogDotCluster extends StatelessWidget {
  const _CatalogDotCluster();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 25,
      height: 18,
      child: Stack(
        children: const [
          Positioned(left: 0, top: 5, child: _CatalogGlowDot(size: 8)),
          Positioned(left: 9, top: 1, child: _CatalogGlowDot(size: 5, faint: true)),
          Positioned(left: 15, top: 10, child: _CatalogGlowDot(size: 4, faint: true)),
        ],
      ),
    );
  }
}

class _CatalogGlowDot extends StatelessWidget {
  final double size;
  final bool faint;
  const _CatalogGlowDot({this.size = 7, this.faint = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CatalogColors.green.withOpacity(faint ? .32 : 1),
        shape: BoxShape.circle,
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
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 15, color: active ? _CatalogColors.greenDark : _CatalogColors.muted),
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

  const _CatalogEmptyDetail({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _CatalogDotCluster(),
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: _CatalogColors.soft, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: _CatalogColors.greenDark, size: 18),
            ),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: _CatalogText.title(13.8)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: _CatalogText.muted(10.5)),
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
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _CatalogColors.greenSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: image.trim().isEmpty
              ? Icon(icon, color: _CatalogColors.green, size: 20)
              : Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(icon, color: _CatalogColors.green, size: 20),
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
                style: AppTypography.menuGroup(color: _CatalogColors.greenDark),
              ),
              const SizedBox(height: 6),
              Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: _CatalogText.title(16.5)),
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
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 3),
      decoration: BoxDecoration(
        color: _CatalogColors.soft,
        borderRadius: BorderRadius.circular(10),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CatalogColors.greenSoft,
        borderRadius: BorderRadius.circular(10),
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
          height: 40,
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

// ===================== MATTE UI ATOMS (локальная копия) =====================

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
        borderRadius: BorderRadius.circular(9),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
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
        color: _CatalogColors.greenSoft,
        borderRadius: borderRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: logo.isNotEmpty
          ? Image.network(
              logo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(fallbackIcon, color: _CatalogColors.green),
            )
          : Icon(fallbackIcon, color: _CatalogColors.green),
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
