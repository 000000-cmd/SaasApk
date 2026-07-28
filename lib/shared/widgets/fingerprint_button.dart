import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saas_app/app/theme/app_colors.dart';

/// En qué punto está el intento de huella.
enum FingerprintStatus { idle, scanning, success, error }

/// Botón de huella con estado propio.
///
/// El lector biométrico del teléfono no avisa de nada mientras piensa: sin algo
/// que se mueva, el usuario no sabe si el toque entró, si está leyendo o si ya
/// falló. Cada estado tiene aquí su propio movimiento, y todos dicen algo:
///
///  - **idle**: dos anillos que respiran hacia afuera, como un pulso. Invitan a
///    tocar sin exigir atención.
///  - **scanning**: los anillos se paran y un arco gira alrededor. Cambiar de
///    "respirar" a "girar" es lo que comunica que ahora sí está trabajando.
///  - **error**: sacudida corta y rojo. Es el gesto físico de "no", y se
///    entiende antes de leer el mensaje.
///  - **success**: el icono se convierte en un visto y el anillo se llena.
///
/// La háptica acompaña a los dos finales: mirando el lector del teléfono, no
/// la pantalla, la vibración es lo único que llega.
class FingerprintButton extends StatefulWidget {
  const FingerprintButton({
    super.key,
    required this.status,
    required this.onTap,
    this.size = 132,
  });

  final FingerprintStatus status;
  final VoidCallback onTap;
  final double size;

  @override
  State<FingerprintButton> createState() => _FingerprintButtonState();
}

class _FingerprintButtonState extends State<FingerprintButton> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool _pressed = false;

  @override
  void didUpdateWidget(FingerprintButton old) {
    super.didUpdateWidget(old);
    if (widget.status == old.status) return;
    switch (widget.status) {
      case FingerprintStatus.scanning:
        _spin.repeat();
      case FingerprintStatus.error:
        _spin.stop();
        _shake.forward(from: 0);
        HapticFeedback.heavyImpact();
      case FingerprintStatus.success:
        _spin.stop();
        HapticFeedback.mediumImpact();
      case FingerprintStatus.idle:
        _spin.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    _shake.dispose();
    super.dispose();
  }

  Color get _tint => switch (widget.status) {
        FingerprintStatus.error => AppColors.error,
        FingerprintStatus.success => AppColors.success,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final bool busy = widget.status == FingerprintStatus.scanning;

    return Semantics(
      button: true,
      label: 'Entrar con huella',
      child: GestureDetector(
        onTapDown: busy ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: busy ? null : widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _spin, _shake]),
          builder: (context, _) {
            // Sacudida: una senoidal amortiguada, que se para sola.
            final double shake = _shake.isAnimating
                ? math.sin(_shake.value * math.pi * 6) * (1 - _shake.value) * 10
                : 0;

            return Transform.translate(
              offset: Offset(shake, 0),
              child: AnimatedScale(
                scale: _pressed ? 0.94 : 1,
                duration: const Duration(milliseconds: 120),
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    painter: _FingerprintPainter(
                      pulse: _pulse.value,
                      spin: _spin.value,
                      tint: _tint,
                      status: widget.status,
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Icon(
                          switch (widget.status) {
                            FingerprintStatus.success => Icons.check_rounded,
                            FingerprintStatus.error => Icons.close_rounded,
                            _ => Icons.fingerprint_rounded,
                          },
                          key: ValueKey<FingerprintStatus>(widget.status),
                          size: widget.size * 0.38,
                          color: _tint,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FingerprintPainter extends CustomPainter {
  _FingerprintPainter({
    required this.pulse,
    required this.spin,
    required this.tint,
    required this.status,
  });

  final double pulse;
  final double spin;
  final Color tint;
  final FingerprintStatus status;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double base = size.width * 0.30;

    // Disco de fondo: la diana del dedo.
    canvas.drawCircle(center, base, Paint()..color = tint.withValues(alpha: 0.12));

    if (status == FingerprintStatus.idle) {
      // Dos ondas desfasadas: siempre hay una saliendo, nunca queda quieto.
      for (final double phase in [0.0, 0.5]) {
        final double t = (pulse + phase) % 1.0;
        final double radius = base + (size.width * 0.20) * t;
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            // Se desvanece al alejarse: la onda se disuelve, no se corta.
            ..color = tint.withValues(alpha: (1 - t) * 0.45),
        );
      }
    }

    if (status == FingerprintStatus.scanning) {
      // Arco que gira: el cambio de "respirar" a "girar" es lo que dice que
      // el lector ya está trabajando.
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: base + size.width * 0.10),
        spin * 2 * math.pi,
        math.pi * 0.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = tint,
      );
    }

    if (status == FingerprintStatus.success) {
      canvas.drawCircle(
        center,
        base + size.width * 0.10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = tint,
      );
    }
  }

  @override
  bool shouldRepaint(_FingerprintPainter old) =>
      old.pulse != pulse || old.spin != spin || old.status != status || old.tint != tint;
}
