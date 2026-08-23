// lib/presentation/advanced_video_analysis/advanced_video_analysis_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sportoteka/presentation/advanced_video_analysis/widgets/analysis_overlay_widget.dart';
import 'package:sportoteka/presentation/advanced_video_analysis/services/websocket_service.dart';
import 'package:sportoteka/presentation/advanced_video_analysis/models/player_detection.dart';
import 'package:sportoteka/presentation/advanced_video_analysis/models/analysis_result.dart';

class AdvancedVideoAnalysisPlaybackController extends ChangeNotifier {
  _AdvancedVideoAnalysisScreenState? _state;

  bool get attached => _state != null;
  bool get isPlaying => !(_state?._isVideoPaused ?? true);
  Duration get position => Duration(milliseconds: (_state?._currentVideoTimeMs ?? 0).round());

  void _attach(_AdvancedVideoAnalysisScreenState state) {
    _state = state;
    notifyListeners();
  }

  void _detach(_AdvancedVideoAnalysisScreenState state) {
    if (_state == state) {
      _state = null;
      notifyListeners();
    }
  }

  Future<void> play() => _state?._hostPlay() ?? Future.value();
  Future<void> pause() => _state?._hostPause() ?? Future.value();
  Future<void> toggle() => isPlaying ? pause() : play();
  Future<void> seekToFraction(double value) => _state?._hostSeekToFraction(value) ?? Future.value();
  Future<void> seekTo(Duration position) => _state?._hostSeekTo(position) ?? Future.value();
  Future<void> seekRelative(int seconds) => _state?._hostSeekRelative(seconds) ?? Future.value();
  Future<void> setSpeed(double speed) => _state?._hostSetSpeed(speed) ?? Future.value();
}

class AdvancedVideoAnalysisScreen extends StatefulWidget {
  final Map<String, dynamic> params;
  final VoidCallback? onClose;

  /// true — экран рисуется как CMR-окно поверх текущего раздела.
  /// Оставлено с default=true, чтобы даже старый Navigator/Get.to открывал единый оконный UI.
  final bool modalWindow;

  /// true — встроенный режим для карточки «Тактический ракурс» внутри Team Match Detail.
  /// В этом режиме не рисуется отдельное окно с шапкой, а показывается только видео + AI overlay.
  final bool embedded;

  /// Отдаёт живые AI-кадры наружу, чтобы экран «Обзор матча» мог обновлять
  /// мини-карту, скорости, спринты, нагрузку и хронологию событий.
  final ValueChanged<AnalysisResult>? onAnalysisFrame;

  /// Отдаёт статус WebSocket/AI наружу для маленьких индикаторов синхронизации.
  final ValueChanged<String>? onStatusChanged;

  /// Управление встроенным AI-плеером с общей нижней панели матча.
  final AdvancedVideoAnalysisPlaybackController? externalPlaybackController;

  /// true — скрыть внутренние кнопки play/seek внутри маленькой карточки.
  final bool hideControls;
  
  const AdvancedVideoAnalysisScreen({
    Key? key, 
    required this.params,
    this.onClose,
    this.modalWindow = true,
    this.embedded = false,
    this.onAnalysisFrame,
    this.onStatusChanged,
    this.externalPlaybackController,
    this.hideControls = false,
  }) : super(key: key);

  static Future<T?> show<T>(
    BuildContext context, {
    required Map<String, dynamic> params,
  }) {
    return showAdvancedVideoAnalysisWindow<T>(context, params);
  }

  @override
  State<AdvancedVideoAnalysisScreen> createState() => _AdvancedVideoAnalysisScreenState();
}

Future<T?> showAdvancedVideoAnalysisWindow<T>(
  BuildContext context,
  Map<String, dynamic> params,
) {
  final completer = Completer<T?>();

  OverlayState? overlay;
  try {
    overlay = Overlay.of(context, rootOverlay: true);
  } catch (_) {
    try {
      overlay = Navigator.of(context, rootNavigator: true).overlay;
    } catch (_) {
      overlay = null;
    }
  }

  if (overlay == null) {
    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: 'AI Video Analysis',
      barrierColor: Colors.black.withOpacity(.34),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return AdvancedVideoAnalysisScreen(
          params: params,
          modalWindow: true,
        );
      },
    );
  }

  late OverlayEntry entry;

  void close([T? result]) {
    if (entry.mounted) entry.remove();
    if (!completer.isCompleted) completer.complete(result);
  }

  entry = OverlayEntry(
    maintainState: true,
    builder: (overlayContext) {
      return Positioned.fill(
        child: Material(
          color: Colors.black.withOpacity(.34),
          child: AdvancedVideoAnalysisScreen(
            params: params,
            modalWindow: true,
            onClose: () => close(),
          ),
        ),
      );
    },
  );

  // Важно: прямой OverlayEntry вставляется ПОСЛЕ текущего CMR-окна матча.
  // Поэтому AI-анализ всегда будет выше TeamMatchDetail, а не под ним.
  overlay.insert(entry);
  return completer.future;
}

class _AdvancedVideoAnalysisScreenState extends State<AdvancedVideoAnalysisScreen> {
  late WebViewController _webController;
  final WebSocketService _wsService = WebSocketService();
  bool _isLoading = true;
  bool _isVideoReady = false;
  List<PlayerDetection> _players = [];
  Map<String, dynamic> _stats = {};
  String _connectionStatus = '🔄 Подключение...';
  bool _isTestMode = false;
  bool _isWindowMaximized = false;
  bool _isWindowMinimized = false;
  String _videoUrl = '';
  StreamSubscription<String>? _statusSub;
  StreamSubscription<AnalysisResult>? _analysisSub;
  bool _wsListenersReady = false;

  final List<AnalysisResult> _analysisBuffer = <AnalysisResult>[];
  Timer? _overlaySyncTimer;
  double _currentVideoTimeMs = 0;
  double _lastAppliedVideoTimeMs = -1;
  bool _isVideoPaused = true;
  bool _videoStateReady = false;
  bool _isSeeking = false;
  double _currentPlaybackRate = 1.0;
  double _lastAppliedSyncPlaybackRate = 1.0;
  DateTime _lastPlaybackRateChangeAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const int _maxBufferedFrames = 3000;

  // Максимальная дистанция между текущим временем видео и ближайшим AI-кадром.
  // Если сделать слишком маленькой — рамки будут пропадать при небольшой задержке сервера.
  static const double _maxFrameDistanceMs = 10000;

  // Fix 9: рамки не должны отставать от игроков.
  // Если AI немного позади видео, сначала предсказываем bbox по двум последним AI-кадрам,
  // а затем мягко замедляем видео, но больше не ставим его постоянно на паузу.
  static const bool _adaptivePlaybackRateSync = true;
  static const double _predictAheadMs = 3600;
  static const double _criticalLagMs = -450;
  static const double _lowBufferAheadMs = 1400;
  static const double _mediumBufferAheadMs = 2800;
  static const double _restoreSpeedAheadMs = 5200;

  // Fix 8: автоматическую паузу отключаем.
  // Сервер может анализировать медленнее реального видео, но плеер не должен постоянно останавливаться.
  // Overlay просто держит последние/ближайшие рамки и обновляется, когда приходят новые AI-кадры.
  static const bool _autoPauseForAiBuffer = false;

