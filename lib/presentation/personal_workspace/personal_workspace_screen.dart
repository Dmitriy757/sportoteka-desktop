import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/core/subscription/personal_module_service.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/tracking/tracking_mode_screen.dart';
import 'package:sportoteka/presentation/tracker/player/player_my_trainings_screen.dart';
import 'package:sportoteka/routes/app_routes.dart';

class PersonalWorkspaceScreen extends StatefulWidget {
  final bool embedded;
  final String? focusModuleCode;

  const PersonalWorkspaceScreen({
    super.key,
    this.embedded = false,
    this.focusModuleCode,
  });

  @override
  State<PersonalWorkspaceScreen> createState() => _PersonalWorkspaceScreenState();
}

class _PersonalWorkspaceScreenState extends State<PersonalWorkspaceScreen> {
  static const Color _bg = Color(0xFFF6F7F6);
  static const Color _panel = Colors.white;
  static const Color _text = Color(0xFF0B0F14);
  static const Color _muted = Color(0xFF667085);
  static const Color _line = Color(0xFFE8ECEA);
  static const Color _soft = Color(0xFFF7F9F8);
  static const Color _green = Color(0xFF00A750);
  static const Color _greenDark = Color(0xFF067A46);
  static const Color _greenSoft = Color(0xFFF0FAF5);
  static const Color _amber = Color(0xFFB54708);
  static const Color _amberSoft = Color(0xFFFFF6ED);

  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _userId = 0;
  String _name = '';
  int _activeCount = 0;
  int _pendingCount = 0;
  List<Map<String, dynamic>> _modules = <Map<String, dynamic>>[];
  final Set<String> _requestBusy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (mounted) {
      setState(() {
        _loading = !refresh;
        _refreshing = refresh;
        _error = null;
      });
    }

    _userId = await PrefUtils.getUserId() ?? 0;
    final first = (await PrefUtils.getUserFirstName()).trim();
    final last = (await PrefUtils.getUserLastName()).trim();
    _name = '$first $last'.trim();
    await PrefUtils.setActiveWorkspaceType('personal');
    await PrefUtils.clearActiveWorkspaceScope();

