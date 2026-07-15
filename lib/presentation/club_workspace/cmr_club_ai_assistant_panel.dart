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

import 'models/club_ai_tactical_diagram.dart';
import 'widgets/club_ai_tactical_diagram_card.dart';

class CmrClubAiAssistantPanel extends StatefulWidget {
  final int clubId;
  final int userId;
  final int? teamId;
  final String? clubName;
  final String? teamName;

  /// target: player_profile / tracker / report / calendar / match / testing / plans / attendance
  /// payload: ids/date/team_id/player_id/session_id/etc.
  final void Function(String target, Map<String, dynamic> payload)? onNavigate;
  /// Вызывается, когда в карточке есть готовый PDF/HTML отчет.
  /// Если не передать callback, ссылка копируется в буфер обмена.
  final void Function(String url)? onOpenPdf;

  /// Для мобильного режима внутри раздела "Чаты": вернуться к списку,
  /// не закрывая Club Workspace и нижнее меню приложения.
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
    this.onNavigate,
    this.onOpenPdf,
    this.onBack,
    this.initialPrompt,
    this.initialPayload,
    this.autoSendInitialPrompt = false,
  });

  @override
  State<CmrClubAiAssistantPanel> createState() => _CmrClubAiAssistantPanelState();
}

class _CmrClubAiAssistantPanelState extends State<CmrClubAiAssistantPanel> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const String _askUrl = 'https://sportotekaapp.ru/api/ai/v1/assistant/chat';
  static const String _feedbackUrl = 'https://sportotekaapp.ru/api/ai/v1/assistant/feedback';
  static const String _personalAlertsUrl = '$_apiBase/player_get_training_notifications.php';

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();
  final List<_AiMessage> _messages = <_AiMessage>[];
  final Map<int, GlobalKey> _messageKeys = <int, GlobalKey>{};

  bool _sending = false;
  String? _error;
  Timer? _alertTimer;
  int _unreadLoadAlerts = 0;
  final Set<String> _seenLoadAlertIds = <String>{};

  static const List<String> _starterPrompts = <String>[
    'Сделай анализ тренировки за вчера',
    'Сделай отчет по Берёзкину за 09.07.2026',
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

  @override
  void initState() {
    super.initState();
    _messages.add(_AiMessage.assistant(
      text:
          'Я локальный ИИ клуба. Работаю на вашем сервере: ищу отчеты, делаю тренерский разбор по GPS/Polar, объясняю причины спринтов и рисков, строю схемы прямо в чате и запоминаю правила тренера. Напишите: «почему такой спринт у Берёзкина», «сделай анализ тренировки», «нарисуй схему прессинга 4-3-3».',
      suggestions: _starterPrompts.take(4).toList(),
    ));
    _loadPersonalLoadAlerts();
    _alertTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadPersonalLoadAlerts());
    final initial = (widget.initialPrompt ?? '').trim();
    if (initial.isNotEmpty) {
      _input.text = initial;
      if (widget.autoSendInitialPrompt) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _ask(initial); });
    }
  }

  Future<void> _loadPersonalLoadAlerts() async {
    try {
      final uri = Uri.parse(_personalAlertsUrl).replace(queryParameters: <String, String>{
        'club_id': '${widget.clubId}',
        if (widget.teamId != null) 'team_id': '${widget.teamId}',
        'days': '1',
        'limit': '30',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = _decodeJson(response.body);
      final map = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
      final raw = map['notifications'] ?? map['items'] ?? map['events'] ?? const <dynamic>[];
      if (raw is! List) return;
      final fresh = <_AiMessage>[];
      for (final value in raw.whereType<Map>()) {
        final row = Map<String, dynamic>.from(value);
        final bpm = _asInt(row['heart_rate_bpm'] ?? row['max_bpm'] ?? row['last_heart_rate_bpm']);
        final load = double.tryParse('${row['load_score'] ?? row['player_load'] ?? row['load'] ?? 0}'.replaceAll(',', '.')) ?? 0;
        if (bpm < 160 && load < 80) continue;
        final playerId = _asInt(row['player_id'] ?? row['owner_user_id'] ?? row['user_id']);
        final sessionId = _asInt(row['session_id'] ?? row['live_session_id'] ?? row['id']);
        final id = '${sessionId}_${playerId}_${bpm}_${load.round()}';
        if (_seenLoadAlertIds.contains(id)) continue;
        _seenLoadAlertIds.add(id);
        final name = '${row['player_short_name'] ?? row['player_name'] ?? row['full_name'] ?? 'Игрок'}'.trim();
        final activity = '${row['activity_label'] ?? row['activity_type'] ?? row['mode'] ?? 'Личная тренировка'}'.trim();
        fresh.add(_AiMessage.assistant(
          text: 'Внимание тренеру: у $name зафиксирована высокая нагрузка.',
          insights: <_AiInsightSection>[
            _AiInsightSection(title: 'Сигнал нагрузки', icon: 'warning', items: <String>[
              'Пульс: ${bpm > 0 ? '$bpm bpm' : 'нет данных'}',
              'Load: ${load > 0 ? load.toStringAsFixed(0) : 'нет данных'}',
              'Вид: $activity',
              'Рекомендуется открыть отчет и проверить время в Z4–Z5.',
            ]),
          ],
          cards: <_AiResultCard>[
            _AiResultCard(type: 'report', title: '$name · высокая нагрузка', subtitle: '$activity · пульс ${bpm > 0 ? bpm : '—'} · Load ${load > 0 ? load.toStringAsFixed(0) : '—'}', badge: 'НАГРУЗКА', actionLabel: 'Открыть отчет', target: 'report', metaLine: 'ИИ-предупреждение по личной тренировке', payload: <String, dynamic>{'player_id': playerId, 'session_id': sessionId, 'team_id': widget.teamId, 'personal': true}),
          ],
        ));
      }
      if (!mounted || fresh.isEmpty) return;
      setState(() {
        _messages.addAll(fresh);
        _unreadLoadAlerts += fresh.length;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
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
      final res = await http
          .post(
            Uri.parse(_askUrl),
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: json.encode(<String, dynamic>{
              'club_id': widget.clubId,
              'user_id': widget.userId,
              if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId,
              'q': q,
              'context': widget.initialPayload ?? const <String, dynamic>{},
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = _decodeJson(res.body);
      if (res.statusCode != 200 || data is! Map || data['success'] != true) {
        throw Exception(data is Map ? (data['message'] ?? 'Ошибка запроса') : 'HTTP ${res.statusCode}');
      }

      final cardsRaw = data['cards'] is List ? data['cards'] as List : const <dynamic>[];
      final cards = cardsRaw
          .whereType<Map>()
          .map((e) => _AiResultCard.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.title.trim().isNotEmpty)
          .toList();

      final suggestionsRaw = data['suggestions'] is List ? data['suggestions'] as List : const <dynamic>[];
      final suggestions = suggestionsRaw.map((e) => '$e').where((e) => e.trim().isNotEmpty).take(6).toList();

      final insightsRaw = data['insights'] is List ? data['insights'] as List : const <dynamic>[];
      final insights = insightsRaw
          .whereType<Map>()
          .map((e) => _AiInsightSection.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.title.trim().isNotEmpty && e.items.isNotEmpty)
          .take(6)
          .toList();

      final diagramsRaw = data['diagrams'] is List ? data['diagrams'] as List : const <dynamic>[];
      final diagrams = diagramsRaw
          .whereType<Map>()
          .map((e) => ClubAiTacticalDiagram.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.players.isNotEmpty)
          .take(3)
          .toList();
      final queryId = _asInt(data['query_id']);

      if (!mounted) return;
      final answerIndex = _messages.length;
      setState(() {
        _messages.add(_AiMessage.assistant(
          text: '${data['answer'] ?? 'Нашел результаты.'}',
          queryId: queryId,
          insights: insights,
          cards: cards,
          diagrams: diagrams,
          suggestions: suggestions,
        ));
      });
      _scrollToMessageStart(answerIndex);
    } catch (e) {
      if (!mounted) return;
      final answerIndex = _messages.length;
      setState(() {
        _error = 'Не удалось выполнить поиск: $e';
        _messages.add(_AiMessage.assistant(
          text:
              'Не смог получить ответ от сервера. Можно попробовать короче: имя игрока + что ищем, например «Берёзкин отчет вчера» или «тренировки U13 за неделю».',
          suggestions: const <String>[
            'Последние тренировки команды',
            'Последняя GPS-сессия',
            'Матчи за месяц',
          ],
        ));
      });
      _scrollToMessageStart(answerIndex);
    } finally {
      if (mounted) setState(() => _sending = false);
      _focus.requestFocus();
    }
  }

  Future<void> _sendFeedback(_AiMessage message, int rating, {String comment = ''}) async {
    if (message.queryId <= 0) return;
    try {
      await http
          .post(
            Uri.parse(_feedbackUrl),
            body: <String, String>{
              'club_id': widget.clubId.toString(),
              'user_id': widget.userId.toString(),
              if ((widget.teamId ?? 0) > 0) 'team_id': widget.teamId.toString(),
              'query_id': message.queryId.toString(),
              'rating': rating.toString(),
              'comment': comment,
            },
          )
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(rating > 0 ? 'Запомнил: ответ полезный' : 'Запомнил: ответ надо улучшить')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось сохранить оценку ИИ')));
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

  void _scrollToMessageStart(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _messageKeys[index]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: .04,
        duration: const Duration(milliseconds: 280),
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
      const SnackBar(content: Text('Ссылка на PDF скопирована. Откройте ее в браузере или обработайте через onOpenPdf.')),
    );
  }

  Future<void> _openCard(_AiResultCard card) async {
    final target = card.target.trim();
    final payload = Map<String, dynamic>.from(card.payload);
    if (target.isEmpty) return;

    // Основной сценарий: родительский экран открывает нужный раздел приложения
    // и использует payload только как внутренний контекст навигации.
    if (widget.onNavigate != null) {
      widget.onNavigate!(target, payload);
      return;
    }

    // Резервный сценарий для карточки отчёта: если внутренняя навигация
    // не подключена, открываем готовый PDF вместо показа технических ID.
    if (target == 'report' && card.hasPdf) {
      await _openPdf(card);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Не удалось открыть раздел. Для ИИ-помощника не подключён обработчик навигации.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
        final media = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : media.width;
        final safeHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 120
            ? constraints.maxHeight
            : math.max(620.0, media.height - MediaQuery.paddingOf(context).vertical - 18);
        final phone = width < 700;
        final tablet = width >= 700 && width < 1120;

        final radius = phone ? 0.0 : 18.0;
        return SizedBox(
          width: double.infinity,
          height: phone ? media.height : safeHeight,
          child: Container(
            decoration: phone ? const BoxDecoration(color: _AiColors.bg) : _AiDecor.workspaceBg(),
            padding: phone ? EdgeInsets.zero : EdgeInsets.all(tablet ? 8 : 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                decoration: phone ? const BoxDecoration(color: _AiColors.bg) : _AiDecor.unifiedWindow(radius: radius),
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
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final topInset = media.viewPadding.top;
    final bottomInset = keyboardOpen ? 0.0 : media.viewPadding.bottom;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: topInset),
          child: _AiHeader(
            clubName: widget.clubName,
            teamName: widget.teamName,
            compact: true,
            onBack: widget.onBack,
            unreadCount: _unreadLoadAlerts,
            onExample: () { setState(() => _unreadLoadAlerts = 0); _ask('Найди последний отчет по игроку'); },
          ),
        ),
        Expanded(child: _buildChat(compact: true)),
        Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: _buildComposer(compact: true),
        ),
      ],
    );
  }

  Widget _buildDesktop({required double width}) {
    final showRail = width >= 1050;
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
                onBack: widget.onBack,
                unreadCount: _unreadLoadAlerts,
                onExample: () { setState(() => _unreadLoadAlerts = 0); _ask('Покажи последнюю тренировку и отчет команды'); },
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
      _AiQuickBlock(Icons.person_search_rounded, 'Игрок', 'Найти профиль, тренировки, отчеты и тесты игрока.'),
      _AiQuickBlock(Icons.monitor_heart_rounded, 'Трекер', 'GPS/Polar, скорость, пульс, спринты, нагрузка.'),
      _AiQuickBlock(Icons.event_rounded, 'Календарь', 'Тренировки, матчи, события и посещаемость.'),
      _AiQuickBlock(Icons.assignment_rounded, 'Отчеты', 'PDF/HTML отчет, карточка сессии и экспорт.'),
      _AiQuickBlock(Icons.tips_and_updates_rounded, 'Советы', 'Выводы по футболу: нагрузка, спринты, пульс, риски.'),
      _AiQuickBlock(Icons.sports_soccer_rounded, 'Схемы', 'Построение расстановки, прессинга, розыгрыша и стандартов.'),
      _AiQuickBlock(Icons.psychology_alt_rounded, 'Самообучение', 'ИИ запоминает оценки тренера и лучшие ответы клуба.'),
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
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ИИ клуба', style: _AiText.title(16.2)),
                    const SizedBox(height: 4),
                    Text('Поиск, разбор, схемы, память', style: _AiText.muted(11)),
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
        padding: EdgeInsets.fromLTRB(compact ? 10 : 18, compact ? 10 : 16, compact ? 10 : 18, compact ? 16 : 20),
        itemCount: _messages.length + (_sending ? 1 : 0),
        itemBuilder: (context, index) {
          final key = _messageKeys.putIfAbsent(index, GlobalKey.new);
          if (_sending && index == _messages.length) {
            return KeyedSubtree(key: key, child: const _AiTypingBubble());
          }
          final msg = _messages[index];
          return KeyedSubtree(
            key: key,
            child: _AiBubble(
              message: msg,
              compact: compact,
              onSuggestion: _ask,
              onOpenCard: (card) { _openCard(card); },
              onOpenPdf: _openPdf,
              onFeedback: _sendFeedback,
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposer({required bool compact}) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 14, 8, compact ? 8 : 14, compact ? 8 : 12),
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
                      const Icon(Icons.auto_awesome_rounded, color: _AiColors.greenDark, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _input,
                          focusNode: _focus,
                          minLines: 1,
                          maxLines: compact ? 3 : 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _ask(),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Спросите: почему такой спринт, сделай анализ, нарисуй схему...',
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
                    decoration: _sending ? _AiDecor.disabledButton(radius: 14) : _AiDecor.aiGradient(radius: 14),
                    child: Icon(_sending ? Icons.more_horiz_rounded : Icons.arrow_upward_rounded, color: Colors.white, size: 19),
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
  final VoidCallback? onBack;
  final VoidCallback onExample;
  final int unreadCount;

  const _AiHeader({required this.clubName, required this.teamName, required this.compact, this.onBack, required this.onExample, this.unreadCount = 0});

  @override
  Widget build(BuildContext context) {
    final scope = [
      if ((clubName ?? '').trim().isNotEmpty) clubName!.trim(),
      if ((teamName ?? '').trim().isNotEmpty) teamName!.trim(),
    ].join(' · ');

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 14, compact ? 9 : 11, compact ? 10 : 14, compact ? 9 : 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.38),
        border: Border(bottom: BorderSide(color: _AiColors.line.withOpacity(.72), width: 1)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            _AiCircleAction(icon: Icons.arrow_back_rounded, onTap: onBack!),
            const SizedBox(width: 8),
          ],
          Container(
            width: compact ? 35 : 38,
            height: compact ? 35 : 38,
            decoration: _AiDecor.aiSoft(radius: 11),
            child: const Icon(Icons.auto_awesome_rounded, color: _AiColors.greenDark, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(child: Text('ИИ помощник', maxLines: 1, overflow: TextOverflow.ellipsis, style: _AiText.title(compact ? 15 : 15.8))),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: _AiColors.graphite, borderRadius: BorderRadius.circular(8)),
                      child: const Text('beta', style: TextStyle(color: Colors.white, fontSize: 9.4, fontWeight: FontWeight.w600, height: 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(scope.isEmpty ? 'Поиск по клубу, командам и отчетам' : scope, maxLines: 1, overflow: TextOverflow.ellipsis, style: _AiText.muted(compact ? 10.2 : 10.8)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (unreadCount > 0) ...[
            Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:5), decoration: BoxDecoration(color: const Color(0xFFFFECEC), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFFFCACA))), child: Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.warning_amber_rounded,color:Color(0xFFE11D48),size:14),const SizedBox(width:4),Text('$unreadCount',style:const TextStyle(color:Color(0xFFE11D48),fontWeight:FontWeight.w900,fontSize:10))])),
            const SizedBox(width:6),
          ],
          if (!compact)
            _AiHeaderAction(icon: Icons.bolt_rounded, text: 'Пример', onTap: onExample)
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

  const _AiBubble({required this.message, required this.compact, required this.onSuggestion, required this.onOpenCard, required this.onOpenPdf, required this.onFeedback});

  @override
  Widget build(BuildContext context) {
    final user = message.role == _AiRole.user;
    final maxWidth = MediaQuery.sizeOf(context).width * (compact ? .88 : .68);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: math.min(maxWidth, user ? 620 : 780)),
          child: Column(
            crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(compact ? 11 : 13, compact ? 9 : 11, compact ? 11 : 13, compact ? 9 : 11),
                decoration: user ? _AiDecor.userBubble() : _AiDecor.aiBubble(),
                child: Text(message.text, style: user ? _AiText.userText(compact ? 12.5 : 13) : _AiText.value(compact ? 12.2 : 13)),
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
              if (message.cards.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final card in message.cards.take(8)) ...[
                  _AiResultCardTile(card: card, compact: compact, onTap: () => onOpenCard(card), onPdfTap: () => onOpenPdf(card)),
                  const SizedBox(height: 7),
                ],
              ],
              if (!user && message.queryId > 0) ...[
                const SizedBox(height: 4),
                _AiFeedbackBar(compact: compact, onLike: () => onFeedback(message, 1), onDislike: () => onFeedback(message, -1)),
              ],
              if (message.suggestions.isNotEmpty) ...[
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: message.suggestions.take(compact ? 4 : 6).map((s) => _AiSuggestionChip(text: s, onTap: () => onSuggestion(s))).toList(),
                ),
              ],
            ],
          ),
        ),
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
          BoxShadow(color: Colors.black.withOpacity(.032), blurRadius: 18, spreadRadius: -12, offset: const Offset(0, 9)),
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
              child: Icon(icon, color: _AiColors.greenDark, size: compact ? 15 : 16),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(section.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _AiText.title(compact ? 12.5 : 13.2))),
          ]),
          const SizedBox(height: 8),
          for (final item in section.items.take(7))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(color: _AiColors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: _AiText.muted(compact ? 10.8 : 11.3).copyWith(color: _AiColors.text2, height: 1.32))),
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

  const _AiResultCardTile({required this.card, required this.compact, required this.onTap, required this.onPdfTap});

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
              BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 18, spreadRadius: -12, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 38 : 42,
                height: compact ? 38 : 42,
                decoration: _AiDecor.aiSoft(radius: 12),
                child: Icon(_icon(card.type), color: _AiColors.greenDark, size: compact ? 18 : 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _AiText.title(compact ? 12.7 : 13.4))),
                        if (card.badge.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _AiBadge(text: card.badge),
                        ],
                      ],
                    ),
                    if (card.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(card.subtitle, maxLines: compact ? 2 : 2, overflow: TextOverflow.ellipsis, style: _AiText.muted(compact ? 10.4 : 11)),
                    ],
                    if (card.metaLine.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(card.metaLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: _AiText.subtle(compact ? 10 : 10.5)),
                    ],
                    if (card.hasPdf || card.type == 'report') ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _AiMiniCardButton(icon: Icons.visibility_rounded, text: card.actionLabel.isEmpty ? 'Открыть' : card.actionLabel, onTap: onTap),
                          if (card.hasPdf)
                            _AiMiniCardButton(icon: Icons.picture_as_pdf_rounded, text: 'PDF', onTap: onPdfTap, dark: true),
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
                decoration: BoxDecoration(color: _AiColors.greenSoft, borderRadius: BorderRadius.circular(9), border: Border.all(color: _AiColors.greenBorder)),
                child: const Icon(Icons.arrow_forward_rounded, color: _AiColors.greenDark, size: 16),
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

  const _AiMiniCardButton({required this.icon, required this.text, required this.onTap, this.dark = false});

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
            border: Border.all(color: dark ? _AiColors.graphite.withOpacity(.16) : _AiColors.greenBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: dark ? Colors.white : _AiColors.greenDark),
              const SizedBox(width: 5),
              Text(text, style: _AiText.chip(size: 10.2, color: dark ? Colors.white : _AiColors.greenDark)),
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
              const Icon(Icons.auto_awesome_rounded, size: 12, color: _AiColors.greenDark),
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
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _AiColors.greenDark)),
            SizedBox(width: 9),
            Text('Ищу по базе клуба...', style: TextStyle(color: _AiColors.text2, fontSize: 12.2, fontWeight: FontWeight.w600)),
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
                Text(block.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _AiText.muted(10.4)),
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

  const _AiHeaderAction({required this.icon, required this.text, required this.onTap});

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
        child: Container(width: 34, height: 34, decoration: _AiDecor.aiSoft(radius: 10), child: Icon(icon, size: 16, color: _AiColors.greenDark)),
      ),
    );
  }
}


