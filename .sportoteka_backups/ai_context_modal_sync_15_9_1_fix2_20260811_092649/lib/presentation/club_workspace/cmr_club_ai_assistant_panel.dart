// lib/presentation/club_workspace/cmr_club_ai_assistant_panel.dart
// V6 локальный ИИ клуба без OpenAI: поиск, анализ, схемы, PDF и самообучение на вашем сервере.
// Вставляется внутрь раздела Чаты как закреплённый диалог «ИИ клуба».

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'ai_actions/ai_workspace_action_api.dart';
import 'models/club_ai_tactical_diagram.dart';
import 'widgets/club_ai_tactical_diagram_card.dart';

class CmrClubAiAssistantPanel extends StatefulWidget {
  final int clubId;
  final int userId;
  final int? teamId;
  final String? clubName;
  final String? teamName;
  final bool playerOnlyMode;
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
  static const String _askUrl =
      'https://sportotekaapp.ru/api/ai/v1/assistant/chat';
  static const String _feedbackUrl =
      'https://sportotekaapp.ru/api/ai/v1/assistant/feedback';

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();
  final List<_AiMessage> _messages = <_AiMessage>[];
  final Set<String> _confirmingActionIds = <String>{};
  final Map<String, String> _completedActionMessages = <String, String>{};

  bool _sending = false;
  String? _error;

