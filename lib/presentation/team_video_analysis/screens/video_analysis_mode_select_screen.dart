import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/presentation/team_video_analysis/video_match_review_screen.dart';
import 'package:sportoteka/presentation/team_video_analysis/screens/video_match_review_simple_screen.dart';

class VideoAnalysisModeSelectScreen extends StatelessWidget {
  final int matchId;
  final int teamId;
  final String teamName;
  final int coachId;
  final String matchTitle;
  final String videoUrl;

  const VideoAnalysisModeSelectScreen({
    super.key,
    required this.matchId,
    required this.teamId,
    required this.teamName,
    required this.coachId,
    required this.matchTitle,
    required this.videoUrl,
  });

  void _openProMode() {
    Get.to(
      () => VideoMatchReviewScreen(
        matchId: matchId,
        teamId: teamId,
        teamName: teamName,
        coachId: coachId,
        matchTitle: matchTitle,
        videoUrl: videoUrl,
      ),
      transition: Transition.rightToLeft,
    );
  }

  void _openSimpleMode() {
    Get.to(
      () => VideoMatchReviewSimpleScreen(
        matchId: matchId,
        teamId: teamId,
        teamName: teamName,
        coachId: coachId,
        matchTitle: matchTitle,
        videoUrl: videoUrl,
      ),
      transition: Transition.rightToLeft,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7FB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Выбор режима анализа',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                isTablet ? 24 : 16,
                8,
                isTablet ? 24 : 16,
                24,
              ),
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 24 : 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F172A),
                        Color(0xFF1E293B),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        matchTitle,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        teamName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Выберите формат работы с видео. Можно открыть полный профессиональный разбор или быстрый режим для оперативной постановки ТТД.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.86),
                          fontSize: isTablet ? 14 : 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                _modeCard(
                  icon: Icons.auto_awesome_rounded,
                  iconBg: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF2563EB),
                  title: 'Pro анализ',
                  subtitle: 'Полный режим для детального разбора матча',
                  bullets: const [
                    'AI-анализ и трекинг игроков',
                    'Heatmap и работа с эпизодами',
                    'ТТД-панель и подробный разбор',
                    'Отчёты и расширенная аналитика',
                  ],
                  buttonText: 'Открыть Pro режим',
                  buttonColor: const Color(0xFF2563EB),
                  onTap: _openProMode,
                ),

                const SizedBox(height: 16),

                _modeCard(
                  icon: Icons.flash_on_rounded,
                  iconBg: const Color(0xFFD1FAE5),
                  iconColor: const Color(0xFF059669),
                  title: 'Быстрый анализ',
                  subtitle: 'Упрощённый режим для тренера',
                  bullets: const [
                    'Видео + список игроков',
                    'Быстрые кнопки ТТД',
                    'Сохранение действий в один клик',
                    'Минимум лишних элементов',
                  ],
                  buttonText: 'Открыть быстрый режим',
                  buttonColor: AppColors.primaryGreen,
                  onTap: _openSimpleMode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<String> bullets,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          ...bullets.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}