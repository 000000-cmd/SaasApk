import 'package:flutter/material.dart';
import 'package:saas_app/app/theme/app_colors.dart';

/// Indicador de carga centrado, con el acento de marca.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: size,
        width: size,
        child: const CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
}
