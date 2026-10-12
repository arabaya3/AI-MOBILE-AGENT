enum UserRole {
  viewer,
  admin,
  superAdmin;

  static UserRole parse(Object? raw) => switch (raw) {
    'super_admin' => UserRole.superAdmin,
    'admin' => UserRole.admin,
    _ => UserRole.viewer,
  };
}

/// `GET /api/v1/auth/me`.
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.jobTitle,
    this.company,
    this.country,
    this.industry,
    this.preferredLanguage,
    this.emailVerified = false,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
    id: json['id'] as String,
    email: json['email'] as String,
    role: UserRole.parse(json['role']),
    firstName: json['first_name'] as String?,
    lastName: json['last_name'] as String?,
    jobTitle: json['job_title'] as String?,
    company: json['company'] as String?,
    country: json['country'] as String?,
    industry: json['industry'] as String?,
    preferredLanguage: json['preferred_language'] as String?,
    emailVerified: json['email_verified'] as bool? ?? false,
  );

  final String id;
  final String email;
  final UserRole role;
  final String? firstName;
  final String? lastName;
  final String? jobTitle;
  final String? company;
  final String? country;
  final String? industry;
  final String? preferredLanguage;
  final bool emailVerified;

  String? get displayName {
    final name = [
      firstName,
      lastName,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(' ');
    return name.isEmpty ? null : name;
  }
}

/// Fields accepted by `POST /api/v1/auth/signup`. The role is never sent: public sign-up is always `viewer`.
class SignUpData {
  const SignUpData({
    required this.email,
    required this.password,
    this.firstName,
    this.lastName,
    this.company,
    this.jobTitle,
    this.preferredLanguage,
  });

  final String email;
  final String password;
  final String? firstName;
  final String? lastName;
  final String? company;
  final String? jobTitle;
  final String? preferredLanguage;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    if (_present(firstName)) 'first_name': firstName!.trim(),
    if (_present(lastName)) 'last_name': lastName!.trim(),
    if (_present(company)) 'company': company!.trim(),
    if (_present(jobTitle)) 'job_title': jobTitle!.trim(),
    if (_present(preferredLanguage)) 'preferred_language': preferredLanguage,
  };

  static bool _present(String? v) => v != null && v.trim().isNotEmpty;
}
