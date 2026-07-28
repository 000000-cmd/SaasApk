import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/router.dart';
import 'package:saas_app/app/theme/app_theme.dart';
import 'package:saas_app/core/theme/theme_controller.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SaaS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Arranca en claro; el usuario cambia a oscuro desde el perfil (persistido).
      themeMode: ref.watch(themeModeProvider),

      // Español fijo. Sin esto los widgets de Material salen en inglés aunque
      // el resto de la app esté en español: el selector de fecha es el caso
      // evidente — nombres de mes, botones y hasta el orden de los campos.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      routerConfig: router,
    );
  }
}
