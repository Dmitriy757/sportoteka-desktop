import 'package:flutter/material.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'video_lessons_screen.dart';

class _VideoLessonsPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);

  static const lightGreen = Color(0xFFE8F5E9);
  static const superLightGreen = Color(0xFFF2FFF5);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);

  static const background = Color(0xFFF8F9FA);
  static const border = Color(0xFFE5E7EB);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class MyVideoLessonsScreen extends StatefulWidget {
  const MyVideoLessonsScreen({super.key});

  @override
  State<MyVideoLessonsScreen> createState() => _MyVideoLessonsScreenState();
}

class _MyVideoLessonsScreenState extends State<MyVideoLessonsScreen> {
  bool _loading = true;
  int _userId = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await PrefUtils.getUserId();
    _userId = id ?? 0;

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Widget _buildMetricChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _VideoLessonsPalette.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _VideoLessonsPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: _VideoLessonsPalette.primaryGreen,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: _VideoLessonsPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _VideoLessonsPalette.primaryGreen.withOpacity(0.12),
            _VideoLessonsPalette.superLightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _VideoLessonsPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: _VideoLessonsPalette.greenGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Мои видеоуроки',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: _VideoLessonsPalette.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ваши личные уроки и тренировки',
                      style: TextStyle(
                        color: _VideoLessonsPalette.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _VideoLessonsPalette.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _VideoLessonsPalette.border),
                ),
                child: const Text(
                  'Мои уроки',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: _VideoLessonsPalette.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetricChip(Icons.folder_copy_rounded, 'Личные папки'),
              _buildMetricChip(Icons.play_circle_fill_rounded, 'Мои уроки'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: _VideoLessonsPalette.background,
        child: const Center(
          child: CircularProgressIndicator(
            color: _VideoLessonsPalette.primaryGreen,
          ),
        ),
      );
    }

    if (_userId <= 0) {
      return Container(
        color: _VideoLessonsPalette.background,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _VideoLessonsPalette.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _VideoLessonsPalette.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_off_rounded,
                  size: 48,
                  color: _VideoLessonsPalette.textMuted,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Пользователь не найден',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: _VideoLessonsPalette.text,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Перезайдите в аккаунт',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _VideoLessonsPalette.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    gradient: _VideoLessonsPalette.greenGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextButton(
                    onPressed: _init,
                    child: const Text(
                      'Повторить',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: _VideoLessonsPalette.background,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: _buildHeaderCard(),
            ),
          ];
        },
        body: VideoLessonsScreen(
          ownerUserId: _userId,
          ownerName: 'Мои видеоуроки',
          isMyMode: true,
          embedded: true,
        ),
      ),
    );
  }
}