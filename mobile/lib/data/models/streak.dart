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
    this.brokenStreakDays = 0,
    this.brokenOn = '',
    this.brokenStartDate = '',
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

  /// What the last break cost, recorded when the streak reset. Lets a customer
  /// repair a streak even after they have already visited again — otherwise
  /// turning up at the shop would destroy the evidence of what they lost.
  final int brokenStreakDays;
  final String brokenOn;
  final String brokenStartDate;

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
    int? brokenStreakDays,
    String? brokenOn,
    String? brokenStartDate,
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
        brokenStreakDays: brokenStreakDays ?? this.brokenStreakDays,
        brokenOn: brokenOn ?? this.brokenOn,
        brokenStartDate: brokenStartDate ?? this.brokenStartDate,
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
        brokenStreakDays: (json['brokenStreakDays'] as num?)?.toInt() ?? 0,
        brokenOn: json['brokenOn'] as String? ?? '',
        brokenStartDate: json['brokenStartDate'] as String? ?? '',
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
        'brokenStreakDays': brokenStreakDays,
        'brokenOn': brokenOn,
        'brokenStartDate': brokenStartDate,
        if (shopOwnerId != null) 'shopOwnerId': shopOwnerId,
        if (userName != null) 'userName': userName,
      };
}
