class User {
  final int id;
  final String email;
  final String nickname;
  final int pointsBalance;
  final int dailyPoints;
  final bool isBanned;
  final DateTime? bannedUntil;
  final bool oobeCompleted;

  User({
    required this.id,
    required this.email,
    required this.nickname,
    required this.pointsBalance,
    required this.dailyPoints,
    required this.isBanned,
    this.bannedUntil,
    required this.oobeCompleted,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      pointsBalance: json['points_balance'] as int? ?? 0,
      dailyPoints: json['daily_points'] as int? ?? 0,
      isBanned: json['is_banned'] as bool? ?? false,
      bannedUntil: json['banned_until'] != null
          ? DateTime.tryParse(json['banned_until'] as String)
          : null,
      oobeCompleted: json['oobe_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'points_balance': pointsBalance,
      'daily_points': dailyPoints,
      'is_banned': isBanned,
      'banned_until': bannedUntil?.toIso8601String(),
      'oobe_completed': oobeCompleted,
    };
  }

  User copyWith({bool? oobeCompleted}) {
    return User(
      id: id,
      email: email,
      nickname: nickname,
      pointsBalance: pointsBalance,
      dailyPoints: dailyPoints,
      isBanned: isBanned,
      bannedUntil: bannedUntil,
      oobeCompleted: oobeCompleted ?? this.oobeCompleted,
    );
  }
}
