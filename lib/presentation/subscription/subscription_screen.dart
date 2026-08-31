import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/core/subscription/subscription_request_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final String? source;
  final String? titleHint;

  const SubscriptionScreen({
    super.key,
    this.source,
    this.titleHint,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loadingSubscription = true;
  _SubscriptionInfo? _subscription;

  // planCode оставлены прежними, чтобы не ломать существующий backend
  // SubscriptionActivationService.
  List<_PlanModel> get _plans => const <_PlanModel>[
        _PlanModel(
          id: 'coach_pro',
          title: 'Базовая',
          subtitle: 'Минимальный набор для клуба, школы или академии',
          price: '150 000 ₽',
          period: 'в год',
          priceNote: '≈ 5 400 BYN · ориентировочно по текущему курсу',
          accent: _SubscriptionUi.green,
          light: _SubscriptionUi.greenSoft,
          features: <String>[
            'Клубный кабинет и управление командами',
            'До 20 команд',
            'До 20 игроков в команде',
            'До 20 родителей',
            'Календарь мероприятий',
            'Журнал посещаемости',
            'Дневник игрока',
            'Планы-конспекты и тестирование',
            'Чаты и уведомления',
          ],
        ),
        _PlanModel(
          id: 'club_pro',
          title: 'Аналитика + AI',
          subtitle: 'Для глубокой работы с тренировками и матчами',
          price: '200 000 ₽',
          period: 'в год',
          priceNote: '≈ 7 190 BYN · ориентировочно по текущему курсу',
          accent: _SubscriptionUi.greenDark,
          light: Color(0xFFEEF8F3),
          isPopular: true,
          features: <String>[
            'Всё из тарифа «Базовая»',
            'Расширенная аналитика команды и игроков',
            'AI-анализ тренировок и матчей',
            'Видеоанализ',
            'Heatmap и маршруты',
            'Расширенные отчёты',
            'AI-рекомендации и профессиональные инструменты',
          ],
        ),
        _PlanModel(
          id: 'full_pro',
          title: 'Оборудование',
          subtitle: 'Трекинг команды и полный аппаратный комплект',
          price: 'По запросу',
          period: '',
          priceNote: 'Комплект на 12–24 трекера',
          accent: _SubscriptionUi.amber,
          light: _SubscriptionUi.amberSoft,
          requestOnly: true,
          features: <String>[
            'Всё из тарифа «Аналитика + AI»',
            'Комплект на 12–24 GPS-трекера',
            'Подключение оборудования к Sportoteka',
            'Настройка команды и рабочих сценариев',
            'Сопровождение при внедрении',
            'Индивидуальная комплектация под клуб',
          ],
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadCurrentSubscription();
  }

  TextStyle _t(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = _SubscriptionUi.text,
    double height = 1.25,
  }) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: height,
      letterSpacing: 0,
    );
  }

  Widget _dot(
    Color color, {
    double size = 5,
    bool glow = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: color.withOpacity(.18),
                  blurRadius: size * 2,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _brandDots({
    Color color = _SubscriptionUi.green,
    bool compact = false,
  }) {
    final values = compact
        ? const <List<double>>[
            <double>[3.0, .34],
            <double>[3.8, .48],
            <double>[4.6, .68],
            <double>[5.4, 1],
          ]
        : const <List<double>>[
            <double>[3.5, .34],
            <double>[4.5, .48],
            <double>[5.5, .68],
            <double>[6.5, 1],
          ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int i = 0; i < values.length; i++) ...<Widget>[
          Container(
            width: values[i][0],
            height: values[i][0],
            decoration: BoxDecoration(
              color: color.withOpacity(values[i][1]),
              shape: BoxShape.circle,
              boxShadow: values[i][1] >= .95
                  ? <BoxShadow>[
                      BoxShadow(
                        color: color.withOpacity(.14),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
          if (i != values.length - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }

  Future<void> _loadCurrentSubscription() async {
    if (mounted) {
      setState(() => _loadingSubscription = true);
    }

    try {
      final userId = await PrefUtils.getUserId();

      if (userId == null || userId <= 0) {
        if (!mounted) return;
        setState(() {
          _subscription = null;
          _loadingSubscription = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse(
          'https://sportotekaapp.ru/api/get_my_subscription.php',
        ),
        body: <String, String>{
          'user_id': userId.toString(),
        },
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() => _loadingSubscription = false);
        return;
      }

      final data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (data is Map<String, dynamic> && data['success'] == true) {
        final sub = data['subscription'];

        setState(() {
          _subscription = sub is Map<String, dynamic>
              ? _SubscriptionInfo.fromJson(sub)
              : null;
        });
      } else {
        setState(() => _subscription = null);
      }
    } catch (e) {
      debugPrint('LOAD SUBSCRIPTION ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingSubscription = false);
      }
    }
  }

  Future<void> _selectPlan(_PlanModel plan) async {
    final userId = await PrefUtils.getUserId();

    if (userId == null || userId <= 0) {
      Get.snackbar(
        'Ошибка',
        'Не удалось определить пользователя',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    Get.dialog(
      const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _SubscriptionUi.green,
        ),
      ),
      barrierDismissible: false,
    );

    final result = await SubscriptionRequestService.submit(
      userId: userId,
      planCode: plan.id,
      billingPeriod: 'yearly',
      source: widget.source ?? 'subscription_screen',
    );

    if (Get.isDialogOpen == true) {
      Get.back();
    }

    if (result['success'] == true) {
      final alreadyPending = result['already_pending'] == true;
      final alreadyActive = result['already_active'] == true;

      Get.snackbar(
        alreadyActive
            ? 'Тариф уже активен'
            : alreadyPending
                ? 'Заявка уже отправлена'
                : 'Заявка отправлена',
        alreadyActive
            ? 'Тариф «${plan.title}» уже подключён.'
            : alreadyPending
                ? 'Заявка на тариф «${plan.title}» уже находится на рассмотрении.'
                : 'Мы получили заявку на тариф «${plan.title}». '
                    'После проверки администратор подтвердит подключение.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 5),
      );

      await _loadCurrentSubscription();
      return;
    }

    Get.snackbar(
      'Не удалось отправить заявку',
      (result['message'] ?? 'Повторите попытку позже').toString(),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  bool _isCurrentPlan(_PlanModel plan) {
    if (_subscription == null) return false;

    return _subscription!.planCode == plan.id && _subscription!.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 1080;
    final medium = width >= 720;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _header(
              mobile: MediaQuery.of(context).size.width < 900,
            ),
            const Divider(
              height: 1,
              thickness: .6,
              color: _SubscriptionUi.line,
            ),
            Expanded(
              child: RefreshIndicator(
                color: _SubscriptionUi.green,
                onRefresh: _loadCurrentSubscription,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    wide
                        ? 20
                        : medium
                            ? 16
                            : 12,
                    12,
                    wide
                        ? 20
                        : medium
                            ? 16
                            : 12,
                    28,
                  ),
                  children: <Widget>[
                    _hero(),
                    const SizedBox(height: 9),
                    if (_loadingSubscription)
                      _loadingStatus()
                    else
                      _subscriptionStatus(),
                    const SizedBox(height: 12),
                    _plansHeader(),
                    const SizedBox(height: 9),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (int i = 0; i < _plans.length; i++) ...<Widget>[
                            Expanded(
                              child: _planCard(_plans[i]),
                            ),
                            if (i != _plans.length - 1)
                              const SizedBox(width: 10),
                          ],
                        ],
                      )
                    else
                      ..._plans.map(
                        (plan) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _planCard(plan),
                        ),
                      ),
                    const SizedBox(height: 4),
                    _priceNotice(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header({
    required bool mobile,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      child: Row(
        children: <Widget>[
          if (!mobile) ...<Widget>[
            Material(
              color: _SubscriptionUi.soft,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: () => Navigator.maybePop(context),
                borderRadius: BorderRadius.circular(9),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: _SubscriptionUi.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          _brandDots(),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Подписка SPORTOTEKA',
                  style: _t(
                    14.5,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Тарифы для клубов, школ и академий',
                  style: _t(
                    9.5,
                    color: _SubscriptionUi.muted,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: _SubscriptionUi.soft,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: _loadCurrentSubscription,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
                child: Row(
                  children: <Widget>[
                    _dot(
                      _SubscriptionUi.green,
                      size: 4.5,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Обновить',
                      style: _t(
                        9.1,
                        weight: FontWeight.w600,
                        color: _SubscriptionUi.greenDark,
                      ),
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

  Widget _hero() {
    final hint = widget.titleHint?.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: _SubscriptionUi.greenSoft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _brandDots(
                color: _SubscriptionUi.greenDark,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Один контур для управления клубом',
                      style: _t(
                        compact ? 14 : 16.2,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hint?.isNotEmpty == true
                          ? 'Модуль «$hint» доступен в соответствующем тарифе. '
                              'Выберите уровень, который подходит вашей организации.'
                          : 'Начните с базового управления клубом, '
                              'добавьте аналитику и AI или подключите '
                              'полный комплект оборудования.',
                      style: _t(
                        9.8,
                        color: _SubscriptionUi.muted,
                        height: 1.38,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: const <Widget>[
                        _HeroTag(
                          label: 'Управление',
                          color: _SubscriptionUi.green,
                        ),
                        _HeroTag(
                          label: 'Аналитика + AI',
                          color: _SubscriptionUi.greenDark,
                        ),
                        _HeroTag(
                          label: '12–24 трекера',
                          color: _SubscriptionUi.amber,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _loadingStatus() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _SubscriptionUi.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _SubscriptionUi.green,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'Проверяем текущую подписку…',
            style: _t(
              9.8,
              color: _SubscriptionUi.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subscriptionStatus() {
    final subscription = _subscription;

    if (subscription == null) {
      return Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _SubscriptionUi.soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            _dot(
              _SubscriptionUi.muted2,
              size: 6,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Подписка не активирована',
                    style: _t(
                      10.8,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Выберите подходящий тариф ниже.',
                    style: _t(
                      9.3,
                      color: _SubscriptionUi.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final statusColor =
        subscription.isActive ? _SubscriptionUi.green : _SubscriptionUi.red;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: subscription.isActive
            ? _SubscriptionUi.greenSoft
            : _SubscriptionUi.redSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _dot(
              statusColor,
              size: 6,
              glow: subscription.isActive,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  subscription.isActive
                      ? 'Подписка активна'
                      : 'Подписка завершена',
                  style: _t(
                    10.6,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subscription.planTitle,
                  style: _t(
                    9.8,
                    weight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    _statusPill(
                      'Начало',
                      _formatDate(
                        subscription.startedAt,
                      ),
                      _SubscriptionUi.greenDark,
                    ),
                    _statusPill(
                      'До',
                      _formatDate(
                        subscription.expiresAt,
                      ),
                      _SubscriptionUi.amber,
                    ),
                    _statusPill(
                      subscription.isActive ? 'Осталось' : 'Статус',
                      subscription.isActive
                          ? '${subscription.daysLeft} дн.'
                          : 'Завершена',
                      statusColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.72),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _dot(
            color,
            size: 4,
          ),
          const SizedBox(width: 5),
          Text(
            '$label: $value',
            style: _t(
              8.8,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  Widget _plansHeader() {
    return Row(
      children: <Widget>[
        _brandDots(
          color: _SubscriptionUi.greenDark,
          compact: true,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Выберите тариф и отправьте заявку',
                style: _t(
                  12,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Платные тарифы подключаются после заявки и подтверждения администратором.',
                style: _t(
                  9.2,
                  color: _SubscriptionUi.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _planCard(_PlanModel plan) {
    final current = _isCurrentPlan(plan);

    return Container(
      decoration: BoxDecoration(
        color: _SubscriptionUi.soft,
        borderRadius: BorderRadius.circular(11),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _brandDots(
                color: plan.accent,
                compact: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            plan.title,
                            style: _t(
                              13.2,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (current)
                          _badge(
                            'Текущий',
                            _SubscriptionUi.green,
                            _SubscriptionUi.greenSoft,
                          )
                        else if (plan.isPopular)
                          _badge(
                            'Рекомендуем',
                            _SubscriptionUi.greenDark,
                            const Color(0xFFE8F5EE),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plan.subtitle,
                      style: _t(
                        9.4,
                        color: _SubscriptionUi.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Text(
                  plan.price,
                  style: _t(
                    21,
                    weight: FontWeight.w600,
                    color: plan.accent,
                    height: 1,
                  ),
                ),
              ),
              if (plan.period.isNotEmpty) ...<Widget>[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    plan.period,
                    style: _t(
                      9.4,
                      color: _SubscriptionUi.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: plan.light,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _dot(
                  plan.accent,
                  size: 4.5,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    plan.priceNote,
                    style: _t(
                      8.9,
                      weight: FontWeight.w500,
                      color: plan.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          ...plan.features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: _dot(
                      plan.accent,
                      size: 4.5,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      feature,
                      style: _t(
                        9.5,
                        color: _SubscriptionUi.text,
                        height: 1.32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: current
                  ? const Color(0xFFE7EAE8)
                  : plan.requestOnly
                      ? plan.light
                      : plan.accent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: current ? null : () => _selectPlan(plan),
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _dot(
                        current
                            ? _SubscriptionUi.muted2
                            : plan.requestOnly
                                ? plan.accent
                                : Colors.white,
                        size: 4.5,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        current
                            ? 'Тариф активен'
                            : plan.requestOnly
                                ? 'Оставить заявку'
                                : 'Подать заявку',
                        style: _t(
                          9.7,
                          weight: FontWeight.w600,
                          color: current
                              ? _SubscriptionUi.muted
                              : plan.requestOnly
                                  ? plan.accent
                                  : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(
    String label,
    Color color,
    Color background,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _dot(
            color,
            size: 4,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: _t(
              8.3,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceNotice() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _SubscriptionUi.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _dot(
            _SubscriptionUi.amber,
            size: 5,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Эквиваленты в BYN указаны ориентировочно по текущему курсу '
              'на 24.08.2026 и могут меняться. '
              'Стоимость оборудования зависит от количества трекеров, '
              'комплектации и условий внедрения.',
              style: _t(
                9.2,
                color: _SubscriptionUi.muted,
                height: 1.38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  final String label;
  final Color color;

  const _HeroTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.76),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 4.5,
            height: 4.5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.custom(
              size: 8.8,
              weight: FontWeight.w600,
              color: _SubscriptionUi.text,
              height: 1.1,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionUi {
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);

  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFF7E8);

  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFFF1F1);

  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF667085);
  static const Color muted2 = Color(0xFF98A2B3);

  static const Color soft = Color(0xFFF7F9F8);
  static const Color line = Color(0xFFEEF1EF);
}

class _PlanModel {
  final String id;
  final String title;
  final String subtitle;
  final String price;
  final String period;
  final String priceNote;
  final Color accent;
  final Color light;
  final bool isPopular;
  final bool requestOnly;
  final List<String> features;

  const _PlanModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.period,
    required this.priceNote,
    required this.accent,
    required this.light,
    this.isPopular = false,
    this.requestOnly = false,
    required this.features,
  });
}

class _SubscriptionInfo {
  final String planCode;
  final String planTitle;
  final String status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final int daysLeft;

  const _SubscriptionInfo({
    required this.planCode,
    required this.planTitle,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    required this.daysLeft,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory _SubscriptionInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final s = value.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? 0;
    }

    final planCode = (json['plan_code'] ?? '').toString();

    String displayTitle;
    switch (planCode) {
      case 'coach_pro':
        displayTitle = 'Базовая';
        break;
      case 'club_pro':
        displayTitle = 'Аналитика + AI';
        break;
      case 'full_pro':
        displayTitle = 'Оборудование';
        break;
      default:
        displayTitle =
            (json['plan_title'] ?? json['plan_code'] ?? 'Подписка').toString();
    }

    return _SubscriptionInfo(
      planCode: planCode,
      planTitle: displayTitle,
      status: (json['status'] ?? 'inactive').toString(),
      startedAt: parseDate(json['started_at']),
      expiresAt: parseDate(json['expires_at']),
      daysLeft: parseInt(json['days_left']),
    );
  }
}
