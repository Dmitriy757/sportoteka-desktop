import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class ClubTrainersScreen extends StatefulWidget {
  final int clubId;
  final String clubName;

  const ClubTrainersScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<ClubTrainersScreen> createState() => _ClubTrainersScreenState();
}

class _ClubTrainersScreenState extends State<ClubTrainersScreen> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getClubTrainersUrl = '$apiBase/get_club_trainers.php';
  static const String searchTrainerByEmailUrl = '$apiBase/search_trainer_by_email.php';
  static const String linkTrainerUrl = '$apiBase/link_trainer_to_club.php';
  static const String unlinkTrainerUrl = '$apiBase/unlink_trainer_from_club.php';

  static const Color _bg = Color(0xFFF5F7FA);
  static const Color _card = Colors.white;
  static const Color _primary = Color(0xFF0F8F4D);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF64748B);
  static const Color _line = Color(0xFFE5E7EB);

  bool loading = true;
  String? error;

  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> trainers = [];
  List<Map<String, dynamic>> filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isTabletLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= 700;
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      if (mounted) setState(() => filtered = List.of(trainers));
      return;
    }

    if (!mounted) return;
    setState(() {
      filtered = trainers.where((t) {
        final values = [
          _asStr(t['first_name']),
          _asStr(t['last_name']),
          _asStr(t['email']),
          _pickAnyStr(t, ['position', 'role_title', 'title']),
          _pickAnyStr(t, ['phone', 'telephone']),
        ].join(' ').toLowerCase();
        return values.contains(q);
      }).toList();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final resp = await http.post(
        Uri.parse(getClubTrainersUrl),
        body: {'club_id': widget.clubId.toString()},
      );
      final data = _decode(resp.body);

      if (data['success'] == true && data['trainers'] is List) {
        final list = (data['trainers'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        trainers = list;
        filtered = List.of(trainers);
      } else {
        trainers = [];
        filtered = [];
        final msg = _asStr(data['message']);
        if (msg.isNotEmpty && !msg.toLowerCase().contains('empty')) {
          debugPrint('ClubTrainersScreen load message: $msg');
        }
      }

      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Не удалось загрузить тренеров. Проверьте соединение или API.';
      });
      debugPrint('ClubTrainersScreen error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _searchTrainerByEmail(String email) async {
    try {
      final clean = email.trim();
      if (clean.isEmpty) return [];

      final resp = await http.post(
        Uri.parse(searchTrainerByEmailUrl),
        body: {'email': clean},
      );
      final data = _decode(resp.body);

      if (data['success'] == true && data['trainers'] is List) {
        return (data['trainers'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Search trainer error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> _pickTrainerByEmailSheet() async {
    final emailCtrl = TextEditingController();
    final isTablet = _isTabletLayout(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    try {
      List<Map<String, dynamic>> results = [];
      bool searching = false;

      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (modalContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSB) {
              Future<void> doSearch() async {
                final q = emailCtrl.text.trim();

                if (q.isEmpty) {
                  if (!sheetContext.mounted) return;
                  setSB(() {
                    searching = false;
                    results = [];
                  });
                  return;
                }

                if (!sheetContext.mounted) return;
                setSB(() => searching = true);

                final r = await _searchTrainerByEmail(q);

                if (!sheetContext.mounted) return;
                setSB(() {
                  searching = false;
                  results = r;
                });
              }

              return _BottomSheetShell(
                maxWidth: isTablet ? 620 : null,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 10,
                    bottom: 16 + bottomInset,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SheetHandle(),
                        Row(
                          children: [
                            const _RoundIcon(icon: Icons.person_add_alt_1_rounded),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Добавить тренера',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _text,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Найдите тренера по точному email',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => doSearch(),
                          decoration: InputDecoration(
                            labelText: 'Email тренера',
                            hintText: 'coach@mail.com',
                            prefixIcon: const Icon(Icons.alternate_email_rounded),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search_rounded),
                              onPressed: doSearch,
                            ),
                            filled: true,
                            fillColor: _bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (searching)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(color: _primary),
                            ),
                          )
                        else if (results.isEmpty)
                          const _CompactHint(
                            icon: Icons.manage_search_rounded,
                            title: 'Введите email',
                            text: 'После поиска выберите тренера из найденных пользователей.',
                          )
                        else
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.42,
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: results.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (itemContext, i) {
                                final t = results[i];
                                final id = _asInt(t['id']);
                                final email = _asStr(t['email']);
                                final name = _trainerName(t, fallback: 'Тренер #$id');

                                return _PickTrainerCard(
                                  name: name,
                                  email: email,
                                  onTap: () {
                                    Navigator.of(modalContext).pop({
                                      'id': id,
                                      'name': name,
                                      'email': email,
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      return picked;
    } finally {
      emailCtrl.dispose();
    }
  }

  Future<void> _linkTrainer(int trainerId) async {
    if (!mounted) return;

    try {
      final resp = await http.post(
        Uri.parse(linkTrainerUrl),
        body: {
          'club_id': widget.clubId.toString(),
          'trainer_id': trainerId.toString(),
        },
      );

      if (!mounted) return;

      final data = _decode(resp.body);

      if (data['success'] == true) {
        Get.snackbar(
          'Готово',
          'Тренер добавлен в клуб',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );

        if (!mounted) return;
        await _load();
      } else {
        final msg = _asStr(data['message']);
        Get.snackbar('Ошибка', msg.isEmpty ? 'Не удалось добавить тренера' : msg);
      }
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Сеть', 'Ошибка соединения');
      debugPrint('Link trainer error: $e');
    }
  }

  Future<void> _unlinkTrainer(int trainerId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Убрать тренера?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Тренер будет отвязан от клуба и исчезнет из списка.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Убрать', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final resp = await http.post(
        Uri.parse(unlinkTrainerUrl),
        body: {
          'club_id': widget.clubId.toString(),
          'trainer_id': trainerId.toString(),
        },
      );
      final data = _decode(resp.body);

      if (data['success'] == true) {
        Get.snackbar(
          'Готово',
          'Тренер удалён из клуба',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        await _load();
      } else {
        final msg = _asStr(data['message']);
        Get.snackbar('Ошибка', msg.isEmpty ? 'Не удалось удалить тренера' : msg);
      }
    } catch (e) {
      Get.snackbar('Сеть', 'Ошибка соединения');
      debugPrint('Unlink trainer error: $e');
    }
  }

  void _openTrainerCard(Map<String, dynamic> t) {
    Get.to(() => TrainerCardScreen(
          clubName: widget.clubName,
          trainer: Map<String, dynamic>.from(t),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = _isTabletLayout(context);

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: isTablet
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _primaryDark,
              elevation: 10,
              onPressed: _onAddTrainer,
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
              label: const Text(
                'Добавить',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : error != null
                ? _ErrorView(text: error!, onRetry: _load)
                : RefreshIndicator(
                    color: _primary,
                    onRefresh: _load,
                    child: isTablet ? _buildTablet(context) : _buildMobile(context),
                  ),
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _MobileTopBar(onBack: () => Get.back(), onRefresh: _load)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: _HeroHeader(
              clubName: widget.clubName,
              trainersCount: trainers.length,
              filteredCount: filtered.length,
              onAdd: _onAddTrainer,
              compact: false,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: _SearchBox(controller: _searchCtrl, compact: true),
          ),
        ),
        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
              child: _EmptyHint(onAdd: _onAddTrainer),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final itemIndex = index ~/ 2;
                  if (index.isOdd) return const SizedBox(height: 10);
                  return _TrainerCard(
                    trainer: filtered[itemIndex],
                    clubName: widget.clubName,
                    compact: true,
                    onTap: () => _openTrainerCard(filtered[itemIndex]),
                    onRemove: () =>
                        _unlinkTrainer(_asInt(filtered[itemIndex]['id'])),
                  );
                },
                childCount: filtered.length * 2 - 1,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTablet(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: _TabletTopBar(
              clubName: widget.clubName,
              onBack: () => Get.back(),
              onRefresh: _load,
              onAdd: _onAddTrainer,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 340,
                  child: Column(
                    children: [
                      _HeroHeader(
                        clubName: widget.clubName,
                        trainersCount: trainers.length,
                        filteredCount: filtered.length,
                        onAdd: _onAddTrainer,
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                      _SearchBox(controller: _searchCtrl, compact: false),
                      const SizedBox(height: 12),
                      _SideInfoPanel(
                        allCount: trainers.length,
                        shownCount: filtered.length,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: filtered.isEmpty
                      ? _EmptyHint(onAdd: _onAddTrainer)
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final cross = width >= 980 ? 3 : 2;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cross,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: width >= 980 ? 1.78 : 1.55,
                              ),
                              itemBuilder: (context, i) => _TrainerCard(
                                trainer: filtered[i],
                                clubName: widget.clubName,
                                compact: false,
                                onTap: () => _openTrainerCard(filtered[i]),
                                onRemove: () => _unlinkTrainer(_asInt(filtered[i]['id'])),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 26)),
      ],
    );
  }

  Future<void> _onAddTrainer() async {
    if (!mounted) return;

    final picked = await _pickTrainerByEmailSheet();

    if (!mounted) return;
    if (picked == null) return;

    final id = _asInt(picked['id']);
    if (id <= 0) return;

    await Future<void>.delayed(const Duration(milliseconds: 80));

    if (!mounted) return;
    await _linkTrainer(id);
  }

  Map<String, dynamic> _decode(String body) {
    try {
      var raw = body.trim();
      if (raw.startsWith('<')) {
        final startObj = raw.indexOf('{');
        final startArr = raw.indexOf('[');
        final starts = [startObj, startArr].where((e) => e >= 0).toList();
        if (starts.isEmpty) return {'success': false, 'message': 'Сервер вернул HTML'};
        final start = starts.reduce((a, b) => a < b ? a : b);
        raw = raw.substring(start);
      }
      final j = json.decode(raw);
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);
      return {'success': false};
    } catch (e) {
      debugPrint('Decode error: $e');
      return {'success': false, 'message': 'Некорректный ответ сервера'};
    }
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _asStr(dynamic v) => (v ?? '').toString();

  String _pickAnyStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty && v.toLowerCase() != 'null') return v;
    }
    return '';
  }

  String _trainerName(Map<String, dynamic> trainer, {String fallback = 'Тренер'}) {
    final fn = _asStr(trainer['first_name']).trim();
    final ln = _asStr(trainer['last_name']).trim();
    final full = _pickAnyStr(trainer, ['full_name', 'name', 'fio']);
    final composed = ('$fn $ln').trim();
    if (composed.isNotEmpty) return composed;
    if (full.isNotEmpty) return full;
    return fallback;
  }
}

// ============================================================================
// Trainer card screen
// ============================================================================
class TrainerCardScreen extends StatelessWidget {
  final String clubName;
  final Map<String, dynamic> trainer;

  const TrainerCardScreen({
    super.key,
    required this.clubName,
    required this.trainer,
  });

  static const Color _bg = Color(0xFFF5F7FA);
  static const Color _card = Colors.white;
  static const Color _primary = Color(0xFF0F8F4D);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF64748B);
  static const Color _line = Color(0xFFE5E7EB);

  String _asStr(dynamic v) => (v ?? '').toString();
  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _pickAnyStr(List<String> keys) {
    for (final k in keys) {
      final v = (trainer[k] ?? '').toString().trim();
      if (v.isNotEmpty && v.toLowerCase() != 'null') return v;
    }
    return '';
  }

  String _name() {
    final id = _asInt(trainer['id']);
    final fn = _asStr(trainer['first_name']).trim();
    final ln = _asStr(trainer['last_name']).trim();
    final full = _pickAnyStr(['full_name', 'name', 'fio']);
    final composed = ('$fn $ln').trim();
    if (composed.isNotEmpty) return composed;
    if (full.isNotEmpty) return full;
    return 'Тренер #$id';
  }

  String? _normalizePhoto(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (!s.startsWith('/')) s = '/$s';
    return 'https://sportotekaapp.ru$s';
  }

  bool _isTablet(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= 700;

  @override
  Widget build(BuildContext context) {
    final isTablet = _isTablet(context);
    final name = _name();
    final email = _asStr(trainer['email']).trim();
    final phone = _pickAnyStr(['phone', 'telephone']);
    final pos = _pickAnyStr(['position', 'role_title', 'title']);
    final bio = _pickAnyStr(['bio', 'about', 'description']);
    final born = _pickAnyStr(['born', 'birth_date', 'birthday']);
    final career = _pickAnyStr(['career', 'experience', 'history']);
    final photo = _normalizePhoto(_asStr(trainer['photo']).trim().isEmpty ? null : _asStr(trainer['photo']));

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(isTablet ? 22 : 14, 14, isTablet ? 22 : 14, 0),
                child: _ProfileTopBar(
                  title: 'Визитка тренера',
                  onBack: () => Get.back(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(isTablet ? 22 : 14, 14, isTablet ? 22 : 14, 24),
                child: isTablet
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 380,
                            child: _TrainerHeroCard(
                              name: name,
                              clubName: clubName,
                              photo: photo,
                              position: pos,
                              email: email,
                              phone: phone,
                              compact: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _MiniFact(title: 'Должность', value: pos.isEmpty ? 'Тренер' : pos, icon: Icons.workspace_premium_rounded)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _MiniFact(title: 'Клуб', value: clubName, icon: Icons.shield_rounded)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (born.isNotEmpty) _InfoSection(title: 'Дата рождения', text: born, icon: Icons.cake_rounded),
                                if (born.isNotEmpty) const SizedBox(height: 12),
                                if (career.isNotEmpty) _InfoSection(title: 'Опыт / карьера', text: career, icon: Icons.timeline_rounded),
                                if (career.isNotEmpty) const SizedBox(height: 12),
                                _InfoSection(
                                  title: 'Описание',
                                  text: bio.isNotEmpty ? bio : 'Описание тренера пока не заполнено.',
                                  icon: Icons.article_rounded,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _TrainerHeroCard(
                            name: name,
                            clubName: clubName,
                            photo: photo,
                            position: pos,
                            email: email,
                            phone: phone,
                            compact: true,
                          ),
                          const SizedBox(height: 12),
                          if (born.isNotEmpty) _InfoSection(title: 'Дата рождения', text: born, icon: Icons.cake_rounded),
                          if (born.isNotEmpty) const SizedBox(height: 12),
                          if (career.isNotEmpty) _InfoSection(title: 'Опыт / карьера', text: career, icon: Icons.timeline_rounded),
                          if (career.isNotEmpty) const SizedBox(height: 12),
                          _InfoSection(
                            title: 'Описание',
                            text: bio.isNotEmpty ? bio : 'Описание тренера пока не заполнено.',
                            icon: Icons.article_rounded,
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
}

// ============================================================================
// UI widgets
// ============================================================================
class _MobileTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _MobileTopBar({required this.onBack, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          _CircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Тренеры клуба',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ClubTrainersScreenState._text),
            ),
          ),
          _CircleButton(icon: Icons.refresh_rounded, onTap: onRefresh),
        ],
      ),
    );
  }
}

class _TabletTopBar extends StatelessWidget {
  final String clubName;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _TabletTopBar({
    required this.clubName,
    required this.onBack,
    required this.onRefresh,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Тренерский состав',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ClubTrainersScreenState._text),
              ),
              const SizedBox(height: 2),
              Text(
                clubName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _ClubTrainersScreenState._muted, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        _TabletAction(icon: Icons.refresh_rounded, label: 'Обновить', onTap: onRefresh, outlined: true),
        const SizedBox(width: 10),
        _TabletAction(icon: Icons.person_add_alt_1_rounded, label: 'Добавить тренера', onTap: onAdd),
      ],
    );
  }
}

class _ProfileTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _ProfileTopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _ClubTrainersScreenState._text),
          ),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String clubName;
  final int trainersCount;
  final int filteredCount;
  final VoidCallback onAdd;
  final bool compact;

  const _HeroHeader({
    required this.clubName,
    required this.trainersCount,
    required this.filteredCount,
    required this.onAdd,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _ClubTrainersScreenState._primaryDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 48 : 46,
                height: compact ? 48 : 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: const Icon(Icons.groups_2_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Тренеры клуба',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 20 : 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      clubName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.74),
                        fontSize: compact ? 12.5 : 12,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 18 : 14),
          Row(
            children: [
              Expanded(child: _HeaderStat(value: trainersCount.toString(), label: 'Всего')),
              const SizedBox(width: 8),
              Expanded(child: _HeaderStat(value: filteredCount.toString(), label: 'Показано')),
            ],
          ),
          SizedBox(height: compact ? 16 : 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _ClubTrainersScreenState._primaryDark,
                elevation: 0,
                minimumSize: Size(0, compact ? 46 : 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text(
                'Добавить тренера',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 1),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final bool compact;

  const _SearchBox({required this.controller, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
      decoration: BoxDecoration(
        color: _ClubTrainersScreenState._card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ClubTrainersScreenState._line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: compact ? 13.5 : 14, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: compact ? 'Поиск тренера' : 'Поиск по ФИО, должности или email',
          hintStyle: const TextStyle(color: _ClubTrainersScreenState._muted, fontWeight: FontWeight.w600),
          icon: const Icon(Icons.search_rounded, color: _ClubTrainersScreenState._muted),
        ),
      ),
    );
  }
}

class _SideInfoPanel extends StatelessWidget {
  final int allCount;
  final int shownCount;

  const _SideInfoPanel({required this.allCount, required this.shownCount});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Управление составом',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _ClubTrainersScreenState._text),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавляйте тренеров по email и открывайте карточку для просмотра данных.',
            style: TextStyle(color: _ClubTrainersScreenState._muted, height: 1.25, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SmallStat(label: 'Всего', value: allCount.toString())),
              const SizedBox(width: 8),
              Expanded(child: _SmallStat(label: 'В списке', value: shownCount.toString())),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;

  const _SmallStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ClubTrainersScreenState._bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _ClubTrainersScreenState._text)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _ClubTrainersScreenState._muted)),
        ],
      ),
    );
  }
}

class _TrainerCard extends StatelessWidget {
  final Map<String, dynamic> trainer;
  final String clubName;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _TrainerCard({
    required this.trainer,
    required this.clubName,
    required this.compact,
    required this.onTap,
    required this.onRemove,
  });

  String _asStr(dynamic v) => (v ?? '').toString();
  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _pickAnyStr(List<String> keys) {
    for (final k in keys) {
      final v = (trainer[k] ?? '').toString().trim();
      if (v.isNotEmpty && v.toLowerCase() != 'null') return v;
    }
    return '';
  }

  String _name() {
    final id = _asInt(trainer['id']);
    final fn = _asStr(trainer['first_name']).trim();
    final ln = _asStr(trainer['last_name']).trim();
    final full = _pickAnyStr(['full_name', 'name', 'fio']);
    final composed = ('$fn $ln').trim();
    if (composed.isNotEmpty) return composed;
    if (full.isNotEmpty) return full;
    return 'Тренер #$id';
  }

  String? _normalizePhoto(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (!s.startsWith('/')) s = '/$s';
    return 'https://sportotekaapp.ru$s';
  }

  @override
  Widget build(BuildContext context) {
    final name = _name();
    final pos = _pickAnyStr(['position', 'role_title', 'title']);
    final email = _asStr(trainer['email']).trim();
    final phone = _pickAnyStr(['phone', 'telephone']);
    final photo = _normalizePhoto(_asStr(trainer['photo']).trim().isEmpty ? null : _asStr(trainer['photo']));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: _SoftCard(
          padding: EdgeInsets.all(compact ? 12 : 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(photo: photo, size: compact ? 52 : 56),
                  SizedBox(width: compact ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: compact ? 14.5 : 15,
                                  height: 1.08,
                                  fontWeight: FontWeight.w900,
                                  color: _ClubTrainersScreenState._text,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Действия',
                              onSelected: (v) {
                                if (v == 'remove') onRemove();
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Row(
                                    children: [
                                      Icon(Icons.link_off_rounded, color: Colors.red, size: 18),
                                      SizedBox(width: 10),
                                      Flexible(child: Text('Убрать из клуба', style: TextStyle(fontWeight: FontWeight.w800))),
                                    ],
                                  ),
                                ),
                              ],
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.more_horiz_rounded, size: 20, color: _ClubTrainersScreenState._muted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _ChipText(
                              icon: Icons.workspace_premium_rounded,
                              text: pos.isNotEmpty ? pos : 'Тренер',
                              compact: compact,
                            ),
                            if (!compact)
                              _ChipText(
                                icon: Icons.shield_rounded,
                                text: clubName,
                                compact: compact,
                                muted: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 10 : 11),
              if (email.isNotEmpty) _TinyLine(icon: Icons.mail_outline_rounded, text: email, compact: compact),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 5),
                _TinyLine(icon: Icons.phone_rounded, text: phone, compact: compact),
              ],
              SizedBox(height: compact ? 10 : 11),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Открыть карточку',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12.5 : 12.8,
                        fontWeight: FontWeight.w900,
                        color: _ClubTrainersScreenState._primary,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: _ClubTrainersScreenState._primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainerHeroCard extends StatelessWidget {
  final String name;
  final String clubName;
  final String? photo;
  final String position;
  final String email;
  final String phone;
  final bool compact;

  const _TrainerHeroCard({
    required this.name,
    required this.clubName,
    required this.photo,
    required this.position,
    required this.email,
    required this.phone,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(photo: photo, size: compact ? 68 : 78),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 18 : 20,
                        height: 1.06,
                        fontWeight: FontWeight.w900,
                        color: _ClubTrainersScreenState._text,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _ChipText(
                      icon: Icons.workspace_premium_rounded,
                      text: position.isEmpty ? 'Тренер' : position,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TinyLine(icon: Icons.shield_rounded, text: clubName, compact: compact),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            _TinyLine(icon: Icons.mail_outline_rounded, text: email, compact: compact),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _TinyLine(icon: Icons.phone_rounded, text: phone, compact: compact),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photo;
  final double size;

  const _Avatar({required this.photo, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _ClubTrainersScreenState._primary.withOpacity(0.18), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: photo != null
            ? Image.network(
                photo!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: _ClubTrainersScreenState._primary.withOpacity(0.10),
      child: Icon(Icons.person_rounded, color: _ClubTrainersScreenState._primary, size: size * 0.48),
    );
  }
}

class _ChipText extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool compact;
  final bool muted;

  const _ChipText({
    required this.icon,
    required this.text,
    required this.compact,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 190 : 240),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 9, vertical: compact ? 5 : 5),
      decoration: BoxDecoration(
        color: muted ? _ClubTrainersScreenState._bg : _ClubTrainersScreenState._primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 14, color: muted ? _ClubTrainersScreenState._muted : _ClubTrainersScreenState._primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11.2 : 11.5,
                fontWeight: FontWeight.w900,
                color: muted ? _ClubTrainersScreenState._text : _ClubTrainersScreenState._primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool compact;

  const _TinyLine({required this.icon, required this.text, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: compact ? 15 : 16, color: _ClubTrainersScreenState._muted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 12.2 : 12.5,
              color: _ClubTrainersScreenState._muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;

  const _InfoSection({required this.title, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundIcon(icon: icon, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _ClubTrainersScreenState._text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(color: _ClubTrainersScreenState._text, fontWeight: FontWeight.w600, height: 1.35, fontSize: 13.2),
          ),
        ],
      ),
    );
  }
}

class _MiniFact extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniFact({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          _RoundIcon(icon: icon, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _ClubTrainersScreenState._muted)),
                const SizedBox(height: 3),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _ClubTrainersScreenState._text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SoftCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _ClubTrainersScreenState._card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _ClubTrainersScreenState._line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _ClubTrainersScreenState._line),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 8)),
          ],
        ),
        child: Icon(icon, color: _ClubTrainersScreenState._text, size: 20),
      ),
    );
  }
}

class _TabletAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  const _TabletAction({required this.icon, required this.label, required this.onTap, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: outlined ? Colors.white : _ClubTrainersScreenState._primaryDark,
          foregroundColor: outlined ? _ClubTrainersScreenState._text : Colors.white,
          side: outlined ? const BorderSide(color: _ClubTrainersScreenState._line) : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          padding: const EdgeInsets.symmetric(horizontal: 13),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _RoundIcon({required this.icon, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _ClubTrainersScreenState._primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(size * 0.36),
      ),
      child: Icon(icon, size: size * 0.48, color: _ClubTrainersScreenState._primary),
    );
  }
}

class _BottomSheetShell extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const _BottomSheetShell({required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: child,
    );

    if (maxWidth == null) return body;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: body,
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _ClubTrainersScreenState._line,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _PickTrainerCard extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onTap;

  const _PickTrainerCard({required this.name, required this.email, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _ClubTrainersScreenState._bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _ClubTrainersScreenState._line),
        ),
        child: Row(
          children: [
            const _RoundIcon(icon: Icons.person_rounded, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: _ClubTrainersScreenState._text)),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, color: _ClubTrainersScreenState._muted, fontSize: 12.5)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.add_circle_rounded, color: _ClubTrainersScreenState._primary),
          ],
        ),
      ),
    );
  }
}

class _CompactHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _CompactHint({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _ClubTrainersScreenState._bg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _ClubTrainersScreenState._line),
      ),
      child: Row(
        children: [
          _RoundIcon(icon: icon, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: _ClubTrainersScreenState._text)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: _ClubTrainersScreenState._muted, fontSize: 12.5, height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyHint({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _RoundIcon(icon: Icons.groups_2_rounded, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Тренеры не найдены',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _ClubTrainersScreenState._text),
          ),
          const SizedBox(height: 5),
          const Text(
            'Добавьте тренера по email или измените поисковый запрос.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _ClubTrainersScreenState._muted, fontWeight: FontWeight.w700, height: 1.3),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: _ClubTrainersScreenState._primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Добавить тренера', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _ErrorView({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _SoftCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _RoundIcon(icon: Icons.wifi_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: _ClubTrainersScreenState._text)),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ClubTrainersScreenState._primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Повторить', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
