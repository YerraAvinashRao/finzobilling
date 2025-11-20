// lib/theme/app_animations.dart
import 'package:flutter/animation.dart';

class AppAnimations {
  AppAnimations._();
  
  // ✅ DURATIONS (Apple-style timing)
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration splash = Duration(milliseconds: 600);
  
  // ✅ CURVES (Smooth, professional)
  static const Curve easeIn = Curves.easeIn;        // ✅ Fixed
  static const Curve easeOut = Curves.easeOut;      // ✅ Fixed
  static const Curve easeInOut = Curves.easeInOut;  // ✅ Fixed
  static const Curve bounceOut = Curves.easeOutBack; // ✅ Fixed
  static const Curve elastic = Curves.elasticOut;   // ✅ Fixed
}
