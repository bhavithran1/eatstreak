/// A shop's check-in code for one day. The owner shows it at checkout; the
/// server checks the scanned code against the one issued for that shop today,
/// so yesterday's code is dead. Issued and validated by the
/// `createCheckInToken` / `checkIn` callables — see functions/src/index.ts.
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
        // Matches CHECK_IN_TOKEN_TTL_SECONDS in functions/src/checkInToken.ts.
        // Only a cleanup backstop: what makes a code valid is its date, so this
        // fallback never decides whether a scan works.
        ttlSeconds: (json['ttlSeconds'] as num?)?.toInt() ?? 48 * 60 * 60,
      );
}
