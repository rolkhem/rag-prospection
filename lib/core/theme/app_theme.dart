import 'package:flutter/material.dart';

/// Palette sombre « cockpit commercial ». Centralisée ici pour que les widgets
/// ne contiennent aucune couleur ad hoc.
abstract final class AppColors {
  static const Color background = Color(0xFF0B1120);
  static const Color surface = Color(0xFF111A2E);
  static const Color surfaceElevated = Color(0xFF1A2540);
  static const Color border = Color(0xFF26324D);
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDeep = Color(0xFF4F46E5);
  static const Color accent = Color(0xFF22D3EE);
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static const Color boamp = Color(0xFF3B82F6);
  static const Color ted = Color(0xFF10B981);
  static const Color decp = Color(0xFFF59E0B);
  static const Color linkedIn = Color(0xFF0A66C2);
  /// Clair plutôt que gris ardoise : sur le fond sombre, un interrupteur X
  /// activé se confondait avec un interrupteur désactivé.
  static const Color x = Color(0xFFCBD5E1);

  static const LinearGradient userBubble = LinearGradient(
    colors: [primary, primaryDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerColor: AppColors.border,
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
