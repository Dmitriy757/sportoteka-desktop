import 'package:flutter/material.dart';
import 'help_detail_screen.dart';
import 'help_repository.dart';

class TipsSection extends StatelessWidget {
  final double cardWidth;
  final double cardHeight;
  final double borderRadius;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final double shadowOpacity;
  final double shadowBlur;
  final bool grid;

  const TipsSection({
    super.key,
    required this.cardWidth,
    required this.cardHeight,
    required this.borderRadius,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.shadowOpacity,
    required this.shadowBlur,
    this.grid = false,
  });

  @override
  Widget build(BuildContext context) {
    final tips = HelpRepository.allTips;

    if (grid) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = _gridColumns(width);
          final spacing = width >= 760 ? 16.0 : 12.0;
          final gridCardHeight = _gridCardHeight(width);
          final itemWidth = (width - (spacing * (columns - 1))) / columns;
          final ratio = itemWidth / gridCardHeight;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tips.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: ratio,
            ),
            itemBuilder: (context, index) {
              return _TipCard(
                tip: tips[index],
                borderRadius: borderRadius,
                cardColor: cardColor,
                textColor: textColor,
                mutedColor: mutedColor,
                shadowOpacity: shadowOpacity,
                shadowBlur: shadowBlur,
                compact: itemWidth < 190,
              );
            },
          );
        },
      );
    }

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tips.length,
        itemBuilder: (context, index) {
          final tip = tips[index];

          return Padding(
            padding: EdgeInsets.only(right: index == tips.length - 1 ? 0 : 16),
            child: SizedBox(
              width: cardWidth,
              child: _TipCard(
                tip: tip,
                borderRadius: borderRadius,
                cardColor: cardColor,
                textColor: textColor,
                mutedColor: mutedColor,
                shadowOpacity: shadowOpacity,
                shadowBlur: shadowBlur,
              ),
            ),
          );
        },
      ),
    );
  }

  int _gridColumns(double width) {
    if (width >= 760) return 4;
    if (width >= 520) return 2;
    return 1;
  }

  double _gridCardHeight(double width) {
    if (width >= 760) return 176;
    if (width >= 520) return 166;
    return 150;
  }
}

class _TipCard extends StatelessWidget {
  final dynamic tip;
  final double borderRadius;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final double shadowOpacity;
  final double shadowBlur;
  final bool compact;

  const _TipCard({
    required this.tip,
    required this.borderRadius,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.shadowOpacity,
    required this.shadowBlur,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HelpDetailScreen(helpId: tip.id),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(shadowOpacity),
                blurRadius: shadowBlur,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: tip.accent.withOpacity(0.10),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -12,
                right: -12,
                child: Container(
                  width: compact ? 62 : 72,
                  height: compact ? 62 : 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tip.accent.withOpacity(0.08),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 14 : 16),
                child: compact ? _buildCompactContent() : _buildRegularContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegularContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iconBox(48, 24),
        const Spacer(),
        _titleText(fontSize: 16, maxLines: 2),
        const SizedBox(height: 8),
        _subtitleText(fontSize: 13, maxLines: 2),
        const SizedBox(height: 12),
        _openRow(),
      ],
    );
  }

  Widget _buildCompactContent() {
    return Row(
      children: [
        _iconBox(46, 23),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titleText(fontSize: 14.5, maxLines: 1),
              const SizedBox(height: 5),
              _subtitleText(fontSize: 12, maxLines: 2),
              const SizedBox(height: 8),
              _openRow(compact: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconBox(double size, double iconSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tip.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        tip.icon,
        color: tip.accent,
        size: iconSize,
      ),
    );
  }

  Widget _titleText({required double fontSize, required int maxLines}) {
    return Text(
      tip.title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: textColor,
        height: 1.15,
      ),
    );
  }

  Widget _subtitleText({required double fontSize, required int maxLines}) {
    return Text(
      tip.subtitle,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        color: mutedColor,
        height: 1.25,
      ),
    );
  }

  Widget _openRow({bool compact = false}) {
    return Row(
      children: [
        Text(
          'Открыть',
          style: TextStyle(
            fontSize: compact ? 12.5 : 13,
            fontWeight: FontWeight.w800,
            color: tip.accent,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.chevron_right_rounded,
          color: tip.accent,
          size: compact ? 20 : 24,
        ),
      ],
    );
  }
}
