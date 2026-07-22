/// Where a scan should land. Shared by the in-app scanner and the deep-link
/// route so both entry points resolve a check-in the same way — the port of the
/// Expo app's src/services/checkInFlow.ts.
library;

import '../data/models/enums.dart';
import '../data/models/visit_result.dart';

sealed class CheckInOutcome {
  const CheckInOutcome();
}

/// The visit was recorded. Carries what the success screen needs.
class CheckInRecorded extends CheckInOutcome {
  const CheckInRecorded({
    required this.shopId,
    required this.streakDays,
    required this.totalVisits,
    required this.newVoucherCount,
  });

  final String shopId;
  final int streakDays;
  final int totalVisits;
  final int newVoucherCount;
}

/// A valid code, but today's visit is already logged. Toast, don't navigate —
/// bouncing to a success screen for a no-op reads as a bug.
class CheckInAlreadyToday extends CheckInOutcome {
  const CheckInAlreadyToday();

  String get message => 'Already checked in today! Come back tomorrow.';
}

/// The code didn't resolve to a partner shop.
class CheckInUnknownShop extends CheckInOutcome {
  const CheckInUnknownShop({required this.qrData, this.extractedName});

  final String qrData;
  final String? extractedName;
}

/// Run a check-in and decide where it goes. [rawData] is the scanned payload,
/// used only to prefill the suggestion form when the shop isn't a partner.
Future<CheckInOutcome> runCheckIn(
  String shopId,
  Future<VisitResult> Function(String shopId) checkIn, {
  String? rawData,
}) async {
  final result = await checkIn(shopId);

  return switch (result.status) {
    CheckInStatus.alreadyVisitedToday => const CheckInAlreadyToday(),
    CheckInStatus.shopNotFound =>
      CheckInUnknownShop(qrData: rawData ?? shopId),
    CheckInStatus.success => CheckInRecorded(
        shopId: shopId,
        streakDays: result.streak?.currentStreakDays ?? 1,
        totalVisits: result.streak?.totalVisits ?? 1,
        newVoucherCount: result.newVouchers.length,
      ),
  };
}
