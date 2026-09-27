// lib/presentation/reels_screen/user_reels_screen.dart
//
// Просмотр Reels конкретного пользователя теперь использует тот же экран,
// что и основная лента Reels. Это важно: один и тот же рендер видео,
// rotation/crop/scale/dx/dy, лайки, комментарии, ответы, просмотры и Share.
// Так профиль больше не воспроизводит ролик "по-своему" и не обрезает его.

import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/reels_screen/reels_screen.dart';

class UserReelsScreen extends StatelessWidget {
  final int userId;
  final int initialIndex;
  final int? initialReelId;
  final String title;

  const UserReelsScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
    this.initialReelId,
    this.title = 'Reels пользователя',
  });

  @override
  Widget build(BuildContext context) {
    return ReelsScreen(
      userIdFilter: userId,
      initialIndex: initialIndex,
      initialReelId: initialReelId,
      title: title,
      showBackButton: true,
      allowUpload: false,
    );
  }
}
