// lib/presentation/club_workspace/cmr_club_ai_assistant_panel.dart
// V6.4 локальный ИИ клуба: история всегда выдвигается сбоку внутри текущего окна.
// Вставляется внутрь раздела Чаты как закреплённый диалог «ИИ клуба».

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sportoteka/presentation/community_screen/app_video_player_screen.dart';

import 'ai_actions/ai_workspace_action_api.dart';
import 'models/club_ai_tactical_diagram.dart';
import 'models/club_ai_visualization.dart';
import 'widgets/ai_plan_preview_card.dart';
import 'widgets/club_ai_tactical_diagram_card.dart';
import 'widgets/club_ai_visualization_card.dart';

class CmrClubAiAssistantPanel extends StatefulWidget {
  final int clubId;
  final int userId;
  final int? teamId;
  final String? clubName;
  final String? teamName;
  final bool playerOnlyMode;

  /// Личный AI в профиле пользователя. В этом режиме клиент не отправляет
  /// club/team/player/session context и использует только personal API.
  final bool personalProfileMode;
  final int? playerId;
  final String? playerName;

  /// target: player_profile / tracker / report / calendar / match / testing / plans / attendance
  /// payload: ids/date/team_id/player_id/session_id/etc.
  final void Function(String target, Map<String, dynamic> payload)? onNavigate;

  /// Вызывается, когда в карточке есть готовый PDF/HTML отчет.
  /// Если не передать callback, ссылка копируется в буфер обмена.
  final void Function(String url)? onOpenPdf;

  /// Для мобильного режима: вернуться к предыдущему экрану.
  final VoidCallback? onBack;
  final String? initialPrompt;
  final Map<String, dynamic>? initialPayload;
  final bool autoSendInitialPrompt;

  const CmrClubAiAssistantPanel({
    super.key,
    required this.clubId,
    required this.userId,
    this.teamId,
    this.clubName,
    this.teamName,
    this.playerOnlyMode = false,
    this.personalProfileMode = false,
    this.playerId,
    this.playerName,
    this.onNavigate,
    this.onOpenPdf,
    this.onBack,
    this.initialPrompt,
    this.initialPayload,
    this.autoSendInitialPrompt = false,
  });

  @override
  State<CmrClubAiAssistantPanel> createState() =>
      _CmrClubAiAssistantPanelState();
}

class _CmrClubAiAssistantPanelState extends State<CmrClubAiAssistantPanel> {
  static const String _feedbackUrl =
      'https://sportotekaapp.ru/api/ai/v1/assistant/feedback';
  static const String _documentAskUrl =
      'https://sportotekaapp.ru/api/ai/v1/documents/ask';

  String get _askUrl => widget.personalProfileMode
      ? 'https://sportotekaapp.ru/api/ai/v1/personal/assistant/chat'
      : 'https://sportotekaapp.ru/api/ai/v1/assistant/chat';

  String get _askStreamUrl => widget.personalProfileMode
      ? 'https://sportotekaapp.ru/api/ai/v1/personal/assistant/chat/stream'
      : 'https://sportotekaapp.ru/api/ai/v1/assistant/chat/stream';

  String get _documentAskStreamUrl =>
      'https://sportotekaapp.ru/api/ai/v1/documents/ask/stream';

  String get _mediaBase => widget.personalProfileMode
      ? 'https://sportotekaapp.ru/api/ai/v1/personal/media'
      : 'https://sportotekaapp.ru/api/ai/v1/media';

  String get _documentBase => 'https://sportotekaapp.ru/api/ai/v1/documents';

  String get _historyBase => widget.personalProfileMode
      ? 'https://sportotekaapp.ru/api/ai/v1/personal/history'
      : 'https://sportotekaapp.ru/api/ai/v1/assistant/history';

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();
  final List<_AiMessage> _messages = <_AiMessage>[];
  final Map<_AiMessage, GlobalKey> _messageKeys = <_AiMessage, GlobalKey>{};
  final Set<String> _confirmingActionIds = <String>{};
  final Map<String, String> _completedActionMessages = <String, String>{};
  final Set<_AiMessage> _continuingMessages = <_AiMessage>{};

  late String _conversationId;
  bool _initialPromptSent = false;
  final List<_AiHistoryItem> _historyItems = <_AiHistoryItem>[];
  bool _historyLoading = false;
  bool _historyRailOpen = false; // по умолчанию история закрыта
  Timer? _historySaveDebounce;
  Timer? _streamFollowDebounce;
  bool _sending = false;
  _AiMessage? _activeStreamingMessage;
  http.Client? _activeAiClient;
  bool _stopRequested = false;
  String? _error;

  final ImagePicker _mediaPicker = ImagePicker();
  _AiComposerMode _composerMode = _AiComposerMode.text;
  XFile? _attachmentFile;
  Map<String, dynamic>? _uploadedAttachment;
  bool _uploadingAttachment = false;
  double _attachmentUploadProgress = 0;
  bool _attachmentUploadFailed = false;
  String? _attachmentUploadKind;

  bool get _hasActiveAiWork => _sending || _continuingMessages.isNotEmpty;
  bool get _canStopAi => _activeAiClient != null || _continuingMessages.isNotEmpty;

  String get _composerHint {
    switch (_composerMode) {
      case _AiComposerMode.image:
        return 'Опишите изображение, которое нужно создать…';
      case _AiComposerMode.video:
        return _attachmentFile == null
            ? 'Опишите видео, которое нужно создать…'
            : 'Опишите, как преобразовать выбранное медиа в видео…';
      case _AiComposerMode.text:
        if (_attachedDocumentId().isNotEmpty) {
          return 'Спросите по документу или сопоставьте его с данными команды…';
        }
        return _attachmentFile == null
            ? (widget.personalProfileMode
                ? 'Спросите что угодно или попросите помочь с текстом…'
                : widget.playerOnlyMode
                    ? 'Спросите о нагрузке, пульсе, скорости или тестах игрока...'
                    : 'Спросите: почему такой спринт, сделай анализ, нарисуй схему...')
            : 'Добавьте вопрос к выбранному файлу…';
    }
  }

  String get _composerModeLabel {
    switch (_composerMode) {
      case _AiComposerMode.image:
        return 'Изображение';
      case _AiComposerMode.video:
        return 'Видео';
      case _AiComposerMode.text:
        return 'ИИ-чат';
    }
  }

  List<String> get _starterPrompts {
    if (widget.personalProfileMode) {
      return const <String>[
        'Объясни высокий прессинг простыми словами',
        'Помоги написать пост для профиля',
        'Придумай идею для футбольной публикации',
        'Помоги составить план на день',
        'Придумай идею для изображения',
        'Напиши поздравление команде с победой',
      ];
    }

    if (widget.playerOnlyMode) {
      final player = (widget.playerName ?? '').trim();
      final prefix = player.isEmpty ? 'игрока' : player;
      return <String>[
        'Сделай анализ последних тренировок $prefix',
        'Оцени нагрузку и восстановление $prefix',
        'Покажи динамику скорости и спринтов $prefix',
        'Разбери пульс по последним сессиям $prefix',
        'Сравни последние тренировки $prefix',
        'Какие риски и рекомендации есть у $prefix?',
      ];
    }
    return const <String>[
      'Сделай анализ тренировки за вчера',
      'Сделай отчет по выбранной тренировке',
      'Разбери последнюю GPS/Polar тренировку команды',
      'Дай советы тренеру по нагрузке и скорости',
      'Покажи PDF отчета последней тренировки',
      'Кто перегружен по пульсу и спринтам?',
      'Что улучшить на следующей тренировке?',
      'Почему у игрока такой спринт?',
      'Нарисуй схему прессинга 4-3-3',
      'Сравни игроков по нагрузке за неделю',
      'Запомни: для U13 не ставить две скоростные тренировки подряд',
    ];
  }

  _AiMessage _welcomeMessage() {
    return _AiMessage.assistant(
      text: widget.personalProfileMode
          ? 'Я Спортотека AI — ваш личный помощник. Можете задать вопрос, попросить помочь с текстом, придумать публикацию, создать изображение или видео.'
          : widget.playerOnlyMode
              ? 'Я ИИ-помощник профиля игрока. В этом окне анализирую только данные ${((widget.playerName ?? '').trim().isEmpty ? 'выбранного игрока' : widget.playerName!.trim())}: тестирования, матчи, GPS/Polar-сессии, скорость, спринты, пульс и нагрузку.'
              : 'Я локальный ИИ клуба. Работаю на вашем сервере и вижу текущий контекст экрана: выбранную команду, тренировку, игроков и пульсовую точку. Ищу отчеты, делаю разбор GPS/Polar, объясняю причины нагрузки и предлагаю действия тренеру.',
      suggestions: _starterPrompts.take(4).toList(),
    );
  }

  String _newConversationId() {
    if (widget.personalProfileMode) {
      return 'personal:${widget.userId}:${DateTime.now().microsecondsSinceEpoch}';
    }
    return 'sportoteka:${widget.clubId}:${widget.teamId ?? 0}:'
        '${widget.playerId ?? 0}:${DateTime.now().microsecondsSinceEpoch}';
  }

  void _resetConversationState({bool notify = true}) {
    void apply() {
      _conversationId = _newConversationId();
      _messages
        ..clear()
        ..add(_welcomeMessage());
      _messageKeys.clear();
      _completedActionMessages.clear();
      _confirmingActionIds.clear();
      _continuingMessages.clear();
      _error = null;
      _sending = false;
      _activeStreamingMessage = null;
      _composerMode = _AiComposerMode.text;
      _attachmentFile = null;
      _uploadedAttachment = null;
    }

    if (notify && mounted) {
      setState(apply);
      _scrollToBottom();
    } else {
      apply();
    }
  }

  Uri _historyUri([String suffix = '']) {
    final path = suffix.isEmpty ? _historyBase : '$_historyBase/$suffix';
    return Uri.parse(path).replace(
      queryParameters: widget.personalProfileMode
          ? <String, String>{
              'user_id': widget.userId.toString(),
            }
          : <String, String>{
              'club_id': widget.clubId.toString(),
              'user_id': widget.userId.toString(),
              if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId.toString(),
              if (widget.playerOnlyMode && (widget.playerId ?? 0) > 0)
                'player_id': widget.playerId.toString(),
            },
    );
  }

  String get _historyTitle {
    for (final message in _messages) {
      if (message.role != _AiRole.user) continue;
      final text = message.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (text.isEmpty) continue;
      return text.length <= 64 ? text : '${text.substring(0, 61)}...';
    }
    if (widget.personalProfileMode) return 'Новый личный диалог';
    return widget.playerOnlyMode ? 'Новый диалог игрока' : 'Новый диалог';
  }

