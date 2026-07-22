import 'enums.dart';
import 'shop.dart';
import 'streak.dart';
import 'visit.dart';
import 'voucher.dart';

/// What a check-in produced. Mirrors the `checkIn` callable's return shape, so
/// the demo and Firestore repositories are interchangeable at the call site.
class VisitResult {
  const VisitResult({
    required this.status,
    this.streak,
    this.visit,
    this.newVouchers = const [],
    this.shop,
  });

  final CheckInStatus status;
  final Streak? streak;
  final Visit? visit;
  final List<Voucher> newVouchers;
  final Shop? shop;

  bool get isSuccess => status == CheckInStatus.success;

  factory VisitResult.fromJson(Map<String, dynamic> json) => VisitResult(
        status: CheckInStatus.fromWire(json['status'] as String?),
        streak: json['streak'] == null
            ? null
            : Streak.fromJson(Map<String, dynamic>.from(json['streak'] as Map)),
        visit: json['visit'] == null
            ? null
            : Visit.fromJson(Map<String, dynamic>.from(json['visit'] as Map)),
        newVouchers: (json['newVouchers'] as List<dynamic>? ?? const [])
            .map((v) => Voucher.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(),
        shop: json['shop'] == null
            ? null
            : Shop.fromJson(Map<String, dynamic>.from(json['shop'] as Map)),
      );
}
