import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' as rive;
import 'package:saas_app/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pantalla completa de borde a borde: la app pinta DEBAJO de la barra de
  // estado y de la de navegación, y las dos se vuelven transparentes. No se
  // ocultan del todo a proposito — esconderlas obliga a deslizar para volver y
  // rompe el gesto que todo el mundo tiene en el dedo. Lo que se arregla es el
  // solape: a partir de aqui NADA se pinta debajo de esas barras sin pedirlo,
  // porque las pantallas respetan los insets.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ),);
  // Solo vertical: toda la maquetacion esta pensada para el pulgar.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Runtime de la mascota ORB (en web además descarga su wasm). Si falla, la
  // app arranca igual: OrbMascot degrada a su fallback estático.
  try {
    await rive.RiveNative.init();
  } catch (e) {
    debugPrint('[mascot] RiveNative.init falló ($e); la mascota usará fallback.');
  }
  // En web (solo para verificación en dev) el árbol de semántica se enciende
  // de una: permite inspeccionar/automatizar la UI sin el gesto del placeholder.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(const ProviderScope(child: App()));
}
