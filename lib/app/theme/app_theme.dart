import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';

/// ThemeData light/dark del sistema "Luminous Aura". La UI usa estos temas + los
/// componentes de `shared/widgets`; evitar colores hardcodeados en pantallas.
///
/// El ColorScheme se arma con los tokens EXPLÍCITOS del sistema (no con
/// `fromSeed`): el diseño define cada rol de color a mano y derivarlos del seed
/// los desviaría.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: isDark ? AppColors.surfaceDarkTone : AppColors.surface,
      onSurface: isDark ? AppColors.onSurfaceDark : AppColors.onSurface,
      onSurfaceVariant: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariant,
      surfaceContainerLowest: isDark ? AppColors.surfaceContainerLowestDark : AppColors.surfaceContainerLowest,
      surfaceContainerLow: isDark ? AppColors.surfaceContainerLowDark : AppColors.surfaceContainerLow,
      surfaceContainer: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainer,
      surfaceContainerHigh: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHigh,
      surfaceContainerHighest: isDark ? AppColors.surfaceContainerHighestDark : AppColors.surfaceContainerHighest,
      outline: isDark ? AppColors.outlineDark : AppColors.outline,
      outlineVariant: isDark ? AppColors.outlineVariantDark : AppColors.outlineVariant,
      inverseSurface: AppColors.inverseSurface,
      onInverseSurface: AppColors.inverseOnSurface,
      inversePrimary: AppColors.inversePrimary,
      surfaceTint: AppColors.surfaceTint,
      shadow: AppColors.shadowTint,
      scrim: const Color(0xFF000000),
    );

    final Color bg = isDark ? AppColors.backgroundDark : AppColors.background;
    final Color onSurface = scheme.onSurface;
    final Color onSurfaceVariant = scheme.onSurfaceVariant;
    final Color cardSurface = scheme.surfaceContainerLowest;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: _textTheme(onSurface, onSurfaceVariant),

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineMd(color: onSurface),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),

      // Tarjetas: 24px+ y definidas por sombra tintada, no por borde.
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
      ),

      // Acción primaria: píldora completa (contrasta con la retícula).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: AppTypography.labelMd(),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: AppTypography.labelMd(),
          elevation: 0,
        ),
      ),
      // Secundaria: borde morado sobre transparente.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.4), width: 1.5),
          textStyle: AppTypography.labelMd(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: AppTypography.labelMd(),
        ),
      ),

      // Inputs: 12px, trazo suave que se vuelve morado al enfocar.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerLow : cardSurface,
        hintStyle: AppTypography.bodyMd(color: onSurfaceVariant.withValues(alpha: 0.7)),
        labelStyle: AppTypography.labelMd(color: onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
      ),

      // Chips de estado: píldora, fondo lavanda muy claro, texto morado.
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryFixed,
        labelStyle: AppTypography.labelSm(color: AppColors.onPrimaryFixedVariant),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),

      // Hojas y diálogos: esquinas muy redondeadas (curvatura del orb).
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXxl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
        titleTextStyle: AppTypography.headlineMd(color: onSurface),
        contentTextStyle: AppTypography.bodyMd(color: onSurfaceVariant),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inverseSurface,
        contentTextStyle: AppTypography.bodyMd(color: AppColors.inverseOnSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: BorderSide(color: color, width: width),
      );

  /// Titulares en Bricolage, cuerpo y etiquetas en Hanken.
  static TextTheme _textTheme(Color onSurface, Color onSurfaceVariant) {
    final TextTheme base = GoogleFonts.hankenGroteskTextTheme();
    return base.copyWith(
      displayLarge: AppTypography.displayXl(color: onSurface),
      displayMedium: AppTypography.displayXl(color: onSurface),
      headlineLarge: AppTypography.headlineLg(color: onSurface),
      headlineMedium: AppTypography.headlineMd(color: onSurface),
      headlineSmall: AppTypography.titleMd(color: onSurface),
      titleLarge: AppTypography.headlineMd(color: onSurface),
      titleMedium: AppTypography.titleMd(color: onSurface),
      titleSmall: AppTypography.labelMd(color: onSurface),
      bodyLarge: AppTypography.bodyLg(color: onSurface),
      bodyMedium: AppTypography.bodyMd(color: onSurface),
      bodySmall: AppTypography.bodySm(color: onSurfaceVariant),
      labelLarge: AppTypography.labelMd(color: onSurface),
      labelMedium: AppTypography.labelMd(color: onSurfaceVariant),
      labelSmall: AppTypography.labelSm(color: onSurfaceVariant),
    );
  }
}
