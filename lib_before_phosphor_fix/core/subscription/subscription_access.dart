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
    return features.contains(featureCode);
  }

  factory SubscriptionAccess.fromJson(Map<String, dynamic> json) {
    return SubscriptionAccess(
      planCode: (json['plan_code'] ?? 'free').toString(),
      isActive: json['is_active'] == true,
      isPremium: json['is_premium'] == true,
      expiresAt: json['expires_at']?.toString(),
      features: (json['features'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  factory SubscriptionAccess.free() {
    return const SubscriptionAccess(
      planCode: 'free',
      isActive: true,
      isPremium: false,
      features: [],
    );
  }
}