import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_player_section_document.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_player_section_browser.dart';

class SportotekaPlayerProjectScreen extends StatelessWidget {
  const SportotekaPlayerProjectScreen({
    super.key,
    required this.player,
    required this.clubId,
    this.teamId,
    this.teamName = '',
    this.onRefresh,
    this.onOpenLegacyProfile,
    this.onClose,
    this.currentUserId = 0,
  });

  final Map<String, dynamic> player;
  final int clubId;
  final int? teamId;
  final String teamName;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onOpenLegacyProfile;
  final VoidCallback? onClose;
  final int currentUserId;

  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE7EAE7);

  String get _playerName {
    final last = '${player['last_name'] ?? player['lastname'] ?? ''}'.trim();
    final first = '${player['first_name'] ?? player['firstname'] ?? ''}'.trim();
    final full = '${player['full_name'] ?? player['fullName'] ?? player['name'] ?? ''}'.trim();
    final joined = <String>[last, first].where((e) => e.isNotEmpty).join(' ').trim();
    return joined.isNotEmpty ? joined : (full.isNotEmpty ? full : 'Игрок');
  }

  String get _position => '${player['position'] ?? player['role_on_field'] ?? player['amplua'] ?? ''}'.trim();
  String get _number => '${player['number'] ?? player['shirt_number'] ?? player['player_number'] ?? ''}'.trim();

  List<_PlayerProjectFile> get _files => const <_PlayerProjectFile>[
        _PlayerProjectFile(
          section: WorkspacePlayerSection.card,
          title: 'Карточка игрока',
          subtitle: 'личные данные, амплуа и контакты',
          glyph: _ProjectGlyph.card,
        ),
        _PlayerProjectFile(
          section: WorkspacePlayerSection.diary,
          title: 'Дневник',
          subtitle: 'оценки, самооценка и заметки',
          glyph: _ProjectGlyph.diary,
        ),
        _PlayerProjectFile(
          section: WorkspacePlayerSection.readiness,
          title: 'Готовность',
          subtitle: 'состояние, readiness и нагрузка',
          glyph: _ProjectGlyph.readiness,
        ),
        _PlayerProjectFile(
          section: WorkspacePlayerSection.activity,
          title: 'Активность',
          subtitle: 'тренировки и показатели',
          glyph: _ProjectGlyph.activity,
        ),
        _PlayerProjectFile(
          section: WorkspacePlayerSection.matches,
          title: 'Матчи',
          subtitle: 'игры и статистика',
          glyph: _ProjectGlyph.matches,
        ),
        _PlayerProjectFile(
          section: WorkspacePlayerSection.testing,
          title: 'Тестирование',
          subtitle: 'тесты и динамика',
          glyph: _ProjectGlyph.testing,
        ),
        _PlayerProjectFile(
          section: WorkspacePlayerSection.health,
          title: 'Здоровье',
          subtitle: 'медкарта, допуски и файлы',
          glyph: _ProjectGlyph.health,
          folderLike: true,
        ),
        _PlayerProjectFile(
          section: WorkspacePlayerSection.documents,
          title: 'Документы',
          subtitle: 'файлы и документы игрока',
          glyph: _ProjectGlyph.documents,
          folderLike: true,
        ),
      ];

  Future<void> _openSection(BuildContext context, _PlayerProjectFile file, {bool createNote = false}) async {
    // Карточка игрока — единственный одиночный системный документ. Остальные
    // разделы открываются как полноценные рабочие экраны со своими записями.
    final Widget child = file.section == WorkspacePlayerSection.card
        ? WorkspacePlayerSectionDocument(
            player: player,
            clubId: clubId,
            teamId: teamId,
            teamName: teamName,
            section: file.section,
            currentUserId: currentUserId,
            onRefresh: onRefresh,
          )
        : WorkspacePlayerSectionBrowser(
            player: player,
            clubId: clubId,
            teamId: teamId,
            teamName: teamName,
            section: file.section,
            createOnOpen: createNote,
            currentUserId: currentUserId,
            onRefresh: onRefresh,
          );

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(child: child),
        ),
        transitionsBuilder: (_, animation, __, routeChild) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(.018, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: routeChild,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 620;
        final showSummary = constraints.maxWidth >= 900;

        return ColoredBox(
          color: Colors.white,
          child: Column(
            children: [
              _ProjectHeader(
                playerName: _playerName,
                teamName: teamName,
                position: _position,
                number: _number,
                player: player,
                onBack: onClose ?? () => Navigator.of(context).maybePop(),
                onOpenLegacyProfile: onOpenLegacyProfile,
                compact: mobile,
              ),
              const Divider(height: 1, color: _line),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          mobile ? 12 : 24,
                          mobile ? 16 : 24,
                          mobile ? 12 : 24,
                          18,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const _PlayerSectionMark(size: 28),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Рабочее пространство игрока', style: AppTypography.sectionTitle(color: _text)),
                                      const SizedBox(height: 2),
                                      Text('Все данные и заметки собраны по смыслу', style: AppTypography.secondary(color: _muted)),
                                    ],
                                  ),
                                ),
                                Text('${_files.length} разделов', style: AppTypography.caption(color: _muted)),
                              ],
                            ),
                            SizedBox(height: mobile ? 12 : 18),
                            Expanded(
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: _files.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, indent: 52, color: _line),
                                itemBuilder: (_, index) {
                                  final file = _files[index];
                                  return _PlayerFileTile(
                                    file: file,
                                    compact: mobile,
                                    onTap: () => _openSection(context, file),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showSummary) ...[
                      Container(width: 1, color: _line),
                      SizedBox(
                        width: 292,
                        child: _PlayerWorkspaceSummary(
                          playerName: _playerName,
                          teamName: teamName,
                          position: _position,
                          number: _number,
                          onNewNote: () => _openSection(
                            context,
                            _files.firstWhere((file) => file.section == WorkspacePlayerSection.diary),
                            createNote: true,
                          ),
                          onOpenProfile: () => _openSection(context, _files.first),
                          onOpenLegacyProfile: onOpenLegacyProfile,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: _line)),
                ),
                child: Row(
                  children: [
                    Text('${_files.length} разделов', style: AppTypography.caption(color: _muted)),
                    const Spacer(),
                    Text('SPORTOTEKA OS · PLAYER', style: AppTypography.menuGroup(color: _muted)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.playerName,
    required this.teamName,
    required this.position,
    required this.number,
    required this.player,
    required this.onBack,
    required this.compact,
    this.onOpenLegacyProfile,
  });

  final String playerName;
  final String teamName;
  final String position;
  final String number;
  final Map<String, dynamic> player;
  final VoidCallback onBack;
  final bool compact;
  final VoidCallback? onOpenLegacyProfile;

  @override
  Widget build(BuildContext context) {
    final photo = '${player['photo'] ?? player['photo_url'] ?? player['avatar'] ?? ''}'.trim();
    final subtitle = <String>[
      if (teamName.trim().isNotEmpty) teamName.trim(),
      if (position.isNotEmpty) position,
      if (number.isNotEmpty) '№$number',
    ].join(' · ');

    return Container(
      height: compact ? 62 : 72,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Назад',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 20, color: SportotekaPlayerProjectScreen._text),
          ),
          const SizedBox(width: 3),
          _PlayerAvatar(photo: photo, name: playerName, size: compact ? 38 : 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.screenTitle(color: SportotekaPlayerProjectScreen._text),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.secondary(color: SportotekaPlayerProjectScreen._muted),
                  ),
                ],
              ],
            ),
          ),
          if (!compact && onOpenLegacyProfile != null)
            TextButton(
              onPressed: onOpenLegacyProfile,
              child: Text('Классический профиль', style: AppTypography.action(color: SportotekaPlayerProjectScreen._muted)),
            ),
        ],
      ),
    );
  }
}

