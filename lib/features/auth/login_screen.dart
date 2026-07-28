import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/config/app_info.dart';
import 'package:saas_app/shared/widgets/app_button.dart';
import 'package:saas_app/shared/widgets/app_text_field.dart';
import 'package:saas_app/shared/widgets/orb_mascot.dart';

/// Login del APK — la ÚNICA puerta de entrada (las cuentas las crea el dueño
/// desde la web, aquí no hay registro).
///
/// Sigue la pantalla "Inicio de Sesión" del sistema Luminous Aura: fondo claro
/// con auras moradas difusas, el ORB flotando como identidad de marca, y las
/// credenciales dentro de una tarjeta de CRISTAL (blanco translúcido + blur).
/// La navegación post-login la maneja el redirect del router.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final OrbMascotController _mascot = OrbMascotController();
  bool _obscure = true;
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_syncTyping);
    _passwordFocus.addListener(_syncTyping);
    // El prompt de huella ya NO se dispara aquí: con sesión guardada el router
    // manda a /unlock, que saluda primero y pide la huella cuando el usuario
    // la pide. Abrir la app y encontrarse el lector del sistema encima de un
    // formulario que no venías a usar era desconcertante.
  }

  /// La mascota "escribe" mientras algún campo tenga el foco (estándar web).
  void _syncTyping() {
    final bool typing = _emailFocus.hasFocus || _passwordFocus.hasFocus;
    if (typing != _typing) setState(() => _typing = typing);
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final bool ok =
        await ref.read(authControllerProvider.notifier).login(_email.text, _password.text);
    if (ok) _mascot.celebrate();
  }

  @override
  Widget build(BuildContext context) {
    // Credenciales inválidas u otro fallo: la mascota reacciona con desánimo.
    ref.listen(authControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) _mascot.reject();
    });
    final AuthState auth = ref.watch(authControllerProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // El teclado empuja/encoge la hoja para que el campo enfocado suba.
      resizeToAvoidBottomInset: true,
      body: _LuminousAura(
        child: LayoutBuilder(
        builder: (context, constraints) {
          // ORB responsivo: grande en teléfonos, acotado en pantallas pequeñas
          // para que el formulario SIEMPRE quede visible (no fuera de pantalla).
          final double orbSize = (constraints.maxHeight * 0.20).clamp(104.0, 168.0);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- Identidad: el ORB es la marca ----
                  Center(
                    child: OrbMascot(
                      size: orbSize,
                      halo: true,
                      typing: _typing,
                      loading: auth.loading,
                      controller: _mascot,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppInfo.appName,
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineLg(color: scheme.primary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    // El saludo de vuelta vive ahora en /unlock; aquí siempre
                    // es la entrada normal.
                    'Cada servicio suma',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLg(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ---- Tarjeta de cristal con las credenciales ----
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          AppTextField(
                            label: 'Correo, usuario o documento',
                            hint: 'tu@correo.com · usuario · nº documento',
                            controller: _email,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            label: 'Contraseña',
                            hint: '••••••••',
                            controller: _password,
                            focusNode: _passwordFocus,
                            obscure: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          if (auth.error != null)
                            Container(
                              margin: const EdgeInsets.only(top: AppSpacing.lg),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg, vertical: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                              child: Text(
                                auth.error!,
                                style: AppTypography.bodySm(color: scheme.onErrorContainer),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.xl),
                          AppButton(
                            label: 'Entrar',
                            size: AppButtonSize.lg,
                            icon: Icons.arrow_forward_rounded,
                            loading: auth.loading,
                            expanded: true,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    '¿Sin cuenta? Tu empleador te la crea desde la plataforma.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Versión ${AppInfo.version}',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSm(color: scheme.outline),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}

/// Fondo del sistema: lienzo claro con dos auras moradas muy difusas en
/// esquinas opuestas. Es lo que da el nombre a "Luminous Aura".
class _LuminousAura extends StatelessWidget {
  const _LuminousAura({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -100,
          child: _AuraBlob(size: 320, color: AppColors.primary.withValues(alpha: 0.10)),
        ),
        Positioned(
          bottom: -140,
          left: -120,
          child: _AuraBlob(size: 300, color: AppColors.primaryContainer.withValues(alpha: 0.10)),
        ),
        child,
      ],
    );
  }
}

class _AuraBlob extends StatelessWidget {
  const _AuraBlob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Tarjeta de cristal: blanco translúcido + desenfoque, esquinas de 32px y
/// sombra luminosa. Es el contenedor de trabajo del sistema.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            boxShadow: AppElevation.raised,
          ),
          child: child,
        ),
      ),
    );
  }
}
