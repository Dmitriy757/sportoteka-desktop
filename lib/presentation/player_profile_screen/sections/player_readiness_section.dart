import 'package:flutter/material.dart';

import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

class PlayerReadinessSection extends StatelessWidget {
  final PlayerProfileSnapshot data;
  final VoidCallback onOpenDetails;

  const PlayerReadinessSection({
    super.key,
    required this.data,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final readiness = data.readiness;
    if (readiness == null) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(
          child: PpEmpty(
            title: 'Данных готовности пока нет',
            text: 'После сохранения GPS-сессий здесь появится расчёт нагрузки',
          ),
        ),
      );
    }

    final accent = _accent(readiness.score);
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Row(
            children: [
              PpDot(color: accent, size: 7),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Готовность', style: PpText.title(18)),
                    const SizedBox(height: 3),
                    Text(
                      'Состояние · восстановление · нагрузка 7 / 28 дней',
                      style: PpText.body(10.2),
                    ),
                  ],
                ),
              ),
              const PpDotCluster(),
            ],
          ),
          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),
          _statusCard(readiness, accent),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final load = _loadCard(readiness);
              final checkin = _checkinCard(readiness);
              if (constraints.maxWidth >= 820) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: load),
                    const SizedBox(width: 10),
                    Expanded(child: checkin),
                  ],
                );
              }
              return Column(
                children: [
                  load,
                  const SizedBox(height: 10),
                  checkin,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          _recommendations(readiness),
          const SizedBox(height: 10),
          PpActionRow(
            icon: Icons.insights_rounded,
            title: 'Открыть подробную аналитику готовности',
            subtitle: 'Графики нагрузки, история анкет и динамика восстановления',
            onTap: onOpenDetails,
          ),
        ],
      ),
    );
  }

  Widget _statusCard(PlayerReadinessSummary value, Color accent) {
    return PpSurface(
      color: _background(value.score),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PpSectionTitle(
            title: 'Статус на сегодня',
            subtitle: 'Расчёт на ${value.referenceDate}',
            dotColor: accent,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(.22)),
                ),
                child: Text(
                  '${value.score.round()}',
                  style: PpText.value(24).copyWith(color: accent),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value.label, style: PpText.title(15)),
                    const SizedBox(height: 5),
                    Text(
                      value.recommendations.first,
                      style: PpText.body(10.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: width,
                    child: PpMetric(
                      label: 'Объективно',
                      value: '${value.objectiveScore.round()}',
                      note: 'GPS и нагрузка',
                      dotColor: PpColors.greenDark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: PpMetric(
                      label: 'Самочувствие',
                      value: value.hasCheckin
                          ? '${value.subjectiveScore.round()}'
                          : '—',
                      note: value.hasCheckin ? 'анкета игрока' : 'анкета не заполнена',
                      dotColor: PpColors.amber,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _loadCard(PlayerReadinessSummary value) {
    final risky = (value.ratio ?? 0) > 1.3;
    return PpSurface(
      color: PpColors.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PpSectionTitle(
            title: 'Нагрузка',
            subtitle: 'Короткое и среднее окно',
            dotColor: PpColors.greenDark,
          ),
          const SizedBox(height: 8),
          _row('7 дней', value.acute7.toStringAsFixed(0), PpColors.green),
          _row('Среднее за неделю / 28 дней', value.chronicWeek.toStringAsFixed(0), PpColors.greenDark),
          _row('Отношение 7 / 28', value.ratio?.toStringAsFixed(2) ?? '—', risky ? PpColors.red : PpColors.amber),
          _row('Сессий за 7 дней', '${value.sessions7}', PpColors.green),
          _row('Сессий за 28 дней', '${value.sessions28}', PpColors.greenDark, last: true),
        ],
      ),
    );
  }

  Widget _checkinCard(PlayerReadinessSummary value) {
    return PpSurface(
      color: PpColors.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PpSectionTitle(
            title: 'Анкета игрока',
            subtitle: value.hasCheckin
                ? 'Самооценка учтена в расчёте'
                : 'Сегодня ещё не заполнена',
            dotColor: value.hasCheckin ? PpColors.green : PpColors.amber,
          ),
          const SizedBox(height: 8),
          _row('Сон', value.hasCheckin ? '${value.sleepHours.toStringAsFixed(1)} ч' : '—', PpColors.greenDark),
          _row('Усталость', value.hasCheckin ? '${value.fatigue}/5' : '—', PpColors.amber),
          _row('Боль', value.hasCheckin ? '${value.pain}/10' : '—', value.pain >= 5 ? PpColors.red : PpColors.green),
          _row('RPE', value.hasCheckin && value.rpe > 0 ? '${value.rpe}/10' : '—', PpColors.amber, last: true),
          if (!value.hasCheckin) ...[
            const SizedBox(height: 8),
            Text(
              'Пока статус рассчитан только по данным GPS. Игрок может заполнить сон, усталость, боль и RPE в анкете готовности.',
              style: PpText.caption(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recommendations(PlayerReadinessSummary value) {
    return PpSurface(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PpSectionTitle(
            title: 'Рекомендации',
            subtitle: 'Для тренера и медицинского специалиста',
            dotColor: PpColors.amber,
          ),
          const SizedBox(height: 7),
          ...value.recommendations.asMap().entries.map(
                (entry) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: PpDot.amber(size: 6),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(entry.value, style: PpText.body(10.6)),
                          ),
                        ],
                      ),
                    ),
                    if (entry.key != value.recommendations.length - 1)
                      const PpThinDivider(margin: EdgeInsets.zero),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value,
    Color color, {
    bool last = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              PpDot(color: color, size: 5.5),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: PpText.body(10.6))),
              Text(
                value,
                style: PpText.body(
                  10.6,
                  color: PpColors.text,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!last) const PpThinDivider(margin: EdgeInsets.zero),
      ],
    );
  }

  Color _accent(double score) {
    if (score >= 80) return PpColors.green;
    if (score >= 60) return PpColors.amber;
    return PpColors.red;
  }

  Color _background(double score) {
    if (score >= 80) return PpColors.greenSoft2;
    if (score >= 60) return PpColors.amberGlass;
    return PpColors.redGlass;
  }
}
