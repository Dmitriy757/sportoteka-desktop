import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/presentation/trainer_profile_screen/cmr_trainer_profile_screen.dart';

class TrainerSelfProfilePanel extends StatefulWidget {
  final int trainerId;
  final int clubId;
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final VoidCallback? onBackToList;
  final VoidCallback? onChanged;

  const TrainerSelfProfilePanel({
    super.key,
    required this.trainerId,
    required this.clubId,
    required this.clubName,
    required this.teams,
    this.onBackToList,
    this.onChanged,
  });

  @override
  State<TrainerSelfProfilePanel> createState() =>
      _TrainerSelfProfilePanelState();
}

class _TrainerSelfProfilePanelState
    extends State<TrainerSelfProfilePanel> {
  static const String _url =
      'https://sportotekaapp.ru/api/get_trainer_profile.php';

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _trainer =
      <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(
    covariant TrainerSelfProfilePanel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.trainerId !=
            widget.trainerId ||
        oldWidget.clubId !=
            widget.clubId) {
      _load();
    }
  }

  dynamic _decode(String body) {
    try {
      final object = body.indexOf('{');
      if (object < 0) return null;
      return jsonDecode(
        body.substring(object),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    if (widget.trainerId <= 0) {
      setState(() {
        _loading = false;
        _error =
            'Не найден ID текущего тренера.';
      });
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(_url),
            headers: const <
                String, String>{
              'Content-Type':
                  'application/json; charset=utf-8',
            },
            body: jsonEncode(
              <String, dynamic>{
                'trainer_id':
                    widget.trainerId,
              },
            ),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      final decoded =
          _decode(response.body);

      if (decoded is! Map) {
        throw Exception(
          'Некорректный ответ сервера',
        );
      }

      final root =
          Map<String, dynamic>.from(
        decoded,
      );

      dynamic raw =
          root['profile'] ??
              root['trainer'] ??
              root['user'] ??
              root['data'];

      if (raw is! Map) {
        raw = root;
      }

      final profile =
          Map<String, dynamic>.from(
        raw as Map,
      );

      // Профиль самого тренера получает только его назначенные команды.
      profile['teams'] =
          widget.teams;
      profile['assigned_teams'] =
          widget.teams;
      profile['trainer_id'] =
          widget.trainerId;
      profile['user_id'] =
          widget.trainerId;

      if (!mounted) return;

      setState(() {
        _trainer = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Не удалось загрузить профиль тренера: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF00A750),
          ),
        ),
      );
    }

    if (_error != null) {
      return ColoredBox(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(20),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: <Widget>[
                Text(
                  _error!,
                  textAlign:
                      TextAlign.center,
                ),
                const SizedBox(
                  height: 10,
                ),
                TextButton(
                  onPressed: _load,
                  child:
                      const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CmrTrainerProfileScreen(
      trainer: _trainer,
      clubId: widget.clubId,
      clubName: widget.clubName,
      embeddedInWorkspace: true,
      onClose: widget.onBackToList,

      // Это всегда профиль текущего тренера.
      allowEdit: true,

      // Сам тренер не управляет кадровыми назначениями.
      onAssign: null,
      onAssignTeam: null,

      availableTeams:
          widget.teams,
      onChanged: () async {
        await _load();
        widget.onChanged?.call();
      },
    );
  }
}
