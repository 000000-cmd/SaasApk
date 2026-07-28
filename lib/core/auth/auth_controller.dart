import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/auth/auth_guard.dart';
import 'package:saas_app/core/auth/auth_models.dart';
import 'package:saas_app/core/auth/auth_repository.dart';
import 'package:saas_app/core/auth/biometric_service.dart';
import 'package:saas_app/core/network/api_client.dart';
import 'package:saas_app/core/storage/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((_) => const TokenStorage());

final biometricServiceProvider = Provider<BiometricService>((_) => BiometricService());

final apiClientProvider = Provider<ApiClient>((ref) {
  final TokenStorage storage = ref.watch(tokenStorageProvider);
  return ApiClient(
    storage: storage,
    onSessionExpired: () => ref.read(authControllerProvider.notifier).onSessionExpired(),
  );
});

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthState {
  final AppUser? user;
  final bool initializing;
  final bool loading;
  final String? error;

  /// El empleado en su primer ingreso debe completar sus datos antes de operar.
  final bool needsOnboarding;

  /// Sesión guardada a la espera de la huella (usuario con biometría activa).
  final AppUser? lockedUser;

  /// Tras un login con contraseña, ofrecer habilitar el ingreso con huella.
  final bool offerBiometrics;

  const AuthState({
    this.user,
    this.initializing = false,
    this.loading = false,
    this.error,
    this.needsOnboarding = false,
    this.lockedUser,
    this.offerBiometrics = false,
  });

  bool get isAuthenticated => AuthGuard.canAccessApp(user);

  /// Hay sesión guardada pero bloqueada por biometría (mostrar botón de huella).
  bool get biometricLocked => user == null && lockedUser != null;

  AuthState copyWith({
    bool? loading,
    String? error,
    bool? needsOnboarding,
    bool? offerBiometrics,
  }) =>
      AuthState(
        user: user,
        initializing: initializing,
        loading: loading ?? this.loading,
        error: error,
        needsOnboarding: needsOnboarding ?? this.needsOnboarding,
        lockedUser: lockedUser,
        offerBiometrics: offerBiometrics ?? this.offerBiometrics,
      );
}

class AuthController extends Notifier<AuthState> {
  TokenStorage get _storage => ref.read(tokenStorageProvider);
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  BiometricService get _biometrics => ref.read(biometricServiceProvider);

  @override
  AuthState build() {
    _restore();
    return const AuthState(initializing: true);
  }

  Future<void> _restore() async {
    final String? token = await _storage.accessToken();
    final String? userJson = await _storage.userJson();
    if (token == null || userJson == null) {
      state = const AuthState();
      return;
    }
    final AppUser user = AppUser.decode(userJson);
    // Con huella activa la sesión queda bloqueada hasta validar biometría.
    if (await _storage.isBiometricEnabled(user.id)) {
      state = AuthState(lockedUser: user);
    } else {
      state = AuthState(user: user, needsOnboarding: await _needsOnboarding(user));
    }
  }

