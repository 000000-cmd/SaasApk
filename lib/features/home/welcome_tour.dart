import 'package:flutter/material.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/shared/widgets/app_button.dart';
import 'package:saas_app/shared/widgets/orb_mascot.dart';

/// Tour de bienvenida (primer ingreso al panel). AQUÍ sí vive el ORB: es el guía
/// que presenta la app en pocos pasos. Se muestra sobre la "bóveda" oscura para
/// que la mascota luzca, y al terminar cede el paso al dashboard (donde el saldo
/// es el protagonista, sin el ORB encima).
///
/// Presentar con [WelcomeTour.show]; resuelve el future cuando el usuario
/// termina o salta.
class WelcomeTour extends StatefulWidget {
  const WelcomeTour({super.key, required this.name});

  /// Nombre para personalizar el saludo (puede ir vacío).
  final String name;

  static Future<void> show(BuildContext context, {required String name}) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Bienvenida',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => WelcomeTour(name: name),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
    );
  }

  @override
  State<WelcomeTour> createState() => _WelcomeTourState();
}

class _WelcomeStep {
  const _WelcomeStep(this.title, this.body);
  final String title;
  final String body;
}

class _WelcomeTourState extends State<WelcomeTour> {
  final PageController _pages = PageController();
  final OrbMascotController _mascot = OrbMascotController();
  int _index = 0;

  late final List<_WelcomeStep> _steps = [
    _WelcomeStep(
      widget.name.isEmpty ? '¡Hola! 👋' : '¡Hola, ${widget.name}! 👋',
      'Soy tu asistente. Te muestro lo esencial en unos segundos.',
    ),
    const _WelcomeStep(
      'Tu saldo, siempre primero',
      'Lo que llevas por cobrar te recibe apenas entras. Se actualiza con cada servicio que completes.',
    ),
    const _WelcomeStep(
      'Todo a un toque',
      'Desde la barra de abajo llegas a tus pagos y, muy pronto, a tus citas. Tu perfil está siempre a mano.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // La mascota saluda al abrir.
    WidgetsBinding.instance.addPostFrameCallback((_) => _mascot.celebrate());
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _steps.length - 1) {
      _mascot.jump();
      _pages.animateToPage(_index + 1,
          duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic,);
    } else {
      _finish();
    }
  }

  void _finish() {
    _mascot.celebrate();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool last = _index == _steps.length - 1;
    return Material(
      color: AppColors.inverseSurface,
      child: SafeArea(
        child: Column(
          children: [
            // Saltar
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm, top: AppSpacing.xs),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Saltar', style: TextStyle(color: AppColors.secondaryFixedDim)),
                ),
              ),
            ),
            // El ORB, protagonista del tour.
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
              child: LayoutBuilder(
                builder: (context, c) {
                  final double s = (MediaQuery.of(context).size.height * 0.24).clamp(140.0, 220.0);
                  return OrbMascot(size: s, halo: true, controller: _mascot);
                },
              ),
            ),
            // Pasos
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final step = _steps[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: AppTypography.headlineLg(color: AppColors.inverseOnSurface),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          step.body,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMd(color: AppColors.secondaryFixedDim),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Indicador de progreso
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(_steps.length, (i) {
                final bool active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 6,
                  width: active ? 22 : 6,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primaryContainer : AppColors.outlineDark,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AppButton(
                label: last ? 'Empezar' : 'Siguiente',
                size: AppButtonSize.lg,
                expanded: true,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
