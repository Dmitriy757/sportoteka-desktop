import 'package:flutter/material.dart';

class PlayerSkillsFifaStub extends StatelessWidget {
  final String playerName;
  final String position; // "ST", "CM" и т.п.
  final String clubName;
  final String? photoUrl;

  // Пока нули, позже подашь реальные значения
  final int pace;
  final int shooting;
  final int passing;
  final int dribbling;
  final int defending;
  final int physical;

  const PlayerSkillsFifaStub({
    super.key,
    required this.playerName,
    required this.position,
    required this.clubName,
    this.photoUrl,
    this.pace = 0,
    this.shooting = 0,
    this.passing = 0,
    this.dribbling = 0,
    this.defending = 0,
    this.physical = 0,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Зелёная тема Sportoteka
    const primary = Color(0xFF00A750);
    const primaryDark = Color(0xFF008C40);

    final overall = _calcOverall([
      pace,
      shooting,
      passing,
      dribbling,
      defending,
      physical,
    ]);

    return Column(
      children: [
        // ======= Большая “карточка FIFA” =======
        _FifaCard(
          primary: primary,
          primaryDark: primaryDark,
          photoUrl: photoUrl,
          playerName: playerName,
          position: position,
          clubName: clubName,
          overall: overall,
          pace: pace,
          shooting: shooting,
          passing: passing,
          dribbling: dribbling,
          defending: defending,
          physical: physical,
        ),

        const SizedBox(height: 12),

        // ======= Детализация с прогресс-барами =======
        _SectionCard(
          title: "Профиль навыков",
          subtitle: "Пока заглушка. Скоро будет рассчитываться из тренировок и игр.",
          child: Column(
            children: const [
              _SkillRow(label: "Скорость (PACE)", value: 0),
              SizedBox(height: 10),
              _SkillRow(label: "Удары (SHO)", value: 0),
              SizedBox(height: 10),
              _SkillRow(label: "Пасы (PAS)", value: 0),
              SizedBox(height: 10),
              _SkillRow(label: "Дриблинг (DRI)", value: 0),
              SizedBox(height: 10),
              _SkillRow(label: "Защита (DEF)", value: 0),
              SizedBox(height: 10),
              _SkillRow(label: "Физика (PHY)", value: 0),
            ],
          ),
        ),

        const SizedBox(height: 12),

        _SectionCard(
          title: "Сильные стороны",
          subtitle: "Здесь появятся “перки” на основе статистики.",
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _TagChip(text: "Финишер 0"),
              _TagChip(text: "Плеймейкер 0"),
              _TagChip(text: "Лидерство 0"),
              _TagChip(text: "Выносливость 0"),
              _TagChip(text: "Отбор 0"),
            ],
          ),
        ),
      ],
    );
  }

  int _calcOverall(List<int> values) {
    if (values.isEmpty) return 0;
    final sum = values.fold<int>(0, (a, b) => a + b);
    return (sum / values.length).round();
  }
}

class _FifaCard extends StatelessWidget {
  final Color primary;
  final Color primaryDark;
  final String? photoUrl;
  final String playerName;
  final String position;
  final String clubName;

  final int overall;
  final int pace, shooting, passing, dribbling, defending, physical;

  const _FifaCard({
    required this.primary,
    required this.primaryDark,
    required this.photoUrl,
    required this.playerName,
    required this.position,
    required this.clubName,
    required this.overall,
    required this.pace,
    required this.shooting,
    required this.passing,
    required this.dribbling,
    required this.defending,
    required this.physical,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.72,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withOpacity(0.96),
              primaryDark.withOpacity(0.95),
              const Color(0xFF0B1B42).withOpacity(0.95), // чуть “премиум” глубины
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -40,
              child: _GlowCircle(color: Colors.white.withOpacity(0.10), size: 140),
            ),
            Positioned(
              bottom: -55,
              left: -55,
              child: _GlowCircle(color: primary.withOpacity(0.25), size: 170),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  // верх
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _OverallBadge(overall: overall),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TinyPill(text: position, bg: Colors.white.withOpacity(0.16)),
                          const SizedBox(height: 6),
                          _TinyPill(text: clubName, bg: Colors.white.withOpacity(0.10)),
                        ],
                      ),
                      const Spacer(),
                      Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.80), size: 22),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // аватар
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: (photoUrl == null || photoUrl!.isEmpty)
                              ? Icon(Icons.person, color: Colors.white.withOpacity(0.70), size: 72)
                              : Image.network(
                                  photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.person,
                                    color: Colors.white.withOpacity(0.70),
                                    size: 72,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    playerName.isEmpty ? "Игрок" : playerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(child: _CardStatLine(label: "PAC", value: pace)),
                      const SizedBox(width: 8),
                      Expanded(child: _CardStatLine(label: "SHO", value: shooting)),
                      const SizedBox(width: 8),
                      Expanded(child: _CardStatLine(label: "PAS", value: passing)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _CardStatLine(label: "DRI", value: dribbling)),
                      const SizedBox(width: 8),
                      Expanded(child: _CardStatLine(label: "DEF", value: defending)),
                      const SizedBox(width: 8),
                      Expanded(child: _CardStatLine(label: "PHY", value: physical)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _OverallBadge extends StatelessWidget {
  final int overall;
  const _OverallBadge({required this.overall});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.16),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Column(
        children: [
          Text(
            overall.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "OVR",
            style: TextStyle(
              color: Colors.white.withOpacity(0.80),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  final String text;
  final Color bg;
  const _TinyPill({required this.text, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        text.isEmpty ? "—" : text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withOpacity(0.92),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CardStatLine extends StatelessWidget {
  final String label;
  final int value;

  const _CardStatLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.86),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          Text(
            value.toString().padLeft(2, "0"),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.black.withOpacity(0.55),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  final String label;
  final int value;

  const _SkillRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF00A750);
    final v = value.clamp(0, 99);
    final p = v / 99.0;

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 10,
              backgroundColor: Colors.black.withOpacity(0.06),
              valueColor: const AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text(
            v.toString(),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  const _TagChip({required this.text});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF00A750);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primary.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