  /// El empleado debe completar su perfil en el primer ingreso (flag local por
  /// ahora; migrará a un campo del back que el dueño dispara al crear la cuenta).
  Future<bool> _needsOnboarding(AppUser user) async {
    if (user.kind != UserKind.employee) return false;
    return !(await _storage.isOnboardingDone(user.id));
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true);
    try {
      final LoginResult r = await _repo.login(email: email.trim(), password: password);
      if (!AuthGuard.canAccessApp(r.user)) {
        await _storage.clear();
        state = const AuthState(error: 'Esta cuenta no tiene acceso a la app. Usa la plataforma web.');
        return false;
      }
      await _storage.save(
        access: r.tokens.accessToken,
        refresh: r.tokens.refreshToken,
        userJson: r.user.encode(),
      );
      state = AuthState(
        user: r.user,
        needsOnboarding: await _needsOnboarding(r.user),
        offerBiometrics: await _shouldOfferBiometrics(r.user),
      );
      return true;
    } on DioException catch (e) {
      state = AuthState(error: _errorMessage(e));
      return false;
    } catch (_) {
      state = const AuthState(error: 'No se pudo iniciar sesión. Intenta de nuevo.');
      return false;
    }
  }

  // ---------------- Huella ----------------

  Future<bool> _shouldOfferBiometrics(AppUser user) async {
    if (await _storage.wasBiometricPrompted(user.id)) return false;
    return _biometrics.isSupported();
  }

  /// Desbloquea la sesión guardada validando la huella en el dispositivo.
  Future<bool> unlockWithBiometrics() async {
    final AppUser? user = state.lockedUser;
    if (user == null) return false;
    final bool ok = await _biometrics.authenticate('Ingresa con tu huella');
    if (!ok) return false;
    state = AuthState(user: user, needsOnboarding: await _needsOnboarding(user));
    return true;
  }

  /// Renuncia al desbloqueo por huella y cae al formulario de siempre.
  ///
  /// Es la salida de emergencia de la pantalla de bienvenida: la huella puede
  /// fallar (dedo mojado, sensor sucio) o el teléfono puede pasar de mano. No
  /// se borra nada guardado — el próximo ingreso con credenciales reemplaza la
  /// sesión, y si el usuario cambia de idea puede volver a abrir la app.
  void useCredentialsInstead() {
    state = const AuthState();
  }

  /// Habilita el ingreso con huella: valida una vez la biometría, persiste el
  /// consentimiento local y lo registra en el back (tolerante a fallos).
  Future<bool> enableBiometrics() async {
    final AppUser? user = state.user;
    if (user == null) return false;
    final bool ok = await _biometrics.authenticate('Confirma tu huella para habilitar el ingreso');
    await _storage.setBiometricPrompted(user.id);
    if (!ok) {
      state = state.copyWith(offerBiometrics: false);
      return false;
    }
    await _storage.setBiometricEnabled(user.id, true);
    state = state.copyWith(offerBiometrics: false);
    try {
      await _repo.syncBiometric(userId: user.id, enabled: true);
    } catch (_) {
      // Sin red o sin persona vinculada: el flag local manda; se reintenta luego.
    }
    return true;
  }

  /// "Ahora no": no volver a ofrecer en próximos ingresos.
  Future<void> declineBiometrics() async {
    final AppUser? user = state.user;
    if (user != null) await _storage.setBiometricPrompted(user.id);
    state = state.copyWith(offerBiometrics: false);
  }

  Future<void> disableBiometrics() async {
    final AppUser? user = state.user;
    if (user == null) return;
    await _storage.setBiometricEnabled(user.id, false);
    state = state.copyWith();
    try {
      await _repo.syncBiometric(userId: user.id, enabled: false);
    } catch (_) {/* tolerante */}
  }

  Future<bool> isBiometricEnabledForCurrentUser() async {
    final AppUser? user = state.user;
    if (user == null) return false;
    return _storage.isBiometricEnabled(user.id);
  }

  // ---------------- Sesión ----------------

  /// Marca el onboarding del empleado como completado (persistente por usuario).
  /// TODO(back): además enviar los datos capturados al backend del empleado.
  Future<void> completeOnboarding() async {
    final AppUser? user = state.user;
    if (user == null) return;
    await _storage.setOnboardingDone(user.id);
    state = state.copyWith(needsOnboarding: false);
  }

  /// Mostrar el tour de bienvenida SOLO si el registro del usuario trae el
  /// indicador de primer ingreso en 1 (app_user.IsFirstLogin). En 0 no se
  /// muestra. Es del servidor a propósito: el indicador local anterior hacía
  /// reaparecer el tour al reinstalar la app o al entrar desde otro teléfono.
  bool shouldShowWelcome() => state.user?.isFirstLogin == true;

  /// Apaga el indicador en el registro y refleja el cambio en la sesión local
  /// para que el tour no reaparezca aunque el PATCH tarde.
  Future<void> markWelcomeShown() async {
    final AppUser? user = state.user;
    if (user == null || !user.isFirstLogin) return;

    _setUser(user.copyWith(isFirstLogin: false));
    try {
      await _repo.markWelcomeSeen();
    } catch (_) {
      // Si el PATCH falla, el indicador sigue en 1 en el servidor y el tour
      // volverá en el próximo ingreso. Es preferible a bloquear al usuario.
    }
  }

  /// Reemplaza el usuario en memoria y en el almacenamiento de sesión.
  void _setUser(AppUser user) {
    state = AuthState(
      user: user,
      initializing: state.initializing,
      loading: state.loading,
      needsOnboarding: state.needsOnboarding,
      lockedUser: state.lockedUser,
      offerBiometrics: state.offerBiometrics,
    );
    _storage.saveUser(user.encode());
  }

  Future<void> logout() async {
    await _storage.clear();
    state = const AuthState();
  }

  void onSessionExpired() {
    state = const AuthState(error: 'Tu sesión expiró. Inicia sesión de nuevo.');
  }

  String _errorMessage(DioException e) {
    final dynamic data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.response?.statusCode == 401) return 'Credenciales inválidas.';
    return 'No se pudo conectar. Revisa tu conexión.';
  }
}
