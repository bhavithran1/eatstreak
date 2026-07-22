/// Shared enums. Each carries the exact wire string used by Firestore and the
/// Cloud Functions, so documents written by the Expo app stay readable here.
library;

enum UserRole {
  customer('customer'),
  owner('owner');

  const UserRole(this.wire);
  final String wire;

  static UserRole fromWire(String? value) =>
      values.firstWhere((r) => r.wire == value, orElse: () => UserRole.customer);
}

enum ShopCategory {
  coffee('coffee'),
  ramen('ramen'),
  pizza('pizza'),
  bistro('bistro'),
  bakery('bakery'),
  smoothie('smoothie'),
  brunch('brunch'),
  mexican('mexican'),
  other('other');

  const ShopCategory(this.wire);
  final String wire;

  static ShopCategory fromWire(String? value) =>
      values.firstWhere((c) => c.wire == value, orElse: () => ShopCategory.other);
}

/// What a reward tier measures: lifetime visits, or consecutive-streak days.
enum RewardType {
  visitCount('visit_count'),
  streakDays('streak_days');

  const RewardType(this.wire);
  final String wire;

  static RewardType fromWire(String? value) =>
      values.firstWhere((t) => t.wire == value, orElse: () => RewardType.visitCount);
}

/// How close a streak is to expiring, derived from the shop's return window.
enum StreakUrgency { safe, warning, critical, dead }

enum CheckInStatus {
  success('success'),
  alreadyVisitedToday('already_visited_today'),
  shopNotFound('shop_not_found');

  const CheckInStatus(this.wire);
  final String wire;

  static CheckInStatus fromWire(String? value) =>
      values.firstWhere((s) => s.wire == value, orElse: () => CheckInStatus.shopNotFound);
}
