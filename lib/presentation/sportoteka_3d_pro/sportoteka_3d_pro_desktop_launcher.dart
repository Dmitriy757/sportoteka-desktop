
import 'dart:convert';
import 'dart:io';

class Sportoteka3DProDesktopPlayer {
  const Sportoteka3DProDesktopPlayer({
    required this.id,
    required this.number,
    required this.name,
    this.position = '',
    this.avatarUrl = '',
    this.avatarPath = '',
    this.logoUrl = '',
    this.logoPath = '',
  });

  final int id;
  final int number;
  final String name;
  final String position;
  final String avatarUrl;
  final String avatarPath;
  final String logoUrl;
  final String logoPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'name': name,
        'position': position,
        'avatarUrl': avatarUrl,
        'avatarPath': avatarPath,
        'logoUrl': logoUrl,
        'logoPath': logoPath,
      };
}

class Sportoteka3DProDesktopLauncherResult {
  const Sportoteka3DProDesktopLauncherResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class Sportoteka3DProDesktopLauncher {
  static Future<Sportoteka3DProDesktopLauncherResult> launch({
    String? teamName,
    List<Sportoteka3DProDesktopPlayer> players = const [],
  }) async {
    try {
      final teamJsonPath = await _writeTeamJson(teamName: teamName, players: players);
      if (Platform.isMacOS) return _launchMacOS(teamJsonPath);
      if (Platform.isWindows) return _launchWindows(teamJsonPath);
      if (Platform.isLinux) return _launchLinux(teamJsonPath);
      return const Sportoteka3DProDesktopLauncherResult(success: false, message: 'Эта платформа не поддерживает запуск standalone Unity.');
    } catch (e) {
      return Sportoteka3DProDesktopLauncherResult(success: false, message: 'Не удалось запустить Unity 3D Pro: $e');
    }
  }

  static Future<String> _writeTeamJson({String? teamName, List<Sportoteka3DProDesktopPlayer> players = const []}) async {
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}sportoteka_3d_pro_team_players.json');
    final payload = <String, dynamic>{
      'teamName': (teamName == null || teamName.trim().isEmpty) ? 'ФК «Гомель» U13' : teamName.trim(),
      'players': players.map((e) => e.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(payload), encoding: utf8);
    return file.path;
  }

  static Future<Sportoteka3DProDesktopLauncherResult> _launchMacOS(String teamJsonPath) async {
    final appPath = _firstExistingDirectory(_macOSCandidates());
    if (appPath == null) {
      return const Sportoteka3DProDesktopLauncherResult(success: false, message: 'Не найден macOS Unity build Sportoteka3DPro.app. Ожидаемый путь: /Users/dmitrij/Desktop/sportoteka2.0/unity_builds/macos/Sportoteka3DPro.app');
    }
    await Process.start('open', ['-n', appPath, '--args', '-screen-fullscreen', '0', '-screen-width', '1360', '-screen-height', '840', '--sportoteka-team-json', teamJsonPath], mode: ProcessStartMode.detached);
    return const Sportoteka3DProDesktopLauncherResult(success: true, message: 'Sportoteka 3D Pro открыт. Игроки команды переданы в Unity.');
  }

  static Future<Sportoteka3DProDesktopLauncherResult> _launchWindows(String teamJsonPath) async {
    final exePath = _firstExistingFile(_windowsCandidates());
    if (exePath == null) {
      return const Sportoteka3DProDesktopLauncherResult(success: false, message: 'Не найден Windows Unity build Sportoteka3DPro.exe. Ожидаемый путь: unity_builds/windows/Sportoteka3DPro.exe');
    }
    await Process.start(exePath, ['-screen-fullscreen', '0', '-screen-width', '1360', '-screen-height', '840', '-popupwindow', '--sportoteka-team-json', teamJsonPath], mode: ProcessStartMode.detached, runInShell: true);
    return const Sportoteka3DProDesktopLauncherResult(success: true, message: 'Sportoteka 3D Pro открыт. Игроки команды переданы в Unity.');
  }

  static Future<Sportoteka3DProDesktopLauncherResult> _launchLinux(String teamJsonPath) async {
    final exePath = _firstExistingFile(_linuxCandidates());
    if (exePath == null) return const Sportoteka3DProDesktopLauncherResult(success: false, message: 'Не найден Linux Unity build Sportoteka3DPro.');
    await Process.start(exePath, ['-screen-fullscreen', '0', '-screen-width', '1360', '-screen-height', '840', '--sportoteka-team-json', teamJsonPath], mode: ProcessStartMode.detached);
    return const Sportoteka3DProDesktopLauncherResult(success: true, message: 'Sportoteka 3D Pro открыт. Игроки команды переданы в Unity.');
  }

  static List<String> _macOSCandidates() {
    final cwd = Directory.current.path;
    return ['/Users/dmitrij/Desktop/sportoteka2.0/unity_builds/macos/Sportoteka3DPro.app', '$cwd/unity_builds/macos/Sportoteka3DPro.app', '$cwd/../unity_builds/macos/Sportoteka3DPro.app', '$cwd/../../unity_builds/macos/Sportoteka3DPro.app', '$cwd/../../../unity_builds/macos/Sportoteka3DPro.app', '$cwd/../../../../unity_builds/macos/Sportoteka3DPro.app'];
  }

  static List<String> _windowsCandidates() {
    final cwd = Directory.current.path;
    return [r'C:\sportoteka2.0\unity_builds\windows\Sportoteka3DPro.exe', '$cwd\\unity_builds\\windows\\Sportoteka3DPro.exe', '$cwd\\..\\unity_builds\\windows\\Sportoteka3DPro.exe', '$cwd\\..\\..\\unity_builds\\windows\\Sportoteka3DPro.exe', '$cwd\\..\\..\\..\\unity_builds\\windows\\Sportoteka3DPro.exe', '$cwd\\..\\..\\..\\..\\unity_builds\\windows\\Sportoteka3DPro.exe'];
  }

  static List<String> _linuxCandidates() {
    final cwd = Directory.current.path;
    return ['$cwd/unity_builds/linux/Sportoteka3DPro', '$cwd/../unity_builds/linux/Sportoteka3DPro', '$cwd/../../unity_builds/linux/Sportoteka3DPro', '$cwd/../../../unity_builds/linux/Sportoteka3DPro'];
  }

  static String? _firstExistingDirectory(List<String> candidates) {
    for (final path in candidates) { if (Directory(path).existsSync()) return path; }
    return null;
  }

  static String? _firstExistingFile(List<String> candidates) {
    for (final path in candidates) { if (File(path).existsSync()) return path; }
    return null;
  }
}
