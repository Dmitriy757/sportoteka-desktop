import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'sportoteka_3d_pro_payload.dart';
import 'sportoteka_3d_pro_scene.dart';

class Sportoteka3DProLauncherButton extends StatelessWidget {
  const Sportoteka3DProLauncherButton({
    super.key,
    this.scene,
    this.clubId = 0,
    this.clubName = '',
    this.teamId = 0,
    this.teamName = '',
    this.teamLogo = '',
    this.players = const <Map<String, dynamic>>[],
    this.isLoadingPlayers = false,
  });

  final Sportoteka3DProScene? scene;
  final int clubId;
  final String clubName;
  final int teamId;
  final String teamName;
  final String teamLogo;
  final List<Map<String, dynamic>> players;
  final bool isLoadingPlayers;

  static const _green = Color(0xFF00A750);
  static const _greenDark = Color(0xFF067A46);
  static const _graphite = Color(0xFF101828);
  static const _muted = Color(0xFF667085);

  @override
  Widget build(BuildContext context) {
    final count = players.length;
    return Tooltip(
      message: count > 0
          ? 'Открыть настоящий Unity 3D: $teamName, игроков: $count'
          : 'Открыть настоящий Unity 3D. Состав загрузится из команды.',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isLoadingPlayers ? null : () => _open(context),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_green, _greenDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _green.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text(
                '3D Pro',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isLoadingPlayers
                    ? const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                      )
                    : Text(
                        count > 0 ? '$count' : 'состав',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openFromPanel(BuildContext context) => _open(context);

  Future<void> _open(BuildContext context) async {
    final payload = Sportoteka3DProPayload.fromRaw(
      clubId: clubId,
      clubName: clubName,
      teamId: teamId,
      teamName: teamName,
      teamLogo: teamLogo,
      players: players,
    );

    final file = await _writePayload(payload);

    if (!context.mounted) return;

    if (kIsWeb) {
      _showUnityNotFoundDialog(
        context,
        payloadPath: file.path,
        searched: const <String>['Web не поддерживает запуск Unity standalone'],
        error: 'Открой macOS desktop сборку Flutter: flutter run -d macos',
      );
      return;
    }

    if (Platform.isMacOS || Platform.isWindows) {
      final result = await _tryLaunchStandalone(file.path);
      if (result.started) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _graphite,
            content: Text(
              'Запускаю Unity 3D Pro. Payload: ${file.path}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        );
        return;
      }

      if (!context.mounted) return;
      _showUnityNotFoundDialog(
        context,
        payloadPath: file.path,
        searched: result.searchedPaths,
        error: result.error,
      );
      return;
    }

    _showUnityNotFoundDialog(
      context,
      payloadPath: file.path,
      searched: const <String>[
        'Android/iOS не используют macOS .app',
        'Для планшета нужен Unity Android Library / UnityPlayerActivity',
      ],
      error: 'Сейчас запущена не macOS desktop-версия. Для проверки на Mac используй: flutter run -d macos',
    );
  }

  Future<File> _writePayload(Sportoteka3DProPayload payload) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sportoteka_3d_pro_team_${payload.teamId}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload.toJson()), flush: true);
    return file;
  }

  Future<_UnityLaunchResult> _tryLaunchStandalone(String payloadPath) async {
    final searched = <String>[];

    try {
      if (Platform.isMacOS) {
        final app = _findMacAppBundle(searched);

        if (app == null) {
          return _UnityLaunchResult(
            started: false,
            searchedPaths: searched,
            error: 'Unity .app не найден. Собери Unity в unity_builds/macos/Sportoteka3DPro.app',
          );
        }

        final result = await Process.run(
          'open',
          ['-n', app.path, '--args', '--sportoteka-team-json', payloadPath],
          runInShell: false,
        );

        if (result.exitCode == 0) {
          return _UnityLaunchResult(started: true, searchedPaths: searched);
        }

        final executable = _findMacExecutable(app);
        if (executable != null) {
          final direct = await Process.start(
            executable.path,
            ['--sportoteka-team-json', payloadPath],
            mode: ProcessStartMode.detached,
          );
          if (direct.pid > 0) {
            return _UnityLaunchResult(started: true, searchedPaths: searched);
          }
        }

        return _UnityLaunchResult(
          started: false,
          searchedPaths: searched,
          error: 'open вернул exitCode=${result.exitCode}. stderr: ${result.stderr}',
        );
      }

      if (Platform.isWindows) {
        final exe = _findWindowsExecutable(searched);
        if (exe == null) {
          return _UnityLaunchResult(
            started: false,
            searchedPaths: searched,
            error: 'Unity .exe не найден. Собери Unity в unity_builds/windows/Sportoteka3DPro.exe',
          );
        }

        final p = await Process.start(
          exe.path,
          ['--sportoteka-team-json', payloadPath],
          mode: ProcessStartMode.detached,
        );

        return _UnityLaunchResult(started: p.pid > 0, searchedPaths: searched);
      }
    } catch (e) {
      return _UnityLaunchResult(started: false, searchedPaths: searched, error: e.toString());
    }

    return _UnityLaunchResult(started: false, searchedPaths: searched, error: 'Неподдерживаемая платформа');
  }

