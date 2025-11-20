// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ✅ PRIMARY COLORS (Better than Zoho's blue)
  static const Color primary = Color(0xFF4A90E2);          // Vibrant blue
  static const Color primaryDark = Color(0xFF357ABD);      // Darker blue
  static const Color primaryLight = Color(0xFF6BA3E8);     // Lighter blue
  
  // ✅ SECONDARY COLORS
  static const Color secondary = Color(0xFF5C6BC0);        // Indigo
  static const Color accent = Color(0xFFFF6B6B);           // Coral red
  static const Color success = Color(0xFF4CAF50);          // Green
  static const Color warning = Color(0xFFFF9800);          // Orange
  static const Color error = Color(0xFFF44336);            // Red
  static const Color info = Color(0xFF2196F3);             // Blue
  
  // ✅ NEUTRAL COLORS
  static const Color background = Color(0xFFF8F9FA);       // Light grey
  static const Color surface = Colors.white;
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color card = Colors.white;
  static const Color cardDark = Color(0xFF2A2A2A);
  
  // ✅ TEXT COLORS
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textWhite = Colors.white;
  
  // ✅ BORDER COLORS
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF424242);
  static const Color divider = Color(0xFFE0E0E0);
  
  // ✅ GRADIENT COLORS
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // ✅ SHADOW COLORS
  static Color shadow = Colors.black.withOpacity(0.08);
  static Color shadowDark = Colors.black.withOpacity(0.20);
}
