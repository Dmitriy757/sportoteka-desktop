import 'package:flutter/material.dart';

import '../flutter_3d_pro_screen.dart';
import '../training_graphics_state.dart';

/// Legacy entry point kept only so older callers continue to compile.
/// 3D is now rendered natively by Flutter Canvas in SportotekaFlutter3DProScreen.
@Deprecated('Use SportotekaFlutter3DProScreen from flutter_3d_pro_screen.dart')
class Field3DScreen extends StatefulWidget {
  const Field3DScreen({super.key});

  @override
  State<Field3DScreen> createState() => _Field3DScreenState();
}

class _Field3DScreenState extends State<Field3DScreen> {
  late final TgState _state;

  @override
  void initState() {
    super.initState();
    _state = TgState(teamId: 0, teamName: '');
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SportotekaFlutter3DProScreen(
      state: _state,
      teamName: 'Режим «Стадион»',
    );
  }
}
