import 'package:flutter_test/flutter_test.dart';

import 'package:extra_ai/models/subscription_state.dart';
import 'package:extra_ai/services/subscription_service.dart';

void main() {
  group('SubscriptionState', () {
    test('calculates remaining analyses and usage ratio', () {
      const state = SubscriptionState(tier: PlanTier.free, usageThisMonth: 3);

      expect(state.monthlyLimit, 5);
      expect(state.remainingAnalyses, 2);
      expect(state.usageRatio, closeTo(0.6, 0.001));
      expect(state.headline, 'Free · 3/5 analyses this month');
    });

    test('clamps over-limit usage', () {
      const state = SubscriptionState(tier: PlanTier.free, usageThisMonth: 12);

      expect(state.remainingAnalyses, 0);
      expect(state.usageRatio, 1);
    });
  });

  group('InMemorySubscriptionService', () {
    test('changes plan without touching UI code', () async {
      final service = InMemorySubscriptionService();

      expect(service.current(usageThisMonth: 1).tier, PlanTier.free);
      await service.selectPlan(PlanTier.pro);

      final state = service.current(usageThisMonth: 7);
      expect(state.tier, PlanTier.pro);
      expect(state.remainingAnalyses, 193);
    });
  });
}