  static const double _pauseWhenBufferAheadLessThanMs = 700;
  static const double _resumeWhenBufferAheadMoreThanMs = 2600;

  bool _userWantsPlayback = false;
  bool _pausedByAnalysisBuffer = false;
  bool _pauseRequestedByBuffer = false;
  bool _resumeRequestedByBuffer = false;
  
  @override
  void initState() {
    super.initState();
    _videoUrl = widget.params['videoUrl'] ?? '';
    widget.externalPlaybackController?._attach(this);
    print('📹 Video URL: $_videoUrl');
    _initWebView();
    _startOverlaySyncTimer();
    _connectWebSocket();
    
  }
  
  void _initWebView() {
    // ВСЕ HTML И JAVASCRIPT КОД ВНУТРИ ТРОЙНЫХ КАВЫЧЕК
    final String html = r'''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AI Video Analysis</title>
  <style>
    * { margin: 0; padding: 0; }
    body { 
      background: #000; 
      display: flex; 
      justify-content: center; 
      align-items: center; 
      height: 100vh; 
      overflow: hidden;
    }
    #video-container { 
      width: 100%; 
      height: 100%; 
      display: flex; 
      justify-content: center; 
      align-items: center; 
      position: relative;
    }
    video { 
      width: 100%; 
      height: 100%; 
      object-fit: contain;
      background: #000;
    }
    .controls {
      position: absolute;
      bottom: 16px;
      left: 50%;
      transform: translateX(-50%);
      display: __SPORTOTEKA_CONTROLS_DISPLAY__;
      align-items: center;
      gap: 8px;
      background: rgba(255,255,255,0.92);
      padding: 8px 10px;
      border-radius: 18px;
      box-shadow: 0 18px 42px rgba(0,0,0,0.22);
      backdrop-filter: blur(16px);
      pointer-events: auto;
      border: 1px solid rgba(255,255,255,0.65);
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Inter, Arial, sans-serif;
    }
    .controls button {
      background: #F6F7F9;
      border: 1px solid rgba(17,24,39,0.06);
      color: #111827;
      font-size: 13px;
      line-height: 1;
      font-weight: 700;
      cursor: pointer;
      padding: 8px 10px;
      border-radius: 13px;
      transition: all 0.16s;
      min-width: 34px;
      box-shadow: 0 10px 20px rgba(15,23,42,0.08);
    }
    .controls button:hover {
      background: #FFFFFF;
      transform: translateY(-1px);
    }
    .controls input[type="range"] {
      width: 150px;
      height: 5px;
      -webkit-appearance: none;
      background: linear-gradient(90deg, #00A750, #DDE3EA);
      border-radius: 999px;
      outline: none;
    }
    .controls input[type="range"]::-webkit-slider-thumb {
      -webkit-appearance: none;
      width: 14px;
      height: 14px;
      border-radius: 50%;
      background: #00A750;
      border: 2px solid #FFFFFF;
      box-shadow: 0 6px 16px rgba(0,167,80,0.35);
      cursor: pointer;
    }
    .time-display {
      color: #374151;
      font-size: 11.5px;
      font-weight: 700;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Inter, Arial, sans-serif;
      min-width: 88px;
      text-align: center;
    }
    .speed-btn {
      color: #067A46 !important;
      font-size: 12px !important;
      font-weight: 800;
      min-width: 38px;
    }
    .volume-btn {
      font-size: 13px !important;
    }
    .error-message {
      color: #ff6b6b;
      font-family: Arial, sans-serif;
      text-align: center;
      padding: 20px;
    }

    @media (max-width: 560px), (max-height: 310px) {
      .controls {
        left: 8px;
        right: 8px;
        bottom: 7px;
        transform: none;
        gap: 5px;
        padding: 6px 7px;
        border-radius: 14px;
      }
      .controls button {
        padding: 6px 7px;
        min-width: 26px;
        border-radius: 10px;
        font-size: 10px;
        box-shadow: none;
      }
      .controls input[type="range"] {
        width: auto;
        min-width: 44px;
        flex: 1;
      }
      .time-display {
        min-width: 64px;
        font-size: 9.5px;
      }
      #rewindBtn, #forwardBtn, #volumeBtn, #fullscreenBtn {
        display: none;
      }
      .speed-btn {
        min-width: 28px;
        font-size: 10px !important;
      }
    }
  </style>
</head>
<body>
  <div id="video-container">
    <video id="video-player" playsinline preload="auto">
      <source src="''' + _videoUrl + '''" type="video/mp4">
      <p class="error-message">❌ Видео не может быть загружено</p>
    </video>
    
    <div class="controls" id="controls">
      <button id="playBtn" title="Play/Pause">▶</button>
      <button id="rewindBtn" title="Назад 10с">↺10</button>
      <button id="forwardBtn" title="Вперед 10с">10↻</button>
      <input type="range" id="seekBar" min="0" max="100" value="0">
      <span class="time-display" id="timeDisplay">00:00 / 00:00</span>
      <button id="speedBtn" class="speed-btn">1x</button>
      <button id="volumeBtn" class="volume-btn">VOL</button>
      <button id="fullscreenBtn" title="Fullscreen">⛶</button>
    </div>
  </div>
  
  <script>
    const video = document.getElementById('video-player');
    const playBtn = document.getElementById('playBtn');
    const rewindBtn = document.getElementById('rewindBtn');
    const forwardBtn = document.getElementById('forwardBtn');
    const seekBar = document.getElementById('seekBar');
    const timeDisplay = document.getElementById('timeDisplay');
    const speedBtn = document.getElementById('speedBtn');
    const volumeBtn = document.getElementById('volumeBtn');
    const fullscreenBtn = document.getElementById('fullscreenBtn');
    
    let isDragging = false;
    let currentSpeed = 1;
    let isMuted = false;
    let lastStateEmit = 0;

    function emitVideoState(reason) {
      const now = performance.now();
      if (reason === 'tick' && now - lastStateEmit < 35) return;
      lastStateEmit = now;

      const payload = {
        type: 'video_state',
        reason: reason,
        time_ms: (video.currentTime || 0) * 1000,
        duration_ms: (video.duration || 0) * 1000,
        paused: video.paused,
        ended: video.ended,
        seeking: video.seeking,
        playback_rate: video.playbackRate || 1
      };

      try {
        if (window.SportotekaVideoBridge) {
          SportotekaVideoBridge.postMessage(JSON.stringify(payload));
        }
      } catch (e) {}
    }
    
    function formatTime(seconds) {
      const mins = Math.floor(seconds / 60);
      const secs = Math.floor(seconds % 60);
      return String(mins).padStart(2, '0') + ':' + String(secs).padStart(2, '0');
    }
    
    function updateTime() {
      if (!isDragging && video.duration) {
        const progress = (video.currentTime / video.duration) * 100;
        seekBar.value = progress;
        timeDisplay.textContent = formatTime(video.currentTime) + ' / ' + formatTime(video.duration);
      }
    }
    
    playBtn.addEventListener('click', function() {
      if (video.paused) {
        video.play();
        playBtn.textContent = '⏸';
      } else {
        video.pause();
        playBtn.textContent = '▶';
      }
    });
    
    rewindBtn.addEventListener('click', function() {
      video.currentTime = Math.max(0, video.currentTime - 10);
    });
    
    forwardBtn.addEventListener('click', function() {
      video.currentTime = Math.min(video.duration, video.currentTime + 10);
    });
    
    seekBar.addEventListener('input', function(e) {
      isDragging = true;
      if (video.duration) {
        const percent = e.target.value / 100;
        video.currentTime = percent * video.duration;
        timeDisplay.textContent = formatTime(video.currentTime) + ' / ' + formatTime(video.duration);
      }
    });
    
    seekBar.addEventListener('change', function() {
      isDragging = false;
    });
    
    speedBtn.addEventListener('click', function() {
      const speeds = [0.5, 1, 1.25, 1.5, 2];
      let index = speeds.indexOf(currentSpeed);
      index = (index + 1) % speeds.length;
      currentSpeed = speeds[index];
      video.playbackRate = currentSpeed;
      speedBtn.textContent = currentSpeed + 'x';
      speedBtn.style.color = currentSpeed === 1 ? '#00A750' : '#FFA500';
    });
    
    volumeBtn.addEventListener('click', function() {
      isMuted = !isMuted;
      video.muted = isMuted;
      volumeBtn.textContent = isMuted ? 'MUTE' : 'VOL';
    });
    
    fullscreenBtn.addEventListener('click', function() {
      if (document.fullscreenElement) {
        document.exitFullscreen();
      } else {
        document.documentElement.requestFullscreen();
      }
    });
    
    video.addEventListener('play', function() {
      playBtn.textContent = '⏸';
      emitVideoState('play');
    });
    
    video.addEventListener('pause', function() {
      playBtn.textContent = '▶';
      emitVideoState('pause');
    });

    video.addEventListener('seeking', function() {
      emitVideoState('seeking');
    });

    video.addEventListener('seeked', function() {
      emitVideoState('seeked');
    });
    
    video.addEventListener('loadedmetadata', function() {
      timeDisplay.textContent = '00:00 / ' + formatTime(video.duration);
      emitVideoState('loadedmetadata');
    });
    
    video.addEventListener('timeupdate', function() {
      updateTime();
      emitVideoState('timeupdate');
    });
    
    function loop() {
      updateTime();
      emitVideoState('tick');
      requestAnimationFrame(loop);
    }
    loop();
    
    window.sportotekaHostPlay = function() {
      if (video) video.play().catch(function(){});
    };
    window.sportotekaHostPause = function() {
      if (video) video.pause();
    };
    window.sportotekaHostSeekFraction = function(value) {
      if (video && video.duration) {
        const safe = Math.max(0, Math.min(1, Number(value) || 0));
        video.currentTime = safe * video.duration;
        emitVideoState('host_seek');
      }
    };
    window.sportotekaHostSeekToMs = function(ms) {
      if (video && video.duration) {
        const sec = Math.max(0, Math.min(video.duration, (Number(ms) || 0) / 1000));
        video.currentTime = sec;
        emitVideoState('host_seek_ms');
      }
    };
    window.sportotekaHostSeekRelative = function(seconds) {
      if (video && video.duration) {
        video.currentTime = Math.max(0, Math.min(video.duration, video.currentTime + (Number(seconds) || 0)));
        emitVideoState('host_seek_relative');
      }
    };
    window.sportotekaHostSetSpeed = function(speed) {
      const safe = Math.max(0.25, Math.min(2.5, Number(speed) || 1));
      currentSpeed = safe;
      video.playbackRate = safe;
      speedBtn.textContent = safe + 'x';
      emitVideoState('host_speed');
    };
    window.sportotekaHostSetControlsVisible = function(visible) {
      const controls = document.getElementById('controls');
      if (controls) controls.style.display = visible ? 'flex' : 'none';
    };

    document.addEventListener('keydown', function(e) {
      if (e.target.tagName === 'INPUT') return;
      
      if (e.code === 'Space') {
        e.preventDefault();
        playBtn.click();
      }
      if (e.code === 'ArrowLeft') {
        e.preventDefault();
        rewindBtn.click();
      }
      if (e.code === 'ArrowRight') {
        e.preventDefault();
        forwardBtn.click();
      }
      if (e.code === 'KeyF') {
        e.preventDefault();
        fullscreenBtn.click();
      }
    });
    
    // Важно: не стартуем видео автоматически.
    // Сначала сервер должен набрать небольшой буфер анализа, иначе видео убегает вперёд
    // и квадраты после нескольких секунд начинают пропадать/зависать.
    emitVideoState('ready_no_autoplay');
    console.log('🎬 Video player initialized without autoplay');
  </script>
</body>
</html>
'''.replaceAll('__SPORTOTEKA_CONTROLS_DISPLAY__', widget.hideControls ? 'none' : 'flex');

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'SportotekaVideoBridge',
        onMessageReceived: _handleVideoBridgeMessage,
      )
      ..loadHtmlString(html);
  }
  
  void _connectWebSocket({bool forceRestart = false}) {
    if (_videoUrl.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _connectionStatus = '❌ Нет ссылки на видео';
      });
      return;
    }

    if (!_wsListenersReady) {
      _wsListenersReady = true;

      _statusSub = _wsService.statusStream.listen((status) {
        widget.onStatusChanged?.call(status);
        if (!mounted) return;
        setState(() {
          _connectionStatus = status;
          if (status.contains('❌') || status.contains('⚠️') || status.contains('кадры ещё не пришли')) {
            _isLoading = false;
          }
        });
      });

      _analysisSub = _wsService.analysisStream.listen(
        (result) {
          if (!mounted) return;
          _addAnalysisFrame(result);
          if (_autoPauseForAiBuffer) {
            _maybeResumeVideoAfterAnalysisBuffer();
          }

          // Важно: не двигаем квадраты просто потому, что сервер прислал новый кадр.
          // Сервер может анализировать быстрее/медленнее видео, а overlay должен жить по времени плеера.
          if (!_isVideoPaused) {
            _applyOverlayForVideoTime();
          } else if (!_videoStateReady && _players.isEmpty) {
            // Fallback только до первого сообщения от video-плеера.
            setState(() {
              _players = result.players;
              _stats = result.stats;
              _isTestMode = false;
              _isLoading = false;
              _connectionStatus = '✅ Анализ: ${result.players.length} игроков';
            });
          } else {
            // На паузе не меняем уже видимые рамки.
            // Исключение: если рамок ещё нет, можно один раз показать ближайший кадр текущего времени.
            if (_players.isEmpty) {
              _applyOverlayForVideoTime(force: true);
            }
            setState(() {
              _stats = result.stats;
              _isTestMode = false;
              _isLoading = false;
              _connectionStatus = '⏸ Пауза: квадраты зафиксированы';
            });
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _connectionStatus = '❌ Ошибка анализа: $error';
          });
        },
      );
    }

    Future<void> run() async {
      if (forceRestart) {
        await _wsService.disconnect(silent: true);
      }
      await _wsService.connect(_videoUrl);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    // Важно: не оставляем Future без catchError, иначе SocketException попадает
    // в dart_vm_initializer как Unhandled Exception.
    unawaited(
      run().catchError((Object error, StackTrace stackTrace) {
        debugPrint('❌ WebSocket start error: $error');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _connectionStatus = '❌ Ошибка WebSocket: $error';
        });
      }),
    );
  }
  
  void _startOverlaySyncTimer() {
    // Важно: НЕ detach внешнего контроллера здесь.
    // Иначе нижняя панель матча теряет связь с embedded AI-плеером,
    // поэтому Play снизу не запускает тактический AI-ракурс.
    _overlaySyncTimer?.cancel();
    _overlaySyncTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || _isVideoPaused || _isSeeking) return;
      if (_autoPauseForAiBuffer) {
        _maybePauseVideoForAnalysisBuffer();
      }
      _applyAdaptivePlaybackRate();
      _applyOverlayForVideoTime();
    });
  }

  void _handleVideoBridgeMessage(JavaScriptMessage message) {
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);
      if (map['type'] != 'video_state') return;

      final reason = map['reason']?.toString() ?? '';
      final nextTimeMs = _asDouble(map['time_ms']);
      final nextPaused = map['paused'] == true;
      final nextSeeking = map['seeking'] == true || reason == 'seeking';
      final nextPlaybackRate = _asDouble(map['playback_rate']);

      _videoStateReady = true;
      _currentVideoTimeMs = nextTimeMs;
      _isVideoPaused = nextPaused;
      _isSeeking = nextSeeking;
      if (nextPlaybackRate > 0) {
        _currentPlaybackRate = nextPlaybackRate;
      }

      if (reason == 'play') {
        _userWantsPlayback = true;
        _pausedByAnalysisBuffer = false;
        _resumeRequestedByBuffer = false;
      } else if (reason == 'pause') {
        if (_pauseRequestedByBuffer) {
          // Это не ручная пауза пользователя, а наша короткая остановка,
          // чтобы видео не убежало дальше обработанных AI-кадров.
          _pauseRequestedByBuffer = false;
          _pausedByAnalysisBuffer = true;
          _userWantsPlayback = true;
        } else {
          _userWantsPlayback = false;
          _pausedByAnalysisBuffer = false;
        }
      } else if (reason == 'seeked') {
        _pausedByAnalysisBuffer = false;
        _pauseRequestedByBuffer = false;
        _resumeRequestedByBuffer = false;
      }

      // На паузе и после перемотки сразу ставим overlay на кадр текущего времени,
      // а потом больше не обновляем его входящими пакетами WebSocket.
      if (nextPaused || reason == 'pause' || reason == 'seeked' || reason == 'loadedmetadata') {
        _applyOverlayForVideoTime(force: true);
      }
    } catch (e) {
      debugPrint('⚠️ Video bridge parse error: $e');
    }
  }

  void _applyAdaptivePlaybackRate() {
    if (!_adaptivePlaybackRateSync) return;
    if (!mounted || _isVideoPaused || _isSeeking || !_videoStateReady) return;
    if (_analysisBuffer.length < 2) return;

    final aheadMs = _bufferAheadMs(_currentVideoTimeMs);
    double desiredRate = 1.0;

    // Если видео убежало вперёд от AI, не ставим на паузу, а мягко замедляем.
    // Так рамки успевают догнать игроков без постоянных остановок.
    if (aheadMs < -1800) {
      desiredRate = 0.50;
    } else if (aheadMs < _criticalLagMs) {
      desiredRate = 0.65;
    } else if (aheadMs < _lowBufferAheadMs) {
      desiredRate = 0.75;
    } else if (aheadMs < _mediumBufferAheadMs) {
      desiredRate = 0.85;
    } else if (aheadMs >= _restoreSpeedAheadMs) {
      desiredRate = 1.0;
    } else {
      // В серой зоне не дёргаем скорость туда-сюда.
      desiredRate = _lastAppliedSyncPlaybackRate < 1.0 ? _lastAppliedSyncPlaybackRate : 1.0;
    }

    desiredRate = double.parse(desiredRate.toStringAsFixed(2));
    if ((desiredRate - _lastAppliedSyncPlaybackRate).abs() < 0.01) return;

    final now = DateTime.now();
    if (now.difference(_lastPlaybackRateChangeAt).inMilliseconds < 450) return;
    _lastPlaybackRateChangeAt = now;
    _lastAppliedSyncPlaybackRate = desiredRate;

    debugPrint(
      '🎚 AI sync speed=${desiredRate}x video=${_currentVideoTimeMs.toStringAsFixed(0)}ms ahead=${aheadMs.toStringAsFixed(0)}ms bufferEnd=${_bufferEndMs.toStringAsFixed(0)}ms',
    );

    final js = '''
      (function(){
        const v = document.getElementById('video-player');
        const b = document.getElementById('speedBtn');
        if (!v) return;
        v.playbackRate = $desiredRate;
        if (b) {
          b.textContent = '${desiredRate}x';
          b.style.color = $desiredRate === 1 ? '#00A750' : '#FFA500';
          b.title = 'AI синхронизация: ${desiredRate}x';
        }
      })();
    ''';

    unawaited(
      _webController.runJavaScript(js).catchError((Object e) {
        debugPrint('⚠️ Cannot set AI sync playbackRate: $e');
      }),
    );
  }

  void _addAnalysisFrame(AnalysisResult result) {
    if (result.players.isEmpty) return;

    final timeMs = _resultTimeMs(result);
    final normalized = AnalysisResult(
      players: result.players,
      stats: result.stats,
      frame: result.frame,
      timestamp: timeMs,
    );

    final duplicateIndex = _analysisBuffer.indexWhere(
      (item) => (_resultTimeMs(item) - timeMs).abs() < 1,
    );
    if (duplicateIndex >= 0) {
      _analysisBuffer[duplicateIndex] = normalized;
    } else {
      _analysisBuffer.add(normalized);
      _analysisBuffer.sort((a, b) => _resultTimeMs(a).compareTo(_resultTimeMs(b)));
    }

    if (_analysisBuffer.length > _maxBufferedFrames) {
      _analysisBuffer.removeRange(0, _analysisBuffer.length - _maxBufferedFrames);
    }
  }

  void _maybePauseVideoForAnalysisBuffer() {
    if (!mounted || _isVideoPaused || _isSeeking || !_videoStateReady) return;
    if (_pausedByAnalysisBuffer || _pauseRequestedByBuffer) return;

    final aheadMs = _analysisBuffer.isEmpty ? -9999.0 : _bufferAheadMs(_currentVideoTimeMs);
    if (aheadMs >= _pauseWhenBufferAheadLessThanMs) return;

    _pauseRequestedByBuffer = true;
    _pausedByAnalysisBuffer = true;

    debugPrint('⏸ AI buffer pause: video=${_currentVideoTimeMs.toStringAsFixed(0)}ms ahead=${aheadMs.toStringAsFixed(0)}ms bufferEnd=${_bufferEndMs.toStringAsFixed(0)}ms');

    unawaited(
      _webController.runJavaScript('''
        (function(){
          const v = document.getElementById('video-player');
          if (v && !v.paused) v.pause();
        })();
      ''').catchError((Object e) {
        debugPrint('⚠️ Cannot pause video for AI buffer: $e');
      }),
    );

    setState(() {
      _connectionStatus = '⏳ Буферизация AI: видео ждёт кадры анализа';
      _isLoading = false;
    });
  }

  void _maybeResumeVideoAfterAnalysisBuffer() {
    if (!mounted || !_pausedByAnalysisBuffer || !_userWantsPlayback || !_videoStateReady) return;
    if (_analysisBuffer.isEmpty || _resumeRequestedByBuffer) return;

    final aheadMs = _bufferAheadMs(_currentVideoTimeMs);
    if (aheadMs < _resumeWhenBufferAheadMoreThanMs) {
      if (mounted) {
        setState(() {
          _connectionStatus = '⏳ Буферизация AI: ${aheadMs.clamp(0, 99999).toStringAsFixed(0)} мс';
          _isLoading = false;
        });
      }
      return;
    }

    _resumeRequestedByBuffer = true;
    _pausedByAnalysisBuffer = false;

    debugPrint('▶️ AI buffer resume: video=${_currentVideoTimeMs.toStringAsFixed(0)}ms ahead=${aheadMs.toStringAsFixed(0)}ms');

    unawaited(
      _webController.runJavaScript('''
        (function(){
          const v = document.getElementById('video-player');
          if (v && v.paused) v.play().catch(function(){});
        })();
      ''').catchError((Object e) {
        debugPrint('⚠️ Cannot resume video after AI buffer: $e');
      }),
    );
  }

  double get _bufferEndMs => _analysisBuffer.isEmpty ? 0.0 : _resultTimeMs(_analysisBuffer.last);

  double _bufferAheadMs(double timeMs) {
    if (_analysisBuffer.isEmpty) return 0.0;
    return _bufferEndMs - timeMs;
  }

  void _applyOverlayForVideoTime({bool force = false}) {
    if (_analysisBuffer.isEmpty || !mounted) return;

    final target = _playersForVideoTime(_currentVideoTimeMs);
    if (target.isEmpty) {
      if (!force && !_isVideoPaused && _autoPauseForAiBuffer) {
        _maybePauseVideoForAnalysisBuffer();
      }
      // Не очищаем старые рамки и не ставим видео на паузу:
      // если AI временно не успевает, кадр продолжает играть, а overlay обновится при следующем пакете.
      if (!_isVideoPaused && mounted) {
        setState(() {
          _connectionStatus = '⏳ AI догоняет видео';
          _isLoading = false;
        });
      }
      return;
    }

    final shouldSmooth = !force && !_isSeeking && _players.isNotEmpty;
    final visiblePlayers = shouldSmooth ? _smoothPlayers(target) : target;

    if (!force && (_currentVideoTimeMs - _lastAppliedVideoTimeMs).abs() < 40) {
      return;
    }

    final nearest = _nearestAnalysisResult(_currentVideoTimeMs);
    final nextStats = nearest?.stats ?? _nearestStats(_currentVideoTimeMs);
    final outgoing = AnalysisResult(
      players: visiblePlayers,
      stats: nextStats,
      frame: nearest?.frame ?? 0,
      timestamp: _currentVideoTimeMs,
    );

    setState(() {
      _players = visiblePlayers;
      _stats = nextStats;
      _isTestMode = false;
      _isLoading = false;
      _connectionStatus = _isVideoPaused
          ? '⏸ Пауза: квадраты зафиксированы'
          : '✅ Синхронный анализ: ${visiblePlayers.length} игроков';
    });

    _lastAppliedVideoTimeMs = _currentVideoTimeMs;
    widget.onAnalysisFrame?.call(outgoing);
  }

  List<PlayerDetection> _playersForVideoTime(double timeMs) {
    if (_analysisBuffer.isEmpty) return const [];

    // Если видео чуть ушло дальше последнего AI-кадра — предсказываем движение
    // по двум последним кадрам. Это убирает визуальное отставание рамок.
    final last = _analysisBuffer.last;
    final lastTime = _resultTimeMs(last);
    if (timeMs > lastTime) {
      final ahead = timeMs - lastTime;
      if (_analysisBuffer.length >= 2 && ahead <= _predictAheadMs) {
        final prev = _analysisBuffer[_analysisBuffer.length - 2];
        final prevTime = _resultTimeMs(prev);
        final dt = lastTime - prevTime;
        if (dt > 25) {
          final factor = (ahead / dt).clamp(0.0, 2.60);
          return _extrapolatePlayers(prev.players, last.players, factor);
        }
      }

      if (ahead <= _maxFrameDistanceMs && _analysisBuffer.length >= 2) {
        final prev = _analysisBuffer[_analysisBuffer.length - 2];
        final prevTime = _resultTimeMs(prev);
        final dt = lastTime - prevTime;
        if (dt > 25) {
          final factor = (ahead / dt).clamp(0.0, 2.60);
          return _extrapolatePlayers(prev.players, last.players, factor);
        }
      }
      if (ahead <= _maxFrameDistanceMs) return last.players;
      return const [];
    }

    AnalysisResult? prev;
    AnalysisResult? next;

    for (final item in _analysisBuffer) {
      final itemTime = _resultTimeMs(item);
      if (itemTime <= timeMs) prev = item;
      if (itemTime >= timeMs) {
        next = item;
        break;
      }
    }

    prev ??= _analysisBuffer.first;
    next ??= _analysisBuffer.last;

    final prevTime = _resultTimeMs(prev);
    final nextTime = _resultTimeMs(next);

    final nearestDistance = [
      (timeMs - prevTime).abs(),
      (timeMs - nextTime).abs(),
    ].reduce((a, b) => a < b ? a : b);

    if (nearestDistance > _maxFrameDistanceMs) return const [];

    if (prev == next || (nextTime - prevTime).abs() < 1) {
      return prev.players;
    }

    final t = ((timeMs - prevTime) / (nextTime - prevTime)).clamp(0.0, 1.0);
    return _interpolatePlayers(prev.players, next.players, t);
  }

  List<PlayerDetection> _extrapolatePlayers(
    List<PlayerDetection> previous,
    List<PlayerDetection> current,
    double factor,
  ) {
    String keyFor(PlayerDetection p) => p.trackId > 0 ? 'track_${p.trackId}' : p.id;

    final previousByKey = <String, PlayerDetection>{
      for (final p in previous) keyFor(p): p,
    };

    return current.map((p) {
      final old = previousByKey[keyFor(p)];
      if (old == null) return p;

      final move = p.bbox.center - old.bbox.center;
      final distance = move.distance;
      if (distance <= 0.2 || distance > 360) return p;

      final dx1 = (p.bbox.left - old.bbox.left) * factor;
      final dy1 = (p.bbox.top - old.bbox.top) * factor;
      final dx2 = (p.bbox.right - old.bbox.right) * factor;
      final dy2 = (p.bbox.bottom - old.bbox.bottom) * factor;

      final predicted = Rect.fromLTRB(
        p.bbox.left + dx1,
        p.bbox.top + dy1,
        p.bbox.right + dx2,
        p.bbox.bottom + dy2,
      );

      return p.copyWith(bbox: predicted);
    }).toList();
  }

  List<PlayerDetection> _interpolatePlayers(
    List<PlayerDetection> previous,
    List<PlayerDetection> next,
    double t,
  ) {
    String keyFor(PlayerDetection p) => p.trackId > 0 ? 'track_${p.trackId}' : p.id;

    final nextByKey = <String, PlayerDetection>{
      for (final p in next) keyFor(p): p,
    };
    final usedNextKeys = <String>{};
    final output = <PlayerDetection>[];

    for (final p in previous) {
      final key = keyFor(p);
      final q = nextByKey[key];
      if (q == null) {
        if (t < 0.65) output.add(p);
        continue;
      }
      usedNextKeys.add(key);
      output.add(
        q.copyWith(
          bbox: Rect.lerp(p.bbox, q.bbox, t) ?? q.bbox,
          confidence: p.confidence + (q.confidence - p.confidence) * t,
          trajectory: q.trajectory.isNotEmpty ? q.trajectory : p.trajectory,
        ),
      );
    }

    for (final q in next) {
      final key = keyFor(q);
      if (!usedNextKeys.contains(key) && t >= 0.35) output.add(q);
    }

    return output;
  }

  List<PlayerDetection> _smoothPlayers(List<PlayerDetection> target) {
    if (_players.isEmpty) return target;

    String keyFor(PlayerDetection p) => p.trackId > 0 ? 'track_${p.trackId}' : p.id;

    final previousByKey = <String, PlayerDetection>{
      for (final p in _players) keyFor(p): p,
    };

    const alpha = 0.94;
    return target.map((p) {
      final old = previousByKey[keyFor(p)];
      if (old == null) return p;

      final oldCenter = old.bbox.center;
      final newCenter = p.bbox.center;
      final jump = (newCenter - oldCenter).distance;

      // При большом скачке, перемотке или смене трека не тянем старую рамку за новой.
      if (jump > 180) return p;

      return p.copyWith(
        bbox: Rect.lerp(old.bbox, p.bbox, alpha) ?? p.bbox,
      );
    }).toList();
  }

  AnalysisResult? _nearestAnalysisResult(double timeMs) {
    if (_analysisBuffer.isEmpty) return null;

    AnalysisResult best = _analysisBuffer.first;
    double bestDistance = (_resultTimeMs(best) - timeMs).abs();

    for (final item in _analysisBuffer) {
      final d = (_resultTimeMs(item) - timeMs).abs();
      if (d < bestDistance) {
        best = item;
        bestDistance = d;
      }
    }

    return best;
  }

  Map<String, dynamic> _nearestStats(double timeMs) {
    if (_analysisBuffer.isEmpty) return _stats;

    AnalysisResult best = _analysisBuffer.first;
    double bestDistance = (_resultTimeMs(best) - timeMs).abs();

    for (final item in _analysisBuffer) {
      final d = (_resultTimeMs(item) - timeMs).abs();
      if (d < bestDistance) {
        best = item;
        bestDistance = d;
      }
    }

    return best.stats;
  }

  double _resultTimeMs(AnalysisResult result) {
    final raw = result.timestamp;
    if (raw <= 0 && result.frame > 0) return result.frame * 20.0; // fallback для 50 fps

    // Если сервер когда-нибудь пришлёт секунды, а не миллисекунды.
    if (raw > 0 && raw < 1000 && result.frame > 1000) return raw * 1000;
    return raw;
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }

  void _addTestData() {
    setState(() {
      _players = [
        PlayerDetection(
          id: '1',
          number: 10,
          name: 'Тестовый 10',
          bbox: Rect.fromLTWH(200, 300, 60, 120),
          teamColor: 0xFF00A750,
          teamId: 'home',
          confidence: 0.95,
          position: 'forward',
          trackId: 1,
          trajectory: [],
          metrics: {},
        ),
        PlayerDetection(
          id: '2',
          number: 7,
          name: 'Тестовый 7',
          bbox: Rect.fromLTWH(450, 250, 60, 120),
          teamColor: 0xFFFF4444,
          teamId: 'away',
          confidence: 0.92,
          position: 'midfield',
          trackId: 2,
          trajectory: [],
          metrics: {},
        ),
        PlayerDetection(
          id: '3',
          number: 9,
          name: 'Тестовый 9',
          bbox: Rect.fromLTWH(700, 350, 60, 120),
          teamColor: 0xFF00A750,
          teamId: 'home',
          confidence: 0.88,
          position: 'defense',
          trackId: 3,
          trajectory: [],
          metrics: {},
        ),
      ];
      _stats = {
        'shots': 8,
        'shots_on_target': 4,
        'passes': 156,
        'possession': 58,
        'sprints': 23,
      };
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildEmbeddedTacticalStage();
    }

    final mq = MediaQuery.of(context);
    final size = mq.size;
    final bool compact = size.width < 760;

    final EdgeInsets outerPadding = _isWindowMaximized
        ? EdgeInsets.zero
        : EdgeInsets.symmetric(
            horizontal: compact ? 10 : 24,
            vertical: compact ? 10 : 18,
          );

    final double targetWidth = _isWindowMaximized
        ? size.width
        : (compact ? size.width - 20 : size.width.clamp(980.0, 1380.0).toDouble());
    final double targetHeight = _isWindowMaximized
        ? size.height
        : (compact ? size.height - 20 : size.height.clamp(640.0, 860.0).toDouble());

    return Scaffold(
      backgroundColor: widget.modalWindow ? Colors.transparent : const Color(0xFFF6F7F9),
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: outerPadding,
          child: Align(
            alignment: _isWindowMinimized ? Alignment.bottomLeft : Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: _isWindowMinimized ? (compact ? size.width - 20 : 520) : targetWidth,
              height: _isWindowMinimized ? 58 : targetHeight,
              constraints: BoxConstraints(
                maxWidth: size.width,
                maxHeight: size.height,
                minHeight: 58,
              ),
              decoration: _AvaDecor.window(maximized: _isWindowMaximized),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildWindowHeader(compact: compact),
                  if (!_isWindowMinimized)
                    Expanded(
                      child: compact ? _buildCompactBody() : _buildDesktopBody(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWindowHeader({required bool compact}) {
    final title = 'AI-анализ ${widget.params['teamName'] ?? 'матча'}';
    final statusColor = _connectionStatus.contains('✅')
        ? _AvaColors.green
        : _connectionStatus.contains('❌')
            ? _AvaColors.red
            : _isTestMode
                ? _AvaColors.orange
                : _AvaColors.amber;

    return Container(
      height: 54,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _AvaColors.divider, width: 1)),
      ),
      child: Row(
        children: [
          _WindowDot(
            tooltip: 'Закрыть',
            icon: Icons.close_rounded,
            onTap: () {
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.of(context, rootNavigator: true).maybePop();
              }
            },
          ),
          const SizedBox(width: 7),
          _WindowDot(
            tooltip: _isWindowMinimized ? 'Развернуть' : 'Свернуть',
            icon: _isWindowMinimized ? Icons.keyboard_arrow_up_rounded : Icons.remove_rounded,
            onTap: () => setState(() => _isWindowMinimized = !_isWindowMinimized),
          ),
          const SizedBox(width: 7),
          _WindowDot(
            tooltip: _isWindowMaximized ? 'Вернуть размер' : 'Раскрыть',
            icon: _isWindowMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
            onTap: () => setState(() {
              _isWindowMinimized = false;
              _isWindowMaximized = !_isWindowMaximized;
            }),
          ),
          const SizedBox(width: 14),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _AvaColors.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: _AvaColors.green, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _AvaText.title(13.6)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _cleanStatus(_connectionStatus),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _AvaText.muted(11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isTestMode)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: _AvaColors.orangeSoft, borderRadius: BorderRadius.circular(999)),
              child: Text('ТЕСТ', style: _AvaText.badge(_AvaColors.orange)),
            ),
          _HeaderPillButton(
            icon: Icons.refresh_rounded,
            text: compact ? '' : 'Обновить',
            onTap: _restartAnalysis,
          ),
          const SizedBox(width: 8),
          _HeaderPillButton(
            icon: Icons.tune_rounded,
            text: compact ? '' : 'Настройки',
            onTap: _showSettings,
          ),
        ],
      ),
    );
  }


  Widget _buildEmbeddedTacticalStage() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoStage(),
          Positioned(
            left: 10,
            top: 10,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.92),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: _AvaColors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      _players.isEmpty ? _cleanStatus(_connectionStatus) : 'AI: ${_players.length} игроков',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _AvaText.title(10.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody() {
    return Container(
      color: _AvaColors.bg,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 238,
            child: _AnalysisTtdPanel(
              stats: _stats,
              players: _players,
              status: _cleanStatus(_connectionStatus),
              videoTimeMs: _currentVideoTimeMs,
              bufferEndMs: _bufferEndMs,
              onRestart: _restartAnalysis,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: _buildVideoStage()),
        ],
      ),
    );
  }

  Widget _buildCompactBody() {
    return Container(
      color: _AvaColors.bg,
      child: Column(
        children: [
          Expanded(child: Padding(padding: const EdgeInsets.all(10), child: _buildVideoStage())),
          SizedBox(
            height: 126,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _AnalysisTtdPanel(
                stats: _stats,
                players: _players,
                status: _cleanStatus(_connectionStatus),
                videoTimeMs: _currentVideoTimeMs,
                bufferEndMs: _bufferEndMs,
                onRestart: _restartAnalysis,
                horizontal: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoStage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageSize = constraints.biggest;
        return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(widget.embedded ? 8 : 18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 28,
            spreadRadius: -14,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _webController)),
          if (_players.isNotEmpty)
            Positioned.fill(
              child: AnalysisOverlayWidget(
                players: _players,
                stats: _stats,
                videoSize: stageSize,
              ),
            ),
          if (!_isLoading && _players.isEmpty)
            Positioned(
              left: 16,
              top: 16,
              child: _StageStatusBadge(
                text: _connectionStatus.contains('Подключено')
                    ? 'Ожидаю реальные detections от сервера…'
                    : _cleanStatus(_connectionStatus),
              ),
            ),
          if (_isLoading && _players.isEmpty)
            Center(
              child: Container(
                width: widget.embedded ? 220 : 360,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.94),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.16),
                      blurRadius: 30,
                      spreadRadius: -14,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(color: _AvaColors.green, strokeWidth: 3),
                    ),
                    const SizedBox(height: 14),
                    Text(_connectionStatus, textAlign: TextAlign.center, style: _AvaText.title(13)),
                    const SizedBox(height: 7),
                    if (!widget.embedded)
                      Text(
                        'Идёт подключение и подготовка анализа',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: _AvaText.muted(10.8),
                      ),
                    const SizedBox(height: 14),
                    _HeaderPillButton(icon: Icons.refresh_rounded, text: 'Попробовать снова', onTap: _restartAnalysis),
                  ],
                ),
              ),
            ),
        ],
      ),
        );
      },
    );
  }

  Future<void> _hostPlay() async {
    await _webController.runJavaScript("""
      (function(){
        if (window.sportotekaHostPlay) window.sportotekaHostPlay();
      })();
    """);
  }

  Future<void> _hostPause() async {
    await _webController.runJavaScript("""
      (function(){
        if (window.sportotekaHostPause) window.sportotekaHostPause();
      })();
    """);
  }

  Future<void> _hostSeekToFraction(double value) async {
    final safe = value.clamp(0.0, 1.0).toDouble();
    await _webController.runJavaScript("""
      (function(){
        if (window.sportotekaHostSeekFraction) window.sportotekaHostSeekFraction($safe);
      })();
    """);
  }

  Future<void> _hostSeekTo(Duration position) async {
    final ms = position.inMilliseconds.clamp(0, 24 * 60 * 60 * 1000);
    await _webController.runJavaScript("""
      (function(){
        if (window.sportotekaHostSeekToMs) window.sportotekaHostSeekToMs($ms);
      })();
    """);
  }

  Future<void> _hostSeekRelative(int seconds) async {
    await _webController.runJavaScript("""
      (function(){
        if (window.sportotekaHostSeekRelative) window.sportotekaHostSeekRelative($seconds);
      })();
    """);
  }

  Future<void> _hostSetSpeed(double speed) async {
    final safe = speed.clamp(0.25, 2.5).toDouble();
    await _webController.runJavaScript("""
      (function(){
        if (window.sportotekaHostSetSpeed) window.sportotekaHostSetSpeed($safe);
      })();
    """);
  }

  void _restartAnalysis() {
    setState(() {
      _connectionStatus = '🔄 Переподключение...';
      _players = [];
      _stats = {};
      _analysisBuffer.clear();
      _lastAppliedVideoTimeMs = -1;
      _userWantsPlayback = false;
      _pausedByAnalysisBuffer = false;
      _pauseRequestedByBuffer = false;
      _resumeRequestedByBuffer = false;
      _lastAppliedSyncPlaybackRate = 1.0;
      _isLoading = true;
    });
    _initWebView();
    _connectWebSocket(forceRestart: true);
  }

  String _cleanStatus(String value) {
    return value
        .replaceAll('✅', '')
        .replaceAll('❌', '')
        .replaceAll('⚠️', '')
        .replaceAll('🔄', '')
        .replaceAll('⏸', '')
        .replaceAll('⏳', '')
        .trim();
  }
  
  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Настройки анализа'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SwitchListTile(
              value: true,
              onChanged: null,
              title: Text('Показывать номера'),
            ),
            const SwitchListTile(
              value: true,
              onChanged: null,
              title: Text('Показывать траектории'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _isTestMode = true;
                    _connectionStatus = '⚠️ ТЕСТОВЫЙ РЕЖИМ';
                  });
                  _addTestData();
                },
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Показать тестовые квадраты'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    widget.externalPlaybackController?._detach(this);
    _overlaySyncTimer?.cancel();
    _statusSub?.cancel();
    _analysisSub?.cancel();
    _wsService.dispose();
    super.dispose();
  }
}
class _AvaColors {
  static const Color bg = Color(0xFFF6F7F9);
  static const Color panel = Colors.white;
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF374151);
  static const Color subtle = Color(0xFF6B7280);
  static const Color divider = Color(0xFFF0F2F4);
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEF2F2);
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF7ED);
  static const Color amber = Color(0xFFF59E0B);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
  static const Color graphite = Color(0xFF111827);
}

