import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_club_ai_assistant_panel.dart';

import 'data/player_profile_controller.dart';
import 'models/player_profile_models.dart';
import 'sections/player_activity_section.dart';
import 'sections/player_analytics_section.dart';
import 'sections/player_card_section.dart';
import 'sections/player_health_section.dart';
import 'sections/player_matches_section.dart';
import 'sections/player_overview_section.dart';
import 'sections/player_testing_section.dart';
import 'widgets/player_profile_header.dart';
import 'widgets/player_profile_editor_panel.dart';
import 'widgets/document_preview_panel.dart';
import 'widgets/player_profile_ui.dart';
import 'widgets/player_section_tabs.dart';

class CmrPlayerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> player;
  final bool embeddedInWorkspace;
  final VoidCallback? onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onMessage;

  const CmrPlayerProfileScreen({
    super.key,
    required this.player,
    this.embeddedInWorkspace = false,
    this.onClose,
    this.onEdit,
    this.onMessage,
  });

  @override
  State<CmrPlayerProfileScreen> createState() => _CmrPlayerProfileScreenState();
}

class _CmrPlayerProfileScreenState extends State<CmrPlayerProfileScreen> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';
  late PlayerProfileController controller;
  PlayerProfileEditorMode? _editorMode;
  Map<String, dynamic>? _editingMedical;
  bool _aiOpen = false;
  Widget Function(VoidCallback close)? _customPanelBuilder;

  @override
  void initState() {
    super.initState();
    controller = PlayerProfileController(player: widget.player)..addListener(_refresh);
    controller.load();
  }

  @override
  void didUpdateWidget(covariant CmrPlayerProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.player['player_id'] ?? oldWidget.player['id'];
    final newId = widget.player['player_id'] ?? widget.player['id'];
    if (oldId != newId) {
      controller.removeListener(_refresh);
      controller.dispose();
      controller = PlayerProfileController(player: widget.player)..addListener(_refresh);
      controller.load();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  int _i(dynamic value) => value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

  String _name() {
    final full = '${widget.player['full_name'] ?? widget.player['fullName'] ?? widget.player['name'] ?? ''}'.trim();
    if (full.isNotEmpty) return full;
    return '${widget.player['first_name'] ?? ''} ${widget.player['last_name'] ?? ''}'.trim();
  }

  Future<void> _handlePhotoEdit() async {
    if (widget.onEdit != null) {
      widget.onEdit!();
      return;
    }

    await Get.toNamed(AppRoutes.editPlayerScreen, arguments: widget.player);
    if (mounted) await controller.load();
  }

  Future<void> _handleMessage() async {
    if (widget.onMessage != null) {
      widget.onMessage!();
      return;
    }

    final myId = await PrefUtils.getUserId() ?? 0;
    final peerId = _i(widget.player['user_id'] ?? widget.player['userId']);
    if (myId <= 0 || peerId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить пользователя для чата')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_apiBase/get_or_create_private_chat.php'),
        body: {'me': '$myId', 'peer_id': '$peerId'},
      ).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      final chatId = decoded is Map ? _i(decoded['chat_id'] ?? decoded['id']) : 0;
      if (chatId <= 0) throw Exception('Сервер не вернул chat_id');
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            chatId: chatId,
            userId: myId,
            chatName: _name().isEmpty ? 'Игрок' : _name(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть чат: $e')),
      );
    }
  }

  void _openEditor(PlayerProfileEditorMode mode, {Map<String, dynamic>? record}) {
    setState(() {
      _aiOpen = false;
      _customPanelBuilder = null;
      _editorMode = mode;
      _editingMedical = record;
    });
  }

  void _toggleAi() {
    setState(() {
      _editorMode = null;
      _editingMedical = null;
      _customPanelBuilder = null;
      _aiOpen = !_aiOpen;
    });
  }


  void _openCustomPanel(Widget Function(VoidCallback close) builder) {
    setState(() {
      _aiOpen = false;
      _editorMode = null;
      _editingMedical = null;
      _customPanelBuilder = builder;
    });
  }

  void _closeCustomPanel() {
    if (!mounted) return;
    setState(() => _customPanelBuilder = null);
  }

  void _closeEditor() {
    if (!mounted) return;
    setState(() {
      _editorMode = null;
      _editingMedical = null;
    });
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = Container(
      color: Colors.white,
      child: Column(
        children: [
          PlayerProfileHeader(
            player: widget.player,
            embedded: widget.embeddedInWorkspace,
            onClose: widget.onClose,
            onPhotoEdit: _handlePhotoEdit,
            onMessage: _handleMessage,
            onAi: _toggleAi,
          ),
          PlayerSectionTabs(value: controller.section, onChanged: controller.selectSection),
          Expanded(child: _content()),
        ],
      ),
    );

    final body = LayoutBuilder(builder: (context, constraints) {
      final editor = _editorMode == null || controller.snapshot == null
          ? null
          : PlayerProfileEditorPanel(
              mode: _editorMode!,
              data: controller.snapshot!,
              medicalRecord: _editingMedical,
              onClose: _closeEditor,
              onSaveMetrics: controller.saveMetrics,
              onSaveMedical: controller.saveMedical,
            );

      final aiPanel = !_aiOpen
          ? null
          : CmrClubAiAssistantPanel(
              clubId: _i(widget.player['club_id'] ?? widget.player['clubId']),
              userId: controller.userId,
              teamId: controller.teamId > 0 ? controller.teamId : null,
              clubName: '${widget.player['club_name'] ?? ''}'.trim(),
              teamName: '${widget.player['team_name'] ?? ''}'.trim(),
              playerOnlyMode: true,
              playerId: controller.playerId,
              playerName: _name(),
              initialPayload: <String, dynamic>{
                'scope': 'player_profile',
                'player_id': controller.playerId,
                'player_name': _name(),
                if (controller.teamId > 0) 'team_id': controller.teamId,
              },
              onBack: () => setState(() => _aiOpen = false),
            );

      final customPanel = _customPanelBuilder?.call(_closeCustomPanel);
      final sidePanel = editor ?? aiPanel ?? customPanel;

      // Важно: на планшете/ПК всегда сохраняем одинаковое дерево Row -> Expanded -> core.
      // Раньше без панели возвращался просто core, а при открытии панели — Row.
      // Из-за смены родителя Flutter dispose-ил StatefulWidget активного раздела,
      // и callback календаря вызывал setState() у уже удалённого State.
      if (constraints.maxWidth >= 720) {
        const panelWidth = 430.0;
        return Row(
          children: [
            Expanded(child: core),
            if (sidePanel != null) ...[
              Container(width: 1, color: PpColors.line),
              SizedBox(width: panelWidth, child: sidePanel),
            ],
          ],
        );
      }

      // На телефоне правая панель занимает весь экран.
      return sidePanel ?? core;
    });

    if (widget.embeddedInWorkspace) return body;
    return Scaffold(
      backgroundColor: PpColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: ClipRRect(borderRadius: BorderRadius.circular(18), child: body),
        ),
      ),
    );
  }

  Widget _content() {
    if (controller.loading && controller.snapshot == null) {
      return const Center(child: CircularProgressIndicator(color: PpColors.green));
    }
    if (controller.error != null && controller.snapshot == null) {
      return Center(
        child: PpActionRow(
          icon: Icons.refresh_rounded,
          title: 'Не удалось загрузить профиль',
          subtitle: controller.error!,
          onTap: controller.load,
        ),
      );
    }
    final data = controller.snapshot;
    if (data == null) return const SizedBox.shrink();

    switch (controller.section) {
      case PlayerProfileSection.overview:
        return PlayerOverviewSection(data: data, session: controller.selectedSession);
      case PlayerProfileSection.activity:
        return PlayerActivitySection(
          data: data,
          selectedSession: controller.selectedSession,
          sessionLoading: controller.sessionLoading,
          onSelectSession: controller.selectSession,
          onOpenSidePanel: _openCustomPanel,
        );
      case PlayerProfileSection.matches:
        return PlayerMatchesSection(data: data);
      case PlayerProfileSection.analytics:
        return PlayerAnalyticsSection(data: data, session: controller.selectedSession);
      case PlayerProfileSection.testing:
        return PlayerTestingSection(
          data: data,
          userId: controller.userId,
          onBack: () => controller.selectSection(PlayerProfileSection.overview),
          onOpenSidePanel: _openCustomPanel,
        );
      case PlayerProfileSection.health:
        return PlayerHealthSection(
          data: data,
          onEditMetrics: () => _openEditor(PlayerProfileEditorMode.metrics),
          onAddMedical: () => _openEditor(PlayerProfileEditorMode.medical),
          onEditMedical: (record) => _openEditor(PlayerProfileEditorMode.medical, record: record),
          onDeleteMedical: controller.deleteMedical,
          onOpenDocument: (record) => _openCustomPanel(
            (close) => DocumentPreviewPanel(
              playerId: controller.playerId,
              record: record,
              onClose: close,
            ),
          ),
        );
      case PlayerProfileSection.card:
        return PlayerCardSection(data: data, session: controller.selectedSession);
    }
  }
}