  List<String> get _starterPrompts {
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

  @override
  void initState() {
    super.initState();
    _messages.add(_AiMessage.assistant(
      text: widget.playerOnlyMode
          ? 'Я ИИ-помощник профиля игрока. В этом окне анализирую только данные ${((widget.playerName ?? '').trim().isEmpty ? 'выбранного игрока' : widget.playerName!.trim())}: тестирования, матчи, GPS/Polar-сессии, скорость, спринты, пульс и нагрузку.'
          : 'Я локальный ИИ клуба. Работаю на вашем сервере и вижу текущий контекст экрана: выбранную команду, тренировку, игроков и пульсовую точку. Ищу отчеты, делаю разбор GPS/Polar, объясняю причины нагрузки и предлагаю действия тренеру.',
      suggestions: _starterPrompts.take(4).toList(),
    ));

    final initial = (widget.initialPrompt ?? '').trim();
    if (initial.isNotEmpty) {
      _input.text = initial;
      if (widget.autoSendInitialPrompt) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ask(initial);
        });
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  int _asInt(dynamic v) => int.tryParse('${v ?? ''}') ?? 0;

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

  Future<void> _ask([String? forced]) async {
    final q = (forced ?? _input.text).trim();
    if (q.isEmpty || _sending) return;

    setState(() {
      _error = null;
      _sending = true;
      _messages.add(_AiMessage.user(q));
      _input.clear();
    });
    _scrollToBottom();

    try {
      final contextPayload = <String, dynamic>{
        ...?widget.initialPayload,
        if (widget.playerOnlyMode) 'scope': 'player_profile',
        if (widget.playerOnlyMode) 'player_only': true,
        if (widget.playerOnlyMode && (widget.playerId ?? 0) > 0)
          'player_id': widget.playerId,
        if (widget.playerOnlyMode &&
            (widget.playerName ?? '').trim().isNotEmpty)
          'player_name': widget.playerName!.trim(),
      };
      final payload = <String, dynamic>{
        'club_id': widget.clubId,
        'user_id': widget.userId,
        if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId,
        if (widget.playerOnlyMode && (widget.playerId ?? 0) > 0)
          'player_id': widget.playerId,
        'q': q,
        'context': contextPayload,
      };

      debugPrint('[AI_CHAT] URL=$_askUrl');
      debugPrint('[AI_CHAT] PAYLOAD=${jsonEncode(payload)}');

      final res = await http
          .post(
            Uri.parse(_askUrl),
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('[AI_CHAT] STATUS=${res.statusCode}');
      // Тело ответа может содержать одноразовый action_token v15.9.1.
      // Не выводим его в debug/system logs.
      debugPrint('[AI_CHAT] RESPONSE_BYTES=${res.bodyBytes.length}');

      final data = _decodeJson(res.body);
      if (res.statusCode != 200 || data is! Map || data['success'] != true) {
        throw Exception(
          data is Map
              ? (data['detail'] ?? data['message'] ?? 'Ошибка запроса')
              : 'HTTP ${res.statusCode}',
        );
      }

      final cardsRaw =
          data['cards'] is List ? data['cards'] as List : const <dynamic>[];
      final cards = cardsRaw
          .whereType<Map>()
          .map((e) => _AiResultCard.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.title.trim().isNotEmpty)
          .toList();

      final suggestionsRaw = data['suggestions'] is List
          ? data['suggestions'] as List
          : const <dynamic>[];
      final suggestions = suggestionsRaw
          .map((e) => '$e')
          .where((e) => e.trim().isNotEmpty)
          .take(6)
          .toList();

      final insightsRaw = data['insights'] is List
          ? data['insights'] as List
          : const <dynamic>[];
      final insights = insightsRaw
          .whereType<Map>()
          .map((e) => _AiInsightSection.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.title.trim().isNotEmpty && e.items.isNotEmpty)
          .take(6)
          .toList();

      final actionsRaw =
          data['actions'] is List ? data['actions'] as List : const <dynamic>[];
      final actions = actionsRaw
          .whereType<Map>()
          .map((e) => AiWorkspaceAction.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.title.trim().isNotEmpty)
          .take(4)
          .toList(growable: false);

      final diagramsRaw = data['diagrams'] is List
          ? data['diagrams'] as List
          : const <dynamic>[];
      final diagrams = diagramsRaw
          .whereType<Map>()
          .map((e) =>
              ClubAiTacticalDiagram.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.players.isNotEmpty)
          .take(3)
          .toList();
      final queryId = _asInt(data['query_id']);
      final toolSource = '${data['tool_source'] ?? ''}'.trim();
      final verifiedData = data['verified_data'] == true;

      if (!mounted) return;
      setState(() {
        _messages.add(_AiMessage.assistant(
          text: '${data['answer'] ?? 'Нашёл результаты.'}',
          queryId: queryId,
          insights: insights,
          cards: cards,
          diagrams: diagrams,
          actions: actions,
          suggestions: suggestions,
          toolSource: toolSource,
          verifiedData: verifiedData,
        ));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось выполнить поиск: $e';
        _messages.add(_AiMessage.assistant(
          text:
              'Не смог получить ответ от сервера. Можно попробовать короче: выбранный игрок + что ищем, например «отчёт за вчера» или «тренировки U13 за неделю».',
          suggestions: const <String>[
            'Последние тренировки команды',
            'Последняя GPS-сессия',
            'Матчи за месяц',
          ],
        ));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
      _focus.requestFocus();
    }
  }

  Future<void> _sendFeedback(_AiMessage message, int rating,
      {String comment = ''}) async {
    if (message.queryId <= 0) return;
    try {
      await http.post(
        Uri.parse(_feedbackUrl),
        body: <String, String>{
          'club_id': widget.clubId.toString(),
          'user_id': widget.userId.toString(),
          if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId.toString(),
          'query_id': message.queryId.toString(),
          'rating': rating.toString(),
          'comment': comment,
        },
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
        actionToken: action.actionToken,
      );
      if (!mounted) return;
      final message = '${result['answer'] ?? 'Действие выполнено'}'.trim();
      setState(() => _completedActionMessages[key] = message);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 240,
        duration: const Duration(milliseconds: 260),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : media.width;
        final safeHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 120
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
    );
  }

  Widget _buildPhone() {
    return Column(
      children: [
        _AiHeader(
          clubName: widget.clubName,
          teamName: widget.teamName,
          compact: true,
          onExample: () => _ask(widget.playerOnlyMode
              ? 'Сделай краткий анализ последних данных игрока'
              : 'Найди последний отчет по игроку'),
          playerOnlyMode: widget.playerOnlyMode,
          playerName: widget.playerName,
          onBack: widget.onBack,
        ),
        Expanded(child: _buildChat(compact: true)),
        _buildComposer(compact: true),
      ],
    );
  }

  Widget _buildDesktop({required double width}) {
    final showRail = !widget.playerOnlyMode && width >= 1050;
    return Row(
      children: [
        if (showRail) ...[
          SizedBox(width: 310, child: _buildRail()),
          Container(width: 1, color: _AiColors.line.withOpacity(.9)),
        ],
        Expanded(
          child: Column(
            children: [
              _AiHeader(
                clubName: widget.clubName,
                teamName: widget.teamName,
                compact: false,
                onExample: () => _ask(widget.playerOnlyMode
                    ? 'Сделай краткий анализ последних данных игрока'
                    : 'Покажи последнюю тренировку и отчет команды'),
                playerOnlyMode: widget.playerOnlyMode,
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
                    Text('ИИ клуба', style: _AiText.title(16.2)),
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
    return Container(
      color: Colors.transparent,
      child: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(compact ? 10 : 18, compact ? 10 : 16,
            compact ? 10 : 18, compact ? 16 : 20),
        itemCount: _messages.length + (_sending ? 1 : 0),
        itemBuilder: (context, index) {
          if (_sending && index == _messages.length)
            return const _AiTypingBubble();
          final msg = _messages[index];
          return _AiBubble(
            message: msg,
            compact: compact,
            onSuggestion: _ask,
            onOpenCard: _openCard,
            onOpenPdf: _openPdf,
            onFeedback: _sendFeedback,
            onConfirmAction: (action) => unawaited(_confirmAction(action)),
            isActionBusy: (action) =>
                _confirmingActionIds.contains(_actionKey(action)),
            actionResult: (action) =>
                _completedActionMessages[_actionKey(action)] ?? '',
          );
        },
      ),
    );
  }

  Widget _buildComposer({required bool compact}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          compact ? 8 : 14, 8, compact ? 8 : 14, compact ? 8 : 12),
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
          Row(
            children: [
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
                      const Icon(Icons.auto_awesome_rounded,
                          color: _AiColors.greenDark, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _input,
                          focusNode: _focus,
                          minLines: 1,
                          maxLines: compact ? 3 : 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _ask(),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: widget.playerOnlyMode
                                ? 'Спросите о нагрузке, пульсе, скорости или тестах игрока...'
                                : 'Спросите: почему такой спринт, сделай анализ, нарисуй схему...',
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
                  onTap: _sending ? null : () => _ask(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: compact ? 42 : 46,
                    height: compact ? 42 : 46,
                    decoration: _sending
                        ? _AiDecor.disabledButton(radius: 14)
                        : _AiDecor.aiGradient(radius: 14),
                    child: Icon(
                        _sending
                            ? Icons.more_horiz_rounded
                            : Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 19),
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

class _AiHeader extends StatelessWidget {
  final String? clubName;
  final String? teamName;
  final bool compact;
  final VoidCallback onExample;
  final bool playerOnlyMode;
  final String? playerName;
  final VoidCallback? onBack;

  const _AiHeader(
      {required this.clubName,
      required this.teamName,
      required this.compact,
      required this.onExample,
      this.playerOnlyMode = false,
      this.playerName,
      this.onBack});

  @override
  Widget build(BuildContext context) {
    final scope = playerOnlyMode
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
                            playerOnlyMode ? 'ИИ игрока' : 'ИИ помощник',
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
                        ? 'Поиск по клубу, командам и отчетам'
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
          if (!compact)
            _AiHeaderAction(
                icon: Icons.bolt_rounded, text: 'Пример', onTap: onExample)
          else
            _AiCircleAction(icon: Icons.bolt_rounded, onTap: onExample),
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
                child: Text(message.text,
                    style: user
                        ? _AiText.userText(compact ? 12.5 : 13)
                        : _AiText.value(compact ? 12.2 : 13)),
              ),
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
                for (final card in message.cards.take(8)) ...[
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

class _AiTypingBubble extends StatelessWidget {
  const _AiTypingBubble();

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
          children: const [
            SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _AiColors.greenDark)),
            SizedBox(width: 9),
            Text('Ищу по базе клуба...',
                style: TextStyle(
                    color: _AiColors.text2,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w600)),
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

enum _AiRole { user, assistant }

class _AiMessage {
  final _AiRole role;
  final String text;
  final int queryId;
  final List<_AiInsightSection> insights;
  final List<_AiResultCard> cards;
  final List<ClubAiTacticalDiagram> diagrams;
  final List<AiWorkspaceAction> actions;
  final List<String> suggestions;
  final String toolSource;
  final bool verifiedData;

  const _AiMessage._({
    required this.role,
    required this.text,
    this.queryId = 0,
    this.insights = const <_AiInsightSection>[],
    this.cards = const <_AiResultCard>[],
    this.diagrams = const <ClubAiTacticalDiagram>[],
    this.actions = const <AiWorkspaceAction>[],
    this.suggestions = const <String>[],
    this.toolSource = '',
    this.verifiedData = false,
  });

  factory _AiMessage.user(String text) =>
      _AiMessage._(role: _AiRole.user, text: text);

  factory _AiMessage.assistant({
    required String text,
    int queryId = 0,
    List<_AiInsightSection> insights = const <_AiInsightSection>[],
    List<_AiResultCard> cards = const <_AiResultCard>[],
    List<ClubAiTacticalDiagram> diagrams = const <ClubAiTacticalDiagram>[],
    List<AiWorkspaceAction> actions = const <AiWorkspaceAction>[],
    List<String> suggestions = const <String>[],
    String toolSource = '',
    bool verifiedData = false,
  }) {
    return _AiMessage._(
      role: _AiRole.assistant,
      text: text,
      queryId: queryId,
      insights: insights,
      cards: cards,
      diagrams: diagrams,
      actions: actions,
      suggestions: suggestions,
      toolSource: toolSource,
      verifiedData: verifiedData,
    );
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
