import 'dart:convert';

import 'package:flutter/material.dart';

import '../flutter_3d_pro_screen.dart';
import '../training_graphics_state.dart';

/// Backward-compatible wrapper for the former Unity screen.
/// No Unity runtime is used anymore: the supplied tactical JSON is opened in
/// the native Flutter presentation renderer.
@Deprecated('Unity was removed. Use SportotekaFlutter3DProScreen.')
class UnityTrainingScreen extends StatefulWidget {
  const UnityTrainingScreen({
    super.key,
    required this.initialSchemeJson,
    required this.teamName,
  });

  final String initialSchemeJson;
  final String teamName;

  @override
  State<UnityTrainingScreen> createState() => _UnityTrainingScreenState();
}

class _UnityTrainingScreenState extends State<UnityTrainingScreen> {
  late final TgState _state;

  @override
  void initState() {
    super.initState();
    _state = TgState(teamId: 0, teamName: widget.teamName);
    try {
      final decoded = jsonDecode(widget.initialSchemeJson);
      if (decoded is Map) {
        _state.loadFromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // A malformed legacy payload should still open a clean 3D field.
    }
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
      teamName: widget.teamName,
    );
  }
}