  Future<void> _loadHistoryIndex() async {
    if (_historyLoading) return;
    if (mounted) setState(() => _historyLoading = true);

    try {
      final res =
          await http.get(_historyUri()).timeout(const Duration(seconds: 15));
      final data = _decodeJson(res.body);
      if (res.statusCode != 200 || data is! Map) return;

      final raw =
          data['items'] is List ? data['items'] as List : const <dynamic>[];
      final items = raw
          .whereType<Map>()
          .map((e) => _AiHistoryItem.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.conversationId.isNotEmpty)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _historyItems
          ..clear()
          ..addAll(items);
      });
    } catch (_) {
      // История не должна мешать основному AI-чату.
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _restoreLatestHistory() async {
    await _loadHistoryIndex();
    if (!mounted || _historyItems.isEmpty) return;
    await _openHistoryConversation(_historyItems.first.conversationId);
  }

  Future<void> _openHistoryConversation(String conversationId) async {
    if (conversationId.trim().isEmpty) return;
    try {
      final uri = _historyUri('item').replace(
        queryParameters: <String, String>{
          ..._historyUri('item').queryParameters,
          'conversation_id': conversationId,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      final data = _decodeJson(res.body);
      if (res.statusCode != 200 || data is! Map) return;

      final raw = data['messages'] is List
          ? data['messages'] as List
          : const <dynamic>[];
      final restored = raw
          .whereType<Map>()
          .map((e) => _AiMessage.fromHistoryMap(Map<String, dynamic>.from(e)))
          .whereType<_AiMessage>()
          .toList(growable: true);

      if (!mounted) return;
      setState(() {
        _conversationId = '${data['conversation_id'] ?? conversationId}';
        _messages
          ..clear()
          ..addAll(
              restored.isEmpty ? <_AiMessage>[_welcomeMessage()] : restored);
        _messageKeys.clear();
        _error = null;
        _sending = false;
      });

      _scrollToBottom();

      // Если пользователь закрыл приложение во время генерации,
      // после возврата продолжим polling незавершённых media-job.
      for (final message in _messages) {
        if (message.jobId.isEmpty || message.mediaKind.isEmpty) continue;
        if (message.mediaStatus == 'completed' ||
            message.mediaStatus == 'failed') {
          continue;
        }
        unawaited(_pollMediaJob(
          kind: message.mediaKind,
          jobId: message.jobId,
        ));
      }
    } catch (_) {
      // Оставляем текущий диалог, если сеть временно недоступна.
    }
  }

  void _scheduleHistorySave() {
    _historySaveDebounce?.cancel();
    _historySaveDebounce = Timer(
      const Duration(milliseconds: 650),
      () => unawaited(_saveHistoryNow()),
    );
  }

  Future<void> _saveHistoryNow() async {
    final hasUserMessage =
        _messages.any((message) => message.role == _AiRole.user);
    if (!hasUserMessage || _conversationId.trim().isEmpty) return;

    final messages = _messages
        .take(220)
        .map((message) => message.toHistoryMap())
        .toList(growable: false);

    final payload = widget.personalProfileMode
        ? <String, dynamic>{
            'user_id': widget.userId,
            'conversation_id': _conversationId,
            'title': _historyTitle,
            'messages': messages,
          }
        : <String, dynamic>{
            'club_id': widget.clubId,
            'user_id': widget.userId,
            if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId,
            if (widget.playerOnlyMode && (widget.playerId ?? 0) > 0)
              'player_id': widget.playerId,
            'player_only': widget.playerOnlyMode,
            'conversation_id': _conversationId,
            'title': _historyTitle,
            'messages': messages,
          };

    try {
      final res = await http
          .post(
            Uri.parse('$_historyBase/save'),
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        unawaited(_loadHistoryIndex());
      }
    } catch (_) {
      // Не блокируем чат, если сохранение истории временно недоступно.
    }
  }

  Future<void> _startNewConversation() async {
    await _saveHistoryNow();
    if (!mounted) return;
    _resetConversationState();
  }

  Future<void> _deleteHistoryConversation(String conversationId) async {
    try {
      final uri = _historyUri('item').replace(
        queryParameters: <String, String>{
          ..._historyUri('item').queryParameters,
          'conversation_id': conversationId,
        },
      );
      final res = await http.delete(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;

      if (conversationId == _conversationId && mounted) {
        _resetConversationState();
      }
      await _loadHistoryIndex();
    } catch (_) {}
  }

  Future<void> _toggleHistoryRail() async {
    if (!mounted) return;
    final next = !_historyRailOpen;
    setState(() => _historyRailOpen = next);
    if (next) {
      await _loadHistoryIndex();
    }
  }

  Widget _buildHistoryRail({required double width}) {
    final railWidth = width < 560
        ? math.min(326.0, math.max(260.0, width * .86))
        : width < 930
            ? 280.0
            : width < 1180
                ? 304.0
                : 324.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: _historyRailOpen ? railWidth : 0,
      child: _historyRailOpen
          ? Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                border: Border(
                  right: BorderSide(color: _AiColors.line.withOpacity(.95)),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
                    child: Row(
                      children: [
                        const _AiSidebarGlyph(
                          size: 18,
                          color: _AiColors.greenDark,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'История',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _AiText.title(15.2),
                          ),
                        ),
                        _AiCircleAction(
                          icon: Icons.add_rounded,
                          onTap: () => unawaited(_startNewConversation()),
                        ),
                        const SizedBox(width: 4),
                        _AiCircleAction(
                          icon: Icons.close_rounded,
                          onTap: () => unawaited(_toggleHistoryRail()),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(9, 0, 9, 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(11),
                        onTap: () => unawaited(_startNewConversation()),
                        child: Container(
                          height: 39,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: _AiColors.line),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_square,
                                size: 16,
                                color: _AiColors.greenDark,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Новый чат',
                                  style: _AiText.title(13.5).copyWith(
                                    color: _AiColors.greenDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: _AiColors.line),
                  Expanded(
                    child: _historyLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _AiColors.green,
                              strokeWidth: 2,
                            ),
                          )
                        : _historyItems.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'История пока пустая',
                                    textAlign: TextAlign.center,
                                    style: _AiText.muted(12.4),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(7, 8, 7, 16),
                                itemCount: _historyItems.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 5),
                                itemBuilder: (_, index) {
                                  final item = _historyItems[index];
                                  final selected =
                                      item.conversationId == _conversationId;

                                  return Material(
                                    color: selected
                                        ? _AiColors.greenSoft
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () async {
                                        await _saveHistoryNow();
                                        await _openHistoryConversation(
                                          item.conversationId,
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          11,
                                          10,
                                          5,
                                          10,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: _AiText.title(
                                                      selected ? 14.0 : 13.6,
                                                    ),
                                                  ),
                                                  if (item.subtitle
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      item.subtitle,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          _AiText.muted(11.4),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              tooltip: 'Действия',
                                              padding: EdgeInsets.zero,
                                              icon: const Icon(
                                                Icons.more_horiz_rounded,
                                                size: 17,
                                                color: _AiColors.muted,
                                              ),
                                              onSelected: (value) {
                                                if (value == 'delete') {
                                                  unawaited(
                                                    _deleteHistoryConversation(
                                                      item.conversationId,
                                                    ),
                                                  );
                                                }
                                              },
                                              itemBuilder: (_) => const [
                                                PopupMenuItem<String>(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 17,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text('Удалить'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Future<void> _showHistorySheet() async {
    await _loadHistoryIndex();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> refresh() async {
              await _loadHistoryIndex();
              if (sheetContext.mounted) setSheetState(() {});
            }

            return SafeArea(
              top: false,
              child: SizedBox(
                height: math.min(
                  MediaQuery.sizeOf(sheetContext).height * .78,
                  660.0,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('История SPORTOTEKA ИИ',
                                    style: _AiText.title(17.0)),
                                const SizedBox(height: 3),
                                Text(
                                  'Сохраняется на сервере для этого пользователя',
                                  style: _AiText.muted(12.0),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              Navigator.of(sheetContext).pop();
                              if (!mounted) return;
                              await _startNewConversation();
                            },
                            icon: const Icon(Icons.add_rounded, size: 17),
                            label: const Text('Новый'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _AiColors.line),
                    Expanded(
                      child: _historyLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: _AiColors.green,
                                strokeWidth: 2,
                              ),
                            )
                          : _historyItems.isEmpty
                              ? Center(
                                  child: Text(
                                    'История пока пустая',
                                    style: _AiText.muted(12.5),
                                  ),
                                )
                              : RefreshIndicator(
                                  color: _AiColors.green,
                                  onRefresh: refresh,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                        10, 10, 10, 22),
                                    itemCount: _historyItems.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 4),
                                    itemBuilder: (_, index) {
                                      final item = _historyItems[index];
                                      final selected = item.conversationId ==
                                          _conversationId;
                                      return Material(
                                        color: selected
                                            ? _AiColors.greenSoft
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        child: ListTile(
                                          dense: true,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          leading: Icon(
                                            item.hasMedia
                                                ? Icons.photo_library_outlined
                                                : Icons
                                                    .chat_bubble_outline_rounded,
                                            color: _AiColors.greenDark,
                                            size: 19,
                                          ),
                                          title: Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: _AiText.title(13.8),
                                          ),
                                          subtitle: Text(
                                            item.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: _AiText.muted(11.4),
                                          ),
                                          trailing: IconButton(
                                            tooltip: 'Удалить',
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: _AiColors.muted,
                                            ),
                                            onPressed: () async {
                                              await _deleteHistoryConversation(
                                                  item.conversationId);
                                              if (sheetContext.mounted) {
                                                setSheetState(() {});
                                              }
                                            },
                                          ),
                                          onTap: () async {
                                            Navigator.pop(sheetContext);
                                            await _saveHistoryNow();
                                            await _openHistoryConversation(
                                                item.conversationId);
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _resetConversationState(notify: false);

    final initial = (widget.initialPrompt ?? '').trim();
    if (initial.isNotEmpty) {
      _input.text = initial;
      if (widget.autoSendInitialPrompt) {
        _initialPromptSent = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ask(initial);
        });
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_restoreLatestHistory());
      });
    }
  }

  @override
  void didUpdateWidget(covariant CmrClubAiAssistantPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initial = (widget.initialPrompt ?? '').trim();
    if (!_initialPromptSent &&
        widget.autoSendInitialPrompt &&
        initial.isNotEmpty) {
      _initialPromptSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ask(initial);
      });
    }
  }

  @override
  void dispose() {
    _historySaveDebounce?.cancel();
    _streamFollowDebounce?.cancel();
    _activeAiClient?.close();
    _activeAiClient = null;
    unawaited(_saveHistoryNow());
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  int _asInt(dynamic v) => int.tryParse('${v ?? ''}') ?? 0;

  List<int> _asIntList(dynamic value) {
    if (value is! Iterable) return <int>[];
    final ids = <int>{};
    for (final item in value) {
      final id = _asInt(item);
      if (id > 0) ids.add(id);
    }
    final result = ids.toList()..sort();
    return result;
  }

  Map<String, dynamic> _conversationMemory({int? throughIndex}) {
    final source = throughIndex == null
        ? _messages
        : _messages.take(math.min(throughIndex + 1, _messages.length));
    final history = source
        .where((message) => message.text.trim().isNotEmpty)
        .toList(growable: false);
    final from = math.max(0, history.length - 8);
    String compactText(String value) {
      final text = value.trim();
      if (text.length <= 1800) return text;
      return '${text.substring(0, 850)}\n…\n${text.substring(text.length - 850)}';
    }

    return <String, dynamic>{
      'policy': 'current_ui_context_first',
      'client_turns': history.sublist(from).map((message) {
        return <String, dynamic>{
          'role': message.role == _AiRole.user ? 'user' : 'assistant',
          'text': compactText(message.text),
          if (message.toolSource.isNotEmpty) 'tool_source': message.toolSource,
          if (message.verifiedData) 'verified_data': true,
        };
      }).toList(growable: false),
    };
  }

  dynamic _decodeJson(String body) {
    var t = body;
    if (t.isNotEmpty && t.codeUnitAt(0) == 0xFEFF) t = t.substring(1);
    t = t.trimLeft();
    final startObj = t.indexOf('{');
    final startArr = t.indexOf('[');
    int start = -1;
    if (startObj >= 0 && startArr >= 0) {
      start = startObj < startArr ? startObj : startArr;
    } else {
      start = startObj >= 0 ? startObj : startArr;
    }
    if (start > 0) t = t.substring(start);
    return json.decode(t);
  }

  void _resetComposerMode() {
    if (!mounted) return;
    setState(() => _composerMode = _AiComposerMode.text);
  }

  Future<void> _showAiPlusMenu() async {
    if (_sending || _uploadingAttachment) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.48),
      builder: (sheetContext) {
        Widget actionTile({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
          bool emphasized = false,
        }) {
          return Material(
            color:
                emphasized ? _AiColors.greenSoft.withOpacity(.9) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: emphasized ? _AiColors.greenBorder : _AiColors.line,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: emphasized ? Colors.white : _AiColors.greenSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: _AiColors.greenDark,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: _AiText.title(13.4),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _AiText.muted(10.7),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: _AiColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        Widget section({
          required String title,
          required String subtitle,
          required List<Widget> children,
        }) {
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _AiColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _AiText.title(13.8)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: _AiText.muted(10.6)),
                    ],
                  ),
                ),
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          );
        }

        void closeThen(VoidCallback callback) {
          Navigator.of(sheetContext).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            callback();
          });
        }

        final createActions = <Widget>[
          actionTile(
            icon: Icons.image_outlined,
            title: 'Создать изображение',
            subtitle: 'Sportoteka Image · генерация по описанию',
            onTap: () => closeThen(() {
              setState(() => _composerMode = _AiComposerMode.image);
              if (_focus.canRequestFocus) _focus.requestFocus();
            }),
          ),
          actionTile(
            icon: Icons.videocam_outlined,
            title: 'Создать видео',
            subtitle: 'Sportoteka Video · задача уйдёт в очередь',
            onTap: () => closeThen(() {
              setState(() => _composerMode = _AiComposerMode.video);
              if (_focus.canRequestFocus) _focus.requestFocus();
            }),
          ),
        ];

        final addActions = <Widget>[
          if (!widget.personalProfileMode)
            actionTile(
              icon: Icons.description_outlined,
              title: 'Добавить документ',
              subtitle:
                  'PDF, Word, Excel, презентации · прочитать и сохранить в OS',
              emphasized: true,
              onTap: () => closeThen(() {
                unawaited(_pickDocumentAttachment());
              }),
            ),
          actionTile(
            icon: Icons.photo_library_outlined,
            title: 'Добавить изображение',
            subtitle: 'Прикрепить фото к запросу ИИ',
            onTap: () => closeThen(() {
              unawaited(_pickAttachment(video: false));
            }),
          ),
          actionTile(
            icon: Icons.video_library_outlined,
            title: 'Добавить видео',
            subtitle: 'Прикрепить ролик к запросу ИИ',
            onTap: () => closeThen(() {
              unawaited(_pickAttachment(video: true));
            }),
          ),
        ];

        return SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = MediaQuery.sizeOf(sheetContext);
              final desktop = size.width >= 760;
              final horizontalPadding = desktop ? 24.0 : 12.0;
              final maxWidth = desktop ? 900.0 : 620.0;

              return Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: math.min(size.width, maxWidth),
                  constraints: BoxConstraints(
                    maxHeight: size.height * .86,
                  ),
                  margin: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.16),
                        blurRadius: 36,
                        spreadRadius: -10,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 42,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 13),
                            decoration: BoxDecoration(
                              color: _AiColors.line,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Что сделать с SPORTOTEKA AI?',
                                      style: _AiText.title(16.0),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      desktop
                                          ? 'Создание слева · добавление файлов справа'
                                          : 'Создание и добавление файлов',
                                      style: _AiText.muted(10.8),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Закрыть',
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (desktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: section(
                                    title: 'Создать',
                                    subtitle:
                                        'Новый контент по вашему описанию',
                                    children: createActions,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: section(
                                    title: 'Добавить',
                                    subtitle: 'Файлы и материалы для работы ИИ',
                                    children: addActions,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            section(
                              title: 'Добавить',
                              subtitle: 'Файлы и материалы для работы ИИ',
                              children: addActions,
                            ),
                            const SizedBox(height: 10),
                            section(
                              title: 'Создать',
                              subtitle: 'Новый контент по вашему описанию',
                              children: createActions,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _pickDocumentAttachment() async {
    if (_uploadingAttachment || _sending || widget.personalProfileMode) {
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>[
          'pdf', 'doc', 'docx', 'txt', 'md', 'rtf', 'csv', 'xlsx', 'pptx',
          'odt', 'jpg', 'jpeg', 'png', 'webp', 'heic',
        ],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final picked = result.files.single;
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _error = 'Не удалось прочитать выбранный документ.');
        return;
      }

      final xFile = XFile.fromData(bytes, name: picked.name);
      setState(() {
        _attachmentFile = xFile;
        _uploadedAttachment = null;
        _composerMode = _AiComposerMode.text;
      });
      await _uploadDocumentAttachment(xFile);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingAttachment = false;
        _attachmentUploadFailed = true;
        _error = 'Не удалось добавить документ. Можно нажать «Повторить».';
      });
    }
  }

  Future<void> _uploadDocumentAttachment(XFile file) async {
    if (!mounted || _uploadingAttachment || widget.personalProfileMode) return;

    setState(() {
      _uploadingAttachment = true;
      _attachmentUploadProgress = 0;
      _attachmentUploadFailed = false;
      _attachmentUploadKind = 'document';
      _error = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_documentBase/upload'),
      );
      request.fields['club_id'] = widget.clubId.toString();
      request.fields['user_id'] = widget.userId.toString();
      if ((widget.teamId ?? 0) > 0) {
        request.fields['team_id'] = widget.teamId.toString();
      }
      request.fields['title'] =
          file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      request.fields['ocr'] = 'auto';
      request.fields['extract_images'] = '1';
      request.fields['vision'] = '1';
      request.fields['analyze_layout'] = '1';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
      ));

      final streamed = await _sendMultipartWithProgress(
        request,
        timeout: const Duration(minutes: 8),
      );
      final response = await http.Response.fromStream(streamed);
      final data = _decodeJson(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data is! Map ||
          data['success'] != true) {
        throw Exception(
          data is Map
              ? (data['detail'] ??
                  data['message'] ??
                  'Не удалось обработать документ')
              : 'HTTP ${response.statusCode}',
        );
      }

      final attachment = data['attachment'] is Map
          ? Map<String, dynamic>.from(data['attachment'] as Map)
          : <String, dynamic>{};
      final document = data['document'] is Map
          ? Map<String, dynamic>.from(data['document'] as Map)
          : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _uploadedAttachment = attachment;
        _uploadingAttachment = false;
        _attachmentUploadProgress = 1;
        _attachmentUploadFailed = false;
        _messages.add(
          _AiMessage.assistant(
            text: document['needs_ocr'] == true
                ? 'Файл «${file.name}» сохранён. Для него включено распознавание OCR и анализ изображений, поэтому ИИ сможет видеть текст страниц, фото и схемы после обработки.'
                : 'Файл «${file.name}» прочитан и сохранён в Спортотека OS → Документы → Методические материалы AI. ИИ сможет использовать текст, изображения и страницы документа в ответах.',
            suggestions: const <String>[
              'Сделай краткий конспект документа',
              'Выдели упражнения и методические принципы',
              'Какие ограничения указаны в документе?',
              'Сопоставь рекомендации документа с последней тренировкой команды',
            ],
          ),
        );
      });
      _scrollToBottom();
      _scheduleHistorySave();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingAttachment = false;
        _attachmentUploadFailed = true;
        _error = 'Не удалось загрузить документ. Можно нажать «Повторить».';
      });
    }
  }

  String _attachedDocumentId() {
    final direct = '${_uploadedAttachment?['document_id'] ?? ''}'.trim();
    if (direct.isNotEmpty) return direct;

    final attachment = _uploadedAttachment?['attachment'];
    if (attachment is Map) {
      final nested = '${attachment['document_id'] ?? ''}'.trim();
      if (nested.isNotEmpty) return nested;
    }

    final document = _uploadedAttachment?['document'];
    if (document is Map) {
      return '${document['document_id'] ?? ''}'.trim();
    }

    return '';
  }

  Future<void> _askAttachedDocument(
    String q,
    String documentId,
  ) async {
    if (q.trim().isEmpty ||
        documentId.isEmpty ||
        _sending ||
        widget.personalProfileMode) {
      return;
    }

    _stopRequested = false;
    setState(() {
      _error = null;
      _sending = true;
      _messages.add(_AiMessage.user(q));
      _input.clear();
    });
    _scrollToBottom();
    _scheduleHistorySave();

    _AiMessage? responseMessage;

    try {
      final contextPayload = <String, dynamic>{
        ...?widget.initialPayload,
        'scope': 'workspace_document',
        'document_id': documentId,
        'attachment': _uploadedAttachment,
        'ocr': true,
        'include_images': true,
        'vision': true,
      };

      final data = await _postAiLegacyJson(
        url: '$_documentBase/ask',
        payload: <String, dynamic>{
          'club_id': widget.clubId,
          'user_id': widget.userId,
          if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId,
          'document_ids': <String>[documentId],
          'q': q,
          'conversation_id': _conversationId,
          'memory': _conversationMemory(),
          'ocr': true,
          'include_images': true,
          'vision': true,
          'context': contextPayload,
        },
      );

      if (!mounted) return;
      setState(() {
        responseMessage = _AiMessage.fromResponse(
          data,
          allowActions: false,
          fallbackText: 'Документ обработан.',
        );
        _messages.add(responseMessage!);
      });
    } on _AiGenerationStopped {
      if (!mounted) return;
      setState(() => _error = null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось проанализировать документ: $e';
        responseMessage = _AiMessage.assistant(
          text: 'Не удалось получить ответ по документу. '
              'Проверьте Document AI на сервере и повторите запрос.',
          suggestions: const <String>[
            'Сделай краткий конспект документа',
            'Какие основные принципы в документе?',
          ],
        );
        _messages.add(responseMessage!);
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
      // Во время streaming не перескакиваем от конца длинного ответа
      // обратно к началу сообщения. Это и давало резкий «прыжок» после final.
      if (_isNearChatBottom()) {
        _scheduleStreamingFollow(force: true);
      }
      _stopRequested = false;
      _scheduleHistorySave();
    }
  }

  Future<void> _pickAttachment({required bool video}) async {
    if (_uploadingAttachment) return;
    try {
      final XFile? file = video
          ? await _mediaPicker.pickVideo(source: ImageSource.gallery)
          : await _mediaPicker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      setState(() {
        _attachmentFile = file;
        _uploadedAttachment = null;
      });
      await _uploadAttachment(file, kind: video ? 'video' : 'image');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось выбрать файл: $e');
    }
  }

  Future<http.StreamedResponse> _sendMultipartWithProgress(
    http.MultipartRequest request, {
    required Duration timeout,
  }) async {
    final source = request.finalize();
    final total = request.contentLength;
    final streamedRequest = http.StreamedRequest(request.method, request.url)
      ..headers.addAll(request.headers)
      ..contentLength = total;

    var sent = 0;
    final client = http.Client();
    try {
      final responseFuture = client.send(streamedRequest).timeout(timeout);
      await for (final chunk in source) {
        streamedRequest.sink.add(chunk);
        sent += chunk.length;
        if (mounted && total > 0) {
          final progress = (sent / total).clamp(0.0, 1.0);
          if ((progress - _attachmentUploadProgress).abs() >= .01 ||
              progress >= 1) {
            setState(() => _attachmentUploadProgress = progress);
          }
        }
      }
      await streamedRequest.sink.close();
      return await responseFuture;
    } catch (_) {
      unawaited(streamedRequest.sink.close());
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> _uploadAttachment(XFile file, {required String kind}) async {
    if (!mounted || _uploadingAttachment) return;
    setState(() {
      _uploadingAttachment = true;
      _attachmentUploadProgress = 0;
      _attachmentUploadFailed = false;
      _attachmentUploadKind = kind;
      _error = null;
    });
    try {
      final req =
          http.MultipartRequest('POST', Uri.parse('$_mediaBase/upload'));
      req.fields['user_id'] = widget.userId.toString();
      if (!widget.personalProfileMode) {
        req.fields['club_id'] = widget.clubId.toString();
        if ((widget.teamId ?? 0) > 0) {
          req.fields['team_id'] = widget.teamId.toString();
        }
      }
      req.fields['kind'] = kind;

      final fileLength = await file.length();
      req.files.add(http.MultipartFile(
        'file',
        file.openRead(),
        fileLength,
        filename: file.name,
      ));

      final streamed = await _sendMultipartWithProgress(
        req,
        timeout: const Duration(minutes: 12),
      );
      final res = await http.Response.fromStream(streamed);
      final data = _decodeJson(res.body);
      if (res.statusCode != 200 || data is! Map || data['success'] == false) {
        throw Exception(
          data is Map
              ? (data['detail'] ?? data['message'] ?? 'Ошибка загрузки')
              : 'HTTP ${res.statusCode}',
        );
      }
      if (!mounted) return;
      setState(() {
        _uploadedAttachment = Map<String, dynamic>.from(data);
        _uploadingAttachment = false;
        _attachmentUploadProgress = 1;
        _attachmentUploadFailed = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingAttachment = false;
        _attachmentUploadFailed = true;
        _error = 'Не удалось загрузить файл. Можно нажать «Повторить».';
      });
    }
  }

  Future<void> _retryAttachmentUpload() async {
    final file = _attachmentFile;
    final kind = _attachmentUploadKind;
    if (file == null || kind == null || _uploadingAttachment) return;
    if (kind == 'document') {
      await _uploadDocumentAttachment(file);
    } else {
      await _uploadAttachment(file, kind: kind);
    }
  }

  void _clearAttachment() {
    if (!mounted) return;
    setState(() {
      _attachmentFile = null;
      _uploadedAttachment = null;
      _attachmentUploadProgress = 0;
      _attachmentUploadFailed = false;
      _attachmentUploadKind = null;
    });
  }

  Future<void> _sendCurrentComposer() async {
    switch (_composerMode) {
      case _AiComposerMode.image:
        await _startMediaGeneration('image');
        break;
      case _AiComposerMode.video:
        await _startMediaGeneration('video');
        break;
      case _AiComposerMode.text:
        await _ask();
        break;
    }
  }

  Future<void> _startMediaGeneration(String kind) async {
    final prompt = _input.text.trim();
    if (prompt.isEmpty || _sending || _uploadingAttachment) return;

    setState(() {
      _error = null;
      _sending = true;
      _messages.add(_AiMessage.user(prompt));
      _input.clear();
    });
    _scrollToBottom();
    _scheduleHistorySave();

    try {
      final payload = <String, dynamic>{
        'user_id': widget.userId,
        if (!widget.personalProfileMode) ...<String, dynamic>{
          'club_id': widget.clubId,
          if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId,
        },
        'prompt': prompt,
        if (_uploadedAttachment != null) 'attachment': _uploadedAttachment,
        if (kind == 'image') ...<String, dynamic>{
          'width': 768,
          'height': 768,
          'steps': 15,
          'guidance_scale': 5.0,
        } else ...<String, dynamic>{
          'width': 832,
          'height': 480,
          if (widget.personalProfileMode) 'frames': 17 else 'num_frames': 17,
          'steps': 8,
          'fps': 16,
        },
      };

      final res = await http
          .post(
            Uri.parse('$_mediaBase/$kind/generate'),
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 40));
      final data = _decodeJson(res.body);
      if (res.statusCode < 200 || res.statusCode >= 300 || data is! Map) {
        final detail = data is Map
            ? '${data['detail'] ?? data['message'] ?? data['error'] ?? 'HTTP ${res.statusCode}'}'
            : 'HTTP ${res.statusCode}';
        throw Exception(detail);
      }
      final jobId = '${data['job_id'] ?? ''}'.trim();
      if (jobId.isEmpty) {
        throw Exception(
            data['detail'] ?? data['message'] ?? 'job_id отсутствует');
      }
      final status = '${data['status'] ?? 'queued'}'.trim().toLowerCase();
      final progress = _asInt(data['progress']);

      final message = _AiMessage.assistantMedia(
        text: kind == 'image'
            ? 'Создаю Sportoteka Image по вашему описанию.'
            : 'Sportoteka Video поставлено в очередь. Можно продолжать работать в чате.',
        mediaKind: kind,
        jobId: jobId,
        mediaStatus: status,
        mediaProgress: progress,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _sending = false;
        _composerMode = _AiComposerMode.text;
      });
      _scrollToMessageStart(message);
      _scheduleHistorySave();
      unawaited(_pollMediaJob(kind: kind, jobId: jobId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _input.text = prompt;
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
        _error = 'Не удалось запустить генерацию: $e';
        _messages.add(
          _AiMessage.assistant(
            text:
                'Генерация сейчас не запустилась. Проверьте подключение AI Media API и повторите запрос.',
          ),
        );
      });
    }
  }

  Uri _mediaJobUri(
    String kind,
    String jobId, {
    bool result = false,
  }) {
    final path = result
        ? '$_mediaBase/$kind/jobs/$jobId/result'
        : '$_mediaBase/$kind/jobs/$jobId';

    return Uri.parse(path).replace(
      queryParameters: widget.personalProfileMode
          ? <String, String>{
              'user_id': widget.userId.toString(),
            }
          : <String, String>{
              'club_id': widget.clubId.toString(),
              'user_id': widget.userId.toString(),
            },
    );
  }

  Future<Map<String, dynamic>?> _loadMediaJobResult({
    required String kind,
    required String jobId,
  }) async {
    final res = await http
        .get(_mediaJobUri(kind, jobId, result: true))
        .timeout(const Duration(seconds: 20));

    final data = _decodeJson(res.body);
    if (res.statusCode != 200 || data is! Map) return null;

    return Map<String, dynamic>.from(data);
  }

  Future<void> _pollMediaJob({
    required String kind,
    required String jobId,
  }) async {
    final maxChecks = kind == 'video' ? 720 : 120;
    final delay = kind == 'video'
        ? const Duration(seconds: 10)
        : const Duration(seconds: 3);

    for (var i = 0; i < maxChecks; i++) {
      if (!mounted) return;
      if (i > 0) await Future<void>.delayed(delay);

      try {
        final res = await http
            .get(_mediaJobUri(kind, jobId))
            .timeout(const Duration(seconds: 20));

        final data = _decodeJson(res.body);

        if (res.statusCode != 200 || data is! Map) {
          // 4xx здесь уже означает не "задача ещё идёт", а неправильный
          // запрос/доступ. Не оставляем карточку бесконечно в очереди.
          if (res.statusCode >= 400 && res.statusCode < 500) {
            final detail = data is Map
                ? '${data['detail'] ?? data['message'] ?? 'HTTP ${res.statusCode}'}'
                : 'HTTP ${res.statusCode}';

            _updateMediaMessage(
              jobId,
              status: 'failed',
              progress: 0,
              errorText: detail,
            );
            return;
          }
          continue;
        }

        final status = '${data['status'] ?? ''}'.trim().toLowerCase();
        final progress = _asInt(data['progress']).clamp(0, 100).toInt();

        var rawUrl =
            '${data['output_url'] ?? data['result_url'] ?? data['url'] ?? ''}'
                .trim();
        var errorText = '${data['error'] ?? data['detail'] ?? ''}'.trim();

        // Некоторые worker/API возвращают output_url только через /result.
        // При completed дочитываем результат отдельным запросом с теми же
        // club_id/user_id.
        if (status == 'completed' && rawUrl.isEmpty) {
          final result = await _loadMediaJobResult(
            kind: kind,
            jobId: jobId,
          );
          if (result != null) {
            rawUrl =
                '${result['output_url'] ?? result['result_url'] ?? result['url'] ?? ''}'
                    .trim();
            if (errorText.isEmpty) {
              errorText = '${result['error'] ?? result['detail'] ?? ''}'.trim();
            }
          }
        }

        final mediaUrl = _absoluteMediaUrl(rawUrl);

        _updateMediaMessage(
          jobId,
          status: status.isEmpty ? 'processing' : status,
          progress: progress,
          mediaUrl: mediaUrl,
          errorText: errorText,
        );

        if (status == 'completed' || status == 'failed') return;
      } catch (_) {
        // Сетевая ошибка не отменяет задачу на сервере.
        // Следующий poll повторит проверку.
      }
    }

    if (mounted) {
      _updateMediaMessage(
        jobId,
        status: 'failed',
        progress: 0,
        errorText: 'Истекло время ожидания результата',
      );
    }
  }

  String _absoluteMediaUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) return 'https://sportotekaapp.ru$value';
    return 'https://sportotekaapp.ru/$value';
  }

  void _updateMediaMessage(
    String jobId, {
    required String status,
    required int progress,
    String mediaUrl = '',
    String errorText = '',
  }) {
    if (!mounted) return;
    final index = _messages.indexWhere((m) => m.jobId == jobId);
    if (index < 0) return;
    final current = _messages[index];
    final completed = status == 'completed';
    final failed = status == 'failed';
    setState(() {
      _messages[index] = current.copyWith(
        text: completed
            ? (current.mediaKind == 'image'
                ? 'Sportoteka Image готово.'
                : 'Sportoteka Video готово.')
            : failed
                ? 'Не удалось завершить генерацию${errorText.isEmpty ? '.' : ': $errorText'}'
                : current.text,
        mediaStatus: status,
        mediaProgress: progress,
        mediaUrl: mediaUrl.isEmpty ? current.mediaUrl : mediaUrl,
      );
    });
    _scheduleHistorySave();
  }

  bool _isNearChatBottom({double threshold = 220}) {
    if (!_scroll.hasClients) return true;
    final position = _scroll.position;
    final distance = position.maxScrollExtent - position.pixels;
    return distance <= threshold;
  }

  void _scheduleStreamingFollow({bool force = false}) {
    if (!mounted) return;
    _streamFollowDebounce?.cancel();
    _streamFollowDebounce = Timer(const Duration(milliseconds: 70), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        if (!force && !_isNearChatBottom()) return;
        final target = _scroll.position.maxScrollExtent;
        if ((target - _scroll.position.pixels).abs() < 1) return;
        // Во время потока не запускаем десятки animateTo одновременно:
        // именно это раньше давало заметные прыжки чата.
        _scroll.jumpTo(target);
      });
    });
  }

  void _applyStreamingText(
    String value, {
    required bool append,
  }) {
    if (!mounted || value.isEmpty) return;

    // Проверяем положение ДО setState. Если пользователь сам ушёл вверх,
    // поток больше не перетягивает его обратно вниз.
    final follow = _isNearChatBottom();

    setState(() {
      final current = _activeStreamingMessage;
      if (current == null || !_messages.contains(current)) {
        final created = _AiMessage.assistant(text: value);
        _messages.add(created);
        _activeStreamingMessage = created;
        return;
      }

      final index = _messages.indexOf(current);
      if (index < 0) return;
      final updated = current.copyWith(
        text: append ? '${current.text}$value' : value,
      );
      final existingKey = _messageKeys.remove(current);
      _messages[index] = updated;
      if (existingKey != null) _messageKeys[updated] = existingKey;
      _activeStreamingMessage = updated;
    });

    if (follow) _scheduleStreamingFollow(force: true);
  }

  void _applyStreamingFinal(
    Map<String, dynamic> data, {
    required bool allowActions,
  }) {
    if (!mounted) return;
    var finalMessage = _AiMessage.fromResponse(
      data,
      allowActions: allowActions,
      fallbackText: 'Нашёл результаты.',
    );

    setState(() {
      final current = _activeStreamingMessage;
      if (current != null && _messages.contains(current)) {
        // final-событие содержит метаданные, карточки и actions. Иногда его
        // answer после серверной нормализации короче уже показанного потока.
        // Текст на экране никогда не должен уменьшаться.
        if (current.text.trimRight().length >
            finalMessage.text.trimRight().length) {
          finalMessage = finalMessage.copyWith(text: current.text);
        }

        final index = _messages.indexOf(current);
        final existingKey = _messageKeys.remove(current);
        _messages[index] = finalMessage;
        if (existingKey != null) _messageKeys[finalMessage] = existingKey;
      } else {
        _messages.add(finalMessage);
      }
      // Не очищаем здесь: пока _sending=true, это предотвращает мигание
      // индикатора набора между final-event и finally.
      _activeStreamingMessage = finalMessage;
    });
  }

  void _stopAiGeneration() {
    if (!_hasActiveAiWork) return;
    _stopRequested = true;
    _activeAiClient?.close();
    _activeAiClient = null;

    if (!mounted) return;
    setState(() {
      _sending = false;
      final partial = _activeStreamingMessage;
      if (partial != null && _messages.contains(partial)) {
        final index = _messages.indexOf(partial);
        final updated = partial.copyWith(canContinue: true);
        final existingKey = _messageKeys.remove(partial);
        _messages[index] = updated;
        if (existingKey != null) _messageKeys[updated] = existingKey;
        _activeStreamingMessage = updated;
      }
      _continuingMessages.clear();
      _error = null;
    });
    _scheduleHistorySave();
  }

  Future<Map<String, dynamic>> _postAiNdjsonStream({
    required String url,
    required Map<String, dynamic> payload,
    required void Function(String event, Map<String, dynamic> packet) onEvent,
  }) async {
    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll(const <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/x-ndjson',
      'Cache-Control': 'no-cache',
    });
    request.body = jsonEncode(payload);

    final client = http.Client();
    _activeAiClient?.close();
    _activeAiClient = client;
    try {
      final response =
          await client.send(request).timeout(const Duration(seconds: 30));
      if (_stopRequested) throw const _AiGenerationStopped();

      if (response.statusCode == 404 || response.statusCode == 405) {
        await response.stream.drain();
        throw const _AiStreamingUnavailable();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        dynamic decoded;
        try {
          decoded = _decodeJson(body);
        } catch (_) {}
        throw Exception(
          decoded is Map
              ? (decoded['detail'] ??
                  decoded['message'] ??
                  'HTTP ${response.statusCode}')
              : 'HTTP ${response.statusCode}',
        );
      }

      Map<String, dynamic>? finalData;
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 210))) {
        if (_stopRequested) throw const _AiGenerationStopped();
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        dynamic decoded;
        try {
          decoded = jsonDecode(trimmed);
        } catch (_) {
          continue;
        }
        if (decoded is! Map) continue;
        final packet = Map<String, dynamic>.from(decoded);
        final event = '${packet['event'] ?? ''}'.trim();
        onEvent(event, packet);

        if (event == 'final' && packet['data'] is Map) {
          finalData = Map<String, dynamic>.from(packet['data'] as Map);
        } else if (event == 'error') {
          throw Exception('${packet['message'] ?? 'Ошибка потокового ответа'}');
        }
      }

      if (_stopRequested) throw const _AiGenerationStopped();
      if (finalData == null) {
        throw Exception('Сервер завершил поток без final-события');
      }
      return finalData;
    } finally {
      if (identical(_activeAiClient, client)) _activeAiClient = null;
      client.close();
    }
  }

  Future<Map<String, dynamic>> _postAiLegacyJson({
    required String url,
    required Map<String, dynamic> payload,
  }) async {
    final client = http.Client();
    _activeAiClient?.close();
    _activeAiClient = client;
    try {
      final res = await client
          .post(
            Uri.parse(url),
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 210));

      if (_stopRequested) throw const _AiGenerationStopped();
      final data = _decodeJson(res.body);
      if (res.statusCode != 200 || data is! Map || data['success'] != true) {
        throw Exception(
          data is Map
              ? (data['detail'] ?? data['message'] ?? 'Ошибка запроса')
              : 'HTTP ${res.statusCode}',
        );
      }
      return Map<String, dynamic>.from(data);
    } finally {
      if (identical(_activeAiClient, client)) _activeAiClient = null;
      client.close();
    }
  }

  Future<void> _ask([String? forced]) async {
    final q = (forced ?? _input.text).trim();
    if (q.isEmpty || _sending) return;

    final attachedDocumentId = _attachedDocumentId();
    if (attachedDocumentId.isNotEmpty && !widget.personalProfileMode) {
      await _askAttachedDocument(q, attachedDocumentId);
      return;
    }

    _stopRequested = false;
    setState(() {
      _error = null;
      _sending = true;
      _activeStreamingMessage = null;
      _messages.add(_AiMessage.user(q));
      _input.clear();
    });
    _scrollToBottom();
    _scheduleHistorySave();

    _AiMessage? responseMessage;
    try {
      final contextPayload = widget.personalProfileMode
          ? <String, dynamic>{}
          : <String, dynamic>{
              ...?widget.initialPayload,
              if (_uploadedAttachment != null) ...<String, dynamic>{
                'attachment': _uploadedAttachment,
                'attachment_analysis': <String, dynamic>{
                  'ocr': true,
                  'include_images': true,
                  'vision': true,
                },
              },
              if (widget.playerOnlyMode) 'scope': 'player_profile',
              if (widget.playerOnlyMode) 'player_only': true,
              if (widget.playerOnlyMode && (widget.playerId ?? 0) > 0)
                'player_id': widget.playerId,
              if (widget.playerOnlyMode &&
                  (widget.playerName ?? '').trim().isNotEmpty)
                'player_name': widget.playerName!.trim(),
            };
      final workspaceDocument = contextPayload['workspace_document'];
      final nestedDocumentKey = workspaceDocument is Map
          ? '${workspaceDocument['document_key'] ?? ''}'.trim()
          : '';
      final documentId =
          '${contextPayload['document_id'] ?? ''}'.trim().isNotEmpty
              ? '${contextPayload['document_id']}'.trim()
              : nestedDocumentKey;
      final documentAi =
          contextPayload['document_ai'] == true && documentId.isNotEmpty;
      final sessionIds = _asIntList(contextPayload['session_ids']);
      final contextSessionId = _asInt(contextPayload['session_id']);
      if (sessionIds.isEmpty && contextSessionId > 0) {
        sessionIds.add(contextSessionId);
      }
      final selectionMode = '${contextPayload['selection_mode'] ?? ''}';
      final contextPlayerId = _asInt(contextPayload['player_id']);
      final selectedDate = '${contextPayload['selected_date'] ?? ''}'.trim();
      final payload = widget.personalProfileMode
          ? <String, dynamic>{
              'user_id': widget.userId,
              'conversation_id': _conversationId,
              'q': q,
              'memory': _conversationMemory(),
            }
          : <String, dynamic>{
              'club_id': widget.clubId,
              'user_id': widget.userId,
              if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId,
              if (sessionIds.isNotEmpty) 'session_id': sessionIds.first,
              if (sessionIds.isNotEmpty) 'session_ids': sessionIds,
              if (selectedDate.isNotEmpty) 'selected_date': selectedDate,
              if (widget.playerOnlyMode && (widget.playerId ?? 0) > 0)
                'player_id': widget.playerId
              else if (selectionMode == 'single_player' && contextPlayerId > 0)
                'player_id': contextPlayerId,
              'conversation_id': _conversationId,
              'q': q,
              'context': contextPayload,
              'memory': _conversationMemory(),
              if (_uploadedAttachment != null) 'ocr': true,
              if (_uploadedAttachment != null) 'include_images': true,
              if (_uploadedAttachment != null) 'vision': true,
            };

      final requestUrl = documentAi ? _documentAskUrl : _askUrl;
      final streamUrl = documentAi ? _documentAskStreamUrl : _askStreamUrl;
      final requestPayload = documentAi
          ? <String, dynamic>{
              'club_id': widget.clubId,
              'user_id': widget.userId,
              if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId,
              'document_ids': <String>[documentId],
              'q': q,
              'conversation_id': _conversationId,
              'memory': _conversationMemory(),
              'context': contextPayload,
            }
          : payload;

      debugPrint('[AI_CHAT_STREAM] URL=$streamUrl');
      Map<String, dynamic> data;
      try {
        data = await _postAiNdjsonStream(
          url: streamUrl,
          payload: requestPayload,
          onEvent: (event, packet) {
            if (event == 'delta') {
              final text = '${packet['text'] ?? ''}';
              if (text.isNotEmpty) {
                _applyStreamingText(text, append: true);
              }
            } else if (event == 'snapshot') {
              final text = '${packet['text'] ?? ''}';
              if (text.isNotEmpty) {
                _applyStreamingText(text, append: false);
              }
            }
          },
        );
      } on _AiStreamingUnavailable {
        debugPrint('[AI_CHAT_STREAM] endpoint unavailable; fallback=$requestUrl');
        data = await _postAiLegacyJson(
          url: requestUrl,
          payload: requestPayload,
        );
      }

      if (!mounted) return;
      _applyStreamingFinal(
        data,
        allowActions: !widget.personalProfileMode,
      );
      responseMessage = _activeStreamingMessage;
    } on _AiGenerationStopped {
      if (!mounted) return;
      final partial = _activeStreamingMessage;
      if (partial != null && _messages.contains(partial)) {
        setState(() {
          final index = _messages.indexOf(partial);
          final updated = partial.copyWith(canContinue: true);
          final existingKey = _messageKeys.remove(partial);
          _messages[index] = updated;
          if (existingKey != null) _messageKeys[updated] = existingKey;
          _activeStreamingMessage = updated;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final partial = _activeStreamingMessage;
      setState(() {
        _error = widget.personalProfileMode
            ? 'Не удалось получить ответ: $e'
            : 'Не удалось выполнить поиск: $e';

        if (partial != null && _messages.contains(partial)) {
          final index = _messages.indexOf(partial);
          final updated = partial.copyWith(canContinue: true);
          final existingKey = _messageKeys.remove(partial);
          _messages[index] = updated;
          if (existingKey != null) _messageKeys[updated] = existingKey;
          responseMessage = updated;
          _activeStreamingMessage = updated;
        } else {
          responseMessage = _AiMessage.assistant(
            text: widget.personalProfileMode
                ? 'Не смог получить ответ от Спортотека AI. Проверьте подключение и попробуйте ещё раз.'
                : 'Не смог получить ответ от сервера. Можно попробовать короче: выбранный игрок + что ищем, например «отчёт за вчера» или «тренировки U13 за неделю».',
            suggestions: widget.personalProfileMode
                ? const <String>[
                    'Объясни высокий прессинг',
                    'Помоги написать короткий пост',
                    'Придумай идею для публикации',
                  ]
                : const <String>[
                    'Последние тренировки команды',
                    'Последняя GPS-сессия',
                    'Матчи за месяц',
                  ],
          );
          _messages.add(responseMessage!);
          _activeStreamingMessage = responseMessage;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _activeStreamingMessage = null;
        });
      }
      // После завершения потока не переносим viewport к началу большого
      // сообщения. Если пользователь оставался внизу — остаёмся внизу;
      // если он прокрутил вверх — вообще не вмешиваемся.
      if (_isNearChatBottom()) {
        _scheduleStreamingFollow(force: true);
      }
      _stopRequested = false;
      _scheduleHistorySave();
    }
  }

  String _stripContinuationPreamble(String value) {
    var text = value.trim();
    // Модель иногда начинает служебной фразой. В UI она только ломает
    // ощущение единого ответа, поэтому убираем её перед склейкой.
    text = text.replaceFirst(
      RegExp(
        r'^(?:#{1,6}\s*)?(?:продолжение|продолжаю|продолжение ответа)\s*[:.\-–—]*\s*',
        caseSensitive: false,
      ),
      '',
    );
    return text.trimLeft();
  }

  bool _endsWithFinishedThought(String value) {
    final text = value.trimRight();
    if (text.isEmpty) return true;
    return RegExp(r'''[.!?…\)\]\}»”"']$''').hasMatch(text);
  }

  bool _continuationLooksIncomplete(String value) {
    final text = value.trimRight();
    if (text.isEmpty) return false;
    if (!_endsWithFinishedThought(text)) return true;
    if (RegExp(r'[:;,\-–—]$').hasMatch(text)) return true;
    if (RegExp(r'(?:^|\n)\s*(?:[-•*]|\d+[.)])\s*$').hasMatch(text)) {
      return true;
    }
    return false;
  }

  String _mergeContinuationText(String current, String addition) {
    final base = current.trimRight();
    var next = _stripContinuationPreamble(addition);
    if (next.isEmpty) return base;

    // При «Далее» модель может повторить несколько последних символов/слов.
    // Ищем даже короткий overlap: это важно для обрыва внутри слова,
    // например «Манчестер Юнайт» + «Юнайтед ...».
    final maxOverlap = math.min(math.min(base.length, next.length), 1200);
    var overlap = 0;
    for (var size = maxOverlap; size >= 4; size--) {
      final left = base.substring(base.length - size);
      final right = next.substring(0, size);
      if (left.toLowerCase() == right.toLowerCase()) {
        overlap = size;
        break;
      }
    }
    if (overlap > 0) {
      next = next.substring(overlap);
    }
    next = next.trimLeft();
    if (next.isEmpty) return base;

    // Если предыдущая часть оборвалась, не создаём новый абзац. Сначала
    // достраиваем оборванное слово/предложение, чтобы ответ читался цельно.
    if (!_endsWithFinishedThought(base)) {
      final first = next.substring(0, 1);
      final last = base.substring(base.length - 1);
      final nextStartsLowerOrPunctuation =
          RegExp(r'^[а-яёa-z0-9,.;:!?…\)\]\}]$', caseSensitive: false)
              .hasMatch(first) &&
          first == first.toLowerCase();
      final baseEndsWord = RegExp(r'[A-Za-zА-Яа-яЁё0-9]$').hasMatch(last);

      if (baseEndsWord && nextStartsLowerOrPunctuation) {
        return '$base$next';
      }
      return '$base $next';
    }

    return '$base\n\n$next';
  }

  Map<String, dynamic> _continuationContextPayload() {
    if (widget.personalProfileMode) return <String, dynamic>{};
    return <String, dynamic>{
      ...?widget.initialPayload,
      if (_uploadedAttachment != null) ...<String, dynamic>{
        'attachment': _uploadedAttachment,
        'attachment_analysis': <String, dynamic>{
          'ocr': true,
          'include_images': true,
          'vision': true,
        },
      },
      if (widget.playerOnlyMode) 'scope': 'player_profile',
      if (widget.playerOnlyMode) 'player_only': true,
      if (widget.playerOnlyMode && (widget.playerId ?? 0) > 0)
        'player_id': widget.playerId,
      if (widget.playerOnlyMode &&
          (widget.playerName ?? '').trim().isNotEmpty)
        'player_name': widget.playerName!.trim(),
    };
  }

  Future<void> _continueAnswer(_AiMessage message) async {
    if (_sending || _continuingMessages.isNotEmpty || !message.canContinue) {
      return;
    }
    final index = _messages.indexOf(message);
    if (index < 0) return;

    var targetMessage = message;
    _stopRequested = false;
    setState(() {
      _error = null;
      _continuingMessages.add(targetMessage);
    });

    try {
      final contextPayload = _continuationContextPayload();
      final workspaceDocument = contextPayload['workspace_document'];
      final nestedDocumentKey = workspaceDocument is Map
          ? '${workspaceDocument['document_key'] ?? ''}'.trim()
          : '';
      final documentId =
          '${contextPayload['document_id'] ?? ''}'.trim().isNotEmpty
              ? '${contextPayload['document_id']}'.trim()
              : (_attachedDocumentId().isNotEmpty
                  ? _attachedDocumentId()
                  : nestedDocumentKey);
      final documentAi = documentId.isNotEmpty &&
          (contextPayload['document_ai'] == true ||
              _attachedDocumentId().isNotEmpty ||
              nestedDocumentKey.isNotEmpty);

      final currentText = message.text.trimRight();

      // PersonalAssistantRequest на сервере ограничивает поле q 2000
      // символами. Раньше инструкция + 1400 символов предыдущего ответа
      // превышали этот лимит, и FastAPI возвращал string_too_long ещё до Qwen.
      //
      // Предыдущий ответ уже присутствует в memory, поэтому для точной склейки
      // достаточно компактного хвоста. Используем runes, чтобы не разрезать
      // surrogate pair/emoji посередине.
      const continuationTailRunes = 720;
      const continuationQueryLimit = 1800; // запас до серверных 2000
      final currentRunes = currentText.runes.toList(growable: false);
      final tailFrom = math.max(0, currentRunes.length - continuationTailRunes);
      var answerTail =
          String.fromCharCodes(currentRunes.sublist(tailFrom));

      const continuePrefix =
          'Продолжи предыдущий ответ без вступления и без повторения уже '
          'показанного текста. Сохрани язык, формат и нумерацию. Если конец '
          'оборван внутри слова или предложения, сначала закончи этот фрагмент. '
          'Продолжай с места остановки до логического завершения текущего '
          'раздела или списка. Не заканчивай на двоеточии, пустом маркере или '
          'половине предложения. Верни только новый текст.\n\n'
          'КОНЕЦ ПРЕДЫДУЩЕГО ОТВЕТА:\n<<<';
      const continueSuffix =
          '>>>\n\nПродолжай непосредственно после текста перед >>>.';

      String buildContinuePrompt() =>
          '$continuePrefix$answerTail$continueSuffix';

      var continuePrompt = buildContinuePrompt();

      // Дополнительная защита на случай изменения инструкции в будущем:
      // q физически не уйдёт на сервер длиннее безопасного лимита.
      while (continuePrompt.runes.length > continuationQueryLimit &&
          answerTail.runes.length > 240) {
        final tailRunes = answerTail.runes.toList(growable: false);
        final removeCount =
            math.min(120, math.max(1, tailRunes.length - 240)).toInt();
        answerTail =
            String.fromCharCodes(tailRunes.sublist(removeCount));
        continuePrompt = buildContinuePrompt();
      }

      debugPrint(
        '[AI_CONTINUE] q_chars=${continuePrompt.runes.length} '
        'tail_chars=${answerTail.runes.length}',
      );

      final memory = _conversationMemory(throughIndex: index);
      final requestUrl = documentAi ? _documentAskUrl : _askUrl;
      final streamUrl = documentAi ? _documentAskStreamUrl : _askStreamUrl;
      final requestPayload = documentAi
          ? <String, dynamic>{
              'club_id': widget.clubId,
              'user_id': widget.userId,
              if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId,
              'document_ids': <String>[documentId],
              'q': continuePrompt,
              'conversation_id': _conversationId,
              'memory': memory,
              'context': contextPayload,
              'continuation': true,
              'ocr': true,
              'include_images': true,
              'vision': true,
              if (message.queryId > 0)
                'continuation_of_query_id': message.queryId,
            }
          : widget.personalProfileMode
              ? <String, dynamic>{
                  'user_id': widget.userId,
                  'conversation_id': _conversationId,
                  'q': continuePrompt,
                  'memory': memory,
                  'continuation': true,
                  if (message.queryId > 0)
                    'continuation_of_query_id': message.queryId,
                }
              : <String, dynamic>{
                  'club_id': widget.clubId,
                  'user_id': widget.userId,
                  if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId,
                  'conversation_id': _conversationId,
                  'q': continuePrompt,
                  'context': contextPayload,
                  'memory': memory,
                  'continuation': true,
                  if (message.queryId > 0)
                    'continuation_of_query_id': message.queryId,
                  if (_uploadedAttachment != null) 'ocr': true,
                  if (_uploadedAttachment != null) 'include_images': true,
                  if (_uploadedAttachment != null) 'vision': true,
                };

      var streamedPart = '';

      void showContinuationPart(String nextPart) {
        if (!mounted || nextPart.isEmpty) return;
        final follow = _isNearChatBottom();
        final currentIndex = _messages.indexOf(targetMessage);
        if (currentIndex < 0) return;
        final current = _messages[currentIndex];
        final updated = current.copyWith(
          text: _mergeContinuationText(currentText, nextPart),
          canContinue: true,
        );
        final existingKey = _messageKeys.remove(current);
        setState(() {
          _messages[currentIndex] = updated;
          if (existingKey != null) _messageKeys[updated] = existingKey;
          _continuingMessages.remove(targetMessage);
          targetMessage = updated;
          _continuingMessages.add(targetMessage);
        });
        if (follow) _scheduleStreamingFollow(force: true);
      }

      Map<String, dynamic> data;
      try {
        data = await _postAiNdjsonStream(
          url: streamUrl,
          payload: requestPayload,
          onEvent: (event, packet) {
            if (event == 'delta') {
              streamedPart += '${packet['text'] ?? ''}';
              if (streamedPart.isNotEmpty) {
                showContinuationPart(streamedPart);
              }
            } else if (event == 'snapshot') {
              streamedPart = '${packet['text'] ?? ''}';
              if (streamedPart.isNotEmpty) {
                showContinuationPart(streamedPart);
              }
            }
          },
        );
      } on _AiStreamingUnavailable {
        data = await _postAiLegacyJson(
          url: requestUrl,
          payload: requestPayload,
        );
      }

      final nextPart = _AiMessage.fromResponse(
        data,
        allowActions: false,
        fallbackText: '',
      );

      if (!mounted) return;
      final currentIndex = _messages.indexOf(targetMessage);
      if (currentIndex < 0) return;
      final current = _messages[currentIndex];

      // Никогда не заменяем уже показанное потоковое продолжение более
      // коротким final.answer — раньше несколько последних строк могли исчезать.
      final finalPart = nextPart.text.trimRight().length >=
              streamedPart.trimRight().length
          ? nextPart.text
          : streamedPart;
      final mergedText = _mergeContinuationText(currentText, finalPart);
      final keepContinue = finalPart.trim().isNotEmpty &&
          (nextPart.canContinue || _continuationLooksIncomplete(mergedText));
      final updated = current.copyWith(
        text: mergedText,
        canContinue: keepContinue,
      );
      final existingKey = _messageKeys.remove(current);

      setState(() {
        _messages[currentIndex] = updated;
        if (existingKey != null) _messageKeys[updated] = existingKey;
        _continuingMessages.remove(targetMessage);
        targetMessage = updated;
        _continuingMessages.add(targetMessage);
      });
      _scheduleHistorySave();
      if (_isNearChatBottom()) {
        _scheduleStreamingFollow(force: true);
      }
    } on _AiGenerationStopped {
      if (!mounted) return;
      setState(() => _error = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить продолжение: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить продолжение ответа')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _continuingMessages.remove(message);
          _continuingMessages.remove(targetMessage);
        });
      }
      _stopRequested = false;
    }
  }

  Future<void> _sendFeedback(_AiMessage message, int rating,
      {String comment = ''}) async {
    if (widget.personalProfileMode || message.queryId <= 0) return;
    try {
      await http.post(
        Uri.parse(_feedbackUrl),
        headers: const <String, String>{
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'club_id': widget.clubId,
          'user_id': widget.userId,
          if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId,
          'query_id': message.queryId,
          'rating': rating,
          'comment': comment,
        }),
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(rating > 0
                ? 'Запомнил: ответ полезный'
                : 'Запомнил: ответ надо улучшить')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить оценку ИИ')));
    }
  }

  String _actionKey(AiWorkspaceAction action) {
    if (action.id.trim().isNotEmpty) return action.id.trim();
    return '${action.type}:${action.actionToken}';
  }

  Future<void> _confirmAction(AiWorkspaceAction action) async {
    final key = _actionKey(action);
    if (!action.canConfirm || _confirmingActionIds.contains(key)) return;
    final teamId = _asInt(action.payload['team_id'] ?? widget.teamId);

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Подтвердить действие ИИ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(action.title),
            if (action.description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                action.description,
                style: const TextStyle(color: _AiColors.muted),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'Запись будет выполнена один раз. Перед выполнением сервер повторно проверит клуб, пользователя, команду и исходное состояние.',
              style: TextStyle(
                color: _AiColors.text2,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _AiColors.greenDark),
            child: const Text('Подтверждаю'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    setState(() {
      _confirmingActionIds.add(key);
      _error = null;
    });
    try {
      final result = await AiWorkspaceActionApi.confirm(
        clubId: widget.clubId,
        userId: widget.userId,
        teamId: teamId,
        conversationId: _conversationId,
        actionToken: action.actionToken,
      );
      if (!mounted) return;
      final message = '${result['answer'] ?? 'Действие выполнено'}'.trim();
      final completedPayload = <String, dynamic>{...result};
      final completedAction = result['action'];
      if (completedAction is Map) {
        completedPayload['actions'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': action.id,
            'type': '${completedAction['type'] ?? action.type}',
            'title': action.title,
            'description': message,
            'status': 'completed',
            'requires_confirmation': false,
            'payload': action.payload,
            'result': completedAction['result'] is Map
                ? Map<String, dynamic>.from(completedAction['result'] as Map)
                : const <String, dynamic>{},
          },
        ];
      }
      final completedMessage = _AiMessage.fromResponse(
        completedPayload,
        allowActions: true,
        fallbackText: 'Действие выполнено',
      );
      setState(() {
        _completedActionMessages[key] = message;
        _messages.add(completedMessage);
      });
      _scheduleHistorySave();
      _scrollToMessageStart(completedMessage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message.isEmpty ? 'Действие выполнено' : message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Действие не выполнено: $e');
    } finally {
      if (mounted) setState(() => _confirmingActionIds.remove(key));
    }
  }

  void _scrollToBottom() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 240,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  GlobalKey _messageKey(_AiMessage message) =>
      _messageKeys.putIfAbsent(message, GlobalKey.new);

  void _scrollToMessageStart(_AiMessage message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _messageKey(message).currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openPdf(_AiResultCard card) async {
    final url = card.pdfUrl.trim();
    if (url.isEmpty) return;
    if (widget.onOpenPdf != null) {
      widget.onOpenPdf!(url);
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Ссылка на PDF скопирована. Откройте ее в браузере или обработайте через onOpenPdf.')),
    );
  }

  void _openCard(_AiResultCard card) {
    final target = card.target.trim();
    final payload = Map<String, dynamic>.from(card.payload);
    if (target.isEmpty) return;

    if (widget.onNavigate != null) {
      widget.onNavigate!(target, payload);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Переход: $target ${payload.isEmpty ? '' : payload}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      minimum: const EdgeInsets.only(top: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.sizeOf(context);
          final width =
              constraints.maxWidth.isFinite && constraints.maxWidth > 0
                  ? constraints.maxWidth
                  : media.width;
          final safeHeight = constraints.maxHeight.isFinite &&
                  constraints.maxHeight > 120
              ? constraints.maxHeight
              : math.max(620.0,
                  media.height - MediaQuery.paddingOf(context).vertical - 18);
          final phone = width < 700;
          final tablet = width >= 700 && width < 1120;

          return SizedBox(
            width: double.infinity,
            height: safeHeight,
            child: Container(
              decoration: _AiDecor.workspaceBg(),
              padding: EdgeInsets.all(phone
                  ? 6
                  : tablet
                      ? 8
                      : 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(phone ? 16 : 18),
                child: Container(
                  decoration: _AiDecor.unifiedWindow(radius: phone ? 16 : 18),
                  child: phone ? _buildPhone() : _buildDesktop(width: width),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhone() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        return Stack(
          children: [
            // Основной AI-чат всегда остаётся в этом же окне.
            Column(
              children: [
                _AiHeader(
                  clubName: widget.clubName,
                  teamName: widget.teamName,
                  compact: true,
                  onExample: () => _ask(
                    widget.personalProfileMode
                        ? 'Объясни высокий прессинг простыми словами'
                        : widget.playerOnlyMode
                            ? 'Сделай краткий анализ последних данных игрока'
                            : 'Найди последний отчет по игроку',
                  ),
                  onHistory: () => unawaited(_toggleHistoryRail()),
                  onNewChat: () => unawaited(_startNewConversation()),
                  historyOpen: _historyRailOpen,
                  playerOnlyMode: widget.playerOnlyMode,
                  personalProfileMode: widget.personalProfileMode,
                  playerName: widget.playerName,
                  onBack: widget.onBack,
                ),
                Expanded(child: _buildChat(compact: true)),
                _buildComposer(compact: true),
              ],
            ),

            // Это НЕ modal/bottom sheet. Затемнение находится внутри
            // текущего окна и только визуально отделяет боковую панель.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_historyRailOpen,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _historyRailOpen ? 1 : 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(_toggleHistoryRail()),
                    child: Container(
                      color: Colors.black.withOpacity(.055),
                    ),
                  ),
                ),
              ),
            ),

            // История выдвигается слева прямо внутри AI-окна.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ClipRect(
                child: _buildHistoryRail(width: width),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktop({required double width}) {
    final showRail =
        !widget.personalProfileMode && !widget.playerOnlyMode && width >= 1180;

    return Row(
      children: [
        if (showRail && !_historyRailOpen) ...[
          SizedBox(width: 310, child: _buildRail()),
          Container(width: 1, color: _AiColors.line.withOpacity(.9)),
        ],

        // История как в ChatGPT: по умолчанию закрыта.
        // Нажатие на иконку плавно раскрывает её в этом же окне.
        _buildHistoryRail(width: width),

        Expanded(
          child: Column(
            children: [
              _AiHeader(
                clubName: widget.clubName,
                teamName: widget.teamName,
                compact: false,
                onExample: () => _ask(widget.personalProfileMode
                    ? 'Помоги написать короткий пост для профиля'
                    : widget.playerOnlyMode
                        ? 'Сделай краткий анализ последних данных игрока'
                        : 'Покажи последнюю тренировку и отчет команды'),
                onHistory: () => unawaited(_toggleHistoryRail()),
                onNewChat: () => unawaited(_startNewConversation()),
                historyOpen: _historyRailOpen,
                playerOnlyMode: widget.playerOnlyMode,
                personalProfileMode: widget.personalProfileMode,
                playerName: widget.playerName,
                onBack: widget.onBack,
              ),
              Expanded(child: _buildChat(compact: false)),
              _buildComposer(compact: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRail() {
    const blocks = <_AiQuickBlock>[
      _AiQuickBlock(Icons.person_search_rounded, 'Игрок',
          'Найти профиль, тренировки, отчеты и тесты игрока.'),
      _AiQuickBlock(Icons.monitor_heart_rounded, 'Трекер',
          'GPS/Polar, скорость, пульс, спринты, нагрузка.'),
      _AiQuickBlock(Icons.event_rounded, 'Календарь',
          'Тренировки, матчи, события и посещаемость.'),
      _AiQuickBlock(Icons.assignment_rounded, 'Отчеты',
          'PDF/HTML отчет, карточка сессии и экспорт.'),
      _AiQuickBlock(Icons.tips_and_updates_rounded, 'Советы',
          'Выводы по футболу: нагрузка, спринты, пульс, риски.'),
      _AiQuickBlock(Icons.sports_soccer_rounded, 'Схемы',
          'Построение расстановки, прессинга, розыгрыша и стандартов.'),
      _AiQuickBlock(Icons.psychology_alt_rounded, 'Самообучение',
          'ИИ запоминает оценки тренера и лучшие ответы клуба.'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: _AiDecor.aiGradient(radius: 13),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SPORTOTEKA ИИ', style: _AiText.title(16.2)),
                    const SizedBox(height: 4),
                    Text('Поиск, разбор, схемы, память',
                        style: _AiText.muted(11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final b in blocks) ...[
            _AiQuickBlockTile(block: b),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _AiColors.line),
            ),
            child: Text(
              'Пишите как тренер: «сделай анализ тренировки», «дай советы по нагрузке», «сформируй PDF». ИИ соберёт данные из GPS, Polar, сессии, игрока и команды.',
              style: _AiText.muted(11.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat({required bool compact}) {
    final showTyping = _sending && _activeStreamingMessage == null;
    return Container(
      color: Colors.transparent,
      child: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(compact ? 10 : 18, compact ? 10 : 16,
            compact ? 10 : 18, compact ? 16 : 20),
        itemCount: _messages.length + (showTyping ? 1 : 0),
        itemBuilder: (context, index) {
          if (showTyping && index == _messages.length) {
            return const _AiTypingBubble();
          }
          final msg = _messages[index];
          return KeyedSubtree(
            key: _messageKey(msg),
            child: _AiBubble(
              message: msg,
              compact: compact,
              onSuggestion: _ask,
              onOpenCard: _openCard,
              onOpenPdf: _openPdf,
              onFeedback: _sendFeedback,
              onContinue: (message) => unawaited(_continueAnswer(message)),
              continuing: _continuingMessages.contains(msg),
              onConfirmAction: (action) => unawaited(_confirmAction(action)),
              isActionBusy: (action) =>
                  _confirmingActionIds.contains(_actionKey(action)),
              actionResult: (action) =>
                  _completedActionMessages[_actionKey(action)] ?? '',
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposer({required bool compact}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 14,
        8,
        compact ? 8 : 14,
        compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.44),
        border: Border(top: BorderSide(color: _AiColors.line.withOpacity(.7))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            _AiInlineError(text: _error!),
            const SizedBox(height: 8),
          ],
          if (_composerMode != _AiComposerMode.text ||
              _attachmentFile != null) ...[
            Row(
              children: [
                if (_composerMode != _AiComposerMode.text)
                  _AiComposerModeChip(
                    label: _composerModeLabel,
                    icon: _composerMode == _AiComposerMode.image
                        ? Icons.image_outlined
                        : Icons.videocam_outlined,
                    onClose: _resetComposerMode,
                  ),
                if (_composerMode != _AiComposerMode.text &&
                    _attachmentFile != null)
                  const SizedBox(width: 6),
                if (_attachmentFile != null)
                  Expanded(
                    child: _AiComposerAttachmentChip(
                      name: _attachmentFile!.name,
                      uploading: _uploadingAttachment,
                      progress: _attachmentUploadProgress,
                      failed: _attachmentUploadFailed,
                      onRetry: _attachmentUploadKind == null
                          ? null
                          : () => unawaited(_retryAttachmentUpload()),
                      icon: _attachedDocumentId().isNotEmpty
                          ? Icons.description_outlined
                          : Icons.attach_file_rounded,
                      onClose: _clearAttachment,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
          ],
          Row(
            children: [
              // Такой же компактный +, как в Community: зелёный квадрат 25x25
              // внутри 36x36 зоны нажатия.
              Tooltip(
                message: 'AI-инструменты',
                child: IconButton(
                  onPressed: (_sending || _uploadingAttachment)
                      ? null
                      : _showAiPlusMenu,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: Container(
                    width: 25,
                    height: 25,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (_sending || _uploadingAttachment)
                          ? _AiColors.line
                          : _AiColors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 42),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _AiColors.line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.035),
                        blurRadius: 18,
                        spreadRadius: -12,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        _composerMode == _AiComposerMode.image
                            ? Icons.image_outlined
                            : _composerMode == _AiComposerMode.video
                                ? Icons.videocam_outlined
                                : Icons.auto_awesome_rounded,
                        color: _AiColors.greenDark,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _input,
                          focusNode: _focus,
                          minLines: 1,
                          maxLines: compact ? 3 : 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (!_hasActiveAiWork && !_uploadingAttachment) {
                              unawaited(_sendCurrentComposer());
                            }
                          },
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: _composerHint,
                            isDense: true,
                          ),
                          style: _AiText.value(compact ? 12.5 : 13.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _uploadingAttachment
                      ? null
                      : _canStopAi
                          ? _stopAiGeneration
                          : _hasActiveAiWork
                              ? null
                              : () => unawaited(_sendCurrentComposer()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: compact ? 42 : 46,
                    height: compact ? 42 : 46,
                    decoration: (_uploadingAttachment ||
                            (_hasActiveAiWork && !_canStopAi))
                        ? _AiDecor.disabledButton(radius: 14)
                        : _canStopAi
                            ? BoxDecoration(
                                color: _AiColors.graphite,
                                borderRadius: BorderRadius.circular(14),
                              )
                            : _AiDecor.aiGradient(radius: 14),
                    child: Icon(
                      _uploadingAttachment ||
                              (_hasActiveAiWork && !_canStopAi)
                          ? Icons.more_horiz_rounded
                          : _canStopAi
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: _canStopAi ? 18 : 19,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiComposerModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onClose;

  const _AiComposerModeChip({
    required this.label,
    required this.icon,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 9, right: 4),
      decoration: BoxDecoration(
        color: _AiColors.greenSoft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _AiColors.greenBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _AiColors.greenDark),
          const SizedBox(width: 6),
          Text(label,
              style: _AiText.chip(size: 10.2, color: _AiColors.greenDark)),
          const SizedBox(width: 2),
          InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: onClose,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  size: 14, color: _AiColors.greenDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiComposerAttachmentChip extends StatelessWidget {
  final String name;
  final bool uploading;
  final double progress;
  final bool failed;
  final IconData icon;
  final VoidCallback onClose;
  final VoidCallback? onRetry;

  const _AiComposerAttachmentChip({
    required this.name,
    required this.uploading,
    required this.progress,
    required this.failed,
    this.icon = Icons.attach_file_rounded,
    required this.onClose,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.only(left: 9, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: failed
            ? const Color(0xFFFFF7F6)
            : Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: failed ? const Color(0xFFF1B8B2) : _AiColors.line,
        ),
      ),
      child: Row(
        children: [
          if (uploading)
            SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress.clamp(0.0, 1.0) : null,
                strokeWidth: 2,
                color: _AiColors.green,
              ),
            )
          else
            Icon(
              failed ? Icons.error_outline_rounded : icon,
              size: 14,
              color: failed ? const Color(0xFFB6473D) : _AiColors.greenDark,
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              uploading
                  ? 'Загрузка $percent% · $name'
                  : failed
                      ? 'Не загружено · $name'
                      : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _AiText.chip(
                size: 10.0,
                color: failed ? const Color(0xFF9A3B33) : _AiColors.text2,
              ),
            ),
          ),
          if (failed && onRetry != null) ...[
            const SizedBox(width: 4),
            InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                child: Text(
                  'Повторить',
                  style: _AiText.chip(
                    size: 9.7,
                    color: _AiColors.greenDark,
                  ),
                ),
              ),
            ),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: uploading ? null : onClose,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child:
                  Icon(Icons.close_rounded, size: 14, color: _AiColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiHeader extends StatelessWidget {
  final String? clubName;
  final String? teamName;
  final bool compact;
  final VoidCallback onExample;
  final VoidCallback onHistory;
  final VoidCallback onNewChat;
  final bool historyOpen;
  final bool playerOnlyMode;
  final bool personalProfileMode;
  final String? playerName;
  final VoidCallback? onBack;

  const _AiHeader(
      {required this.clubName,
      required this.teamName,
      required this.compact,
      required this.onExample,
      required this.onHistory,
      required this.onNewChat,
      this.historyOpen = false,
      this.playerOnlyMode = false,
      this.personalProfileMode = false,
      this.playerName,
      this.onBack});

  @override
  Widget build(BuildContext context) {
    final scope = personalProfileMode
        ? 'Личный помощник'
        : playerOnlyMode
            ? ((playerName ?? '').trim().isEmpty
                ? 'Только выбранный игрок'
                : 'Только ${playerName!.trim()}')
            : [
                if ((clubName ?? '').trim().isNotEmpty) clubName!.trim(),
                if ((teamName ?? '').trim().isNotEmpty) teamName!.trim(),
              ].join(' · ');

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 14, compact ? 9 : 11,
          compact ? 10 : 14, compact ? 9 : 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.38),
        border: Border(
            bottom:
                BorderSide(color: _AiColors.line.withOpacity(.72), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 35 : 38,
            height: compact ? 35 : 38,
            decoration: _AiDecor.aiSoft(radius: 11),
            child: const Icon(Icons.auto_awesome_rounded,
                color: _AiColors.greenDark, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                        child: Text(
                            personalProfileMode
                                ? 'Спортотека AI'
                                : playerOnlyMode
                                    ? 'ИИ игрока'
                                    : 'ИИ помощник',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _AiText.title(compact ? 15 : 15.8))),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: _AiColors.graphite,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('beta',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.4,
                              fontWeight: FontWeight.w600,
                              height: 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    scope.isEmpty
                        ? (personalProfileMode
                            ? 'Личный помощник'
                            : 'Поиск по клубу, командам и отчетам')
                        : scope,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _AiText.muted(compact ? 10.2 : 10.8)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onBack != null) ...[
            _AiCircleAction(icon: Icons.close_rounded, onTap: onBack!),
            const SizedBox(width: 6),
          ],
          if (!compact) ...[
            _AiSidebarAction(
              open: historyOpen,
              onTap: onHistory,
            ),
            const SizedBox(width: 6),
            _AiCircleAction(
              icon: Icons.add_comment_outlined,
              onTap: onNewChat,
            ),
            const SizedBox(width: 6),
            _AiCircleAction(
              icon: Icons.bolt_rounded,
              onTap: onExample,
            ),
          ] else ...[
            _AiSidebarAction(
              open: false,
              onTap: onHistory,
            ),
            const SizedBox(width: 5),
            _AiCircleAction(
              icon: Icons.add_comment_outlined,
              onTap: onNewChat,
            ),
          ],
        ],
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final _AiMessage message;
  final bool compact;
  final ValueChanged<String> onSuggestion;
  final ValueChanged<_AiResultCard> onOpenCard;
  final ValueChanged<_AiResultCard> onOpenPdf;
  final void Function(_AiMessage message, int rating) onFeedback;
  final ValueChanged<_AiMessage> onContinue;
  final bool continuing;
  final ValueChanged<AiWorkspaceAction> onConfirmAction;
  final bool Function(AiWorkspaceAction action) isActionBusy;
  final String Function(AiWorkspaceAction action) actionResult;

  const _AiBubble({
    required this.message,
    required this.compact,
    required this.onSuggestion,
    required this.onOpenCard,
    required this.onOpenPdf,
    required this.onFeedback,
    required this.onContinue,
    required this.continuing,
    required this.onConfirmAction,
    required this.isActionBusy,
    required this.actionResult,
  });

  @override
  Widget build(BuildContext context) {
    final user = message.role == _AiRole.user;
    final maxWidth = MediaQuery.sizeOf(context).width * (compact ? .88 : .68);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: math.min(maxWidth, user ? 620 : 780)),
          child: Column(
            crossAxisAlignment:
                user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!user &&
                  (message.verifiedData || message.toolSource.isNotEmpty)) ...[
                _AiVerifiedBadge(
                  verified: message.verifiedData,
                  toolSource: message.toolSource,
                ),
                const SizedBox(height: 6),
              ],
              Container(
                padding: EdgeInsets.fromLTRB(compact ? 11 : 13,
                    compact ? 9 : 11, compact ? 11 : 13, compact ? 9 : 11),
                decoration: user ? _AiDecor.userBubble() : _AiDecor.aiBubble(),
                child: user
                    ? Text(
                        message.text,
                        style: _AiText.userText(compact ? 12.5 : 13),
                      )
                    : _AiMarkdownText(
                        text: message.text,
                        compact: compact,
                      ),
              ),
              if (!user && message.canContinue) ...[
                const SizedBox(height: 6),
                _AiContinueButton(
                  compact: compact,
                  loading: continuing,
                  onTap: () => onContinue(message),
                ),
              ],
              if (!user && message.jobId.isNotEmpty) ...[
                const SizedBox(height: 8),
                _AiGeneratedMediaCard(message: message, compact: compact),
              ],
              if (!user && message.insights.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final section in message.insights.take(6)) ...[
                  _AiInsightSectionTile(section: section, compact: compact),
                  const SizedBox(height: 7),
                ],
              ],
              if (!user && message.diagrams.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final diagram in message.diagrams.take(3)) ...[
                  ClubAiTacticalDiagramCard(diagram: diagram, compact: compact),
                  const SizedBox(height: 7),
                ],
              ],
              if (!user && message.visualizations.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final visualization in message.visualizations.take(4)) ...[
                  ClubAiVisualizationCard(
                    visualization: visualization,
                    compact: compact,
                  ),
                  const SizedBox(height: 7),
                ],
              ],
              if (!user && message.plans.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final plan in message.plans.take(3)) ...[
                  AiPlanPreviewCard(
                    title: '${plan['title'] ?? 'План SPORTOTEKA AI'}',
                    templateJson: plan,
                    onOpen: () => onOpenCard(
                      _AiResultCard(
                        type: 'plan',
                        title: '${plan['title'] ?? 'План SPORTOTEKA AI'}',
                        subtitle: 'Открыть и доработать',
                        badge: 'ПЛАН',
                        actionLabel: 'Открыть',
                        target: 'plans',
                        metaLine: 'SPORTOTEKA Planner',
                        payload: <String, dynamic>{'plan': plan},
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
              ],
              if (!user && message.actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final action in message.actions.take(4)) ...[
                  _AiActionCard(
                    action: action,
                    compact: compact,
                    busy: isActionBusy(action),
                    completedMessage: actionResult(action),
                    onConfirm: () => onConfirmAction(action),
                  ),
                  const SizedBox(height: 7),
                ],
              ],
              if (message.cards.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final card in message.cards
                    .where((item) =>
                        item.type != 'plan' || message.plans.isEmpty)
                    .take(8)) ...[
                  _AiResultCardTile(
                      card: card,
                      compact: compact,
                      onTap: () => onOpenCard(card),
                      onPdfTap: () => onOpenPdf(card)),
                  const SizedBox(height: 7),
                ],
              ],
              if (!user && message.queryId > 0) ...[
                const SizedBox(height: 4),
                _AiFeedbackBar(
                    compact: compact,
                    onLike: () => onFeedback(message, 1),
                    onDislike: () => onFeedback(message, -1)),
              ],
              if (message.suggestions.isNotEmpty) ...[
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: message.suggestions
                      .take(compact ? 4 : 6)
                      .map((s) => _AiSuggestionChip(
                          text: s, onTap: () => onSuggestion(s)))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


/// Lightweight Markdown renderer for streamed AI text.
///
/// It intentionally has no package dependency so this panel can be dropped into
/// the existing SPORTOTEKA project without changing pubspec.yaml. The parser is
/// tolerant of half-written Markdown while tokens are still arriving: opening
/// ** / * / ` markers are rendered as formatting even before their closing
/// marker arrives, so raw service characters do not flicker in the chat.
class _AiMarkdownText extends StatelessWidget {
  final String text;
  final bool compact;

  const _AiMarkdownText({
    required this.text,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final base = _AiText.value(compact ? 12.2 : 13).copyWith(height: 1.42);
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final children = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final trimmed = raw.trim();

      if (trimmed.isEmpty) {
        if (children.isNotEmpty && children.last is! SizedBox) {
          children.add(SizedBox(height: compact ? 7 : 9));
        }
        continue;
      }

      final heading = RegExp(r'^(#{1,4})\s+(.+)$').firstMatch(trimmed);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final headingText = heading.group(2)!.trim();
        final sizes = compact
            ? const <double>[16.2, 14.8, 13.7, 12.9]
            : const <double>[17.2, 15.6, 14.4, 13.5];
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: children.isEmpty ? 0 : (compact ? 3 : 4),
              bottom: compact ? 2 : 3,
            ),
            child: Text.rich(
              TextSpan(
                children: _inlineSpans(
                  headingText,
                  base.copyWith(
                    fontSize: sizes[level - 1],
                    fontWeight: FontWeight.w800,
                    height: 1.28,
                  ),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final quote = RegExp(r'^>\s?(.*)$').firstMatch(trimmed);
      if (quote != null) {
        final value = (quote.group(1) ?? '').trim();
        if (value.isEmpty) continue;
        children.add(
          Container(
            margin: EdgeInsets.symmetric(vertical: compact ? 2 : 3),
            padding: EdgeInsets.fromLTRB(compact ? 9 : 10, 6, 8, 6),
            decoration: BoxDecoration(
              color: _AiColors.greenSoft.withOpacity(.45),
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                left: BorderSide(color: _AiColors.greenDark, width: 3),
              ),
            ),
            child: Text.rich(
              TextSpan(
                children: _inlineSpans(
                  value,
                  base.copyWith(color: _AiColors.text2),
                ),
              ),
            ),
          ),
        );
        continue;
      }

      final ordered = RegExp(r'^(\d{1,3})[.)]\s+(.*)$').firstMatch(trimmed);
      if (ordered != null) {
        final body = (ordered.group(2) ?? '').trim();
        if (body.isEmpty) continue;
        children.add(
          _AiMarkdownListLine(
            marker: '${ordered.group(1)}.',
            spans: _inlineSpans(body, base),
            baseStyle: base,
            compact: compact,
          ),
        );
        continue;
      }

      final bullet = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        final body = (bullet.group(1) ?? '').trim();
        // Streaming can briefly end in a bare bullet marker. Hiding an empty
        // marker prevents the two orphan dots visible in the old UI.
        if (body.isEmpty) continue;
        children.add(
          _AiMarkdownListLine(
            marker: '•',
            spans: _inlineSpans(body, base),
            baseStyle: base,
            compact: compact,
          ),
        );
        continue;
      }

      // Ignore a bare Markdown list marker that arrived as the final token.
      if (trimmed == '•' || trimmed == '-' || trimmed == '*') continue;

      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: compact ? 2 : 3),
          child: Text.rich(
            TextSpan(children: _inlineSpans(raw.trim(), base)),
          ),
        ),
      );
    }

    while (children.isNotEmpty && children.last is SizedBox) {
      children.removeLast();
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  static List<InlineSpan> _inlineSpans(String source, TextStyle base) {
    final spans = <InlineSpan>[];
    final plain = StringBuffer();

    void flushPlain() {
      if (plain.isEmpty) return;
      spans.add(TextSpan(text: plain.toString(), style: base));
      plain.clear();
    }

    var i = 0;
    while (i < source.length) {
      if (source.startsWith('**', i) || source.startsWith('__', i)) {
        final marker = source.substring(i, i + 2);
        final end = source.indexOf(marker, i + 2);
        flushPlain();
        final content = end >= 0
            ? source.substring(i + 2, end)
            : source.substring(i + 2);
        if (content.isNotEmpty) {
          spans.addAll(
            _inlineSpans(
              content,
              base.copyWith(fontWeight: FontWeight.w800),
            ),
          );
        }
        i = end >= 0 ? end + 2 : source.length;
        continue;
      }

      if (source[i] == '`') {
        final end = source.indexOf('`', i + 1);
        flushPlain();
        final content = end >= 0
            ? source.substring(i + 1, end)
            : source.substring(i + 1);
        if (content.isNotEmpty) {
          spans.add(
            TextSpan(
              text: content,
              style: base.copyWith(
                fontFamily: 'monospace',
                fontSize: (base.fontSize ?? 13) * .94,
                backgroundColor: const Color(0xFFF0F2F4),
                color: _AiColors.text2,
              ),
            ),
          );
        }
        i = end >= 0 ? end + 1 : source.length;
        continue;
      }

      if (source[i] == '*' || source[i] == '_') {
        final marker = source[i];
        final end = source.indexOf(marker, i + 1);
        // Do not interpret punctuation-like underscores inside identifiers.
        final previousIsWord = i > 0 && RegExp(r'[A-Za-zА-Яа-яЁё0-9]').hasMatch(source[i - 1]);
        final nextIsWord = i + 1 < source.length &&
            RegExp(r'[A-Za-zА-Яа-яЁё0-9]').hasMatch(source[i + 1]);
        if (marker == '_' && previousIsWord && nextIsWord) {
          plain.write(source[i]);
          i++;
          continue;
        }
        flushPlain();
        final content = end >= 0
            ? source.substring(i + 1, end)
            : source.substring(i + 1);
        if (content.isNotEmpty) {
          spans.addAll(
            _inlineSpans(
              content,
              base.copyWith(fontStyle: FontStyle.italic),
            ),
          );
        }
        i = end >= 0 ? end + 1 : source.length;
        continue;
      }

      // Markdown escape: \* -> * etc.
      if (source[i] == r'\' && i + 1 < source.length) {
        final next = source[i + 1];
        if ('*_`#>-'.contains(next)) {
          plain.write(next);
          i += 2;
          continue;
        }
      }

      plain.write(source[i]);
      i++;
    }

    flushPlain();
    return spans;
  }
}

class _AiMarkdownListLine extends StatelessWidget {
  final String marker;
  final List<InlineSpan> spans;
  final TextStyle baseStyle;
  final bool compact;

  const _AiMarkdownListLine({
    required this.marker,
    required this.spans,
    required this.baseStyle,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 3 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: marker == '•' ? 17 : (compact ? 27 : 30),
            child: Text(
              marker,
              textAlign: marker == '•' ? TextAlign.center : TextAlign.right,
              style: baseStyle.copyWith(
                fontWeight: marker == '•' ? FontWeight.w800 : FontWeight.w700,
                color: marker == '•' ? _AiColors.greenDark : _AiColors.text2,
              ),
            ),
          ),
          SizedBox(width: marker == '•' ? 5 : 7),
          Expanded(
            child: Text.rich(TextSpan(children: spans)),
          ),
        ],
      ),
    );
  }
}

class _AiContinueButton extends StatelessWidget {
  final bool compact;
  final bool loading;
  final VoidCallback onTap;

  const _AiContinueButton({
    required this.compact,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _AiColors.greenSoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 7 : 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: compact ? 13 : 14,
                  height: compact ? 13 : 14,
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: _AiColors.greenDark,
                  ),
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: compact ? 16 : 18,
                  color: _AiColors.greenDark,
                ),
              const SizedBox(width: 5),
              Text(
                loading ? 'Продолжаю…' : 'Далее',
                style: _AiText.chip(
                  size: compact ? 10.2 : 10.8,
                  color: _AiColors.greenDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiGeneratedMediaCard extends StatelessWidget {
  final _AiMessage message;
  final bool compact;

  const _AiGeneratedMediaCard({
    required this.message,
    required this.compact,
  });

  String get _statusLabel {
    switch (message.mediaStatus) {
      case 'completed':
        return 'Готово';
      case 'failed':
        return 'Ошибка';
      case 'processing':
      case 'running':
        return 'Генерация';
      default:
        return 'В очереди';
    }
  }

  String get _fileExtension => message.mediaKind == 'video' ? 'mp4' : 'png';

  Future<void> _copyLink(BuildContext context) async {
    if (message.mediaUrl.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: message.mediaUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка скопирована')),
    );
  }

  Future<void> _saveMedia(BuildContext context) async {
    final url = message.mediaUrl.trim();
    if (url.isEmpty || !context.mounted) return;

    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(minutes: 3));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final fileName =
          'sportoteka_ai_${DateTime.now().millisecondsSinceEpoch}.$_fileExtension';

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          final file = File('${downloads.path}/$fileName');
          await file.writeAsBytes(res.bodyBytes, flush: true);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Сохранено: ${file.path}')),
          );
          return;
        }
      }

      // На iOS/Android используем системное меню:
      // пользователь может выбрать «Сохранить в Файлы», галерею и т.п.
      final temp = await getTemporaryDirectory();
      final file = File('${temp.path}/$fileName');
      await file.writeAsBytes(res.bodyBytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: message.mediaKind == 'image'
              ? 'Sportoteka Image'
              : 'Sportoteka Video',
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: $e')),
      );
    }
  }

  void _openImageViewer(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final small = size.width < 700 || size.height < 650;

    showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF0B0F14),
          insetPadding: EdgeInsets.all(small ? 4 : 18),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: math.min(size.width - (small ? 8 : 36), 1500),
            height: math.min(size.height - (small ? 8 : 36), 980),
            child: Column(
              children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF111827),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF263041)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'SPORTOTEKA Image',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Копировать ссылку',
                        onPressed: () => unawaited(_copyLink(dialogContext)),
                        icon: const Icon(
                          Icons.content_copy_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Сохранить',
                        onPressed: () => unawaited(_saveMedia(dialogContext)),
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: .6,
                    maxScale: 5,
                    boundaryMargin: const EdgeInsets.all(80),
                    child: Center(
                      child: Image.network(
                        message.mediaUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _AiColors.greenSoft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: _AiColors.greenDark),
              const SizedBox(width: 5),
              Text(
                label,
                style: _AiText.chip(
                  size: 9.8,
                  color: _AiColors.greenDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed =
        message.mediaStatus == 'completed' && message.mediaUrl.isNotEmpty;
    final failed = message.mediaStatus == 'failed';
    final isImage = message.mediaKind == 'image';
    final progress = message.mediaProgress.clamp(0, 100).toInt();
    final screen = MediaQuery.sizeOf(context);

    // Главное исправление малого окна:
    // превью больше не растягивает весь чат по высоте.
    final previewHeight = math.max(
      170.0,
      math.min(
        compact ? 300.0 : 430.0,
        screen.height * (compact ? .38 : .46),
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 9 : 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: failed ? const Color(0xFFF4C7C3) : _AiColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _AiColors.greenSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isImage ? Icons.image_rounded : Icons.movie_creation_outlined,
                  size: 16,
                  color: _AiColors.greenDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isImage ? 'Sportoteka Image' : 'Sportoteka Video',
                      style: _AiText.title(compact ? 11.6 : 12.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_statusLabel${progress > 0 && !completed ? ' · $progress%' : ''}',
                      style: _AiText.muted(9.8),
                    ),
                  ],
                ),
              ),
              if (completed)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: _AiColors.green,
                ),
            ],
          ),
          if (!completed && !failed) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress <= 0 ? null : progress / 100,
                minHeight: 5,
                backgroundColor: _AiColors.greenSoft,
                color: _AiColors.green,
              ),
            ),
          ],
          if (completed && isImage) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              height: previewHeight,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openImageViewer(context),
                child: Image.network(
                  message.mediaUrl,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => Container(
                    alignment: Alignment.center,
                    color: _AiColors.greenSoft,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: _AiColors.muted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _actionButton(
                  context: context,
                  icon: Icons.fullscreen_rounded,
                  label: 'Открыть',
                  onTap: () => _openImageViewer(context),
                ),
                _actionButton(
                  context: context,
                  icon: Icons.download_rounded,
                  label: 'Сохранить',
                  onTap: () => unawaited(_saveMedia(context)),
                ),
                _actionButton(
                  context: context,
                  icon: Icons.content_copy_rounded,
                  label: 'Копировать ссылку',
                  onTap: () => unawaited(_copyLink(context)),
                ),
              ],
            ),
          ],
          if (completed && !isImage) ...[
            const SizedBox(height: 9),
            Material(
              color: _AiColors.graphite,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => AppVideoPlayerScreen(
                        title: 'SPORTOTEKA ИИ · Видео',
                        videoUrl: message.mediaUrl,
                      ),
                    ),
                  );
                },
                child: SizedBox(
                  height: math.min(compact ? 118 : 145, screen.height * .28),
                  width: double.infinity,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Открыть видео',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _actionButton(
                  context: context,
                  icon: Icons.download_rounded,
                  label: 'Сохранить',
                  onTap: () => unawaited(_saveMedia(context)),
                ),
                _actionButton(
                  context: context,
                  icon: Icons.content_copy_rounded,
                  label: 'Копировать ссылку',
                  onTap: () => unawaited(_copyLink(context)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AiActionCard extends StatelessWidget {
  const _AiActionCard({
    required this.action,
    required this.compact,
    required this.busy,
    required this.completedMessage,
    required this.onConfirm,
  });

  final AiWorkspaceAction action;
  final bool compact;
  final bool busy;
  final String completedMessage;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final completed = completedMessage.trim().isNotEmpty;
    final canConfirm = action.canConfirm && !busy && !completed;
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: completed ? _AiColors.greenSoft : const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: completed ? _AiColors.greenBorder : const Color(0xFFF3DFC0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: completed
                      ? const Color(0xFFE4F7EB)
                      : const Color(0xFFFFF0D8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  completed ? Icons.check_rounded : Icons.lock_clock_rounded,
                  color: completed ? _AiColors.greenDark : _AiColors.orange,
                  size: 17,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _AiText.title(compact ? 12.3 : 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      completed
                          ? 'Выполнено безопасно'
                          : 'Нужно явное подтверждение',
                      style: _AiText.chip(
                        size: 9.8,
                        color:
                            completed ? _AiColors.greenDark : _AiColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action.description.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(action.description, style: _AiText.muted(compact ? 10.5 : 11)),
          ],
          if (completed) ...[
            const SizedBox(height: 8),
            Text(completedMessage, style: _AiText.value(compact ? 10.5 : 11)),
          ] else ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canConfirm ? onConfirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _AiColors.graphite,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_user_rounded, size: 16),
                label: Text(busy ? 'Проверяю...' : 'Проверить и подтвердить'),
              ),
            ),
            if (!action.canConfirm) ...[
              const SizedBox(height: 7),
              Text(
                'Предпросмотр устарел или не содержит одноразового токена. Сформируйте действие заново.',
                style: _AiText.muted(9.8),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AiVerifiedBadge extends StatelessWidget {
  final bool verified;
  final String toolSource;

  const _AiVerifiedBadge({
    required this.verified,
    required this.toolSource,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        verified ? 'Проверено по данным клуба' : 'Ответ Assistant Brain';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: verified ? _AiColors.greenSoft : Colors.white.withOpacity(.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: verified ? _AiColors.greenBorder : _AiColors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.auto_awesome_rounded,
            size: 14,
            color: _AiColors.greenDark,
          ),
          const SizedBox(width: 6),
          Text(
            toolSource.isEmpty ? label : '$label · $toolSource',
            style: _AiText.chip(
              size: 10.2,
              color: _AiColors.greenDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightSectionTile extends StatelessWidget {
  final _AiInsightSection section;
  final bool compact;

  const _AiInsightSectionTile({required this.section, required this.compact});

  IconData _icon(String raw) {
    switch (raw) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'metrics':
        return Icons.query_stats_rounded;
      case 'advice':
        return Icons.tips_and_updates_rounded;
      case 'football':
        return Icons.sports_soccer_rounded;
      case 'heart':
        return Icons.monitor_heart_rounded;
      case 'speed':
        return Icons.speed_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon(section.icon);
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AiColors.line),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.032),
              blurRadius: 18,
              spreadRadius: -12,
              offset: const Offset(0, 9)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: compact ? 28 : 31,
              height: compact ? 28 : 31,
              decoration: _AiDecor.aiSoft(radius: 10),
              child: Icon(icon,
                  color: _AiColors.greenDark, size: compact ? 15 : 16),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(section.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _AiText.title(compact ? 12.5 : 13.2))),
          ]),
          const SizedBox(height: 8),
          for (final item in section.items.take(7))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                      color: _AiColors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(item,
                        style: _AiText.muted(compact ? 10.8 : 11.3)
                            .copyWith(color: _AiColors.text2, height: 1.32))),
              ]),
            ),
        ],
      ),
    );
  }
}

class _AiResultCardTile extends StatelessWidget {
  final _AiResultCard card;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onPdfTap;

  const _AiResultCardTile(
      {required this.card,
      required this.compact,
      required this.onTap,
      required this.onPdfTap});

  IconData _icon(String type) {
    switch (type) {
      case 'player':
        return Icons.person_rounded;
      case 'tracker':
      case 'report':
        return Icons.monitor_heart_rounded;
      case 'match':
        return Icons.sports_soccer_rounded;
      case 'calendar':
      case 'training':
        return Icons.event_rounded;
      case 'testing':
        return Icons.speed_rounded;
      case 'plan':
        return Icons.folder_copy_rounded;
      case 'attendance':
        return Icons.fact_check_rounded;
      default:
        return Icons.search_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(compact ? 10 : 11),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.86),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _AiColors.line),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(.035),
                  blurRadius: 18,
                  spreadRadius: -12,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 38 : 42,
                height: compact ? 38 : 42,
                decoration: _AiDecor.aiSoft(radius: 12),
                child: Icon(_icon(card.type),
                    color: _AiColors.greenDark, size: compact ? 18 : 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(card.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _AiText.title(compact ? 12.7 : 13.4))),
                        if (card.badge.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _AiBadge(text: card.badge),
                        ],
                      ],
                    ),
                    if (card.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(card.subtitle,
                          maxLines: compact ? 2 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: _AiText.muted(compact ? 10.4 : 11)),
                    ],
                    if (card.metaLine.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(card.metaLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _AiText.subtle(compact ? 10 : 10.5)),
                    ],
                    if (card.hasPdf || card.type == 'report') ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _AiMiniCardButton(
                              icon: Icons.visibility_rounded,
                              text: card.actionLabel.isEmpty
                                  ? 'Открыть'
                                  : card.actionLabel,
                              onTap: onTap),
                          if (card.hasPdf)
                            _AiMiniCardButton(
                                icon: Icons.picture_as_pdf_rounded,
                                text: 'PDF',
                                onTap: onPdfTap,
                                dark: true),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                    color: _AiColors.greenSoft,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _AiColors.greenBorder)),
                child: const Icon(Icons.arrow_forward_rounded,
                    color: _AiColors.greenDark, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiMiniCardButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool dark;

  const _AiMiniCardButton(
      {required this.icon,
      required this.text,
      required this.onTap,
      this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: dark ? _AiColors.graphite : _AiColors.greenSoft,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: dark
                    ? _AiColors.graphite.withOpacity(.16)
                    : _AiColors.greenBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13, color: dark ? Colors.white : _AiColors.greenDark),
              const SizedBox(width: 5),
              Text(text,
                  style: _AiText.chip(
                      size: 10.2,
                      color: dark ? Colors.white : _AiColors.greenDark)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiSuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _AiSuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _AiColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 12, color: _AiColors.greenDark),
              const SizedBox(width: 5),
              Text(text, style: _AiText.tab()),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiTypingBubble extends StatefulWidget {
  const _AiTypingBubble();

  @override
  State<_AiTypingBubble> createState() => _AiTypingBubbleState();
}

class _AiTypingBubbleState extends State<_AiTypingBubble> {
  static const List<String> _statuses = <String>[
    'Анализирую запрос…',
    'Сопоставляю контекст…',
    'Проверяю данные…',
    'Формирую ответ…',
    'Готовлю вывод…',
  ];

  Timer? _timer;
  int _statusIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1900), (_) {
      if (!mounted) return;
      setState(() {
        _statusIndex = (_statusIndex + 1) % _statuses.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: _AiDecor.aiBubble(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _AiColors.greenDark,
              ),
            ),
            const SizedBox(width: 9),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 156),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Text(
                  _statuses[_statusIndex],
                  key: ValueKey<int>(_statusIndex),
                  style: const TextStyle(
                    color: _AiColors.text2,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiQuickBlockTile extends StatelessWidget {
  final _AiQuickBlock block;

  const _AiQuickBlockTile({required this.block});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.76),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _AiColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: _AiDecor.aiSoft(radius: 10),
            child: Icon(block.icon, color: _AiColors.greenDark, size: 16),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(block.title, style: _AiText.title(12.5)),
                const SizedBox(height: 3),
                Text(block.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _AiText.muted(10.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiSidebarAction extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;

  const _AiSidebarAction({
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: open ? 'Закрыть историю' : 'Открыть историю',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: open ? _AiColors.greenSoft : Colors.white.withOpacity(.94),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: open ? _AiColors.greenBorder : _AiColors.line,
              ),
            ),
            child: _AiSidebarGlyph(
              size: 18,
              color: open ? _AiColors.greenDark : _AiColors.text2,
            ),
          ),
        ),
      ),
    );
  }
}

class _AiSidebarGlyph extends StatelessWidget {
  final double size;
  final Color color;

  const _AiSidebarGlyph({
    this.size = 18,
    this.color = _AiColors.text2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _AiSidebarGlyphPainter(color),
    );
  }
}

class _AiSidebarGlyphPainter extends CustomPainter {
  final Color color;

  const _AiSidebarGlyphPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(1.25, size.width * .085);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        stroke,
        stroke,
        size.width - stroke * 2,
        size.height - stroke * 2,
      ),
      Radius.circular(size.width * .18),
    );
    canvas.drawRRect(rect, paint);

    final dividerX = size.width * .36;
    canvas.drawLine(
      Offset(dividerX, stroke * 1.8),
      Offset(dividerX, size.height - stroke * 1.8),
      paint,
    );

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * .53, size.height * .37),
      Offset(size.width * .78, size.height * .37),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * .53, size.height * .61),
      Offset(size.width * .72, size.height * .61),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AiSidebarGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _AiHeaderAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _AiHeaderAction(
      {required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _AiDecor.aiSoft(radius: 12),
          child: Row(
            children: [
              Icon(icon, size: 15, color: _AiColors.greenDark),
              const SizedBox(width: 6),
              Text(text, style: _AiText.action(color: _AiColors.greenDark)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiCircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AiCircleAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
            width: 34,
            height: 34,
            decoration: _AiDecor.aiSoft(radius: 10),
            child: Icon(icon, size: 16, color: _AiColors.greenDark)),
      ),
    );
  }
}

class _AiFeedbackBar extends StatelessWidget {
  const _AiFeedbackBar(
      {required this.compact, required this.onLike, required this.onDislike});

  final bool compact;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _AiColors.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Оценить ответ', style: _AiText.muted(compact ? 9.8 : 10.2)),
        const SizedBox(width: 7),
        _AiFeedbackButton(icon: Icons.thumb_up_alt_outlined, onTap: onLike),
        const SizedBox(width: 5),
        _AiFeedbackButton(
            icon: Icons.thumb_down_alt_outlined, onTap: onDislike),
      ]),
    );
  }
}

class _AiFeedbackButton extends StatelessWidget {
  const _AiFeedbackButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, color: _AiColors.greenDark, size: 16)),
      ),
    );
  }
}

class _AiInlineError extends StatelessWidget {
  final String text;

  const _AiInlineError({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _AiColors.orangeSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: _AiColors.orange, size: 15),
          const SizedBox(width: 7),
          Expanded(
              child: Text(text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _AiText.muted(10.8)
                      .copyWith(color: const Color(0xFF9A3412)))),
        ],
      ),
    );
  }
}

class _AiBadge extends StatelessWidget {
  final String text;

  const _AiBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: _AiColors.greenSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _AiColors.greenBorder)),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _AiText.chip(size: 9.8, color: _AiColors.greenDark)),
    );
  }
}

class _AiStreamingUnavailable implements Exception {
  const _AiStreamingUnavailable();
}

class _AiGenerationStopped implements Exception {
  const _AiGenerationStopped();
}

enum _AiComposerMode { text, image, video }

enum _AiRole { user, assistant }

class _AiMessage {
  final _AiRole role;
  final String text;
  final int queryId;
  final List<_AiInsightSection> insights;
  final List<_AiResultCard> cards;
  final List<ClubAiTacticalDiagram> diagrams;
  final List<ClubAiVisualization> visualizations;
  final List<Map<String, dynamic>> plans;
  final List<AiWorkspaceAction> actions;
  final List<String> suggestions;
  final String toolSource;
  final bool verifiedData;
  final String mediaKind;
  final String mediaUrl;
  final String jobId;
  final String mediaStatus;
  final int mediaProgress;
  final bool canContinue;

  const _AiMessage._({
    required this.role,
    required this.text,
    this.queryId = 0,
    this.insights = const <_AiInsightSection>[],
    this.cards = const <_AiResultCard>[],
    this.diagrams = const <ClubAiTacticalDiagram>[],
    this.visualizations = const <ClubAiVisualization>[],
    this.plans = const <Map<String, dynamic>>[],
    this.actions = const <AiWorkspaceAction>[],
    this.suggestions = const <String>[],
    this.toolSource = '',
    this.verifiedData = false,
    this.mediaKind = '',
    this.mediaUrl = '',
    this.jobId = '',
    this.mediaStatus = '',
    this.mediaProgress = 0,
    this.canContinue = false,
  });

  factory _AiMessage.user(String text) =>
      _AiMessage._(role: _AiRole.user, text: text);

  factory _AiMessage.assistant({
    required String text,
    int queryId = 0,
    List<_AiInsightSection> insights = const <_AiInsightSection>[],
    List<_AiResultCard> cards = const <_AiResultCard>[],
    List<ClubAiTacticalDiagram> diagrams = const <ClubAiTacticalDiagram>[],
    List<ClubAiVisualization> visualizations = const <ClubAiVisualization>[],
    List<Map<String, dynamic>> plans = const <Map<String, dynamic>>[],
    List<AiWorkspaceAction> actions = const <AiWorkspaceAction>[],
    List<String> suggestions = const <String>[],
    String toolSource = '',
    bool verifiedData = false,
    bool canContinue = false,
  }) {
    return _AiMessage._(
      role: _AiRole.assistant,
      text: text,
      queryId: queryId,
      insights: insights,
      cards: cards,
      diagrams: diagrams,
      visualizations: visualizations,
      plans: plans,
      actions: actions,
      suggestions: suggestions,
      toolSource: toolSource,
      verifiedData: verifiedData,
      canContinue: canContinue,
    );
  }

  factory _AiMessage.fromResponse(
    Map<String, dynamic> data, {
    bool allowActions = true,
    String fallbackText = 'Нашёл результаты.',
  }) {
    List<Map<String, dynamic>> maps(String key, {int limit = 20}) {
      final raw = data[key];
      if (raw is! List) return <Map<String, dynamic>>[];
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .take(limit)
          .toList(growable: false);
    }

    final insights = maps('insights', limit: 6)
        .map(_AiInsightSection.fromMap)
        .where((item) => item.title.trim().isNotEmpty && item.items.isNotEmpty)
        .toList(growable: false);
    final cards = maps('cards', limit: 8)
        .map(_AiResultCard.fromMap)
        .where((item) => item.title.trim().isNotEmpty)
        .toList(growable: false);
    final diagrams = maps('diagrams', limit: 3)
        .map(ClubAiTacticalDiagram.fromJson)
        .where((item) => item.players.isNotEmpty)
        .toList(growable: false);
    final actions = allowActions
        ? maps('actions', limit: 4)
            .map(AiWorkspaceAction.fromMap)
            .where((item) => item.title.trim().isNotEmpty)
            .toList(growable: false)
        : <AiWorkspaceAction>[];
    final suggestions = data['suggestions'] is List
        ? (data['suggestions'] as List)
            .map((item) => '$item')
            .where((item) => item.trim().isNotEmpty)
            .take(6)
            .toList(growable: false)
        : <String>[];

    final answer = '${data['answer'] ?? fallbackText}'.trim();
    final finishReason = '${data['finish_reason'] ?? data['stop_reason'] ?? data['termination_reason'] ?? ''}'
        .trim()
        .toLowerCase();
    final explicitlyMore = data['has_more'] == true ||
        data['truncated'] == true ||
        data['can_continue'] == true ||
        finishReason == 'length' ||
        finishReason == 'max_tokens' ||
        finishReason == 'token_limit';
    // Даже если сервер пока не отдаёт has_more/finish_reason, длинный ответ
    // получает кнопку «Далее». Это закрывает текущий случай, когда модель
    // упирается в серверный лимит генерации, но API не помечает truncation.
    final canContinue = explicitlyMore || answer.length >= 700;

    return _AiMessage._(
      role: _AiRole.assistant,
      text: answer,
      queryId: int.tryParse('${data['query_id'] ?? 0}') ?? 0,
      insights: insights,
      cards: cards,
      diagrams: diagrams,
      visualizations: ClubAiVisualization.fromResponse(data).take(4).toList(),
      plans: maps('plans', limit: 3),
      actions: actions,
      suggestions: suggestions,
      toolSource: '${data['tool_source'] ?? ''}'.trim(),
      verifiedData: data['verified_data'] == true,
      canContinue: canContinue,
    );
  }

  factory _AiMessage.assistantMedia({
    required String text,
    required String mediaKind,
    required String jobId,
    required String mediaStatus,
    int mediaProgress = 0,
    String mediaUrl = '',
  }) {
    return _AiMessage._(
      role: _AiRole.assistant,
      text: text,
      mediaKind: mediaKind,
      jobId: jobId,
      mediaStatus: mediaStatus,
      mediaProgress: mediaProgress,
      mediaUrl: mediaUrl,
    );
  }

  Map<String, dynamic> toHistoryMap() {
    return <String, dynamic>{
      'role': role == _AiRole.user ? 'user' : 'assistant',
      'text': text,
      if (queryId > 0) 'query_id': queryId,
      if (suggestions.isNotEmpty) 'suggestions': suggestions.take(6).toList(),
      if (insights.isNotEmpty)
        'insights': insights.map((item) => item.toMap()).toList(growable: false),
      if (cards.isNotEmpty)
        'cards': cards.map((item) => item.toMap()).toList(growable: false),
      if (diagrams.isNotEmpty)
        'diagrams': diagrams.map((item) => item.toJson()).toList(growable: false),
      if (visualizations.isNotEmpty)
        'visualizations':
            visualizations.map((item) => item.toMap()).toList(growable: false),
      if (plans.isNotEmpty) 'plans': plans,
      if (actions.isNotEmpty)
        'actions':
            actions.map((item) => item.toHistoryMap()).toList(growable: false),
      if (toolSource.isNotEmpty) 'tool_source': toolSource,
      if (verifiedData) 'verified_data': true,
      if (mediaKind.isNotEmpty) 'media_kind': mediaKind,
      if (mediaUrl.isNotEmpty) 'media_url': mediaUrl,
      if (jobId.isNotEmpty) 'job_id': jobId,
      if (mediaStatus.isNotEmpty) 'media_status': mediaStatus,
      if (mediaProgress > 0) 'media_progress': mediaProgress,
      if (canContinue) 'can_continue': true,
    };
  }

  static _AiMessage? fromHistoryMap(Map<String, dynamic> map) {
    final text = '${map['text'] ?? ''}'.trim();
    final role = '${map['role'] ?? ''}'.trim().toLowerCase();
    if (text.isEmpty && '${map['job_id'] ?? ''}'.trim().isEmpty) return null;

    final suggestionsRaw =
        map['suggestions'] is List ? map['suggestions'] as List : const [];
    final suggestions = suggestionsRaw
        .map((e) => '$e')
        .where((e) => e.trim().isNotEmpty)
        .take(6)
        .toList(growable: false);

    final restored = _AiMessage.fromResponse(
      <String, dynamic>{...map, 'answer': text},
      allowActions: true,
      fallbackText: text,
    );
    return _AiMessage._(
      role: role == 'user' ? _AiRole.user : _AiRole.assistant,
      text: text,
      queryId: restored.queryId,
      insights: restored.insights,
      cards: restored.cards,
      diagrams: restored.diagrams,
      visualizations: restored.visualizations,
      plans: restored.plans,
      actions: restored.actions,
      suggestions: suggestions,
      toolSource: restored.toolSource,
      verifiedData: restored.verifiedData,
      mediaKind: '${map['media_kind'] ?? ''}',
      mediaUrl: '${map['media_url'] ?? ''}',
      jobId: '${map['job_id'] ?? ''}',
      mediaStatus: '${map['media_status'] ?? ''}',
      mediaProgress: int.tryParse('${map['media_progress'] ?? 0}') ?? 0,
      canContinue: map['can_continue'] == true || restored.canContinue,
    );
  }

  _AiMessage copyWith({
    String? text,
    String? mediaUrl,
    String? mediaStatus,
    int? mediaProgress,
    bool? canContinue,
  }) {
    return _AiMessage._(
      role: role,
      text: text ?? this.text,
      queryId: queryId,
      insights: insights,
      cards: cards,
      diagrams: diagrams,
      visualizations: visualizations,
      plans: plans,
      actions: actions,
      suggestions: suggestions,
      toolSource: toolSource,
      verifiedData: verifiedData,
      mediaKind: mediaKind,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      jobId: jobId,
      mediaStatus: mediaStatus ?? this.mediaStatus,
      mediaProgress: mediaProgress ?? this.mediaProgress,
      canContinue: canContinue ?? this.canContinue,
    );
  }
}

class _AiHistoryItem {
  final String conversationId;
  final String title;
  final String updatedAt;
  final int messageCount;
  final bool hasMedia;
  final String lastPreview;

  const _AiHistoryItem({
    required this.conversationId,
    required this.title,
    required this.updatedAt,
    required this.messageCount,
    required this.hasMedia,
    required this.lastPreview,
  });

  factory _AiHistoryItem.fromMap(Map<String, dynamic> map) {
    return _AiHistoryItem(
      conversationId: '${map['conversation_id'] ?? ''}',
      title: '${map['title'] ?? 'Диалог'}'.trim().isEmpty
          ? 'Диалог'
          : '${map['title']}',
      updatedAt: '${map['updated_at'] ?? ''}',
      messageCount: int.tryParse('${map['message_count'] ?? 0}') ?? 0,
      hasMedia: map['has_media'] == true,
      lastPreview: '${map['last_preview'] ?? ''}',
    );
  }

  String get subtitle {
    final date = updatedAt.replaceFirst('T', ' ');
    final shortDate = date.length >= 16 ? date.substring(0, 16) : date;
    final count = messageCount > 0 ? '$messageCount сообщ.' : '';
    final preview = lastPreview.trim();
    return <String>[
      if (shortDate.isNotEmpty) shortDate,
      if (count.isNotEmpty) count,
      if (preview.isNotEmpty) preview,
    ].join(' · ');
  }
}

class _AiInsightSection {
  final String title;
  final String icon;
  final List<String> items;

  const _AiInsightSection(
      {required this.title, required this.icon, required this.items});

  factory _AiInsightSection.fromMap(Map<String, dynamic> map) {
    final rawItems =
        map['items'] is List ? map['items'] as List : const <dynamic>[];
    return _AiInsightSection(
      title: '${map['title'] ?? ''}',
      icon: '${map['icon'] ?? 'auto'}',
      items: rawItems
          .map((e) => '$e')
          .where((e) => e.trim().isNotEmpty)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        'icon': icon,
        'items': items,
      };
}

class _AiResultCard {
  final String type;
  final String title;
  final String subtitle;
  final String badge;
  final String actionLabel;
  final String target;
  final String metaLine;
  final Map<String, dynamic> payload;
  final String pdfUrl;

  bool get hasPdf => pdfUrl.trim().isNotEmpty;

  const _AiResultCard({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.actionLabel,
    required this.target,
    required this.metaLine,
    required this.payload,
    this.pdfUrl = '',
  });

  factory _AiResultCard.fromMap(Map<String, dynamic> map) {
    final route = map['route'] is Map
        ? Map<String, dynamic>.from(map['route'] as Map)
        : <String, dynamic>{};
    final payload = route['payload'] is Map
        ? Map<String, dynamic>.from(route['payload'] as Map)
        : <String, dynamic>{};
    final rawPdf = map['pdf_url'] ??
        payload['pdf_url'] ??
        map['file_url'] ??
        payload['file_url'] ??
        '';
    return _AiResultCard(
      type: '${map['type'] ?? 'search'}',
      title: '${map['title'] ?? ''}',
      subtitle: '${map['subtitle'] ?? ''}',
      badge: '${map['badge'] ?? ''}',
      actionLabel: '${map['action_label'] ?? 'Открыть'}',
      target: '${route['target'] ?? map['target'] ?? ''}',
      metaLine: '${map['meta'] ?? ''}',
      payload: payload,
      pdfUrl: '$rawPdf',
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': type,
        'title': title,
        'subtitle': subtitle,
        'badge': badge,
        'action_label': actionLabel,
        'meta': metaLine,
        if (pdfUrl.isNotEmpty) 'pdf_url': pdfUrl,
        'route': <String, dynamic>{
          'target': target,
          'payload': payload,
        },
      };
}

class _AiQuickBlock {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AiQuickBlock(this.icon, this.title, this.subtitle);
}

class _AiText {
  static const String _family = 'Segoe UI';
  static const List<String> _fallback = <String>[
    'SF Pro Display',
    'SF Pro Text',
    'Inter',
    'Roboto',
    'Arial'
  ];

  static double _compact(double size) => size <= 10 ? size : size - .75;

  static TextStyle _base(
      {required double size,
      required FontWeight weight,
      required Color color,
      double height = 1.18,
      double letterSpacing = -0.08,
      List<FontFeature>? features}) {
    return TextStyle(
        fontFamily: _family,
        fontFamilyFallback: _fallback,
        color: color,
        fontSize: _compact(size),
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        fontFeatures: features);
  }

  static TextStyle title(double size) => _base(
      size: size,
      weight: FontWeight.w700,
      color: _AiColors.text,
      height: 1.08,
      letterSpacing: -0.38);
  static TextStyle value(double size) => _base(
      size: size,
      weight: FontWeight.w600,
      color: _AiColors.text2,
      height: 1.28,
      letterSpacing: -0.08,
      features: const [FontFeature.tabularFigures()]);
  static TextStyle userText(double size) => _base(
      size: size,
      weight: FontWeight.w600,
      color: Colors.white,
      height: 1.28,
      letterSpacing: -0.08);
  static TextStyle muted(double size) => _base(
      size: size,
      weight: FontWeight.w500,
      color: _AiColors.muted,
      height: 1.34,
      letterSpacing: -0.05);
  static TextStyle subtle(double size) => _base(
      size: size,
      weight: FontWeight.w500,
      color: _AiColors.muted2,
      height: 1.2,
      letterSpacing: -0.04);
  static TextStyle chip({double size = 10.8, Color? color}) => _base(
      size: size,
      weight: FontWeight.w700,
      color: color ?? _AiColors.text,
      height: 1.08,
      letterSpacing: -0.02);
  static TextStyle tab() => _base(
      size: 10.8,
      weight: FontWeight.w600,
      color: _AiColors.greenDark,
      height: 1.08,
      letterSpacing: -0.02);
  static TextStyle action({Color color = _AiColors.text}) =>
      _base(size: 11.8, weight: FontWeight.w700, color: color, height: 1.1);
}

class _AiColors {
  static const Color soft = Color(0xFFFAFBFC);
  static const Color soft2 = Color(0xFFF6F7F9);
  static const Color text = Color(0xFF0B0F14);
  static const Color text2 = Color(0xFF182230);
  static const Color muted = Color(0xFF374151);
  static const Color muted2 = Color(0xFF6B7280);
  static const Color graphite = Color(0xFF111827);
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color greenBorder = Color(0xFFD7F0E2);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
  static const Color violet = Color(0xFF7C3AED);
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF7ED);
  static const Color line = Color(0xFFEFF1F4);
}

class _AiDecor {
  static BoxDecoration workspaceBg() =>
      const BoxDecoration(color: Color(0xFFF6F7F9));

  static BoxDecoration unifiedWindow({double radius = 18}) => BoxDecoration(
        color: _AiColors.soft2,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.055),
              blurRadius: 22,
              spreadRadius: -14,
              offset: const Offset(0, 12)),
          BoxShadow(
              color: _AiColors.blue.withOpacity(.035),
              blurRadius: 14,
              spreadRadius: -12,
              offset: const Offset(0, 6)),
        ],
      );

  static BoxDecoration aiGradient({double radius = 16}) => BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_AiColors.green, _AiColors.blue, _AiColors.violet]),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
              color: _AiColors.green.withOpacity(.20),
              blurRadius: 24,
              spreadRadius: -12,
              offset: const Offset(0, 13))
        ],
      );

  static BoxDecoration aiSoft({double radius = 16}) => BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _AiColors.green.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
              color: _AiColors.green.withOpacity(.055),
              blurRadius: 18,
              spreadRadius: -11,
              offset: const Offset(0, 9)),
          BoxShadow(
              color: Colors.black.withOpacity(.035),
              blurRadius: 12,
              spreadRadius: -10,
              offset: const Offset(0, 5)),
        ],
      );

  static BoxDecoration disabledButton({double radius = 16}) => BoxDecoration(
      color: _AiColors.graphite.withOpacity(.55),
      borderRadius: BorderRadius.circular(radius));

  static BoxDecoration aiBubble() => BoxDecoration(
        color: Colors.white.withOpacity(.90),
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(5),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16)),
        border: Border.all(color: _AiColors.line),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.035),
              blurRadius: 18,
              spreadRadius: -12,
              offset: const Offset(0, 10))
        ],
      );

  static BoxDecoration userBubble() => BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_AiColors.green, _AiColors.blue]),
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(5),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
              color: _AiColors.green.withOpacity(.18),
              blurRadius: 20,
              spreadRadius: -12,
              offset: const Offset(0, 12))
        ],
      );
}
