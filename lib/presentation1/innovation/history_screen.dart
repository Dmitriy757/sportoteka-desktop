// lib/presentation/innovation/history_screen.dart
import 'package:flutter/material.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/data/innovation_api.dart';

class InnovationHistoryScreen extends StatefulWidget {
  const InnovationHistoryScreen({super.key});

  @override
  State<InnovationHistoryScreen> createState() => _InnovationHistoryScreenState();
}

class _InnovationHistoryScreenState extends State<InnovationHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _userId = 'guest';

  // списки
  List<Map<String, dynamic>> _ai = [];
  List<Map<String, dynamic>> _ar = [];
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _hm = [];

  // пагинация
  int _aiPage = 1, _arPage = 1, _plPage = 1, _hmPage = 1;
  bool _aiMore = true, _arMore = true, _plMore = true, _hmMore = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _init();
  }

  Future<void> _init() async {
    final uid = await PrefUtils.getUserId();
    setState(() => _userId = (uid?.toString().trim().isNotEmpty ?? false) ? uid.toString() : 'guest');
    await Future.wait([
      _loadAi(reset: true),
      _loadAr(reset: true),
      _loadPlans(reset: true),
      _loadHm(reset: true),
    ]);
  }

  Future<void> _loadAi({bool reset=false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (reset) { _aiPage = 1; _ai.clear(); _aiMore = true; }
      final r = await InnovationApi.listAiSessions(userId: _userId, page: _aiPage, pageSize: 20);
      final items = (r['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _ai.addAll(items);
        _aiMore = r['has_more'] == true;
        if (_aiMore) _aiPage++;
      });
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadAr({bool reset=false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (reset) { _arPage = 1; _ar.clear(); _arMore = true; }
      final r = await InnovationApi.listArOverlays(userId: _userId, page: _arPage, pageSize: 20);
      final items = (r['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _ar.addAll(items);
        _arMore = r['has_more'] == true;
        if (_arMore) _arPage++;
      });
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadPlans({bool reset=false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (reset) { _plPage = 1; _plans.clear(); _plMore = true; }
      final r = await InnovationApi.listTrainingPlans(userId: _userId, page: _plPage, pageSize: 20);
      final items = (r['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _plans.addAll(items);
        _plMore = r['has_more'] == true;
        if (_plMore) _plPage++;
      });
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadHm({bool reset=false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (reset) { _hmPage = 1; _hm.clear(); _hmMore = true; }
      final r = await InnovationApi.listHeatmapSessions(userId: _userId, page: _hmPage, pageSize: 20);
      final items = (r['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _hm.addAll(items);
        _hmMore = r['has_more'] == true;
        if (_hmMore) _hmPage++;
      });
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onBg = Theme.of(context).colorScheme.onBackground;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои инновации'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'AI'),
            Tab(text: 'AR'),
            Tab(text: 'Планы'),
            Tab(text: 'Heatmap'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildList(
            items: _ai,
            onRefresh: () => _loadAi(reset: true),
            onMore: _aiMore ? () => _loadAi() : null,
            itemBuilder: (it) => ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: Text('Старт: ${it['started_at'] ?? '-'}', style: TextStyle(color: onBg)),
              subtitle: Text('Повторы: ${it['reps'] ?? 0} • Длительность: ${it['duration_sec'] ?? 0}s'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openAiDetail(it),
            ),
          ),
          _buildList(
            items: _ar,
            onRefresh: () => _loadAr(reset: true),
            onMore: _arMore ? () => _loadAr() : null,
            itemBuilder: (it) => ListTile(
              leading: const Icon(Icons.brush_outlined),
              title: Text('Overlay: ${it['overlay_path'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('Создано: ${it['created_at'] ?? ''}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openArDetail(it),
            ),
          ),
          _buildList(
            items: _plans,
            onRefresh: () => _loadPlans(reset: true),
            onMore: _plMore ? () => _loadPlans() : null,
            itemBuilder: (it) => ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(it['goal'] ?? 'План', style: TextStyle(color: onBg)),
              subtitle: Text('Сессий/нед: ${it['sessions_per_week'] ?? '-'} • Недель: ${it['weeks'] ?? '-'}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openPlanDetail(it),
            ),
          ),
          _buildList(
            items: _hm,
            onRefresh: () => _loadHm(reset: true),
            onMore: _hmMore ? () => _loadHm() : null,
            itemBuilder: (it) => ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text('Старт: ${it['started_at'] ?? '-'}'),
              subtitle: Text('Дист: ${(it['distance_km'] ?? 0).toString()} км • Темп: ${it['pace'] ?? '--'}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openHmDetail(it),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList({
    required List<Map<String, dynamic>> items,
    required Future<void> Function() onRefresh,
    required Widget Function(Map<String, dynamic>) itemBuilder,
    VoidCallback? onMore,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length + (onMore != null ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (ctx, i) {
          if (onMore != null && i == items.length) {
            return Center(
              child: OutlinedButton.icon(
                onPressed: onMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Загрузить ещё'),
              ),
            );
          }
          final it = items[i];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: itemBuilder(it),
          );
        },
      ),
    );
  }

  // ---------- details ----------
  Future<void> _openAiDetail(Map<String, dynamic> item) async {
    final id = int.tryParse(item['id'].toString()) ?? 0;
    final data = await InnovationApi.getAiSession(id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final samples = (data['samples'] as List?) ?? const [];
        return _DetailSheet(
          title: 'AI сессия #$id',
          content: [
            'Старт: ${data['started_at'] ?? '-'}',
            'Длительность: ${data['duration_sec'] ?? 0}s',
            'Повторы: ${data['reps'] ?? 0}',
            'Замеров: ${samples.length}',
          ],
        );
      },
    );
  }

  Future<void> _openArDetail(Map<String, dynamic> item) async {
    final id = int.tryParse(item['id'].toString()) ?? 0;
    final data = await InnovationApi.getArOverlay(id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return _DetailSheet(
          title: 'AR Overlay #$id',
          content: [
            'Overlay: ${data['overlay_path'] ?? ''}',
            'Composite: ${data['composite_path'] ?? '-'}',
            'Заметки: ${data['notes'] ?? ''}',
            'Создано: ${data['created_at'] ?? ''}',
          ],
        );
      },
    );
  }

  Future<void> _openPlanDetail(Map<String, dynamic> item) async {
    final id = int.tryParse(item['id'].toString()) ?? 0;
    final data = await InnovationApi.getTrainingPlan(id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            controller: controller,
            children: [
              const SizedBox(height: 8),
              Text('План #$id', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Цель: ${data['goal']}'),
              Text('Сессий/нед: ${data['sessions_per_week']} • Недель: ${data['weeks']}'),
              const Divider(),
              Text(data['plan_text'] ?? ''),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openHmDetail(Map<String, dynamic> item) async {
    final id = int.tryParse(item['id'].toString()) ?? 0;
    final data = await InnovationApi.getHeatmapSession(id);
    if (!mounted) return;
    final zones = (data['zones'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _DetailSheet(
        title: 'Heatmap #$id',
        content: [
          'Старт: ${data['started_at'] ?? '-'}',
          'Время: ${data['duration_sec'] ?? 0}s',
          'Дистанция: ${data['distance_km'] ?? 0} км',
          'Темп: ${data['pace'] ?? '--'}',
          if (zones.isNotEmpty) 'Зоны: ${zones.entries.map((e) => '${e.key}:${e.value}s').join(', ')}',
        ],
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  final String title;
  final List<String> content;
  const _DetailSheet({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...content.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(t),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
