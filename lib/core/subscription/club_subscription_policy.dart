enum ClubSubscriptionTier {
  none,
  basic,
  analyticsAi,
  equipment,
}

class ClubSubscriptionPolicy {
  const ClubSubscriptionPolicy._();

  static String normalizePlanCode(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  static ClubSubscriptionTier tierForPlan(String? planCode) {
    final code = normalizePlanCode(planCode);

    switch (code) {
      case 'coach_pro':
      case 'club_basic':
      case 'basic':
      case 'club_base':
        return ClubSubscriptionTier.basic;

      case 'club_pro':
      case 'analytics_ai':
      case 'club_analytics':
      case 'club_ai':
        return ClubSubscriptionTier.analyticsAi;

      case 'full_pro':
      case 'equipment':
      case 'club_full':
      case 'club_equipment':
        return ClubSubscriptionTier.equipment;

      default:
        return ClubSubscriptionTier.none;
    }
  }

  static int rank(ClubSubscriptionTier tier) {
    switch (tier) {
      case ClubSubscriptionTier.none:
        return 0;
      case ClubSubscriptionTier.basic:
        return 1;
      case ClubSubscriptionTier.analyticsAi:
        return 2;
      case ClubSubscriptionTier.equipment:
        return 3;
    }
  }

  static bool atLeast(
    ClubSubscriptionTier current,
    ClubSubscriptionTier required,
  ) {
    return rank(current) >= rank(required);
  }

  static String titleForTier(ClubSubscriptionTier tier) {
    switch (tier) {
      case ClubSubscriptionTier.none:
        return 'Без подписки';
      case ClubSubscriptionTier.basic:
        return 'Базовая';
      case ClubSubscriptionTier.analyticsAi:
        return 'Аналитика + AI';
      case ClubSubscriptionTier.equipment:
        return 'Оборудование';
    }
  }

  static String titleForPlan(String? planCode) {
    return titleForTier(tierForPlan(planCode));
  }

  static ClubSubscriptionTier requiredTierForFeature(String featureCode) {
    switch (featureCode.trim().toLowerCase()) {
      case 'club_basic':
      case 'club_workspace':
      case 'club_training_editor':
      case 'club_plans':
      case 'club_attendance':
      case 'club_testing':
      case 'club_game_zone':
      case 'club_player_diary':
      case 'club_parents':
      case 'club_notifications':
        return ClubSubscriptionTier.basic;

      case 'club_analytics':
      case 'club_ai':
      case 'club_video_analysis':
      case 'club_heatmap':
      case 'club_reports':
      case 'club_ai_recommendations':
      case 'club_manager':
        return ClubSubscriptionTier.analyticsAi;

      case 'club_tracker':
      case 'club_gps':
      case 'club_hardware':
        return ClubSubscriptionTier.equipment;

      default:
        return ClubSubscriptionTier.none;
    }
  }

  static bool hasFeature({
    required String? planCode,
    required bool isActive,
    required String featureCode,
  }) {
    if (!isActive) return false;

    final required = requiredTierForFeature(featureCode);
    if (required == ClubSubscriptionTier.none) return false;

    return atLeast(tierForPlan(planCode), required);
  }

  static int? maxTeams(String? planCode) {
    return tierForPlan(planCode) == ClubSubscriptionTier.basic ? 20 : null;
  }

  static bool isStatusActive(dynamic value) {
    if (value == true) return true;
    if (value is num) return value > 0;

    final text = '${value ?? ''}'.trim().toLowerCase();

    return const <String>{
      '1',
      'true',
      'active',
      'paid',
      'current',
      'trial',
      'trialing',
      'enabled',
    }.contains(text);
  }

  static bool isStatusInactive(dynamic value) {
    if (value == false) return true;

    final text = '${value ?? ''}'.trim().toLowerCase();

    return const <String>{
      '0',
      'false',
      'inactive',
      'expired',
      'cancelled',
      'canceled',
      'blocked',
      'disabled',
    }.contains(text);
  }
}
