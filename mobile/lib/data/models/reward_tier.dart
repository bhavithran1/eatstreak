import 'enums.dart';

/// One rung of a shop's reward ladder. Crossing its threshold mints a voucher.
class RewardTier {
  const RewardTier({
    required this.id,
    required this.shopId,
    required this.type,
    required this.threshold,
    required this.discountPercent,
    required this.label,
    required this.description,
    required this.emoji,
  });

  final String id;
  final String shopId;
  final RewardType type;
  final int threshold;
  final int discountPercent;
  final String label;
  final String description;
  final String emoji;

  RewardTier copyWith({
    int? threshold,
    int? discountPercent,
    String? label,
    String? description,
  }) =>
      RewardTier(
        id: id,
        shopId: shopId,
        type: type,
        threshold: threshold ?? this.threshold,
        discountPercent: discountPercent ?? this.discountPercent,
        label: label ?? this.label,
        description: description ?? this.description,
        emoji: emoji,
      );

  /// Value equality, so the rewards editor can tell a real edit from a rebuild.
  @override
  bool operator ==(Object other) =>
      other is RewardTier &&
      other.id == id &&
      other.type == type &&
      other.threshold == threshold &&
      other.discountPercent == discountPercent &&
      other.label == label &&
      other.description == description;

  @override
  int get hashCode =>
      Object.hash(id, type, threshold, discountPercent, label, description);

  factory RewardTier.fromJson(Map<String, dynamic> json) => RewardTier(
        id: json['id'] as String,
        shopId: json['shopId'] as String? ?? '',
        type: RewardType.fromWire(json['type'] as String?),
        threshold: (json['threshold'] as num?)?.toInt() ?? 0,
        discountPercent: (json['discountPercent'] as num?)?.toInt() ?? 0,
        label: json['label'] as String? ?? '',
        description: json['description'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'shopId': shopId,
        'type': type.wire,
        'threshold': threshold,
        'discountPercent': discountPercent,
        'label': label,
        'description': description,
        'emoji': emoji,
      };
}