    if (_userId <= 0) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = 'Не удалось определить пользователя';
      });
      return;
    }

    final result = await PersonalModuleService.status(userId: _userId);
    if (!mounted) return;

    setState(() {
      _loading = false;
      _refreshing = false;
      if (result['success'] == true) {
        _activeCount = _asInt(result['active_count']);
        _pendingCount = _asInt(result['pending_count']);
        _modules = PersonalModuleService.modules(result);
      } else {
        _error = '${result['message'] ?? 'Не удалось загрузить модули'}';
      }
    });
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  String _state(Map<String, dynamic> item) =>
      '${item['state'] ?? 'locked'}'.trim().toLowerCase();

  bool _hasAccess(Map<String, dynamic> item) => item['has_access'] == true;

  String _price(Map<String, dynamic> item) {
    if (item['is_free'] == true) return 'Бесплатно';
    final value = _asInt(item['price_monthly_rub']);
    if (value <= 0) return 'По запросу';
    final raw = '$value';
    final chars = raw.split('');
    final out = <String>[];
    for (int i = 0; i < chars.length; i++) {
      final remain = chars.length - i;
      out.add(chars[i]);
      if (remain > 1 && remain % 3 == 1) out.add(' ');
    }
    return '${out.join()} ₽ / мес.';
  }

  String _expiry(Map<String, dynamic> item) {
    final ent = item['entitlement'];
    if (ent is! Map) return '';
    final raw = '${ent['expires_at'] ?? ''}'.trim();
    if (raw.isEmpty || raw == 'null') return 'без ограничения срока';
    final dt = DateTime.tryParse(raw.replaceAll(' ', 'T'));
    if (dt == null) return 'до $raw';
    String two(int v) => v.toString().padLeft(2, '0');
    return 'до ${two(dt.day)}.${two(dt.month)}.${dt.year}';
  }

  IconData _iconFor(String code) {
    switch (code) {
      case 'workspace_personal':
        return Icons.space_dashboard_outlined;
      case 'tactics_2d':
        return Icons.draw_outlined;
      case 'tactics_3d':
        return Icons.view_in_ar_outlined;
      case 'training_plans':
        return Icons.description_outlined;
      case 'training_management':
        return Icons.directions_run_outlined;
      case 'matches':
        return Icons.sports_soccer_outlined;
      case 'testing':
        return Icons.fact_check_outlined;
      case 'player_analytics':
        return Icons.insights_outlined;
      case 'video_center':
        return Icons.video_library_outlined;
      case 'video_analysis':
        return Icons.movie_filter_outlined;
      case 'video_ai':
        return Icons.auto_awesome_outlined;
      case 'tracker':
        return Icons.sensors_outlined;
      case 'live_analytics':
        return Icons.monitor_heart_outlined;
      case 'ai_assistant':
        return Icons.psychology_alt_outlined;
      default:
        return Icons.apps_outlined;
    }
  }

  Future<void> _requestModule(Map<String, dynamic> item) async {
    final code = '${item['module_code'] ?? ''}'.trim();
    if (code.isEmpty || _requestBusy.contains(code)) return;

    setState(() => _requestBusy.add(code));
    final result = await PersonalModuleService.request(
      userId: _userId,
      moduleCode: code,
      source: 'personal_workspace',
    );
    if (!mounted) return;
    setState(() => _requestBusy.remove(code));

    if (result['success'] == true) {
      final alreadyActive = result['already_active'] == true;
      final alreadyPending = result['already_pending'] == true;
      Get.snackbar(
        alreadyActive
            ? 'Модуль уже активен'
            : alreadyPending
                ? 'Заявка уже отправлена'
                : 'Заявка отправлена',
        alreadyActive
            ? 'Доступ уже есть в вашем Личном Workspace.'
            : alreadyPending
                ? 'Заявка находится на рассмотрении.'
                : 'Администратор получил заявку. После подтверждения модуль появится как активный.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      await _load(refresh: true);
      return;
    }

    Get.snackbar(
      'Не удалось отправить заявку',
      '${result['message'] ?? 'Повторите попытку позже'}',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  Future<void> _openModule(Map<String, dynamic> item) async {
    final code = '${item['module_code'] ?? ''}'.trim();
    if (!_hasAccess(item)) {
      await _requestModule(item);
      return;
    }

    switch (code) {
      case 'workspace_personal':
        Get.toNamed(AppRoutes.myProfileScreen);
        return;
      case 'tracker':
        Get.to<void>(() => const TrackingModeScreen());
        return;
      case 'training_management':
        final teamId = await PrefUtils.getTeamId() ?? 0;
        final teamName = (await PrefUtils.getUserClubName()).trim();
        if (!mounted) return;
        Get.to<void>(
          () => PlayerMyTrainingsScreen(
            teamId: teamId,
            teamName: teamName.isEmpty || teamName == 'Мой клуб'
                ? 'Личные тренировки'
                : teamName,
            userId: _userId,
          ),
        );
        return;
      default:
        Get.snackbar(
          '${item['title'] ?? 'Модуль'}',
          'Лицензия активна. Этот экран пока остаётся командным по своей модели данных; '
              'его нельзя безопасно открыть из личного контекста без owner_user_id.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 5),
        );
    }
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _green, strokeWidth: 2.2),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.cloud_off_outlined, size: 34, color: _muted),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: _t(12, color: _muted),
              ),
              const SizedBox(height: 12),
              _plainButton(
                label: 'Повторить',
                onTap: () => _load(),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: () => _load(refresh: true),
      child: ScrollConfiguration(
        behavior: const _PersonalWorkspaceScrollBehavior(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverToBoxAdapter(child: _hero()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 9),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Модули',
                        style: _t(14, weight: FontWeight.w700),
                      ),
                    ),
                    if (_refreshing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _green,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_modules.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: _line),
                    ),
                    child: Text(
                      'Каталог модулей пока пуст. Нажмите «Обновить» после установки серверной миграции.',
                      style: _t(10.2, color: _muted, height: 1.35),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 430,
                    mainAxisExtent: 205,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _moduleCard(_modules[index]),
                    childCount: _modules.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _plainButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: _t(10.2, weight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.space_dashboard_outlined, color: _greenDark, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _name.isEmpty ? 'Личный Workspace' : 'Личный Workspace · $_name',
                  style: _t(16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Личный контекст не наследует подписку клуба. Staff-доступы остаются отдельными рабочими пространствами.',
                  style: _t(10.2, color: _muted, height: 1.35),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: <Widget>[
                    _pill('$_activeCount платных активных', _greenDark, _greenSoft),
                    if (_pendingCount > 0)
                      _pill('$_pendingCount на рассмотрении', _amber, _amberSoft),
                    _pill('Workspace включён', _greenDark, Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moduleCard(Map<String, dynamic> item) {
    final code = '${item['module_code'] ?? ''}'.trim();
    final state = _state(item);
    final active = _hasAccess(item);
    final pending = state == 'pending';
    final free = item['is_free'] == true;
    final busy = _requestBusy.contains(code);
    final entitlement = item['entitlement'];
    final usageLimit = entitlement is Map ? _asInt(entitlement['usage_limit']) : 0;
    final usageUsed = entitlement is Map ? _asInt(entitlement['usage_used']) : 0;

    return Semantics(
      button: true,
      label: '${item['title'] ?? code}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : () => _openModule(item),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _panel,
            border: Border.all(
              color: active ? const Color(0xFFD9EEE3) : _line,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: active ? _greenSoft : _soft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      _iconFor(code),
                      size: 18,
                      color: active ? _greenDark : _muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _stateBadge(state, free: free),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                '${item['title'] ?? code}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(12.4, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${item['description'] ?? ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _t(9.5, color: _muted, height: 1.35),
              ),
              const SizedBox(height: 10),
              if (active && !free && _expiry(item).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _expiry(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(
                      8.8,
                      color: _greenDark,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              if (usageLimit > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Квота: $usageUsed / $usageLimit',
                    style: _t(8.8, color: _muted),
                  ),
                ),
              const Spacer(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _price(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(
                        9.5,
                        weight: FontWeight.w700,
                        color: active ? _greenDark : _text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _green,
                      ),
                    )
                  else
                    Text(
                      active
                          ? 'Открыть'
                          : pending
                              ? 'Ожидает'
                              : 'Подключить',
                      style: _t(
                        9.2,
                        weight: FontWeight.w700,
                        color: active
                            ? _greenDark
                            : pending
                                ? _amber
                                : _green,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stateBadge(String state, {required bool free}) {
    String title;
    Color fg;
    Color bg;
    if (free || state == 'free') {
      title = 'Включён'; fg = _greenDark; bg = _greenSoft;
    } else if (state == 'active') {
      title = 'Активен'; fg = _greenDark; bg = _greenSoft;
    } else if (state == 'pending') {
      title = 'Заявка'; fg = _amber; bg = _amberSoft;
    } else if (state == 'expired') {
      title = 'Истёк'; fg = _muted; bg = _soft;
    } else {
      title = 'Модуль'; fg = _muted; bg = _soft;
    }
    return _pill(title, fg, bg);
  }

  Widget _pill(String title, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(title, style: _t(8.3, weight: FontWeight.w700, color: color)),
    );
  }

  TextStyle _t(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = _text,
    double height = 1.2,
  }) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: height,
      letterSpacing: 0,
    );
  }

  Widget _headerAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: Icon(icon, size: 19, color: _text),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _line, width: .7)),
      ),
      child: Row(
        children: <Widget>[
          if (!widget.embedded)
            _headerAction(
              icon: Icons.arrow_back_ios_new_rounded,
              label: 'Назад',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          const SizedBox(width: 4),
          const Icon(
            Icons.space_dashboard_outlined,
            color: _greenDark,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Личный Workspace',
                  style: _t(13.5, weight: FontWeight.w700),
                ),
                Text(
                  'личные модули и подписки',
                  style: _t(9.1, color: _muted),
                ),
              ],
            ),
          ),
          _headerAction(
            icon: Icons.refresh_rounded,
            label: 'Обновить',
            onTap: () => _load(refresh: true),
          ),
          _headerAction(
            icon: Icons.person_outline_rounded,
            label: 'Мой профиль',
            onTap: () => Get.toNamed(AppRoutes.myProfileScreen),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: <Widget>[
        _header(),
        Expanded(child: _body()),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(color: _bg, child: content);
    }

    return Scaffold(backgroundColor: _bg, body: SafeArea(child: content));
  }
}


class _PersonalWorkspaceScrollBehavior extends MaterialScrollBehavior {
  const _PersonalWorkspaceScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
