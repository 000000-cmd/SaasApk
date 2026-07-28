import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/shared/widgets/fingerprint_button.dart';
import 'package:saas_app/shared/widgets/orb_mascot.dart';

/// Volver a entrar cuando ya hay una sesión guardada con huella.
///
/// Antes esto no existía: el login disparaba el lector nada más abrir la app.
/// Salía un diálogo del sistema encima de un formulario que no venías a usar,
/// y si lo cancelabas quedabas en una pantalla de credenciales sin saber por
/// qué. Ahora el lector NO se dispara solo: primero se saluda a quien vuelve y
/// la huella se pide cuando la pide el usuario.
///
/// Una sola acción en pantalla — la huella — y debajo, discreta, la salida a
/// las credenciales de siempre.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  FingerprintStatus _status = FingerprintStatus.idle;
  String? _message;

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
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted && _status == FingerprintStatus.error) {
      setState(() => _status = FingerprintStatus.idle);
    }
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
