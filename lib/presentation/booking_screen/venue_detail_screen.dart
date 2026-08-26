import 'package:flutter/material.dart';

import 'package:sportoteka/core/theme/app_typography.dart';

class VenueDetailScreen extends StatelessWidget {
  final Map<String, dynamic> venue;

  const VenueDetailScreen({
    super.key,
    required this.venue,
  });

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

  String _text(dynamic value) {
    final result = '${value ?? ''}'.trim();
    return result.toLowerCase() == 'null' ? '' : result;
  }

  String _image() {
    final raw = _text(
      venue['image_url'] ??
          venue['image_path'] ??
          venue['image'],
    );

    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final clean = raw.startsWith('/') ? raw.substring(1) : raw;
    return 'https://sportotekaapp.ru/$clean';
  }

  @override
  Widget build(BuildContext context) {
    final title = _text(venue['title']).isEmpty
        ? 'Площадка'
        : _text(venue['title']);
    final image = _image();
    final address = _text(venue['address']);
    final category = _text(venue['category']);
    final conditions = _text(venue['conditions']);
    final description = _text(venue['description']);

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
              _header(context, title),
              const Divider(
                height: 1,
                thickness: .6,
                color: _BookingUi.line,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: <Widget>[
                    if (image.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AspectRatio(
                          aspectRatio: 16 / 8.5,
                          child: Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _imagePlaceholder(),
                          ),
                        ),
                      )
                    else
                      AspectRatio(
                        aspectRatio: 16 / 8.5,
                        child: _imagePlaceholder(),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: _BookingUi.soft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              _dot(
                                _BookingUi.green,
                                size: 6,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title,
                                  style: _t(
                                    14.2,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (address.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 10),
                            _row(
                              'Адрес',
                              address,
                              _BookingUi.greenDark,
                            ),
                          ],
                          if (category.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 7),
                            _row(
                              'Категория',
                              category,
                              _BookingUi.amber,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (conditions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      _textBlock(
                        'Условия бронирования',
                        conditions,
                        _BookingUi.greenDark,
                      ),
                    ],
                    if (description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      _textBlock(
                        'Описание',
                        description,
                        _BookingUi.green,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    String title,
  ) {
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
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t(
                14.2,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: _dot(
            color,
            size: 4.5,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: _t(
                9.8,
                color: _BookingUi.muted,
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: '$label: ',
                  style: _t(
                    9.8,
                    weight: FontWeight.w600,
                    color: _BookingUi.text,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _textBlock(
    String title,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _BookingUi.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _dot(
                color,
                size: 5,
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: _t(
                  10.8,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: _t(
              10,
              color: _BookingUi.muted,
              height: 1.4,
            ),
          ),
        ],
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