class _PlayerFileTile extends StatefulWidget {
  const _PlayerFileTile({
    required this.file,
    required this.compact,
    required this.onTap,
  });

  final _PlayerProjectFile file;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_PlayerFileTile> createState() => _PlayerFileTileState();
}

class _PlayerFileTileState extends State<_PlayerFileTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onHover: (value) => setState(() => _hovered = value),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 10, vertical: widget.compact ? 7 : 8),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF4F7F5) : Colors.white,
          ),
          child: Row(
            children: [
              _SectionMosaicMark(glyph: widget.file.glyph, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.file.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: SportotekaPlayerProjectScreen._text)),
                    const SizedBox(height: 2),
                    Text(widget.file.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: SportotekaPlayerProjectScreen._muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 17, color: SportotekaPlayerProjectScreen._muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerSectionMark extends StatelessWidget {
  const _PlayerSectionMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(2),
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        children: List.generate(9, (index) {
          final strong = index == 1 || index == 4 || index == 8;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: strong ? const Color(0xFF0B8F55) : const Color(0xFFD7E5DD),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

class _SectionMosaicMark extends StatelessWidget {
  const _SectionMosaicMark({required this.glyph, required this.size});

  final _ProjectGlyph glyph;
  final double size;

  @override
  Widget build(BuildContext context) {
    final active = <int>{4, glyph.index % 9, (glyph.index * 2 + 1) % 9};
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .22),
      decoration: const BoxDecoration(color: Color(0xFFF1F4F2), shape: BoxShape.circle),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 2.4,
        crossAxisSpacing: 2.4,
        children: List.generate(9, (index) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: active.contains(index) ? const Color(0xFF0B8F55) : const Color(0xFFC7D2CC),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

class _PlayerWorkspaceSummary extends StatelessWidget {
  const _PlayerWorkspaceSummary({
    required this.playerName,
    required this.teamName,
    required this.position,
    required this.number,
    required this.onNewNote,
    required this.onOpenProfile,
    this.onOpenLegacyProfile,
  });

  final String playerName;
  final String teamName;
  final String position;
  final String number;
  final VoidCallback onNewNote;
  final VoidCallback onOpenProfile;
  final VoidCallback? onOpenLegacyProfile;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF6F7F6),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          const _BrandDots(),
          const SizedBox(height: 18),
          Text('РАБОЧАЯ КАРТОЧКА', style: AppTypography.menuGroup(color: SportotekaPlayerProjectScreen._muted)),
          const SizedBox(height: 7),
          Text(playerName, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.sectionTitle(color: SportotekaPlayerProjectScreen._text)),
          const SizedBox(height: 18),
          _SummaryValue(label: 'Команда', value: teamName),
          _SummaryValue(label: 'Амплуа', value: position),
          _SummaryValue(label: 'Номер', value: number.isEmpty ? '' : '№$number'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onNewNote,
            style: FilledButton.styleFrom(
              backgroundColor: SportotekaPlayerProjectScreen._green,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Новая заметка', style: AppTypography.actionStrong(color: Colors.white)),
          ),
          const SizedBox(height: 7),
          TextButton(
            onPressed: onOpenProfile,
            child: Text('Открыть карточку', style: AppTypography.actionStrong(color: SportotekaPlayerProjectScreen._green)),
          ),
          if (onOpenLegacyProfile != null)
            TextButton(
              onPressed: onOpenLegacyProfile,
              child: Text('Исходный профиль', style: AppTypography.action(color: SportotekaPlayerProjectScreen._muted)),
            ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: SportotekaPlayerProjectScreen._line),
          const SizedBox(height: 16),
          Text(
            'Созданные и скопированные записи сохраняются внутри выбранного раздела игрока.',
            style: AppTypography.caption(color: SportotekaPlayerProjectScreen._muted).copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: AppTypography.caption(color: SportotekaPlayerProjectScreen._muted))),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.secondaryMedium(color: SportotekaPlayerProjectScreen._text),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandDots extends StatelessWidget {
  const _BrandDots({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 5.0 : 6.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: index == 1 ? const Color(0xFF17A36A) : const Color(0xFFB8D9C6),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.photo, required this.name, required this.size});
  final String photo;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final uri = _absolutePhoto(photo);
    if (uri.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          uri,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e.substring(0, 1).toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Color(0xFFEAF5EF), shape: BoxShape.circle),
      child: Text(initials.isEmpty ? 'И' : initials, style: AppTypography.menuTitle(color: SportotekaPlayerProjectScreen._green)),
    );
  }

  String _absolutePhoto(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('/')) return 'https://sportotekaapp.ru$value';
    if (value.startsWith('uploads/')) return 'https://sportotekaapp.ru/$value';
    return 'https://sportotekaapp.ru/uploads/$value';
  }
}

enum _ProjectGlyph { card, diary, readiness, activity, matches, testing, health, documents }

class _ProjectGlyphIcon extends StatelessWidget {
  const _ProjectGlyphIcon({required this.glyph, required this.folderLike, required this.size});
  final _ProjectGlyph glyph;
  final bool folderLike;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ProjectGlyphPainter(glyph: glyph, folderLike: folderLike),
      ),
    );
  }
}

class _ProjectGlyphPainter extends CustomPainter {
  const _ProjectGlyphPainter({required this.glyph, required this.folderLike});
  final _ProjectGlyph glyph;
  final bool folderLike;

  @override
  void paint(Canvas canvas, Size size) {
    final green = Paint()
      ..color = SportotekaPlayerProjectScreen._green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final graphite = Paint()
      ..color = const Color(0xFF253029)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final soft = Paint()
      ..color = const Color(0xFFF0F7F3)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(size.width * .08, size.height * .13, size.width * .84, size.height * .72);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(size.width * .12));
    canvas.drawRRect(rr, soft);

    if (folderLike) {
      final path = Path()
        ..moveTo(size.width * .16, size.height * .35)
        ..lineTo(size.width * .16, size.height * .25)
        ..lineTo(size.width * .43, size.height * .25)
        ..lineTo(size.width * .51, size.height * .34)
        ..lineTo(size.width * .84, size.height * .34)
        ..lineTo(size.width * .84, size.height * .73)
        ..lineTo(size.width * .16, size.height * .73)
        ..close();
      canvas.drawPath(path, graphite);
    } else {
      final doc = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .23, size.height * .19, size.width * .54, size.height * .62),
        Radius.circular(size.width * .06),
      );
      canvas.drawRRect(doc, graphite);
      canvas.drawLine(Offset(size.width * .34, size.height * .34), Offset(size.width * .66, size.height * .34), green);
    }

    switch (glyph) {
      case _ProjectGlyph.card:
        canvas.drawCircle(Offset(size.width * .5, size.height * .49), size.width * .08, green);
        canvas.drawArc(Rect.fromCenter(center: Offset(size.width * .5, size.height * .66), width: size.width * .3, height: size.height * .2), 3.35, 2.72, false, green);
        break;
      case _ProjectGlyph.diary:
        canvas.drawLine(Offset(size.width * .35, size.height * .5), Offset(size.width * .65, size.height * .5), green);
        canvas.drawLine(Offset(size.width * .35, size.height * .61), Offset(size.width * .59, size.height * .61), green);
        break;
      case _ProjectGlyph.readiness:
        final p = Path()
          ..moveTo(size.width * .31, size.height * .57)
          ..lineTo(size.width * .42, size.height * .57)
          ..lineTo(size.width * .48, size.height * .43)
          ..lineTo(size.width * .55, size.height * .65)
          ..lineTo(size.width * .62, size.height * .53)
          ..lineTo(size.width * .69, size.height * .53);
        canvas.drawPath(p, green);
        break;
      case _ProjectGlyph.activity:
        canvas.drawArc(Rect.fromCenter(center: Offset(size.width * .5, size.height * .56), width: size.width * .32, height: size.height * .32), 0.4, 5.1, false, green);
        break;
      case _ProjectGlyph.matches:
        canvas.drawCircle(Offset(size.width * .5, size.height * .57), size.width * .13, green);
        canvas.drawLine(Offset(size.width * .42, size.height * .48), Offset(size.width * .58, size.height * .66), green);
        canvas.drawLine(Offset(size.width * .58, size.height * .48), Offset(size.width * .42, size.height * .66), green);
        break;
      case _ProjectGlyph.testing:
        canvas.drawLine(Offset(size.width * .34, size.height * .65), Offset(size.width * .34, size.height * .53), green);
        canvas.drawLine(Offset(size.width * .49, size.height * .65), Offset(size.width * .49, size.height * .43), green);
        canvas.drawLine(Offset(size.width * .64, size.height * .65), Offset(size.width * .64, size.height * .36), green);
        break;
      case _ProjectGlyph.health:
        canvas.drawLine(Offset(size.width * .5, size.height * .43), Offset(size.width * .5, size.height * .64), green);
        canvas.drawLine(Offset(size.width * .39, size.height * .535), Offset(size.width * .61, size.height * .535), green);
        break;
      case _ProjectGlyph.documents:
        canvas.drawLine(Offset(size.width * .35, size.height * .48), Offset(size.width * .67, size.height * .48), green);
        canvas.drawLine(Offset(size.width * .35, size.height * .58), Offset(size.width * .62, size.height * .58), green);
        break;
      }
  }

  @override
  bool shouldRepaint(covariant _ProjectGlyphPainter oldDelegate) => oldDelegate.glyph != glyph || oldDelegate.folderLike != folderLike;
}

class _PlayerProjectFile {
  const _PlayerProjectFile({
    required this.section,
    required this.title,
    required this.subtitle,
    required this.glyph,
    this.folderLike = false,
  });
  final WorkspacePlayerSection section;
  final String title;
  final String subtitle;
  final _ProjectGlyph glyph;
  final bool folderLike;
}
