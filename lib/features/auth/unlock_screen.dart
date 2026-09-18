import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/shared/widgets/fingerprint_button.dart';
import 'package:saas_app/shared/widgets/orb_mascot.dart';

/// PANTALLA DE RECURRENCIA: volver a entrar cuando ya hay sesión guardada.
///
/// Es la puerta de quien ya vive aquí, no un formulario de acceso. Por eso el
/// lector de huella se dispara SOLO al abrirla: con la biometría vinculada, la
/// app se abre con el dedo puesto y ya, sin un toque intermedio que no aporta
/// nada.
///
/// (Antes no se disparaba solo, y con razón: el prompt del sistema salía encima
/// del formulario de credenciales, que no era lo que venías a usar, y al
/// cancelarlo te quedabas en una pantalla de login sin saber por qué. Eso deja
/// de aplicar cuando la pantalla es esta y su única razón de ser es entrar.)
///
/// Se dispara UNA vez. Si falla o se cancela, el botón queda ahí para
/// reintentar a mano, y debajo —discreta— la salida a las credenciales: la
/// huella puede fallar con el dedo mojado, y el teléfono puede pasar de mano.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  FingerprintStatus _status = FingerprintStatus.idle;
  String? _message;

  /// Solo el primer intento es automático. Sin esta marca, un fallo volvería a
  /// levantar el prompt en el siguiente repintado y quedaría un bucle del que
  /// no se puede salir ni para pulsar "entrar con usuario y contraseña".
  bool _autoIntentado = false;

  /// La espera que devuelve el botón a reposo tras un fallo. Se guarda para
  /// poder cancelarla: si la pantalla se va antes (la salida a credenciales,
  /// por ejemplo), un temporizador suelto seguiría vivo apuntando a un estado
  /// que ya no existe.
  Timer? _volverAReposo;

  @override
  void initState() {
    super.initState();
    // Tras el primer frame: el prompt del sistema es una vista nativa y
    // levantarla durante la construcción deja la pantalla a medio pintar
    // detrás del diálogo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoIntentado) return;
      _autoIntentado = true;
      _unlock();
    });
  }

  Future<void> _unlock() async {
    setState(() {
      _status = FingerprintStatus.scanning;
      _message = null;
    });

    final bool ok = await ref.read(authControllerProvider.notifier).unlockWithBiometrics();
    if (!mounted) return;

    if (ok) {
      // El acierto se deja ver un instante antes de que el router cambie de
      // pantalla: sin esa pausa el visto no llega a percibirse.
      setState(() => _status = FingerprintStatus.success);
      return;
    }
    setState(() {
      _status = FingerprintStatus.error;
      _message = 'No reconocimos tu huella. Inténtalo de nuevo.';
    });
    // Vuelve a reposo para que se note que puede reintentar.
    _volverAReposo?.cancel();
    _volverAReposo = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && _status == FingerprintStatus.error) {
        setState(() => _status = FingerprintStatus.idle);
      }
    });
  }

  @override
  void dispose() {
    _volverAReposo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    final String name =
        (auth.lockedUser?.fullName ?? auth.lockedUser?.username ?? '').split(' ').first;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
          child: Column(
            children: [
              const Spacer(flex: 2),

              OrbMascot(size: 110, loading: _status == FingerprintStatus.scanning),
              const SizedBox(height: AppSpacing.xl),

              Text(
                name.isEmpty ? 'Hola de nuevo' : 'Hola de nuevo, $name',
                textAlign: TextAlign.center,
                style: AppTypography.headlineLg(color: scheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tu sesión sigue abierta. Toca para entrar.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
              ),

              const Spacer(),

              // La única acción de la pantalla.
              FingerprintButton(status: _status, onTap: _unlock),
              const SizedBox(height: AppSpacing.lg),

              // El hueco del mensaje se reserva siempre: si apareciera y
              // desapareciera, todo lo de arriba daría un salto.
              SizedBox(
                height: 40,
                child: AnimatedOpacity(
                  opacity: _message == null ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _message ?? '',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm(color: AppColors.error),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Salida secundaria: deliberadamente sin peso visual, para que
              // no compita con la huella pero tampoco deje a nadie encerrado
              // (huella que falla, dedo mojado, otro usuario en el mismo
              // teléfono).
              TextButton(
                onPressed: () => ref.read(authControllerProvider.notifier).useCredentialsInstead(),
                child: Text(
                  'Entrar con usuario y contraseña',
                  style: AppTypography.labelMd(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