class _AiFeedbackBar extends StatelessWidget {
  const _AiFeedbackBar({required this.compact, required this.onLike, required this.onDislike});

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
        _AiFeedbackButton(icon: Icons.thumb_down_alt_outlined, onTap: onDislike),
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
        child: SizedBox(width: 28, height: 28, child: Icon(icon, color: _AiColors.greenDark, size: 16)),
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
          const Icon(Icons.info_outline_rounded, color: _AiColors.orange, size: 15),
          const SizedBox(width: 7),
          Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: _AiText.muted(10.8).copyWith(color: const Color(0xFF9A3412)))),
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
      decoration: BoxDecoration(color: _AiColors.greenSoft, borderRadius: BorderRadius.circular(999), border: Border.all(color: _AiColors.greenBorder)),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _AiText.chip(size: 9.8, color: _AiColors.greenDark)),
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
  final List<String> suggestions;

  const _AiMessage._({required this.role, required this.text, this.queryId = 0, this.insights = const <_AiInsightSection>[], this.cards = const <_AiResultCard>[], this.diagrams = const <ClubAiTacticalDiagram>[], this.suggestions = const <String>[]});

  factory _AiMessage.user(String text) => _AiMessage._(role: _AiRole.user, text: text);

  factory _AiMessage.assistant({required String text, int queryId = 0, List<_AiInsightSection> insights = const <_AiInsightSection>[], List<_AiResultCard> cards = const <_AiResultCard>[], List<ClubAiTacticalDiagram> diagrams = const <ClubAiTacticalDiagram>[], List<String> suggestions = const <String>[]}) {
    return _AiMessage._(role: _AiRole.assistant, text: text, queryId: queryId, insights: insights, cards: cards, diagrams: diagrams, suggestions: suggestions);
  }
}

