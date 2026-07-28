import 'dart:convert';

/// Tipo de usuario derivado de sus roles. El APK SOLO admite [owner] y [employee].
enum UserKind { owner, employee, systemAdmin, unknown }

class AppUser {
  final String id;
  final String username;
  final String? email;
  final String? fullName;
  final List<String> roles;
  final UserKind kind;

  /// Indicador del REGISTRO (app_user.IsFirstLogin): true = aún no ha visto la
  /// bienvenida. Es del servidor, no del dispositivo: así el tour no reaparece
  /// al reinstalar la app ni al entrar desde otro teléfono.
  final bool isFirstLogin;

  const AppUser({
    required this.id,
    required this.username,
    this.email,
    this.fullName,
    required this.roles,
    required this.kind,
    this.isFirstLogin = false,
  });

  AppUser copyWith({bool? isFirstLogin}) => AppUser(
        id: id,
        username: username,
        email: email,
        fullName: fullName,
        roles: roles,
        kind: kind,
        isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      );

  factory AppUser.fromJson(Map<String, dynamic> j) {
    final List<String> roles =
        ((j['roleCodes'] ?? j['roles'] ?? const <dynamic>[]) as List).map((e) => e.toString()).toList();
    final String full = (j['fullName'] as String?) ??
        [j['firstName'], j['lastName']].where((e) => e != null && '$e'.isNotEmpty).join(' ');
    return AppUser(
      id: j['id'].toString(),
      username: (j['username'] ?? '').toString(),
      email: j['email'] as String?,
      fullName: full.isEmpty ? null : full,
      roles: roles,
      kind: kindFromRoles(roles),
      isFirstLogin: j['isFirstLogin'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'fullName': fullName,
        'roleCodes': roles,
        'isFirstLogin': isFirstLogin,
      };

  String encode() => jsonEncode(toJson());
  static AppUser decode(String s) => AppUser.fromJson(jsonDecode(s) as Map<String, dynamic>);

  static UserKind kindFromRoles(List<String> roles) {
    const Set<String> adminRoles = {'ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'};
    if (roles.any(adminRoles.contains)) return UserKind.systemAdmin;
    if (roles.contains('OWNER')) return UserKind.owner;
    if (roles.contains('EMPLOYEE')) return UserKind.employee;
    return UserKind.unknown;
  }
}

class TokenPair {
  final String accessToken;
  final String refreshToken;
  const TokenPair({required this.accessToken, required this.refreshToken});

  factory TokenPair.fromJson(Map<String, dynamic> j) => TokenPair(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
      );
}

class LoginResult {
  final TokenPair tokens;
  final AppUser user;
  const LoginResult({required this.tokens, required this.user});

  factory LoginResult.fromJson(Map<String, dynamic> j) => LoginResult(
        tokens: TokenPair.fromJson(j['tokens'] as Map<String, dynamic>),
        user: AppUser.fromJson(j['user'] as Map<String, dynamic>),
      );
}
