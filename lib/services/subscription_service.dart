import 'package:hive/hive.dart';

import '../models/subscription_state.dart';

/// Outcome of attempting to redeem a promo code.
class PromoRedemption {
  const PromoRedemption({required this.accepted, this.tier, this.message});

  final bool accepted;
  final PlanTier? tier;
  final String? message;

  static const PromoRedemption invalid = PromoRedemption(
    accepted: false,
    message: "That code isn't valid.",
  );
}

/// Known promo codes. Kept in one place so the gateway and any tests agree.
class PromoCodes {
  PromoCodes._();

  /// Unlocks unlimited admin mode.
  static const String adminUnlimited = 'AD2011AD';

  /// Normalizes user input (trim + uppercase) before matching.
  static String normalize(String raw) => raw.trim().toUpperCase();

  static PlanTier? tierFor(String raw) {
    switch (normalize(raw)) {
      case adminUnlimited:
        return PlanTier.admin;
      default:
        return null;
    }
  }
}

abstract class SubscriptionGateway {
  SubscriptionState current({required int usageThisMonth});
  Future<void> selectPlan(PlanTier tier);

  /// Validates a promo code and, if valid, switches to the granted tier.
  Future<PromoRedemption> redeemPromoCode(String code);
}

/// Local billing adapter for the MVP. The UI and AppState depend on the
/// gateway contract, so a Stripe/Supabase adapter can replace this without
/// changing product surfaces.
class LocalSubscriptionService implements SubscriptionGateway {
  LocalSubscriptionService(this._box);

  static const String boxName = 'subscription_state';
  static const String _tierKey = 'tier';

  final Box _box;

  @override
  SubscriptionState current({required int usageThisMonth}) {
    final tier = PlanTier.fromId(_box.get(_tierKey, defaultValue: 'free'));
    return SubscriptionState(
      tier: tier,
      usageThisMonth: usageThisMonth,
      renewalDate: _nextMonth(),
    );
  }

  @override
  Future<void> selectPlan(PlanTier tier) => _box.put(_tierKey, tier.name);

  @override
  Future<PromoRedemption> redeemPromoCode(String code) async {
    final tier = PromoCodes.tierFor(code);
    if (tier == null) return PromoRedemption.invalid;
    await selectPlan(tier);
    return PromoRedemption(
      accepted: true,
      tier: tier,
      message: 'Admin mode unlocked — unlimited analyses.',
    );
  }

  static DateTime _nextMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
  }
}

class InMemorySubscriptionService implements SubscriptionGateway {
  InMemorySubscriptionService([this.tier = PlanTier.free]);

  PlanTier tier;

  @override
  SubscriptionState current({required int usageThisMonth}) =>
      SubscriptionState(tier: tier, usageThisMonth: usageThisMonth);

  @override
  Future<void> selectPlan(PlanTier tier) async {
    this.tier = tier;
  }

  @override
  Future<PromoRedemption> redeemPromoCode(String code) async {
    final granted = PromoCodes.tierFor(code);
    if (granted == null) return PromoRedemption.invalid;
    tier = granted;
    return PromoRedemption(
      accepted: true,
      tier: granted,
      message: 'Admin mode unlocked — unlimited analyses.',
    );
  }
}
