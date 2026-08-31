import 'club_subscription_policy.dart';

class SubscriptionAccess {
  final String planCode;
  final bool isActive;
  final bool isPremium;
  final String? expiresAt;
  final List<String> features;

  const SubscriptionAccess({
    required this.planCode,
    required this.isActive,
    required this.isPremium,
    required this.features,
    this.expiresAt,
  });

  bool has(String featureCode) {
    if (!isActive) return false;

    if (features.contains(featureCode)) {
      return true;
    }

    return ClubSubscriptionPolicy.hasFeature(
      planCode: planCode,
      isActive: isActive,
      featureCode: featureCode,
    );
  }

  ClubSubscriptionTier get tier => ClubSubscriptionPolicy.tierForPlan(planCode);

  String get planTitle => ClubSubscriptionPolicy.titleForPlan(planCode);

  factory SubscriptionAccess.fromJson(Map<String, dynamic> json) {
    final planCode = (json['plan_code'] ?? 'free').toString();

    final activeRaw = json['is_active'] ?? json['active'] ?? json['status'];

    final isActive = ClubSubscriptionPolicy.isStatusActive(activeRaw);

    final premiumRaw = json['is_premium'] ?? json['premium'];

    final isPremium = ClubSubscriptionPolicy.isStatusActive(premiumRaw) ||
        (isActive &&
            ClubSubscriptionPolicy.tierForPlan(planCode) !=
                ClubSubscriptionTier.none);

    final rawFeatures = json['features'];

    return SubscriptionAccess(
      planCode: planCode,
      isActive: isActive,
      isPremium: isPremium,
      expiresAt: (json['expires_at'] ?? json['end_date'] ?? json['valid_until'])
          ?.toString(),
      features: rawFeatures is List
          ? rawFeatures.map((e) => e.toString()).toList()
          : const <String>[],
    );
  }

  factory SubscriptionAccess.free() {
    return const SubscriptionAccess(
      planCode: 'free',
      isActive: true,
      isPremium: false,
      features: <String>[],
    );
  }
}