class _AvaText {
  static const String _family = 'Segoe UI';
  static const List<String> _fallback = <String>[
    'SF Pro Display',
    'SF Pro Text',
    'Inter',
    'Roboto',
    'Arial',
  ];

  static TextStyle title(double size) => TextStyle(
        color: _AvaColors.text,
        fontFamily: _family,
        fontFamilyFallback: _fallback,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        height: 1.1,
      );

  static TextStyle value(double size) => TextStyle(
        color: _AvaColors.text,
        fontFamily: _family,
        fontFamilyFallback: _fallback,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.22,
        height: 1.05,
      );

  static TextStyle muted(double size) => TextStyle(
        color: _AvaColors.subtle,
        fontFamily: _family,
        fontFamilyFallback: _fallback,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.15,
      );

  static TextStyle badge(Color color) => TextStyle(
        color: color,
        fontFamily: _family,
        fontFamilyFallback: _fallback,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        height: 1,
      );
}

class _AvaDecor {
  static BoxDecoration window({required bool maximized}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(maximized ? 0 : 24),
        border: Border.all(color: Colors.white.withOpacity(.86), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: maximized ? 0 : 46,
            spreadRadius: maximized ? 0 : -18,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: _AvaColors.green.withOpacity(.05),
            blurRadius: maximized ? 0 : 28,
            spreadRadius: -18,
            offset: const Offset(-10, 12),
          ),
        ],
      );

  static BoxDecoration card({double radius = 18, Color? tint}) => BoxDecoration(
        color: tint ?? Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(.78), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 22,
            spreadRadius: -13,
            offset: const Offset(0, 12),
          ),
        ],
      );
}