  Directory? _findMacAppBundle(List<String> searched) {
    final envPath = Platform.environment['SPORTOTEKA_3D_PRO_APP'];
    final names = <String>[
      'Sportoteka3DPro.app',
      'Sportoteka 3D Pro.app',
      'Sportoteka 3DPro.app',
      'sportoteka_3d_pro.app',
    ];

    final candidates = <String>[];

    if (envPath != null && envPath.trim().isNotEmpty) {
      candidates.add(envPath.trim());
    }

    final home = Platform.environment['HOME'] ?? '/Users/dmitrij';

    for (final name in names) {
      candidates.add('/Users/dmitrij/Desktop/sportoteka2.0/unity_builds/macos/$name');
      candidates.add('$home/Desktop/sportoteka2.0/unity_builds/macos/$name');
      candidates.add('${Directory.current.path}/unity_builds/macos/$name');
    }

    candidates.addAll(_candidateBundlesFromParents(Directory.current, names));

    final executableParent = File(Platform.resolvedExecutable).parent;
    candidates.addAll(_candidateBundlesFromParents(executableParent, names));

    final unique = <String>{};
    for (final path in candidates) {
      if (path.trim().isEmpty || !unique.add(path)) continue;
      searched.add(path);

      final dir = Directory(path);
      if (dir.existsSync() && File('${dir.path}/Contents/Info.plist').existsSync()) {
        return dir;
      }
    }

    return null;
  }

  List<String> _candidateBundlesFromParents(Directory start, List<String> names) {
    final result = <String>[];
    var dir = start;

    for (var i = 0; i < 8; i++) {
      for (final name in names) {
        result.add('${dir.path}/unity_builds/macos/$name');
        result.add('${dir.path}/../unity_builds/macos/$name');
        result.add('${dir.path}/../../unity_builds/macos/$name');
      }

      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    return result;
  }

  File? _findMacExecutable(Directory appBundle) {
    final macos = Directory('${appBundle.path}/Contents/MacOS');
    if (!macos.existsSync()) return null;

    final exact = File('${macos.path}/Sportoteka3DPro');
    if (exact.existsSync()) return exact;

    final files = macos
        .listSync(followLinks: false)
        .whereType<File>()
        .where((f) => !f.path.endsWith('.dylib') && !f.path.endsWith('.meta') && !f.path.endsWith('.DS_Store'))
        .toList();

    return files.isNotEmpty ? files.first : null;
  }

  File? _findWindowsExecutable(List<String> searched) {
    final home = Platform.environment['USERPROFILE'] ?? '';
    final candidates = <String>[
      r'C:\sportoteka2.0\unity_builds\windows\Sportoteka3DPro.exe',
      r'C:\Users\dmitrij\Desktop\sportoteka2.0\unity_builds\windows\Sportoteka3DPro.exe',
      if (home.isNotEmpty) '$home\\Desktop\\sportoteka2.0\\unity_builds\\windows\\Sportoteka3DPro.exe',
      '${Directory.current.path}\\unity_builds\\windows\\Sportoteka3DPro.exe',
    ];

    final unique = <String>{};
    for (final path in candidates) {
      if (!unique.add(path)) continue;
      searched.add(path);
      final file = File(path);
      if (file.existsSync()) return file;
    }

    return null;
  }

  void _showUnityNotFoundDialog(
    BuildContext context, {
    required String payloadPath,
    required List<String> searched,
    String? error,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _green, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Unity 3D не запущен',
                  style: TextStyle(color: _graphite, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: DefaultTextStyle(
                style: const TextStyle(color: _graphite, fontSize: 13, height: 1.35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Это не 3D-экран, а Flutter-заглушка больше не открывается. Нужно, чтобы Flutter нашёл собранный Unity .app.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const Text('Payload команды сохранён:', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                    SelectableText(payloadPath),
                    const SizedBox(height: 12),
                    if (error != null && error.trim().isNotEmpty) ...[
                      const Text('Ошибка запуска:', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                      SelectableText(error),
                      const SizedBox(height: 12),
                    ],
                    const Text('Проверенные пути:', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                    SelectableText(searched.take(18).join('\n')),
                    if (searched.length > 18)
                      Text('\n...и ещё ${searched.length - 18} путей', style: const TextStyle(color: _muted)),
                    const SizedBox(height: 14),
                    const Text(
                      'Правильная папка для проверки на Mac:',
                      style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
                    ),
                    const SelectableText('/Users/dmitrij/Desktop/sportoteka2.0/unity_builds/macos/Sportoteka3DPro.app'),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }
}

class _UnityLaunchResult {
  const _UnityLaunchResult({
    required this.started,
    required this.searchedPaths,
    this.error,
  });

  final bool started;
  final List<String> searchedPaths;
  final String? error;
}
