class AuthResponse {
  final String accessToken;
  final String tokenType;
  final String refreshToken;
  final DateTime expiresAt;
  final User user;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      refreshToken: json['refresh_token'],
      expiresAt: DateTime.parse(json['expires_at']),
      user: User.fromJson(json['user']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "access_token": accessToken,
      "token_type": tokenType,
      "refresh_token": refreshToken,
      "expires_at": expiresAt.toIso8601String(),
      "user": user.toJson(),
    };
  }
}


class User {
  final int userId;
  final String email;
  final String? firstName;
  final String? lastName;

  User({
    required this.userId,
    required this.email,
    this.firstName,
    this.lastName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "user_id": userId,
      "email": email,
      "first_name": firstName,
      "last_name": lastName,
    };
  }
}
