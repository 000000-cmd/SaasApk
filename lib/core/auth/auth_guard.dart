import 'package:saas_app/core/auth/auth_models.dart';

/// Gate de acceso del APK. SOLO dueño y empleados. El admin del sistema usa la web.
class AuthGuard {
  AuthGuard._();

  static const Set<UserKind> allowedKinds = {UserKind.owner, UserKind.employee};

  static bool canAccessApp(AppUser? user) =>
      user != null && allowedKinds.contains(user.kind);
}
