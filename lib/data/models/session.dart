class Session {
  const Session({
    required this.accessToken,
    required this.email,
    required this.role,
  });
  final String accessToken;
  final String email;
  final String role;
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'email': email,
    'role': role,
  };
  factory Session.fromJson(Map<String, dynamic> json) {
    final token = json['accessToken'];
    final email = json['email'];
    final role = json['role'];
    if (token is! String ||
        token.trim().isEmpty ||
        email is! String ||
        role is! String) {
      throw const FormatException('Invalid session.');
    }
    return Session(accessToken: token, email: email, role: role);
  }
}
