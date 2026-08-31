import 'subscription_request_service.dart';

/// Совместимый фасад для старого кода.
///
/// Клиент больше НЕ активирует платную подписку сам.
/// Любой старый вызов activatePlan() теперь только создаёт заявку,
/// которую должен подтвердить администратор SPORTOTEKA.
class SubscriptionActivationService {
  static Future<Map<String, dynamic>> activatePlan({
    required int userId,
    required String role,
    required String planCode,
    required bool isYearly,
  }) {
    return SubscriptionRequestService.submit(
      userId: userId,
      planCode: planCode,
      billingPeriod: isYearly ? 'yearly' : 'monthly',
      source: 'legacy_activation_service',
    );
  }
}
