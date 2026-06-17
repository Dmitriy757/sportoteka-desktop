import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF3F5F8); // матовый светлый фон

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Сообщество',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
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
                  Text(
                    'ВЫБЕРИТЕ ВИД СПОРТА',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.4),
                      letterSpacing: 1.2,
                    ),
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
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
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
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => _toggleCategory(key),
                      showCheckmark: false,
                      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                      side: BorderSide(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
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
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          'Ничего не найдено',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SportCommunityScreen(sportName: sport['name'] as String),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (sport['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.2,
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
