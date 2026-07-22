/// A user's running streak at one shop. Written only by the `checkIn` Cloud
/// Function — the client reads these, never writes them (Firestore rules deny it).
class Streak {
  const Streak({
    required this.id,
    required this.userId,
    required this.shopId,
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.totalVisits,
    required this.lastVisitDate,
    required this.streakStartDate,
    required this.isStreakAlive,
    this.shopOwnerId,
    this.userName,
  });

  final String id;
  final String userId;
  final String shopId;
  final int currentStreakDays;
  final int longestStreakDays;
  final int totalVisits;

  /// yyyy-MM-dd in the shop's timezone.
  final String lastVisitDate;
  final String streakStartDate;
  final bool isStreakAlive;

  /// Denormalized by the backend so owners can query without cross-user reads.
  final String? shopOwnerId;
  final String? userName;

  Streak copyWith({
    int? currentStreakDays,
    int? longestStreakDays,
    int? totalVisits,
    String? lastVisitDate,
    String? streakStartDate,
    bool? isStreakAlive,
    String? shopOwnerId,
    String? userName,
  }) =>
      Streak(
        id: id,
        userId: userId,
        shopId: shopId,
        currentStreakDays: currentStreakDays ?? this.currentStreakDays,
        longestStreakDays: longestStreakDays ?? this.longestStreakDays,
        totalVisits: totalVisits ?? this.totalVisits,
        lastVisitDate: lastVisitDate ?? this.lastVisitDate,
        streakStartDate: streakStartDate ?? this.streakStartDate,
        isStreakAlive: isStreakAlive ?? this.isStreakAlive,
        shopOwnerId: shopOwnerId ?? this.shopOwnerId,
        userName: userName ?? this.userName,
      );

  factory Streak.fromJson(Map<String, dynamic> json) => Streak(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        shopId: json['shopId'] as String? ?? '',
        currentStreakDays: (json['currentStreakDays'] as num?)?.toInt() ?? 0,
        longestStreakDays: (json['longestStreakDays'] as num?)?.toInt() ?? 0,
        totalVisits: (json['totalVisits'] as num?)?.toInt() ?? 0,
        lastVisitDate: json['lastVisitDate'] as String? ?? '',
        streakStartDate: json['streakStartDate'] as String? ?? '',
        isStreakAlive: json['isStreakAlive'] as bool? ?? false,
        shopOwnerId: json['shopOwnerId'] as String?,
        userName: json['userName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'shopId': shopId,
        'currentStreakDays': currentStreakDays,
        'longestStreakDays': longestStreakDays,
        'totalVisits': totalVisits,
        'lastVisitDate': lastVisitDate,
        'streakStartDate': streakStartDate,
        'isStreakAlive': isStreakAlive,
        if (shopOwnerId != null) 'shopOwnerId': shopOwnerId,
        if (userName != null) 'userName': userName,
      };
}