class _AiInsightSection {
  final String title;
  final String icon;
  final List<String> items;

  const _AiInsightSection({required this.title, required this.icon, required this.items});

  factory _AiInsightSection.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] is List ? map['items'] as List : const <dynamic>[];
    return _AiInsightSection(
      title: '${map['title'] ?? ''}',
      icon: '${map['icon'] ?? 'auto'}',
      items: rawItems.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList(growable: false),
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
    final route = map['route'] is Map ? Map<String, dynamic>.from(map['route'] as Map) : <String, dynamic>{};
    final payload = route['payload'] is Map ? Map<String, dynamic>.from(route['payload'] as Map) : <String, dynamic>{};
    final rawPdf = map['pdf_url'] ?? payload['pdf_url'] ?? map['file_url'] ?? payload['file_url'] ?? '';
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
  static const List<String> _fallback = <String>['SF Pro Display', 'SF Pro Text', 'Inter', 'Roboto', 'Arial'];

  static double _compact(double size) => size <= 10 ? size + .8 : size + .5;

  static TextStyle _base({required double size, required FontWeight weight, required Color color, double height = 1.18, double letterSpacing = -0.08, List<FontFeature>? features}) {
    return TextStyle(fontFamily: _family, fontFamilyFallback: _fallback, color: color, fontSize: _compact(size), fontWeight: weight, height: height, letterSpacing: letterSpacing, fontFeatures: features);
  }

  static TextStyle title(double size) => _base(size: size, weight: FontWeight.w600, color: _AiColors.text, height: 1.08, letterSpacing: -0.38);
  static TextStyle value(double size) => _base(size: size, weight: FontWeight.w600, color: _AiColors.text2, height: 1.28, letterSpacing: -0.08, features: const [FontFeature.tabularFigures()]);
  static TextStyle userText(double size) => _base(size: size, weight: FontWeight.w600, color: Colors.white, height: 1.28, letterSpacing: -0.08);
  static TextStyle muted(double size) => _base(size: size, weight: FontWeight.w500, color: _AiColors.muted, height: 1.34, letterSpacing: -0.05);
  static TextStyle subtle(double size) => _base(size: size, weight: FontWeight.w500, color: _AiColors.muted2, height: 1.2, letterSpacing: -0.04);
  static TextStyle chip({double size = 10.8, Color? color}) => _base(size: size, weight: FontWeight.w700, color: color ?? _AiColors.text, height: 1.08, letterSpacing: -0.02);
  static TextStyle tab() => _base(size: 10.8, weight: FontWeight.w600, color: _AiColors.greenDark, height: 1.08, letterSpacing: -0.02);
  static TextStyle action({Color color = _AiColors.text}) => _base(size: 11.8, weight: FontWeight.w700, color: color, height: 1.1);
}

