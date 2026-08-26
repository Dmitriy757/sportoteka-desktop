import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'sport_community_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  // --- Категории для фильтров
  static const Map<String, String> kCategoryLabels = {
    'winter': 'Зимние',
    'combat': 'Единоборства',
    'team': 'Командные',
    'individual': 'Индивидуальные',
    'water': 'Водные/циклические',
    'para': 'Паралимпийские',
    'esports': 'Киберспорт',
  };

  // --- Источник данных: добавлены категории и новые виды спорта
  static const List<Map<String, dynamic>> _sports = [
    // Топ популярные (разнесены по категориям)
    {'name': 'Футбол', 'icon': Icons.sports_soccer, 'color': Colors.blue, 'cat': 'team'},
    {'name': 'Хоккей', 'icon': Icons.sports_hockey, 'color': Colors.indigo, 'cat': 'team'},
    {'name': 'Баскетбол', 'icon': Icons.sports_basketball, 'color': Colors.orange, 'cat': 'team'},
    {'name': 'Волейбол', 'icon': Icons.sports_volleyball, 'color': Colors.red, 'cat': 'team'},
    {'name': 'Теннис', 'icon': Icons.sports_tennis, 'color': Colors.green, 'cat': 'individual'},
    {'name': 'Плавание', 'icon': Icons.pool, 'color': Colors.teal, 'cat': 'water'},
    {'name': 'Лёгкая атлетика', 'icon': Icons.run_circle, 'color': Colors.purple, 'cat': 'individual'},

    // Зимние
    {'name': 'Фигурное катание', 'icon': Icons.ac_unit, 'color': Colors.lightBlue, 'cat': 'winter'},
    {'name': 'Биатлон', 'icon': Icons.downhill_skiing, 'color': Colors.cyan, 'cat': 'winter'},
    {'name': 'Лыжные гонки', 'icon': Icons.downhill_skiing, 'color': Colors.blueGrey, 'cat': 'winter'},
    {'name': 'Сноуборд', 'icon': Icons.snowboarding, 'color': Colors.lightBlueAccent, 'cat': 'winter'},

    // Единоборства
    {'name': 'Бокс', 'icon': Icons.sports_mma, 'color': Colors.brown, 'cat': 'combat'},
    {'name': 'ММА', 'icon': Icons.sports_mma, 'color': Colors.deepOrange, 'cat': 'combat'},
    {'name': 'Самбо', 'icon': Icons.sports_kabaddi, 'color': Colors.redAccent, 'cat': 'combat'},
    {'name': 'Дзюдо', 'icon': Icons.sports_kabaddi, 'color': Colors.indigoAccent, 'cat': 'combat'},
    {'name': 'Борьба', 'icon': Icons.sports_kabaddi, 'color': Colors.deepPurple, 'cat': 'combat'},
    {'name': 'Каратэ', 'icon': Icons.sports_kabaddi, 'color': Colors.orangeAccent, 'cat': 'combat'},
    {'name': 'Тхэквондо', 'icon': Icons.sports_kabaddi, 'color': Colors.teal, 'cat': 'combat'},

    // Командные/игровые
    {'name': 'Регби', 'icon': Icons.sports_rugby, 'color': Colors.blueGrey, 'cat': 'team'},
    {'name': 'Гандбол', 'icon': Icons.sports_handball, 'color': Colors.pink, 'cat': 'team'},
    {'name': 'Крикет', 'icon': Icons.sports_cricket, 'color': Colors.amber, 'cat': 'team'},
    {'name': 'Бадминтон', 'icon': Icons.sports_tennis, 'color': Colors.lightGreen, 'cat': 'individual'},
    {'name': 'Настольный теннис', 'icon': Icons.sports_tennis, 'color': Colors.greenAccent, 'cat': 'individual'},

    // Индивидуальные/технические
    {'name': 'Гольф', 'icon': Icons.sports_golf, 'color': Colors.lightGreen, 'cat': 'individual'},
    // Фехтование — точной иконки нет, используем «шлем» (mma) как заглушку/позже можно заменить на кастом
    {'name': 'Фехтование', 'icon': Icons.sports_mma, 'color': Colors.cyan, 'cat': 'individual'},
    {'name': 'Гимнастика', 'icon': Icons.accessibility, 'color': Colors.deepPurple, 'cat': 'individual'},
    {'name': 'Тяжёлая атлетика', 'icon': Icons.fitness_center, 'color': Colors.blueGrey, 'cat': 'individual'},
    {'name': 'Киберспорт', 'icon': Icons.sports_esports, 'color': Colors.grey, 'cat': 'esports'},
    {'name': 'Шахматы', 'icon': Icons.sports_esports, 'color': Colors.grey, 'cat': 'individual'},

    // Циклические и водные
    {'name': 'Велоспорт', 'icon': Icons.pedal_bike, 'color': Colors.blueAccent, 'cat': 'water'},
    {'name': 'Гребля', 'icon': Icons.kayaking, 'color': Colors.teal, 'cat': 'water'},
    {'name': 'Каноэ-каяк', 'icon': Icons.kayaking, 'color': Colors.cyanAccent, 'cat': 'water'},
    {'name': 'Парусный спорт', 'icon': Icons.sailing, 'color': Colors.indigoAccent, 'cat': 'water'},

    // Паралимпийские (примерные дисциплины)
    {'name': 'Паралимпийская лёгкая атлетика', 'icon': Icons.accessible_forward, 'color': Colors.blue, 'cat': 'para'},
    {'name': 'Сидячий волейбол', 'icon': Icons.sports_volleyball, 'color': Colors.orange, 'cat': 'para'},
    {'name': 'Параплавание', 'icon': Icons.pool, 'color': Colors.teal, 'cat': 'para'},
  ];

  // --- Состояние фильтров/поиска/сортировки
  final Set<String> _selectedCats = {}; // ключи из kCategoryLabels
  String _query = '';
  String _sort = 'pop'; // 'pop' (по умолчанию) | 'az'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    // 1) фильтр по категориям (если выбрано хоть что-то)
    Iterable<Map<String, dynamic>> list = _sports;
    if (_selectedCats.isNotEmpty) {
      list = list.where((s) => _selectedCats.contains(s['cat']));
    }

    // 2) поиск по названию
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((s) => (s['name'] as String).toLowerCase().contains(q));
    }

    // 3) сортировка
    final result = list.toList();
    if (_sort == 'az') {
      result.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    } else {
      // 'pop' — оставляем «как задано» (ручной порядок как «популярный»)
    }

    return result;
  }

  void _toggleCategory(String key) {
    setState(() {
      if (_selectedCats.contains(key)) {
        _selectedCats.remove(key);
      } else {
        _selectedCats.add(key);
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedCats.clear();
      _query = '';
      _searchCtrl.clear();
      _sort = 'pop';
    });
  }

  TextStyle _title(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = const Color(0xFF0B0F14),
  }) {
    final TextStyle base;
    if (size >= 15.5) {
      base = AppTypography.screenTitle(color: color);
    } else if (size >= 14) {
      base = AppTypography.sectionTitle(color: color);
    } else if (size >= 13) {
      base = AppTypography.subsectionTitle(color: color);
    } else {
      base = AppTypography.menuTitle(color: color);
    }
    return base.copyWith(fontWeight: weight);
  }

  TextStyle _text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = const Color(0xFF5F6670),
  }) {
    final TextStyle base;
    if (size >= 12.2) {
      base = AppTypography.body(color: color);
    } else if (size >= 11.2) {
      base = AppTypography.secondary(color: color);
    } else if (size >= 10) {
      base = AppTypography.caption(color: color);
    } else {
      base = AppTypography.commentMeta(color: color);
    }
    return base.copyWith(fontWeight: weight);
  }

  Widget _brandDots({Color color = const Color(0xFF00A750)}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final item in const <(double, double)>[
          (3.5, .34),
          (4.5, .48),
          (5.5, .68),
          (6.5, 1.0),
        ]) ...[
          Container(
            width: item.$1,
            height: item.$1,
            decoration: BoxDecoration(
              color: color.withOpacity(item.$2),
              shape: BoxShape.circle,
              boxShadow: item.$2 >= .9
                  ? [
                      BoxShadow(
                        color: color.withOpacity(.16),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 3),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _brandDots(),
            const SizedBox(width: 9),
            Text(
              'Сообщество',
              style: _title(16),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Сортировка',
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'pop', child: Text('По популярности')),
              PopupMenuItem(value: 'az', child: Text('А → Я')),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Заголовок
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _brandDots(color: const Color(0xFF067A46)),
                      const SizedBox(width: 8),
                      Text(
                        'Виды спорта',
                        style: _title(12.4),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Сбросить'),
                  ),
                ],
              ),
            ),
          ),

          // Поиск
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Поиск по видам спорта',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF7F9F8),
                  hintStyle: _text(11.2, color: const Color(0xFF98A2B3)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          // Фильтры (горизонтальные chips)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kCategoryLabels.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final key = kCategoryLabels.keys.elementAt(i);
                    final label = kCategoryLabels[key]!;
                    final selected = _selectedCats.contains(key);

                    return FilterChip(
                      label: Text(
                        label,
                        style: _text(
                          10.2,
                          weight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected
                              ? const Color(0xFF067A46)
                              : const Color(0xFF5F6670),
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) => _toggleCategory(key),
                      showCheckmark: false,
                      selectedColor: const Color(0xFFF3FAF6),
                      backgroundColor: const Color(0xFFF7F9F8),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Сетка карточек
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _filtered.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          'Ничего не найдено',
                          style: AppTypography.screenTitle(),
                        ),
                      ),
                    ),
                  )
                : SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final sport = _filtered[index];
                        return _buildSportCard(context, sport);
                      },
                      childCount: _filtered.length,
                    ),
                  ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildSportCard(BuildContext context, Map<String, dynamic> sport) {
    return Material(
      color: const Color(0xFFF7F9F8),
      borderRadius: BorderRadius.circular(10),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SportCommunityScreen(sportName: sport['name'] as String),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (sport['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  sport['icon'] as IconData,
                  size: 28,
                  color: sport['color'] as Color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                sport['name'] as String,
                textAlign: TextAlign.center,
                style: _title(12.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Бейдж категории
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  kCategoryLabels[sport['cat']] ?? 'Другое',
                  style: _text(
                    9.6,
                    weight: FontWeight.w500,
                    color: const Color(0xFF667085),
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
