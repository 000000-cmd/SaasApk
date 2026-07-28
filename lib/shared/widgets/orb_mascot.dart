import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;
import 'package:saas_app/app/theme/app_colors.dart';

/// Acciones imperativas de la mascota — mismo contrato que la web
/// (`MascotComponent`): el host las dispara desde eventos de UI que YA ocurren.
class OrbMascotController {
  _OrbMascotState? _state;

  /// Éxito: la mascota celebra.
  void celebrate() => _state?._fire(_MascotTrigger.correct);

  /// Error: la mascota reacciona con desánimo.
  void reject() => _state?._fire(_MascotTrigger.wrong);

  /// Micro-interacción de saludo.
  void jump() => _state?._fire(_MascotTrigger.jump);
}

enum _MascotTrigger { correct, wrong, jump }

/// La mascota ORB (Rive) — la MISMA `.riv` y el MISMO estándar que la web:
/// state machine "State Machine 1" controlada por data binding (ViewModel) con
/// booleanos `typingBoolean`/`loadingBoolean` y triggers `correct`/`wrong`/
/// `jump`. Sin lógica de negocio: el host empuja `typing`/`loading` y dispara
/// las acciones del [OrbMascotController].
///
/// Reduced-motion (MediaQuery.disableAnimations): la mascota queda pausada y
/// los triggers se ignoran, igual que el guard de `prefers-reduced-motion` web.
/// Si el runtime o el asset fallan, degrada a una esfera estática de marca.
class OrbMascot extends StatefulWidget {
  const OrbMascot({
    super.key,
    required this.size,
    this.typing = false,
    this.loading = false,
    this.dim = false,
    this.halo = false,
    this.controller,
  });

  /// Lado del cuadrado que ocupa la mascota, en px lógicos.
  final double size;

  /// El usuario está interactuando con un campo (foco/escritura).
  final bool typing;

  /// Hay una operación en curso (submit).
  final bool loading;

  /// Estado apagado (módulos bloqueados): pausada y atenuada.
  final bool dim;

  /// Escenario detrás de la mascota: aurora radial + anillo de luz en órbita.
  /// Para los momentos hero (login, splash); apagado en usos pequeños.
  final bool halo;

  final OrbMascotController? controller;

  /// Apaga el runtime Rive (los widget tests lo activan: el runtime nativo
  /// carga librerías en un microtask que el harness reporta como error).
  /// La mascota queda en su fallback estático.
  static bool riveDisabled = false;

  @override
  State<OrbMascot> createState() => _OrbMascotState();
}

