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
  });

  @override
  Widget build(BuildContext context) {
    final tips = HelpRepository.allTips;

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
              child: Material(
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
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tip.accent.withOpacity(0.08),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: tip.accent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  tip.icon,
                                  color: tip.accent,
                                  size: 24,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                tip.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tip.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: mutedColor,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    'Открыть',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: tip.accent,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: tip.accent,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}