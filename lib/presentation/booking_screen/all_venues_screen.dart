import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/booking_screen/venue_detail_screen.dart';

class AllVenuesScreen extends StatefulWidget {
  const AllVenuesScreen({super.key});

  @override
  State<AllVenuesScreen> createState() => _AllVenuesScreenState();
}

class _AllVenuesScreenState extends State<AllVenuesScreen> {
  String selectedSport = 'Все';
  late Future<List<Map<String, dynamic>>> _futureVenues;

  final List<String> sports = const <String>[
    'Все',
    'Футбол',
    'Баскетбол',
    'Волейбол',
    'Теннис',
    'Хоккей',
  ];

  @override
  void initState() {
    super.initState();
    _futureVenues = _fetchVenues();
  }

  TextStyle _t(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = _BookingUi.text,
    double height = 1.25,
  }) {
    final TextStyle base;

    if (size >= 14.0) {
      base = AppTypography.screenTitle(color: color);
    } else if (size >= 12.3) {
      base = AppTypography.subsectionTitle(color: color);
    } else if (size >= 11.3) {
      base = AppTypography.itemTitle(color: color);
    } else if (size >= 10.1) {
      base = AppTypography.body(color: color);
    } else if (size >= 9.5) {
      base = AppTypography.secondary(color: color);
    } else if (size >= 9.0) {
      base = AppTypography.caption(color: color);
    } else {
      base = AppTypography.menuGroup(color: color);
    }

    return base.copyWith(
      fontWeight: weight,
      color: color,
    );
  }

  Widget _dot(
    Color color, {
    double size = 5,
  }) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );

  Widget _brandDots({
    Color color = _BookingUi.green,
  }) {
    const values = <List<double>>[
      <double>[3.5, .34],
      <double>[4.5, .48],
      <double>[5.5, .68],
      <double>[6.5, 1],
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int i = 0; i < values.length; i++) ...<Widget>[
          Container(
            width: values[i][0],
            height: values[i][0],
            decoration: BoxDecoration(
              color: color.withOpacity(values[i][1]),
              shape: BoxShape.circle,
            ),
          ),
          if (i != values.length - 1)
            const SizedBox(width: 3),
        ],
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchVenues() async {
    final uri = Uri.parse(
      'https://sportotekaapp.ru/api/get_venues.php'
      '${selectedSport != 'Все' ? '?sport=$selectedSport' : ''}',
    );

    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);

      if (data is Map && data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(
          (data['venues'] as List?) ?? const <dynamic>[],
        );
      }

      if (data is Map && data['venues'] is List) {
        return List<Map<String, dynamic>>.from(
          data['venues'] as List,
        );
      }
    }

    return <Map<String, dynamic>>[];
  }

  void _onSportChanged(String sport) {
    setState(() {
      selectedSport = sport;
      _futureVenues = _fetchVenues();
    });
  }

  String _image(Map<String, dynamic> venue) {
    final raw = '${venue['image_path'] ?? venue['image_url'] ?? ''}'.trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final clean = raw.startsWith('/') ? raw.substring(1) : raw;
    return 'https://sportotekaapp.ru/$clean';
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(
          fontFamily: AppTypography.fontFamily,
          bodyColor: _BookingUi.text,
          displayColor: _BookingUi.text,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _header(),
              const Divider(
                height: 1,
                thickness: .6,
                color: _BookingUi.line,
              ),
              _filters(),
              const Divider(
                height: 1,
                thickness: .6,
                color: _BookingUi.line,
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _futureVenues,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _BookingUi.green,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _state(
                        color: _BookingUi.red,
                        title: 'Ошибка загрузки',
                        text: 'Не удалось получить список площадок.',
                      );
                    }

                    final venues =
                        snapshot.data ?? const <Map<String, dynamic>>[];

                    if (venues.isEmpty) {
                      return _state(
                        color: _BookingUi.amber,
                        title: 'Площадок нет',
                        text: 'Для выбранного вида спорта ничего не найдено.',
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final maxExtent =
                            constraints.maxWidth >= 900 ? 350.0 : 320.0;

                        return GridView.builder(
                          padding: const EdgeInsets.all(14),
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: maxExtent,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.13,
                          ),
                          itemCount: venues.length,
                          itemBuilder: (_, index) =>
                              _venueCard(venues[index]),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      child: Row(
        children: <Widget>[
          Material(
            color: _BookingUi.soft,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(9),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: _BookingUi.text,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _brandDots(),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Все площадки',
                  style: _t(
                    14.5,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Каталог спортивных объектов',
                  style: _t(
                    9.6,
                    color: _BookingUi.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 7,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: sports.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (_, index) {
          final sport = sports[index];
          final selected = sport == selectedSport;

          return Material(
            color: selected
                ? _BookingUi.greenSoft
                : _BookingUi.soft,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => _onSportChanged(sport),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
                child: Row(
                  children: <Widget>[
                    _dot(
                      selected
                          ? _BookingUi.green
                          : _BookingUi.muted2,
                      size: selected ? 5 : 4,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sport,
                      style: _t(
                        9.5,
                        weight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? _BookingUi.greenDark
                            : _BookingUi.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _venueCard(Map<String, dynamic> venue) {
    final title = '${venue['title'] ?? 'Площадка'}';
    final address = '${venue['address'] ?? ''}'.trim();
    final category = '${venue['category'] ?? ''}'.trim();
    final conditions = '${venue['conditions'] ?? ''}'.trim();
    final image = _image(venue);

    return Material(
      color: _BookingUi.soft,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => VenueDetailScreen(
                venue: venue,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 11,
              child: image.isEmpty
                  ? _imagePlaceholder()
                  : Image.network(
                      image,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _imagePlaceholder(),
                    ),
            ),
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _dot(
                          _BookingUi.green,
                          size: 5,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            category.isEmpty
                                ? 'Спортивная площадка'
                                : category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _t(
                              8.9,
                              weight: FontWeight.w600,
                              color: _BookingUi.greenDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _t(
                        11.6,
                        weight: FontWeight.w600,
                      ),
                    ),
                    if (address.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(
                          9.1,
                          color: _BookingUi.muted,
                        ),
                      ),
                    ],
                    if (conditions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        conditions,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(
                          8.9,
                          color: _BookingUi.muted2,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: <Widget>[
                        _brandDots(
                          color: _BookingUi.greenDark,
                        ),
                        const Spacer(),
                        Text(
                          'Подробнее',
                          style: _t(
                            9.2,
                            weight: FontWeight.w600,
                            color: _BookingUi.greenDark,
                          ),
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

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF0F4F1),
      alignment: Alignment.center,
      child: _brandDots(
        color: _BookingUi.greenDark,
      ),
    );
  }

  Widget _state({
    required Color color,
    required String title,
    required String text,
  }) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _BookingUi.soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _dot(
              color,
              size: 7,
            ),
            const SizedBox(height: 9),
            Text(
              title,
              style: _t(
                11.8,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              style: _t(
                9.5,
                color: _BookingUi.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _BookingUi {
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFF7E8);
  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFFF1F1);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF667085);
  static const Color muted2 = Color(0xFF98A2B3);
  static const Color soft = Color(0xFFF7F9F8);
  static const Color line = Color(0xFFEEF1EF);
}
