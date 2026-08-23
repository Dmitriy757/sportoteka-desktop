import 'package:flutter/material.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import 'cmr_video_lessons_theme.dart';
import 'video_lessons_screen.dart';

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
    if (!mounted) return;
    setState(() {
      _userId = id ?? 0;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: CmrVideoColors.bg,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: CmrVideoColors.green,
            ),
          ),
        ),
      );
    }

    if (_userId <= 0) {
      return ColoredBox(
        color: CmrVideoColors.bg,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CmrVideoSurface(
                color: CmrVideoColors.soft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const CmrVideoSectionTitle(
                      title: 'Пользователь не найден',
                      subtitle: 'Перезайдите в аккаунт и повторите загрузку',
                      dotColor: CmrVideoColors.red,
                    ),
                    const SizedBox(height: 13),
                    CmrVideoTextButton(
                      label: 'Повторить',
                      primary: true,
                      onTap: _init,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: CmrVideoColors.bg,
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: Colors.white,
            child: const CmrVideoSectionTitle(
              title: 'Мои видеоуроки',
              subtitle: 'Личные папки, уроки и тренировочные материалы',
              trailing: CmrVideoDotCluster(),
            ),
          ),
          Expanded(
            child: VideoLessonsScreen(
              ownerUserId: _userId,
              ownerName: 'Мои видеоуроки',
              isMyMode: true,
              embedded: true,
            ),
          ),
        ],
      ),
    );
  }
}
