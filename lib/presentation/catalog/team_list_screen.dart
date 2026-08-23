// lib/presentation/catalog/team_list_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/team_screen/team_detail_screen.dart';

const String apiBaseUrl = 'https://sportotekaapp.ru/api/';

enum TeamCatalogView { list, grid, map }

class TeamListScreen extends StatefulWidget {
  final String? initialSport;
  final bool embedded;
  final VoidCallback? onClose;

  const TeamListScreen({
    super.key,
    this.initialSport,
    this.embedded = false,
    this.onClose,
  });

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
  String _selectedTeamKey = '';

  // --- Map
  GoogleMapController? _mapCtrl;
  final CameraPosition _initialCamera = const CameraPosition(
    target: LatLng(53.9, 27.56), // Минск по умолчанию
    zoom: 11,
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialSport != null && widget.initialSport!.trim().isNotEmpty) {
      _sport = widget.initialSport!.trim();
    }
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
        _syncSelectedTeam(data);
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

  String _teamKey(Map<String, dynamic> team) {
    final id = (team['id'] ?? team['team_id'] ?? '').toString().trim();
    if (id.isNotEmpty) return id;
    return '${team['name'] ?? ''}|${team['city'] ?? ''}';
  }

  void _syncSelectedTeam(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      _selectedTeamKey = '';
      return;
    }
    if (!items.any((team) => _teamKey(team) == _selectedTeamKey)) {
      _selectedTeamKey = _teamKey(items.first);
    }
  }

  Map<String, dynamic>? get _selectedTeam {
    for (final team in _items) {
      if (_teamKey(team) == _selectedTeamKey) return team;
    }
    return _items.isEmpty ? null : _items.first;
  }

  void _selectTeam(Map<String, dynamic> team, {required bool compact}) {
    if (compact) {
      _openDetails(team);
      return;
    }
    setState(() => _selectedTeamKey = _teamKey(team));
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final inMap = _view == TeamCatalogView.map;

    void toggleMap() {
      setState(() {
        _view = inMap ? TeamCatalogView.list : TeamCatalogView.map;
        if (!inMap) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitAllMarkers());
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final paneWidth = math.min(372.0, math.max(316.0, constraints.maxWidth * .34));
        final canClose = widget.onClose != null || Navigator.of(context).canPop();
        final listPane = _buildListPane(compact: compact);

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
                  _EmbeddedCatalogHeader(
                    icon: Icons.shield_rounded,
                    title: 'Клубы и команды',
                    subtitle: '${_items.length} команд · каталог и составы',
                    onClose: canClose
                        ? (widget.onClose ?? () => Navigator.of(context).maybePop())
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
                                    : _teamDetailPane(_selectedTeam),
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

  Widget _buildListPane({required bool compact}) {
    return RefreshIndicator(
      color: _CatalogColors.green,
      onRefresh: _loadFirst,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _CatalogPaneLabel(title: 'Команды', subtitle: 'Выберите команду', count: _items.length)),
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

  Widget _teamDetailPane(Map<String, dynamic>? team) {
    if (team == null) {
      return const _CatalogEmptyDetail(
        icon: Icons.shield_outlined,
        title: 'Выберите команду',
        subtitle: 'Карточка клуба появится в правом блоке.',
      );
    }

    final name = (team['name'] ?? 'Клуб').toString();
    final sport = _readTeamSport(team);
    final region = (team['region'] ?? '').toString();
    final city = (team['city'] ?? '').toString();
    final address = (team['address'] ?? '').toString();
    final description =
        (team['description'] ?? team['about'] ?? team['bio'] ?? '').toString();
    final logo = _normalizeMediaUrl((team['logo'] ?? '').toString());
    final players = (team['players_count'] ?? team['players'] ?? '—').toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        _CatalogDetailHero(
          image: logo,
          icon: Icons.shield_rounded,
          eyebrow: sport.isEmpty ? 'СПОРТИВНЫЙ КЛУБ' : sport.toUpperCase(),
          title: name,
          subtitle: [city, region].where((value) => value.trim().isNotEmpty).join(', ').isEmpty
              ? 'Местоположение не указано'
              : [city, region].where((value) => value.trim().isNotEmpty).join(', '),
        ),
        const SizedBox(height: 12),
        _CatalogMetrics(
          items: [
            _CatalogMetricData(
              icon: Icons.groups_2_rounded,
              value: players,
              label: 'Игроки',
            ),
            _CatalogMetricData(
              icon: Icons.sports_soccer_rounded,
              value: sport.isEmpty ? '—' : sport,
              label: 'Спорт',
            ),
            _CatalogMetricData(
              icon: Icons.location_city_rounded,
              value: city.isEmpty ? '—' : city,
              label: 'Город',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CatalogInfoSection(
          title: 'Данные клуба',
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
          title: 'О клубе',
          text: description.trim().isEmpty
              ? 'Описание клуба пока не заполнено.'
              : description,
        ),
        const SizedBox(height: 12),
        _CatalogPrimaryButton(
          title: 'Открыть полный профиль',
          icon: Icons.arrow_forward_rounded,
          onTap: () => _openDetails(team),
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
                      hintText: 'Поиск по названию клуба',
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
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      sliver: SliverList.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 1),
        itemBuilder: (_, i) => _teamTile(_items[i], compact: compact),
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
  Widget _teamTile(Map<String, dynamic> t, {bool compact = true}) {
    final name = (t['name'] ?? 'Клуб').toString();
    final sport = _readTeamSport(t);
    final region = (t['region'] ?? '').toString();
    final city = (t['city'] ?? '').toString();
    final logo = _normalizeMediaUrl((t['logo'] ?? '').toString());
    final active = _teamKey(t) == _selectedTeamKey;

    return _MatteSurface(
      selected: active,
      onTap: () => _selectTeam(t, compact: compact),
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
            fallbackIcon: Icons.shield_rounded,
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
                    if (city.trim().isNotEmpty) city,
                    if (region.trim().isNotEmpty) region,
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
            style: _CatalogText.title(13.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            [city, region].where((e) => e.trim().isNotEmpty).join(', '),
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
                  ? Text('Прокрутите вниз, чтобы загрузить ещё', style: _CatalogText.muted(10.5))
                  : Text('Больше результатов нет', style: _CatalogText.muted(10.5)),
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
            Text('Ничего не найдено', style: _CatalogText.title(15)),
            const SizedBox(height: 6),
            Text('Попробуйте изменить фильтры или запрос', style: _CatalogText.muted(11)),
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
            Text('Ошибка загрузки', style: _CatalogText.title(15)),
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
                style: AppTypography.custom(
                  size: 9,
                  weight: FontWeight.w600,
                  color: _CatalogColors.greenDark,
                  height: 1.1,
                  letterSpacing: .35,
                ),
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
          Expanded(
            child: Text(value, textAlign: TextAlign.right, style: _CatalogText.title(11.2)),
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
