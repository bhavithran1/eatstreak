import 'enums.dart';
import 'reward_tier.dart';

class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.category,
    required this.emoji,
    required this.description,
    required this.address,
    required this.rewardTiers,
    required this.streakWindowDays,
    required this.createdAt,
    this.sourceQR,
    this.planId,
    this.timeZone,
  });

  final String id;
  final String name;
  final String ownerId;
  final ShopCategory category;
  final String emoji;
  final String description;
  final String address;
  final List<RewardTier> rewardTiers;

  /// How many days may pass between visits before the streak dies.
  final int streakWindowDays;
  final String createdAt;

  /// Raw payload of a third-party QR this shop was created from, if any.
  final String? sourceQR;
  final String? planId;

  /// Day-boundary timezone for streak math; the Cloud Function is authoritative.
  final String? timeZone;

  Shop copyWith({
    String? name,
    String? ownerId,
    ShopCategory? category,
    String? description,
    String? address,
    List<RewardTier>? rewardTiers,
    int? streakWindowDays,
    String? sourceQR,
    String? planId,
  }) =>
      Shop(
        id: id,
        name: name ?? this.name,
        ownerId: ownerId ?? this.ownerId,
        category: category ?? this.category,
        emoji: emoji,
        description: description ?? this.description,
        address: address ?? this.address,
        rewardTiers: rewardTiers ?? this.rewardTiers,
        streakWindowDays: streakWindowDays ?? this.streakWindowDays,
        createdAt: createdAt,
        sourceQR: sourceQR ?? this.sourceQR,
        planId: planId ?? this.planId,
        timeZone: timeZone,
      );

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        ownerId: json['ownerId'] as String? ?? '',
        category: ShopCategory.fromWire(json['category'] as String?),
        emoji: json['emoji'] as String? ?? '',
        description: json['description'] as String? ?? '',
        address: json['address'] as String? ?? '',
        rewardTiers: (json['rewardTiers'] as List<dynamic>? ?? const [])
            .map((t) => RewardTier.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
        streakWindowDays: (json['streakWindowDays'] as num?)?.toInt() ?? 3,
        createdAt: json['createdAt'] as String? ?? '',
        sourceQR: json['sourceQR'] as String?,
        planId: json['planId'] as String?,
        timeZone: json['timeZone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'category': category.wire,
        'emoji': emoji,
        'description': description,
        'address': address,
        'rewardTiers': rewardTiers.map((t) => t.toJson()).toList(),
        'streakWindowDays': streakWindowDays,
        'createdAt': createdAt,
        if (sourceQR != null) 'sourceQR': sourceQR,
        if (planId != null) 'planId': planId,
        if (timeZone != null) 'timeZone': timeZone,
      };
}
