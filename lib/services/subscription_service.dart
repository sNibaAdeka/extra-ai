import 'package:hive/hive.dart';

import '../models/subscription_state.dart';

abstract class SubscriptionGateway {
  SubscriptionState current({required int usageThisMonth});
  Future<void> selectPlan(PlanTier tier);
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
}
