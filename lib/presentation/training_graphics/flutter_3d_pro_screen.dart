import 'package:flutter/material.dart';

import 'game_view_screen.dart';
import 'training_graphics_state.dart';

/// Backward-compatible entry point kept for older routes/imports.
/// The actual presentation renderer is now Game View.
@Deprecated('Use TrainingGraphicsGameViewScreen from game_view_screen.dart')
class SportotekaFlutter3DProScreen extends StatelessWidget {
  const SportotekaFlutter3DProScreen({
    super.key,
    required this.state,
    this.teamName = '',
  });

  final TgState state;
  final String teamName;

  @override
  Widget build(BuildContext context) {
    final name = teamName.trim().isEmpty ? state.teamName : teamName.trim();
    return TrainingGraphicsGameViewScreen(
      state: state,
      title: name.isEmpty ? 'Game View' : '$name · Game View',
    );
  }
}
