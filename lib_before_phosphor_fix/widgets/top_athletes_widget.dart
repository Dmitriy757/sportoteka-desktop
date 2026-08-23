// lib/widgets/top_athletes_widget.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class TopAthletesWidget extends StatefulWidget {
  final String apiUrl; // e.g. https://example.com/api/get_athletes.php
  const TopAthletesWidget({super.key, required this.apiUrl});

  @override
  State<TopAthletesWidget> createState() => _TopAthletesWidgetState();
}

class _TopAthletesWidgetState extends State<TopAthletesWidget> {
  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> football = [];
  List<Map<String, dynamic>> hockey = [];

  @override
  void initState() {
    super.initState();
    _loadWithRetry();
  }

  // --- helpers: анти-дубль ---
  String _normName(Object? x) =>
      (x ?? '').toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  List<Map<String, dynamic>> _dedupAthletes(List<Map<String, dynamic>> list) {
    final byId = <String, Map<String, dynamic>>{};
    final byName = <String, Map<String, dynamic>>{};

    for (final e in list) {
      final id = (e['id'] ?? '').toString();
      final nameKey = _normName(e['name']);
      if (id.isNotEmpty) {
        byId.putIfAbsent(id, () => e);
      } else if (nameKey.isNotEmpty) {
        byName.putIfAbsent(nameKey, () => e);
      }
    }

    final out = <Map<String, dynamic>>[];
    out.addAll(byId.values);
    // Добавляем тех, у кого нет id, но уникальное имя
    for (final entry in byName.entries) {
      final id = (entry.value['id'] ?? '').toString();
      if (id.isEmpty || !byId.containsKey(id)) out.add(entry.value);
    }

    // Сортировка: по pop_score (убывающе), потом по имени
    out.sort((a, b) {
      final pa = (a['pop_score'] is int) ? a['pop_score'] as int : int.tryParse('${a['pop_score'] ?? 0}') ?? 0;
      final pb = (b['pop_score'] is int) ? b['pop_score'] as int : int.tryParse('${b['pop_score'] ?? 0}') ?? 0;
      if (pa != pb) return pb.compareTo(pa);
      return _normName(a['name']).compareTo(_normName(b['name']));
    });

    return out;
  }

  Future<void> _loadWithRetry() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ));

    int attempts = 0;
    while (attempts < 2) {
      attempts++;
      try {
        final resp = await dio.get(widget.apiUrl, options: Options(responseType: ResponseType.json));
        if (resp.statusCode != 200) {
          throw DioException(
            requestOptions: resp.requestOptions,
            response: resp,
            error: 'HTTP ${resp.statusCode}',
            type: DioExceptionType.badResponse,
          );
        }

        final data = (resp.data as Map).cast<String, dynamic>();
        final fb = ((data['football'] as List?) ?? []).cast<Map<String, dynamic>>();
        final hk = ((data['hockey'] as List?) ?? []).cast<Map<String, dynamic>>();

        setState(() {
          football = _dedupAthletes(fb);
          hockey = _dedupAthletes(hk);
          isLoading = false;
        });
        debugPrint('✅ TopAthletes loaded: fb=${football.length}, hk=${hockey.length}');
        return;
      } catch (e, st) {
        debugPrint('❌ TopAthletes load error (try $attempts): $e');
        debugPrint('$st');
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }

    // офлайн-фоллбек
    setState(() {
      isLoading = false;
      error = 'Не удалось загрузить топ спортсменов — показаны офлайн данные';
      football = [
        {
          'id': 'Q204756',
          'name': 'Александр Глеб',
          'sport': 'Футбол',
          'position': 'Полузащитник',
          'club': 'ex Arsenal, Barcelona',
          'image': 'https://upload.wikimedia.org/wikipedia/commons/1/1d/Aliaksandr_Hleb_2012.jpg',
          'wiki_url':
              'https://ru.wikipedia.org/wiki/%D0%93%D0%BB%D0%B5%D0%B1,_%D0%90%D0%BB%D0%B5%D0%BA%D1%81%D0%B0%D0%BD%D0%B4%D1%80_%D0%A1%D1%8F%D1%80%D0%B3%D0%B5%D0%B5%D0%B2%D0%B8%D1%87',
          'pop_score': 100,
        },
      ];
      hockey = [
        {
          'id': 'Q1964470',
          'name': 'Алексей Калюжный',
          'sport': 'Хоккей',
          'position': 'Центр',
          'club': 'Сборная Беларуси (ex)',
          'image': 'https://upload.wikimedia.org/wikipedia/commons/0/09/Alexei_Kalyuzhny_2011-12-02.jpg',
          'wiki_url':
              'https://ru.wikipedia.org/wiki/%D0%9A%D0%B0%D0%BB%D1%8E%D0%B6%D0%BD%D1%8B%D0%B9,_%D0%90%D0%BB%D0%B5%D0%BA%D1%81%D0%B5%D0%B9_%D0%9D%D0%B8%D0%BA%D0%BE%D0%BB%D0%B0%D0%B5%D0%B2%D0%B8%D1%87',
          'pop_score': 100,
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(error!, style: const TextStyle(color: Colors.orange))),
                TextButton(onPressed: _loadWithRetry, child: const Text('Повторить')),
              ],
            ),
          ),

        _sectionTitle('Топ футболисты Беларуси', onSeeAll: football.isNotEmpty ? () {} : null),
        const SizedBox(height: 8),
        _cardsScroller(football),

     
      ],
    );
  }

  Widget _sectionTitle(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (onSeeAll != null)
            TextButton.icon(
              onPressed: onSeeAll,
              icon: const Icon(Icons.arrow_outward, size: 18),
              label: const Text('Открыть'),
            ),
        ],
      ),
    );
  }

  Widget _cardsScroller(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const SizedBox(height: 160, child: Center(child: Text('Нет данных')));
    }
    return SizedBox(
      height: 260,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _athleteCard(items[i]),
      ),
    );
  }

  Widget _athleteCard(Map<String, dynamic> a) {
    final name = (a['name'] ?? '') as String;
    final pos = a['position'] as String?;
    final club = a['club'] as String?;
    final img = a['image'] as String?;
    final url = a['wiki_url'] as String?;
    final tag = (a['sport'] ?? '') as String;

    return GestureDetector(
      onTap: () async {
        if (url != null && url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06182A), Color(0xFF0B2E6B)], // FIFA-like dark bg
          ),
          boxShadow: const [
            BoxShadow(blurRadius: 24, offset: Offset(0, 12), color: Color(0x33061A2E)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Фото
              Positioned.fill(
                child: (img != null && img.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.black12),
                        errorWidget: (_, __, ___) => Container(color: Colors.black26),
                      )
                    : Container(color: Colors.black26),
              ),

              // Нижний затемняющий градиент
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, const Color(0xFF06182A).withOpacity(0.85)],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Диагональный блик
              Positioned(
                top: -60,
                right: -80,
                child: Transform.rotate(
                  angle: -0.7,
                  child: Container(
                    width: 220,
                    height: 160,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white.withOpacity(0.12), Colors.transparent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),

              // Контент
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // бейдж вида спорта
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF29D3FF).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (pos != null && pos.isNotEmpty)
                        Text(
                          pos,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      if (club != null && club.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          club,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
