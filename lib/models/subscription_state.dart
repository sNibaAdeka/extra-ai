enum PlanTier {
  free('Free', 5, 1, false),
  pro('Pro', 200, 1, true),
  studio('Studio', 500, 5, true),
  // Unlocked only via the AD2011AD promo code. Unlimited everything.
  admin('Admin', 1 << 30, 1 << 30, true);

  const PlanTier(
    this.label,
    this.monthlyAnalysisLimit,
    this.projectLimit,
    this.securityIncluded,
  );

  final String label;
  final int monthlyAnalysisLimit;
  final int projectLimit;
  final bool securityIncluded;

  /// True for tiers with no practical usage ceiling (admin mode).
  bool get isUnlimited => this == PlanTier.admin;

  static PlanTier fromId(String id) => PlanTier.values.firstWhere(
    (tier) => tier.name == id,
    orElse: () => PlanTier.free,
  );
}

class SubscriptionState {
  const SubscriptionState({
    required this.tier,
    required this.usageThisMonth,
    this.renewalDate,
  });

  final PlanTier tier;
  final int usageThisMonth;
  final DateTime? renewalDate;

  int get monthlyLimit => tier.monthlyAnalysisLimit;

  bool get isUnlimited => tier.isUnlimited;

  int get remainingAnalyses {
    final remaining = monthlyLimit - usageThisMonth;
    if (remaining < 0) return 0;
    if (remaining > monthlyLimit) return monthlyLimit;
    return remaining;
  }

  double get usageRatio {
    if (isUnlimited) return 0;
    if (monthlyLimit <= 0) return 0;
    final ratio = usageThisMonth / monthlyLimit;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }

  bool get isLimited => tier == PlanTier.free;

  String get headline => isUnlimited
      ? 'Admin · unlimited analyses'
      : '${tier.label} · $usageThisMonth/$monthlyLimit analyses this month';
}