class _WindowDot extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _WindowDot({required this.tooltip, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3F5),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE6E8EC)),
          ),
          child: Icon(icon, size: 13, color: _AvaColors.muted),
        ),
      ),
    );
  }
}

class _HeaderPillButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _HeaderPillButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: text.isEmpty ? 8 : 11),
          decoration: BoxDecoration(
            color: _AvaColors.greenSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _AvaColors.green.withOpacity(.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _AvaColors.greenDark, size: 16),
              if (text.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(text, style: _AvaText.badge(_AvaColors.greenDark)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StageStatusBadge extends StatelessWidget {
  final String text;
  const _StageStatusBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Text(text, style: _AvaText.muted(11.5)),
    );
  }
}

class _AnalysisTtdPanel extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<PlayerDetection> players;
  final String status;
  final double videoTimeMs;
  final double bufferEndMs;
  final VoidCallback onRestart;
  final bool horizontal;

  const _AnalysisTtdPanel({
    required this.stats,
    required this.players,
    required this.status,
    required this.videoTimeMs,
    required this.bufferEndMs,
    required this.onRestart,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (horizontal) {
      return Container(
        decoration: _AvaDecor.card(radius: 18),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _MiniStatus(status: status),
            const SizedBox(width: 10),
            Expanded(child: _MetricStrip(metrics: _metrics())),
          ],
        ),
      );
    }

    return Container(
      decoration: _AvaDecor.card(radius: 20),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: _AvaColors.greenSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.query_stats_rounded, color: _AvaColors.green, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text('ТТД и AI', style: _AvaText.title(13.4))),
            ],
          ),
          const SizedBox(height: 11),
          _MiniStatus(status: status),
          const SizedBox(height: 12),
          _MetricGrid(metrics: _metrics()),
          const SizedBox(height: 12),
          _SyncBlock(videoTimeMs: videoTimeMs, bufferEndMs: bufferEndMs),
          const SizedBox(height: 12),
          Text('Игроки в кадре', style: _AvaText.title(12.3)),
          const SizedBox(height: 8),
          Expanded(
            child: players.isEmpty
                ? Center(child: Text('Ожидаю detections…', style: _AvaText.muted(11.5)))
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final p = players[index];
                      return _PlayerMiniRow(player: p);
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemCount: players.length.clamp(0, 18).toInt(),
                  ),
          ),
        ],
      ),
    );
  }

  List<_TtdMetric> _metrics() {
    num n(dynamic value, {num fallback = 0}) {
      if (value is num) return value;
      if (value is String) return num.tryParse(value.replaceAll(',', '.')) ?? fallback;
      return fallback;
    }

    return [
      _TtdMetric('Игроки', players.isNotEmpty ? players.length.toString() : n(stats['players_count']).toStringAsFixed(0), Icons.groups_2_rounded),
      _TtdMetric('Удары', n(stats['shots']).toStringAsFixed(0), Icons.sports_soccer_rounded),
      _TtdMetric('В створ', n(stats['shots_on_target']).toStringAsFixed(0), Icons.center_focus_strong_rounded),
      _TtdMetric('Пасы', n(stats['passes']).toStringAsFixed(0), Icons.compare_arrows_rounded),
      _TtdMetric('Спринты', n(stats['sprints']).toStringAsFixed(0), Icons.directions_run_rounded),
      _TtdMetric('Владение', '${n(stats['possession'], fallback: 50).toStringAsFixed(0)}%', Icons.donut_large_rounded),
    ];
  }
}

