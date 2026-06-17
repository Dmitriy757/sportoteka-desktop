import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/core/subscription/subscription_activation_service.dart';

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
  static const String subscriptionInfoUrl =
      'https://sportoteka.by/api/get_my_subscription.php';
  // Если у тебя подписки обслуживаются на другом домене — просто замени URL.

  bool _yearly = false;

  bool _loadingSubscription = true;
  _SubscriptionInfo? _subscription;

  List<_PlanModel> get _plans => [
        _PlanModel(
          id: 'coach_pro',
          title: 'Coach Pro',
          subtitle: 'Для тренеров и команд',
          monthlyPrice: '19 BYN',
          yearlyPrice: '190 BYN',
          yearlyBadge: '2 мес. в подарок',
          accent: const Color(0xFF2563EB),
          light: const Color(0xFFEFF6FF),
          features: const [
            'Графический редактор команды',
            'Планы-конспекты',
            'Видеоанализ',
            'Heatmap',
            'Профессиональные модули команды',
          ],
        ),
        _PlanModel(
          id: 'club_pro',
          title: 'Club Pro',
          subtitle: 'Для клубов и академий',
          monthlyPrice: '49 BYN',
          yearlyPrice: '490 BYN',
          yearlyBadge: '2 мес. в подарок',
          accent: AppColors.primaryGreen,
          light: const Color(0xFFEFFAF3),
          isPopular: true,
          features: const [
            'Панель клуба',
            'Графический редактор клуба',
            'Планы и конспекты',
            'Видеоанализ клуба',
            'Heatmap',
            'Расширенная аналитика',
            'Управление командами клуба',
          ],
        ),
        _PlanModel(
          id: 'full_pro',
          title: 'Full Pro',
          subtitle: 'Максимальный доступ',
          monthlyPrice: '99 BYN',
          yearlyPrice: '990 BYN',
          yearlyBadge: '2 мес. в подарок',
          accent: const Color(0xFF7C3AED),
          light: const Color(0xFFF5F3FF),
          features: const [
            'Все функции Coach Pro',
            'Все функции Club Pro',
            'Видеоуроки',
            'AI-модули',
            'Все PRO-инструменты',
            'Приоритетный доступ к новым функциям',
          ],
        ),
      ];

  String get _periodLabel => _yearly ? 'в год' : 'в месяц';

  @override
  void initState() {
    super.initState();
    _loadCurrentSubscription();
  }

  Future<void> _loadCurrentSubscription() async {
  setState(() => _loadingSubscription = true);

  try {
    final userId = await PrefUtils.getUserId();
    debugPrint('SUB userId = $userId');

    if (userId == null || userId <= 0) {
      setState(() {
        _subscription = null;
        _loadingSubscription = false;
      });
      return;
    }

    final response = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/get_my_subscription.php'),
      body: {'user_id': userId.toString()},
    );

    debugPrint('SUB statusCode = ${response.statusCode}');
    debugPrint('SUB raw body = ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode != 200) {
      setState(() => _loadingSubscription = false);
      return;
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    debugPrint('SUB parsed = $data');

    if (data is Map<String, dynamic> && data['success'] == true) {
      final sub = data['subscription'];
      if (sub is Map<String, dynamic>) {
        _subscription = _SubscriptionInfo.fromJson(sub);
      } else {
        _subscription = null;
      }
    } else {
      _subscription = null;
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
    debugPrint('SELECT PLAN tapped: ${plan.id}');

    final userId = await PrefUtils.getUserId();
    debugPrint('USER ID = $userId');

    if (userId == null || userId <= 0) {
      Get.snackbar(
        'Ошибка',
        'Не удалось определить пользователя',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    String role = 'user';
    if (plan.id == 'coach_pro') {
      role = 'coach';
    } else if (plan.id == 'club_pro') {
      role = 'club';
    } else if (plan.id == 'full_pro') {
      role = 'club';
    }

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    final result = await SubscriptionActivationService.activatePlan(
  userId: userId,
  role: role,
  planCode: plan.id,
  isYearly: _yearly,
);
    if (Get.isDialogOpen == true) {
      Get.back();
    }

    if (result['success'] == true) {
      Get.snackbar(
        'Подписка активирована',
        'Тариф ${plan.title} подключён',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );

      await _loadCurrentSubscription();
      return;
    }

    Get.snackbar(
      'Ошибка',
      (result['message'] ?? 'Не удалось активировать тариф').toString(),
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
    final hint = widget.titleHint?.trim();
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Sportoteka PRO',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadCurrentSubscription,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCurrentSubscription,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isTablet ? 24 : 16,
            8,
            isTablet ? 24 : 16,
            24,
          ),
          children: [
            _HeroSubscriptionCard(
              titleHint: hint,
              source: widget.source,
            ),
            const SizedBox(height: 16),

            if (_loadingSubscription)
              const _SubscriptionLoadingCard()
            else
              _SubscriptionStatusCard(
                subscription: _subscription,
                onRefresh: _loadCurrentSubscription,
              ),

            const SizedBox(height: 16),
            _BillingToggle(
              yearly: _yearly,
              onChanged: (v) => setState(() => _yearly = v),
            ),
            const SizedBox(height: 16),

            if (isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _plans
                    .map(
                      (plan) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: plan == _plans.last ? 0 : 12,
                          ),
                          child: _PlanCard(
                            plan: plan,
                            yearly: _yearly,
                            isCurrent: _isCurrentPlan(plan),
                            onTap: () => _selectPlan(plan),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              )
            else
              ..._plans.map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _PlanCard(
                    plan: plan,
                    yearly: _yearly,
                    isCurrent: _isCurrentPlan(plan),
                    onTap: () => _selectPlan(plan),
                  ),
                ),
              ),

            const SizedBox(height: 8),
            _BenefitsGrid(yearly: _yearly, periodLabel: _periodLabel),
            const SizedBox(height: 16),
            _BottomInfoCard(yearly: _yearly),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionStatusCard extends StatelessWidget {
  final _SubscriptionInfo? subscription;
  final VoidCallback onRefresh;

  const _SubscriptionStatusCard({
    required this.subscription,
    required this.onRefresh,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (subscription == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [AppColors.cardShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.subscriptions_outlined,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Подписка не активирована',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Выберите тариф ниже, чтобы открыть PRO-возможности Sportoteka.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      );
    }

    final activeColor = subscription!.isActive
        ? AppColors.primaryGreen
        : const Color(0xFFEF4444);

    final activeBg = subscription!.isActive
        ? const Color(0xFFEFFAF3)
        : const Color(0xFFFEF2F2);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [AppColors.cardShadow],
        border: Border.all(color: activeBg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: activeBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  subscription!.isActive
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  color: activeColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription!.isActive
                          ? 'Подписка активна'
                          : 'Подписка истекла',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subscription!.planTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: activeColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.calendar_today_outlined,
                label: 'Начало: ${_formatDate(subscription!.startedAt)}',
              ),
              _InfoChip(
                icon: Icons.event_available_outlined,
                label: 'До: ${_formatDate(subscription!.expiresAt)}',
              ),
              _InfoChip(
                icon: Icons.timelapse_rounded,
                label: subscription!.isActive
                    ? 'Осталось ${subscription!.daysLeft} дн.'
                    : 'Срок завершён',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubscriptionLoadingCard extends StatelessWidget {
  const _SubscriptionLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [AppColors.cardShadow],
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Загружаем информацию о подписке...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSubscriptionCard extends StatelessWidget {
  final String? titleHint;
  final String? source;

  const _HeroSubscriptionCard({
    required this.titleHint,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF00A750),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Профессиональный доступ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Открой все PRO-инструменты Sportoteka',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            titleHint?.isNotEmpty == true
                ? 'Для доступа к модулю «$titleHint» выберите подходящий тариф и активируйте подписку.'
                : 'Выберите подходящий тариф для команды, клуба или полного профессионального доступа.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeroChip(label: 'Видеоанализ'),
              _HeroChip(label: 'Heatmap'),
              _HeroChip(label: 'Планы'),
              _HeroChip(label: 'AI-модули'),
            ],
          ),
          if (source != null && source!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Источник: $source',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BillingToggle extends StatelessWidget {
  final bool yearly;
  final ValueChanged<bool> onChanged;

  const _BillingToggle({
    required this.yearly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Row(
        children: [
          Expanded(
            child: _PeriodButton(
              active: !yearly,
              title: 'Помесячно',
              subtitle: 'гибкая оплата',
              onTap: () => onChanged(false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _PeriodButton(
                  active: yearly,
                  title: 'На год',
                  subtitle: 'выгоднее',
                  onTap: () => onChanged(true),
                ),
                Positioned(
                  top: -10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '−17%',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final bool active;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.active,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primaryGreen : const Color(0xFFF6F8FB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: active
                      ? Colors.white.withOpacity(0.9)
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _PlanModel plan;
  final bool yearly;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.yearly,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = yearly ? plan.yearlyPrice : plan.monthlyPrice;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent
              ? AppColors.primaryGreen
              : (plan.isPopular ? plan.accent : const Color(0xFFE5E7EB)),
          width: (isCurrent || plan.isPopular) ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? AppColors.primaryGreen.withOpacity(0.14)
                : plan.isPopular
                    ? plan.accent.withOpacity(0.14)
                    : Colors.black.withOpacity(0.05),
            blurRadius: isCurrent || plan.isPopular ? 22 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCurrent)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Текущий тариф',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  )
                else if (plan.isPopular)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: plan.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Популярный план',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: plan.light,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _iconForPlan(plan.id),
                        color: plan.accent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: plan.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        yearly ? 'в год' : 'в месяц',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (yearly) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: plan.light,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      plan.yearlyBadge,
                      style: TextStyle(
                        color: plan.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ...plan.features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: plan.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.25,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrent ? null : onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isCurrent ? const Color(0xFFE5E7EB) : plan.accent,
                      foregroundColor:
                          isCurrent ? const Color(0xFF6B7280) : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isCurrent
                          ? 'Тариф уже активен'
                          : (plan.isPopular
                              ? 'Выбрать популярный план'
                              : 'Выбрать тариф'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (plan.isPopular && !isCurrent)
            Positioned(
              top: -8,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'TOP',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconForPlan(String id) {
    switch (id) {
      case 'coach_pro':
        return Icons.sports;
      case 'club_pro':
        return Icons.shield_outlined;
      case 'full_pro':
        return Icons.workspace_premium_outlined;
      default:
        return Icons.star_outline;
    }
  }
}

class _BenefitsGrid extends StatelessWidget {
  final bool yearly;
  final String periodLabel;

  const _BenefitsGrid({
    required this.yearly,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _BenefitItem(
        icon: Icons.lock_open_rounded,
        title: 'Доступ к PRO',
        subtitle: 'Открытие профессиональных инструментов',
      ),
      _BenefitItem(
        icon: Icons.calendar_today_outlined,
        title: yearly ? 'Оплата на год' : 'Ежемесячная оплата',
        subtitle: yearly ? 'Более выгодный формат' : 'Гибкий формат подключения',
      ),
      _BenefitItem(
        icon: Icons.bolt_rounded,
        title: 'Мгновенная активация',
        subtitle: 'После подтверждения оплаты',
      ),
      _BenefitItem(
        icon: Icons.support_agent_outlined,
        title: 'Поддержка',
        subtitle: 'Помощь по настройке доступа',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Что входит',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [AppColors.cardShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, color: AppColors.primaryGreen, size: 24),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BottomInfoCard extends StatelessWidget {
  final bool yearly;

  const _BottomInfoCard({required this.yearly});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [AppColors.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Оплата и подключение',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            yearly
                ? 'Вы выбрали годовой формат. Он выгоднее и позволяет не продлевать подписку каждый месяц.'
                : 'Вы выбрали помесячный формат. Он подойдёт для гибкого старта и тестирования возможностей.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.textTertiary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Здесь далее можно подключить оплату, промокоды, пробный период или заявку менеджеру.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
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

class _PlanModel {
  final String id;
  final String title;
  final String subtitle;
  final String monthlyPrice;
  final String yearlyPrice;
  final String yearlyBadge;
  final Color accent;
  final Color light;
  final bool isPopular;
  final List<String> features;

  const _PlanModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.yearlyBadge,
    required this.accent,
    required this.light,
    this.isPopular = false,
    required this.features,
  });
}

class _BenefitItem {
  final IconData icon;
  final String title;
  final String subtitle;

  _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
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

  factory _SubscriptionInfo.fromJson(Map<String, dynamic> json) {
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

    return _SubscriptionInfo(
      planCode: (json['plan_code'] ?? '').toString(),
      planTitle: (json['plan_title'] ?? json['plan_code'] ?? 'Подписка')
          .toString(),
      status: (json['status'] ?? 'inactive').toString(),
      startedAt: parseDate(json['started_at']),
      expiresAt: parseDate(json['expires_at']),
      daysLeft: parseInt(json['days_left']),
    );
  }
}