class _OrbMascotState extends State<OrbMascot> with SingleTickerProviderStateMixin {
  AnimationController? _haloSpin;
  rive.File? _file;
  rive.RiveWidgetController? _rive;
  rive.ViewModelInstance? _vmi;
  rive.ViewModelInstanceBoolean? _typingProp;
  rive.ViewModelInstanceBoolean? _loadingProp;
  rive.ViewModelInstanceTrigger? _correctProp;
  rive.ViewModelInstanceTrigger? _wrongProp;
  rive.ViewModelInstanceTrigger? _jumpProp;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    if (widget.halo) {
      _haloSpin = AnimationController(vsync: this, duration: const Duration(seconds: 18));
    }
    _init();
  }

  Future<void> _init() async {
    if (OrbMascot.riveDisabled) {
      setState(() => _failed = true);
      return;
    }
    String stage = 'File.asset';
    try {
      // Factory.rive = renderer propio de Rive (el mismo que usa el runtime
      // web del front); Factory.flutter en web falla al inicializar su wasm.
      final rive.File? file = await rive.File.asset(
        'assets/mascot/ai-orb-mascot.riv',
        riveFactory: rive.Factory.rive,
      );
      if (file == null) throw StateError('riv ilegible');
      stage = 'RiveWidgetController';
      final rive.RiveWidgetController controller = rive.RiveWidgetController(file);
      stage = 'dataBind';
      final rive.ViewModelInstance vmi = controller.dataBind(rive.DataBind.auto());
      if (!mounted) {
        vmi.dispose();
        controller.dispose();
        file.dispose();
        return;
      }
      setState(() {
        _file = file;
        _rive = controller;
        _vmi = vmi;
        // Nombres reales del archivo (los mismos que resuelve la web).
        _typingProp = vmi.boolean('typingBoolean');
        _loadingProp = vmi.boolean('loadingBoolean');
        _correctProp = vmi.trigger('correct');
        _wrongProp = vmi.trigger('wrong');
        _jumpProp = vmi.trigger('jump');
        // Sincroniza el estado inicial una vez enlazado el ViewModel.
        _typingProp?.value = widget.typing;
        _loadingProp?.value = widget.loading;
      });
    } catch (e, st) {
      // Runtime nativo o asset no disponibles (p. ej. tests): esfera estática.
      debugPrint('[mascot] Rive no disponible en "$stage" ($e); usando fallback estático.');
      debugPrint('[mascot] stack: ${st.toString().split('\n').take(6).join(' | ')}');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(OrbMascot old) {
    super.didUpdateWidget(old);
    widget.controller?._state = this;
    if (old.typing != widget.typing) _typingProp?.value = widget.typing;
    if (old.loading != widget.loading) _loadingProp?.value = widget.loading;
  }

  void _fire(_MascotTrigger trigger) {
    if (!mounted || widget.dim) return;
    if (MediaQuery.of(context).disableAnimations) return;
    switch (trigger) {
      case _MascotTrigger.correct:
        _correctProp?.trigger();
      case _MascotTrigger.wrong:
        _wrongProp?.trigger();
      case _MascotTrigger.jump:
        _jumpProp?.trigger();
    }
  }

  @override
  void dispose() {
    _haloSpin?.dispose();
    if (widget.controller?._state == this) widget.controller?._state = null;
    _typingProp?.dispose();
    _loadingProp?.dispose();
    _correctProp?.dispose();
    _wrongProp?.dispose();
    _jumpProp?.dispose();
    _vmi?.dispose();
    _rive?.dispose();
    _file?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final Widget child;
    if (_rive != null) {
      child = TickerMode(
        enabled: !reduceMotion && !widget.dim,
        child: rive.RiveWidget(controller: _rive!, fit: rive.Fit.contain),
      );
    } else if (_failed) {
      child = const _MascotFallback();
    } else {
      child = const SizedBox.shrink(); // cargando: sin placeholder que parpadee
    }
    final Widget mascot = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Opacity(opacity: widget.dim ? 0.45 : 1, child: child),
    );
    if (!widget.halo) return mascot;

    // Escenario: aurora + anillo orbitando detrás de la mascota. Con
    // reduced-motion queda un fotograma fijo (el controller no corre).
    final AnimationController? spin = _haloSpin;
    if (spin != null) {
      if (reduceMotion) {
        spin.stop();
      } else if (!spin.isAnimating) {
        spin.repeat();
      }
    }
    final double stage = widget.size * 1.5;
    return SizedBox(
      width: stage,
      height: stage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: spin ?? const AlwaysStoppedAnimation<double>(0.3),
              builder: (context, _) => CustomPaint(
                size: Size.square(stage),
                painter: _HaloPainter(t: spin?.value ?? 0.3),
              ),
            ),
          ),
          mascot,
        ],
      ),
    );
  }
}

/// Aurora del escenario: dos glows radiales de marca y un anillo de luz con
/// dos destellos que orbitan lento. Todo vive DETRÁS de la mascota.
class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2;

    // Aurora base: morado amplio + lavanda descentrada (profundidad).
    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.34),
          AppColors.primary.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, glow);

    final Offset amberC = center + Offset(-r * 0.25, -r * 0.3);
    final Paint amber = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primaryFixedDim.withValues(alpha: 0.20),
          AppColors.primaryFixedDim.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: amberC, radius: r * 0.7));
    canvas.drawCircle(amberC, r * 0.7, amber);

    // Anillo de luz: trazo tenue + dos destellos en órbita.
    final double ringR = r * 0.82;
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.primaryFixed.withValues(alpha: 0.22);
    canvas.drawCircle(center, ringR, ring);

    final double angle = 2 * math.pi * t;
    for (final (double phase, Color color) in [
      (0.0, AppColors.primaryFixed),
      (math.pi, AppColors.primaryContainer),
    ]) {
      final Offset p = center + Offset(math.cos(angle + phase), math.sin(angle + phase)) * ringR;
      canvas.drawCircle(
        p,
        7,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: p, radius: 7)),
      );
    }
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.t != t;
}

/// Degradación estática (sin runtime Rive): esfera oscura con el brillo de
/// marca, suficiente para que el layout no quede cojo.
class _MascotFallback extends StatelessWidget {
  const _MascotFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: [AppColors.primaryContainer, AppColors.onPrimaryFixed],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}