class _AiColors {
  static const Color bg = Color(0xFFF6F7F9);
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
  static BoxDecoration workspaceBg() => const BoxDecoration(color: Color(0xFFF6F7F9));

  static BoxDecoration unifiedWindow({double radius = 18}) => BoxDecoration(
        color: _AiColors.soft2,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.055), blurRadius: 22, spreadRadius: -14, offset: const Offset(0, 12)),
          BoxShadow(color: _AiColors.blue.withOpacity(.035), blurRadius: 14, spreadRadius: -12, offset: const Offset(0, 6)),
        ],
      );

  static BoxDecoration aiGradient({double radius = 16}) => BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_AiColors.green, _AiColors.blue, _AiColors.violet]),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: _AiColors.green.withOpacity(.20), blurRadius: 24, spreadRadius: -12, offset: const Offset(0, 13))],
      );

  static BoxDecoration aiSoft({double radius = 16}) => BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _AiColors.green.withOpacity(.18)),
        boxShadow: [
          BoxShadow(color: _AiColors.green.withOpacity(.055), blurRadius: 18, spreadRadius: -11, offset: const Offset(0, 9)),
          BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 12, spreadRadius: -10, offset: const Offset(0, 5)),
        ],
      );

  static BoxDecoration disabledButton({double radius = 16}) => BoxDecoration(color: _AiColors.graphite.withOpacity(.55), borderRadius: BorderRadius.circular(radius));

  static BoxDecoration aiBubble() => BoxDecoration(
        color: Colors.white.withOpacity(.90),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
        border: Border.all(color: _AiColors.line),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 18, spreadRadius: -12, offset: const Offset(0, 10))],
      );

  static BoxDecoration userBubble() => BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_AiColors.green, _AiColors.blue]),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(5), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
        boxShadow: [BoxShadow(color: _AiColors.green.withOpacity(.18), blurRadius: 20, spreadRadius: -12, offset: const Offset(0, 12))],
      );
}
