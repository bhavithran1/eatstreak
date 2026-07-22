import 'enums.dart';

/// An earned discount. Minted and redeemed server-side; the deterministic id
/// `{uid}_{tierId}` is what makes minting idempotent (one voucher per tier ever).
class Voucher {
  const Voucher({
    required this.id,
    required this.userId,
    required this.shopId,
    required this.shopName,
    required this.shopEmoji,
    required this.tierId,
    required this.type,
    required this.discountPercent,
    required this.tierLabel,
    required this.earnedAt,
    required this.expiresAt,
    required this.isRedeemed,
    required this.code,
    this.redeemedAt,
    this.shopOwnerId,
  });

  final String id;
  final String userId;
  final String shopId;
  final String shopName;
  final String shopEmoji;
  final String tierId;
  final RewardType type;
  final int discountPercent;
  final String tierLabel;
  final String earnedAt;
  final String expiresAt;
  final bool isRedeemed;

  /// EAT-XXXX, shown to staff at redemption.
  final String code;
  final String? redeemedAt;
  final String? shopOwnerId;

  Voucher copyWith({bool? isRedeemed, String? redeemedAt}) => Voucher(
        id: id,
        userId: userId,
        shopId: shopId,
        shopName: shopName,
        shopEmoji: shopEmoji,
        tierId: tierId,
        type: type,
        discountPercent: discountPercent,
        tierLabel: tierLabel,
        earnedAt: earnedAt,
        expiresAt: expiresAt,
        isRedeemed: isRedeemed ?? this.isRedeemed,
        code: code,
        redeemedAt: redeemedAt ?? this.redeemedAt,
        shopOwnerId: shopOwnerId,
      );

  factory Voucher.fromJson(Map<String, dynamic> json) => Voucher(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        shopId: json['shopId'] as String? ?? '',
        shopName: json['shopName'] as String? ?? '',
        shopEmoji: json['shopEmoji'] as String? ?? '',
        tierId: json['tierId'] as String? ?? '',
        type: RewardType.fromWire(json['type'] as String?),
        discountPercent: (json['discountPercent'] as num?)?.toInt() ?? 0,
        tierLabel: json['tierLabel'] as String? ?? '',
        earnedAt: json['earnedAt'] as String? ?? '',
        expiresAt: json['expiresAt'] as String? ?? '',
        isRedeemed: json['isRedeemed'] as bool? ?? false,
        code: json['code'] as String? ?? '',
        redeemedAt: json['redeemedAt'] as String?,
        shopOwnerId: json['shopOwnerId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'shopId': shopId,
        'shopName': shopName,
        'shopEmoji': shopEmoji,
        'tierId': tierId,
        'type': type.wire,
        'discountPercent': discountPercent,
        'tierLabel': tierLabel,
        'earnedAt': earnedAt,
        'expiresAt': expiresAt,
        'isRedeemed': isRedeemed,
        'code': code,
        'redeemedAt': redeemedAt,
        if (shopOwnerId != null) 'shopOwnerId': shopOwnerId,
      };
}
