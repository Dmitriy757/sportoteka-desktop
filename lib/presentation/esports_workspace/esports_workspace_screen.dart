import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/theme/app_typography.dart';

enum EsportsWorkspaceSection {
  overview,
  teams,
  athletes,
  matches,
  tournaments,
  analytics,
  video,
  ai,
  workspaceOs,
}

class EsportsWorkspaceScreen extends StatefulWidget {
  final int clubId;
  final int userId;
  final String clubName;
  final String? clubLogoUrl;

  const EsportsWorkspaceScreen({
    super.key,
    required this.clubId,
    required this.userId,
    required this.clubName,
    this.clubLogoUrl,
  });

  @override
  State<EsportsWorkspaceScreen> createState() => _EsportsWorkspaceScreenState();
}

class _EsportsWorkspaceScreenState extends State<EsportsWorkspaceScreen> {
  static const _apiBase = 'https://sportotekaapp.ru/api/esports';

  EsportsWorkspaceSection _section = EsportsWorkspaceSection.overview;
  bool _loading = true;
  String? _loadError;
  final List<Map<String, dynamic>> _athletes = [];
  final List<Map<String, dynamic>> _teams = [];
  final List<Map<String, dynamic>> _matches = [];
  final List<Map<String, dynamic>> _tournaments = [];

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  Future<void> _loadWorkspace() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final results = await Future.wait([
        _getList('players/list.php'),
        _getList('teams/list.php'),
        _getList('matches/list.php'),
        _getList('tournaments/list.php'),
      ]);

