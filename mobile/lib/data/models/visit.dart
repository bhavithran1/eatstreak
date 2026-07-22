/// One recorded check-in. Server-written, client read-only.
class Visit {
  const Visit({
    required this.id,
    required this.userId,
    required this.shopId,
    required this.timestamp,
    this.shopOwnerId,
    this.userName,
  });

  final String id;
  final String userId;
  final String shopId;

  /// ISO-8601 instant of the check-in.
  final String timestamp;
  final String? shopOwnerId;
  final String? userName;

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        shopId: json['shopId'] as String? ?? '',
        timestamp: json['timestamp'] as String? ?? '',
        shopOwnerId: json['shopOwnerId'] as String?,
        userName: json['userName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'shopId': shopId,
        'timestamp': timestamp,
        if (shopOwnerId != null) 'shopOwnerId': shopOwnerId,
        if (userName != null) 'userName': userName,
      };
}
