import 'package:flutter/material.dart';

import 'cmr_player_profile_screen.dart';

/// Совместимая точка входа для старых экранов приложения.
/// GlobalSearchScreen и другие существующие вызовы могут продолжать
/// использовать PlayerProfileScreen(player: ...).
class PlayerProfileScreen extends StatelessWidget {
  const PlayerProfileScreen({
    super.key,
    required this.player,
    this.embeddedInWorkspace = false,
    this.onClose,
    this.onEdit,
    this.onMessage,
  });

  final Map<String, dynamic> player;
  final bool embeddedInWorkspace;
  final VoidCallback? onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    return CmrPlayerProfileScreen(
      player: player,
      embeddedInWorkspace: embeddedInWorkspace,
      onClose: onClose,
      onEdit: onEdit,
      onMessage: onMessage,
    );
  }
}
