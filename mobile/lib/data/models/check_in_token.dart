/// A short-lived, single-use check-in code the owner's device mints at payment
/// time. The customer scans it once; the server marks it used, so a screenshot
/// can't be replayed and a saved code can't be used from home. Minted and
/// validated by the `createCheckInToken` / `checkIn` callables — see
/// functions/src/index.ts.
class CheckInToken {
  const CheckInToken({
    required this.token,
    required this.shopId,
    required this.expiresAt,
    required this.ttlSeconds,
  });

  final String token;
  final String shopId;
  final DateTime expiresAt;
  final int ttlSeconds;

  factory CheckInToken.fromJson(Map<String, dynamic> json) => CheckInToken(
        token: json['token'] as String,
        shopId: json['shopId'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        ttlSeconds: (json['ttlSeconds'] as num?)?.toInt() ?? 90,
      );
}