      _athletes
        ..clear()
        ..addAll(results[0]);
      _teams
        ..clear()
        ..addAll(results[1]);
      _matches
        ..clear()
        ..addAll(results[2]);
      _tournaments
        ..clear()
        ..addAll(results[3]);
    } catch (e) {
      // До подключения server layer экран остаётся рабочим и показывает
      // пустые состояния вместо ошибки всего HUB.
      _loadError = 'Серверный слой Esports ещё не подключён.';
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<List<Map<String, dynamic>>> _getList(String endpoint) async {
    final uri = Uri.parse('$_apiBase/$endpoint').replace(
      queryParameters: {
        'club_id': '${widget.clubId}',
        'user_id': '${widget.userId}',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    dynamic raw = decoded;
    if (decoded is Map) {
      raw = decoded['items'] ??
          decoded['data'] ??
          decoded['players'] ??
          decoded['teams'] ??
          decoded['matches'] ??
          decoded['tournaments'];
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  String _s(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  int _i(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

  void _select(EsportsWorkspaceSection section) {
    if (_section == section) return;
    setState(() => _section = section);
  }

  Future<void> _openAddAthlete() async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: _EsportsAthleteEditor(
            clubId: widget.clubId,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );

    if (created == null || !mounted) return;
    setState(() {
      _athletes.insert(0, created);
      _section = EsportsWorkspaceSection.athletes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 820;

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: mobile ? _buildMobile() : _buildDesktop(),
      ),
    );
  }

  Widget _buildDesktop() {
    return Row(
      children: [
        SizedBox(width: 244, child: _buildSidebar()),
        Container(width: 1, color: _C.line),
        Expanded(child: _buildMain()),
      ],
    );
  }

  Widget _buildMobile() {
    return Column(
      children: [
        _buildMobileHeader(),
        _buildMobileTabs(),
        Container(height: 1, color: _C.line),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildSidebar() {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _backButton(),
                const SizedBox(width: 10),
                Expanded(child: _brand()),
              ],
            ),
            const SizedBox(height: 24),
            _clubIdentity(),
            const SizedBox(height: 22),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final section in EsportsWorkspaceSection.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: _navTile(section),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _smallInfo(
              'Киберспорт работает отдельным слоем и не меняет футбольный состав клуба.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMain() {
    return Column(
      children: [
        _desktopHeader(),
        Container(height: 1, color: _C.line),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _desktopHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleFor(_section),
                  style: AppTypography.custom(
                    size: 22,
                    weight: FontWeight.w600,
                    color: _C.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitleFor(_section),
                  style: AppTypography.captionMedium(color: _C.muted),
                ),
              ],
            ),
          ),
          if (_section == EsportsWorkspaceSection.athletes ||
              _section == EsportsWorkspaceSection.overview)
            _primaryAction(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Добавить киберспортсмена',
              onTap: _openAddAthlete,
            ),
          const SizedBox(width: 8),
          _iconAction(Icons.refresh_rounded, _loadWorkspace),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      child: Row(
        children: [
          _backButton(),
          const SizedBox(width: 9),
          Expanded(child: _clubIdentity(compact: true)),
          _iconAction(Icons.person_add_alt_1_rounded, _openAddAthlete),
        ],
      ),
    );
  }

  Widget _buildMobileTabs() {
    return Container(
      color: Colors.white,
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: EsportsWorkspaceSection.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (_, index) {
          final section = EsportsWorkspaceSection.values[index];
          final active = section == _section;
          return InkWell(
            onTap: () => _select(section),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? _C.greenSoft : _C.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _shortTitleFor(section),
                style: AppTypography.custom(
                  size: 10.5,
                  weight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? _C.greenDark : _C.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _C.green, strokeWidth: 2),
      );
    }

    return RefreshIndicator(
      color: _C.green,
      onRefresh: _loadWorkspace,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: switch (_section) {
          EsportsWorkspaceSection.overview => _overview(),
          EsportsWorkspaceSection.teams => _teamsSection(),
          EsportsWorkspaceSection.athletes => _athletesSection(),
          EsportsWorkspaceSection.matches => _matchesSection(),
          EsportsWorkspaceSection.tournaments => _tournamentsSection(),
          EsportsWorkspaceSection.analytics => _analyticsSection(),
          EsportsWorkspaceSection.video => _emptyModule(
              Icons.video_library_outlined,
              'Видео киберспорта',
              'Записи матчей, клипы и видеоразборы будут храниться отдельно от футбольного видеоцентра.',
            ),
          EsportsWorkspaceSection.ai => _emptyModule(
              Icons.auto_awesome_rounded,
              'ИИ-анализ киберспорта',
              'ИИ будет анализировать игровые матчи, серии, формации, ошибки и динамику рейтинга.',
            ),
          EsportsWorkspaceSection.workspaceOs => _emptyModule(
              Icons.folder_copy_outlined,
              'Sportoteka OS · Киберспорт',
              'Отдельное дерево: команды → киберспортсмены → матчи → турниры → видео → ИИ-анализ → документы.',
            ),
        },
      ),
    );
  }

  Widget _overview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loadError != null) ...[
          _serverNotice(),
          const SizedBox(height: 14),
        ],
        LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 720;
            final cards = [
              _metric('Киберспортсмены', '${_athletes.length}', Icons.sports_esports_rounded),
              _metric('Команды', '${_teams.length}', Icons.groups_2_outlined),
              _metric('Матчи', '${_matches.length}', Icons.stadium_outlined),
              _metric('Турниры', '${_tournaments.length}', Icons.emoji_events_outlined),
            ];
            return narrow
                ? Wrap(spacing: 10, runSpacing: 10, children: cards)
                : Row(children: _withGaps(cards));
          },
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Sportoteka Esports',
          subtitle: 'Отдельное спортивное направление клуба',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _featureRow('EA Sports FC', '1×1 · 2×2 · Clubs · Ultimate Team'),
              _featureRow('eFootball', 'Матчи · рейтинги · турниры'),
              _featureRow('Другие дисциплины', 'CS2 · Dota 2 · Valorant и новые игры'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Быстрый старт',
          subtitle: 'Создание идёт только внутри Esports Workspace',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _primaryAction(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Добавить киберспортсмена',
                onTap: _openAddAthlete,
              ),
              _secondaryAction(
                icon: Icons.groups_2_outlined,
                label: 'Команды',
                onTap: () => _select(EsportsWorkspaceSection.teams),
              ),
              _secondaryAction(
                icon: Icons.emoji_events_outlined,
                label: 'Турниры',
                onTap: () => _select(EsportsWorkspaceSection.tournaments),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _withGaps(List<Widget> children) {
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(Expanded(child: children[i]));
      if (i != children.length - 1) result.add(const SizedBox(width: 10));
    }
    return result;
  }

  Widget _teamsSection() {
    if (_teams.isEmpty) {
      return _emptyModule(
        Icons.groups_2_outlined,
        'Киберспортивных команд пока нет',
        'Здесь будут отдельные команды клуба: например FC Esports, EA Sports FC Academy или Clubs Squad.',
      );
    }
    return _listCard(
      title: 'Команды',
      items: _teams,
      titleBuilder: (m) => _s(m['name'] ?? m['team_name']).isEmpty
          ? 'Киберспортивная команда'
          : _s(m['name'] ?? m['team_name']),
      subtitleBuilder: (m) => [
        _s(m['game_title'] ?? m['game']),
        _s(m['discipline']),
        if (_i(m['athletes_count'] ?? m['players_count']) > 0)
          '${_i(m['athletes_count'] ?? m['players_count'])} спортсменов',
      ].where((e) => e.isNotEmpty).join(' · '),
      icon: Icons.groups_2_outlined,
    );
  }

  Widget _athletesSection() {
    if (_athletes.isEmpty) {
      return _emptyModule(
        Icons.sports_esports_rounded,
        'Киберспортсменов пока нет',
        'Добавьте первого киберспортсмена. Он не попадёт в футбольный состав и будет жить только в Esports Workspace.',
        action: _primaryAction(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Добавить киберспортсмена',
          onTap: _openAddAthlete,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final athlete in _athletes) ...[
          _athleteCard(athlete),
          const SizedBox(height: 9),
        ],
      ],
    );
  }

  Widget _athleteCard(Map<String, dynamic> athlete) {
    final tag = _s(athlete['gamer_tag'] ?? athlete['nickname']);
    final fullName = '${_s(athlete['first_name'])} ${_s(athlete['last_name'])}'.trim();
    final game = _s(athlete['game_title'] ?? athlete['game']);
    final platform = _s(athlete['platform']);
    final rating = _s(athlete['rating']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _C.greenSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.sports_esports_rounded, color: _C.greenDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag.isNotEmpty ? tag : (fullName.isEmpty ? 'Киберспортсмен' : fullName),
                  style: AppTypography.custom(size: 14.5, weight: FontWeight.w600, color: _C.text),
                ),
                if (tag.isNotEmpty && fullName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(fullName, style: AppTypography.captionMedium(color: _C.muted)),
                ],
                const SizedBox(height: 4),
                Text(
                  [game, platform, if (rating.isNotEmpty) 'Рейтинг $rating']
                      .where((e) => e.isNotEmpty)
                      .join(' · '),
                  style: AppTypography.captionMedium(color: _C.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _C.muted),
        ],
      ),
    );
  }

  Widget _matchesSection() => _matches.isEmpty
      ? _emptyModule(
          Icons.stadium_outlined,
          'Матчей пока нет',
          'Здесь появится история игровых матчей с результатом, статистикой и ИИ-разбором.',
        )
      : _listCard(
          title: 'Матчи',
          items: _matches,
          titleBuilder: (m) => _s(m['title'] ?? m['opponent']).isEmpty
              ? 'Матч'
              : _s(m['title'] ?? m['opponent']),
          subtitleBuilder: (m) => [
            _s(m['score']),
            _s(m['game_title'] ?? m['game']),
            _s(m['played_at'] ?? m['date']),
          ].where((e) => e.isNotEmpty).join(' · '),
          icon: Icons.stadium_outlined,
        );

  Widget _tournamentsSection() => _tournaments.isEmpty
      ? _emptyModule(
          Icons.emoji_events_outlined,
          'Турниров пока нет',
          'Лиги, кубки, сетки и результаты будут храниться отдельно от футбольного календаря.',
        )
      : _listCard(
          title: 'Турниры',
          items: _tournaments,
          titleBuilder: (m) => _s(m['name'] ?? m['title']).isEmpty
              ? 'Турнир'
              : _s(m['name'] ?? m['title']),
          subtitleBuilder: (m) => [
            _s(m['game_title'] ?? m['game']),
            _s(m['status']),
            _s(m['date_from'] ?? m['start_date']),
          ].where((e) => e.isNotEmpty).join(' · '),
          icon: Icons.emoji_events_outlined,
        );

  Widget _analyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          title: 'Аналитика Esports',
          subtitle: 'Показатели не смешиваются с GPS и футбольной нагрузкой',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _AnalyticsChip('Win Rate'),
              _AnalyticsChip('Рейтинг'),
              _AnalyticsChip('Голы / матч'),
              _AnalyticsChip('xG'),
              _AnalyticsChip('Владение'),
              _AnalyticsChip('Точность передач'),
              _AnalyticsChip('Серии W/D/L'),
              _AnalyticsChip('Формации'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _emptyModule(
          Icons.query_stats_rounded,
          'Данные появятся после первых матчей',
          'Аналитика будет строиться только по киберспортивным матчам и турнирам.',
        ),
      ],
    );
  }

  Widget _listCard({
    required String title,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) titleBuilder,
    required String Function(Map<String, dynamic>) subtitleBuilder,
    required IconData icon,
  }) {
    return _sectionCard(
      title: title,
      subtitle: '${items.length} записей',
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _C.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: _C.greenDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleBuilder(items[index]),
                        style: AppTypography.action(color: _C.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleBuilder(items[index]),
                        style: AppTypography.captionMedium(color: _C.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (index != items.length - 1) ...[
              const SizedBox(height: 10),
              Container(height: 1, color: _C.line),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  Widget _emptyModule(
    IconData icon,
    String title,
    String subtitle, {
    Widget? action,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 300),
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _C.greenSoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: _C.greenDark, size: 25),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.custom(size: 16, weight: FontWeight.w600, color: _C.text),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.custom(size: 11.5, weight: FontWeight.w400, color: _C.muted, height: 1.45),
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _serverNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF92400E)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Интерфейс Esports уже отделён. Сейчас нужны отдельные PHP/API и таблицы — футбольный API здесь не используется.',
              style: AppTypography.custom(size: 10.6, weight: FontWeight.w500, color: const Color(0xFF92400E), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: _C.greenDark),
          const SizedBox(height: 14),
          Text(value, style: AppTypography.custom(size: 22, weight: FontWeight.w600, color: _C.text)),
          const SizedBox(height: 2),
          Text(title, style: AppTypography.captionMedium(color: _C.muted)),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.subsectionTitle(color: _C.text)),
          const SizedBox(height: 3),
          Text(subtitle, style: AppTypography.captionMedium(color: _C.muted)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _featureRow(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: _C.green, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AppTypography.action(color: _C.text))),
          const SizedBox(width: 10),
          Flexible(child: Text(subtitle, textAlign: TextAlign.right, style: AppTypography.captionMedium(color: _C.muted))),
        ],
      ),
    );
  }

  Widget _smallInfo(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: AppTypography.custom(size: 9.8, weight: FontWeight.w400, color: _C.muted, height: 1.35)),
    );
  }

  Widget _brand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SPORTOTEKA', style: AppTypography.custom(size: 12, weight: FontWeight.w700, color: _C.text)),
        const SizedBox(height: 1),
        Text('ESPORTS', style: AppTypography.custom(size: 9.5, weight: FontWeight.w600, color: _C.greenDark, letterSpacing: .8)),
      ],
    );
  }

  Widget _clubIdentity({bool compact = false}) {
    final name = widget.clubName.trim().isEmpty ? 'Киберспорт клуба' : widget.clubName.trim();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _logo(size: compact ? 38 : 46),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.action(color: _C.text)),
              const SizedBox(height: 2),
              Text('Киберспортивное направление', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.captionMedium(color: _C.muted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _logo({required double size}) {
    final url = (widget.clubLogoUrl ?? '').trim();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _C.greenSoft, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.sports_esports_rounded, color: _C.greenDark),
    );
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }

  Widget _navTile(EsportsWorkspaceSection section) {
    final active = section == _section;
    return Material(
      color: active ? _C.greenSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _select(section),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            children: [
              Icon(_iconFor(section), size: 17, color: active ? _C.greenDark : _C.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _shortTitleFor(section),
                  style: AppTypography.custom(size: 11, weight: active ? FontWeight.w600 : FontWeight.w500, color: active ? _C.text : _C.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backButton() => Material(
        color: _C.soft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(10),
          child: const SizedBox(width: 36, height: 36, child: Icon(Icons.arrow_back_rounded, size: 18, color: _C.muted)),
        ),
      );

  Widget _iconAction(IconData icon, VoidCallback onTap) => Material(
        color: _C.soft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 18, color: _C.greenDark)),
        ),
      );

  Widget _primaryAction({required IconData icon, required String label, required VoidCallback onTap}) => Material(
        color: _C.green,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: Colors.white),
                const SizedBox(width: 7),
                Text(label, style: AppTypography.action(color: Colors.white)),
              ],
            ),
          ),
        ),
      );

  Widget _secondaryAction({required IconData icon, required String label, required VoidCallback onTap}) => Material(
        color: _C.soft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: _C.muted),
                const SizedBox(width: 7),
                Text(label, style: AppTypography.action(color: _C.text)),
              ],
            ),
          ),
        ),
      );

  String _titleFor(EsportsWorkspaceSection section) => switch (section) {
        EsportsWorkspaceSection.overview => 'Киберспорт',
        EsportsWorkspaceSection.teams => 'Киберспортивные команды',
        EsportsWorkspaceSection.athletes => 'Киберспортсмены',
        EsportsWorkspaceSection.matches => 'Матчи',
        EsportsWorkspaceSection.tournaments => 'Турниры',
        EsportsWorkspaceSection.analytics => 'Аналитика',
        EsportsWorkspaceSection.video => 'Видео',
        EsportsWorkspaceSection.ai => 'ИИ',
        EsportsWorkspaceSection.workspaceOs => 'Sportoteka OS',
      };

  String _shortTitleFor(EsportsWorkspaceSection section) => switch (section) {
        EsportsWorkspaceSection.overview => 'Обзор',
        EsportsWorkspaceSection.teams => 'Команды',
        EsportsWorkspaceSection.athletes => 'Спортсмены',
        EsportsWorkspaceSection.matches => 'Матчи',
        EsportsWorkspaceSection.tournaments => 'Турниры',
        EsportsWorkspaceSection.analytics => 'Аналитика',
        EsportsWorkspaceSection.video => 'Видео',
        EsportsWorkspaceSection.ai => 'ИИ',
        EsportsWorkspaceSection.workspaceOs => 'Sportoteka OS',
      };

  String _subtitleFor(EsportsWorkspaceSection section) => switch (section) {
        EsportsWorkspaceSection.overview => 'Отдельное рабочее пространство Esports',
        EsportsWorkspaceSection.teams => 'Составы по дисциплинам и игровым режимам',
        EsportsWorkspaceSection.athletes => 'Игровые профили, рейтинг и специализация',
        EsportsWorkspaceSection.matches => 'Результаты и игровая статистика',
        EsportsWorkspaceSection.tournaments => 'Лиги, кубки и турнирные сетки',
        EsportsWorkspaceSection.analytics => 'Динамика рейтинга и показатели матчей',
        EsportsWorkspaceSection.video => 'Клипы, записи и видеоразборы',
        EsportsWorkspaceSection.ai => 'ИИ-анализ матчей и игровых решений',
        EsportsWorkspaceSection.workspaceOs => 'Документы и архив киберспортивного направления',
      };

  IconData _iconFor(EsportsWorkspaceSection section) => switch (section) {
        EsportsWorkspaceSection.overview => Icons.dashboard_outlined,
        EsportsWorkspaceSection.teams => Icons.groups_2_outlined,
        EsportsWorkspaceSection.athletes => Icons.sports_esports_rounded,
        EsportsWorkspaceSection.matches => Icons.stadium_outlined,
        EsportsWorkspaceSection.tournaments => Icons.emoji_events_outlined,
        EsportsWorkspaceSection.analytics => Icons.query_stats_rounded,
        EsportsWorkspaceSection.video => Icons.video_library_outlined,
        EsportsWorkspaceSection.ai => Icons.auto_awesome_rounded,
        EsportsWorkspaceSection.workspaceOs => Icons.folder_copy_outlined,
      };
}

