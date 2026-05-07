class UserOut {
  const UserOut({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.isEmailVerified,
    required this.isAdmin,
    required this.onboarded,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String? fullName;
  final bool isActive;
  final bool isEmailVerified;
  final bool isAdmin;
  final bool onboarded;
  final DateTime createdAt;

  factory UserOut.fromJson(Map<String, dynamic> json) {
    return UserOut(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      isActive: json['is_active'] as bool,
      isEmailVerified: json['is_email_verified'] as bool,
      isAdmin: (json['is_admin'] as bool?) ?? false,
      onboarded: (json['onboarded'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}