class _TtdMetric {
  final String label;
  final String value;
  final IconData icon;
  const _TtdMetric(this.label, this.value, this.icon);
}

class _MetricGrid extends StatelessWidget {
  final List<_TtdMetric> metrics;
  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.62,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) => _MetricTile(metric: metrics[index]),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  final List<_TtdMetric> metrics;
  const _MetricStrip({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemBuilder: (context, index) => SizedBox(width: 92, child: _MetricTile(metric: metrics[index], compact: true)),
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemCount: metrics.length,
    );
  }
}

class _MetricTile extends StatelessWidget {
  final _TtdMetric metric;
  final bool compact;
  const _MetricTile({required this.metric, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 9),
      decoration: BoxDecoration(
        color: _AvaColors.bg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(metric.icon, size: compact ? 14 : 16, color: _AvaColors.green),
          SizedBox(height: compact ? 5 : 7),
          Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _AvaText.value(compact ? 13 : 14.4)),
          const SizedBox(height: 2),
          Text(metric.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _AvaText.muted(compact ? 9.8 : 10.4)),
        ],
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  final String status;
  const _MiniStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _AvaColors.greenSoft,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: _AvaColors.green, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Flexible(child: Text(status.isEmpty ? 'Готов к анализу' : status, maxLines: 2, overflow: TextOverflow.ellipsis, style: _AvaText.muted(10.8))),
        ],
      ),
    );
  }
}

class _SyncBlock extends StatelessWidget {
  final double videoTimeMs;
  final double bufferEndMs;
  const _SyncBlock({required this.videoTimeMs, required this.bufferEndMs});

  @override
  Widget build(BuildContext context) {
    final ahead = bufferEndMs - videoTimeMs;
    final color = ahead >= 0 ? _AvaColors.green : _AvaColors.amber;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _AvaColors.bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.timeline_rounded, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Синхронизация AI', style: _AvaText.title(11.6)),
                const SizedBox(height: 3),
                Text('Буфер: ${(ahead / 1000).toStringAsFixed(1)} сек', style: _AvaText.muted(10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerMiniRow extends StatelessWidget {
  final PlayerDetection player;
  const _PlayerMiniRow({required this.player});

  @override
  Widget build(BuildContext context) {
    final color = Color(player.teamColor);
    final label = player.name.isNotEmpty ? player.name : 'Игрок ${player.trackId > 0 ? player.trackId : player.id}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(color: _AvaColors.bg, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _AvaText.value(11.2))),
          const SizedBox(width: 8),
          Text('${(player.confidence * 100).toStringAsFixed(0)}%', style: _AvaText.muted(10.3)),
        ],
      ),
    );
  }
}