class _EsportsAthleteEditor extends StatefulWidget {
  final int clubId;
  final VoidCallback onClose;

  const _EsportsAthleteEditor({required this.clubId, required this.onClose});

  @override
  State<_EsportsAthleteEditor> createState() => _EsportsAthleteEditorState();
}

class _EsportsAthleteEditorState extends State<_EsportsAthleteEditor> {
  static const _createUrl = 'https://sportotekaapp.ru/api/esports/players/create.php';

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _gamerTag = TextEditingController();
  final _gameId = TextEditingController();
  final _rating = TextEditingController();
  final _rank = TextEditingController();
  final _region = TextEditingController();
  final _teamRole = TextEditingController();

  String _game = 'EA Sports FC';
  String _platform = 'PlayStation 5';
  String _mode = '1×1';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _gamerTag, _gameId, _rating, _rank, _region, _teamRole]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_gamerTag.text.trim().isEmpty || _firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      setState(() => _error = 'Укажите имя, фамилию и игровой ник.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'club_id': widget.clubId,
      'athlete_type': 'esports',
      'first_name': _firstName.text.trim(),
      'last_name': _lastName.text.trim(),
      'email': _email.text.trim(),
      'gamer_tag': _gamerTag.text.trim(),
      'game_title': _game,
      'platform': _platform,
      'game_mode': _mode,
      'game_account_id': _gameId.text.trim(),
      'rating': int.tryParse(_rating.text.trim()) ?? 0,
      'rank': _rank.text.trim(),
      'region': _region.text.trim(),
      'team_role': _teamRole.text.trim(),
    };

    try {
      final response = await http
          .post(
            Uri.parse(_createUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      final decoded = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map &&
          (decoded['success'] == true || decoded['status'] == 'success');

      if (!ok) {
        final message = decoded is Map ? '${decoded['message'] ?? decoded['error'] ?? ''}'.trim() : '';
        throw Exception(message.isEmpty ? 'Esports API пока не подключён' : message);
      }

      final raw = decoded['player'] ?? decoded['data'];
      final result = <String, dynamic>{
        ...payload,
        if (raw is Map) ...Map<String, dynamic>.from(raw),
      };

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 12, 13),
            child: Row(
              children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: _C.green, shape: BoxShape.circle)),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Новый киберспортсмен', style: AppTypography.subsectionTitle(color: _C.text)),
                      const SizedBox(height: 2),
                      Text('Отдельный Esports-профиль', style: AppTypography.captionMedium(color: _C.muted)),
                    ],
                  ),
                ),
                IconButton(onPressed: _saving ? null : widget.onClose, icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          Container(height: 1, color: _C.line),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _editorSection(
                    'Основная информация',
                    Column(
                      children: [
                        _two(_field(_firstName, 'Имя'), _field(_lastName, 'Фамилия')),
                        _field(_email, 'Email'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _editorSection(
                    'Игровой профиль',
                    Column(
                      children: [
                        _field(_gamerTag, 'Игровой ник'),
                        _two(
                          _dropdown('Игра', _game, const ['EA Sports FC', 'eFootball', 'Counter-Strike 2', 'Dota 2', 'Valorant', 'Другая'], (v) => setState(() => _game = v)),
                          _dropdown('Платформа', _platform, const ['PlayStation 5', 'Xbox Series', 'PC', 'Nintendo Switch', 'Другая'], (v) => setState(() => _platform = v)),
                        ),
                        _two(
                          _dropdown('Режим', _mode, const ['1×1', '2×2', 'Clubs', 'Ultimate Team', 'Командный'], (v) => setState(() => _mode = v)),
                          _field(_gameId, 'Игровой ID'),
                        ),
                        _two(_field(_rating, 'Рейтинг', number: true), _field(_rank, 'Ранг')),
                        _two(_field(_region, 'Регион'), _field(_teamRole, 'Роль в команде')),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: AppTypography.custom(size: 10.8, weight: FontWeight.w500, color: const Color(0xFFD92D20))),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _dialogButton('Отмена', widget.onClose, primary: false)),
                      const SizedBox(width: 9),
                      Expanded(child: _dialogButton(_saving ? 'Сохраняем…' : 'Добавить', _saving ? null : _save, primary: true)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editorSection(String title, Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: AppTypography.action(color: _C.text)),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _two(Widget a, Widget b) => LayoutBuilder(
        builder: (context, c) => c.maxWidth < 520
            ? Column(children: [a, b])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]),
      );

  Widget _field(TextEditingController c, String label, {bool number = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: _input(label),
          style: AppTypography.formText(color: _C.text),
        ),
      );

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: _input(label),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: _C.soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.greenDark)),
      );

  Widget _dialogButton(String label, VoidCallback? onTap, {required bool primary}) => Material(
        color: primary ? _C.green : _C.soft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 44,
            child: Center(child: Text(label, style: AppTypography.action(color: primary ? Colors.white : _C.text))),
          ),
        ),
      );
}

class _AnalyticsChip extends StatelessWidget {
  final String text;
  const _AnalyticsChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: AppTypography.captionMedium(color: _C.text)),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: _C.line, width: .7),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.015), blurRadius: 14, spreadRadius: -10, offset: const Offset(0, 8))],
    );

class _C {
  static const bg = Color(0xFFF6F7F6);
  static const text = Color(0xFF0B0F14);
  static const muted = Color(0xFF5F6670);
  static const line = Color(0xFFE9ECEA);
  static const soft = Color(0xFFF7F8F7);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
}
