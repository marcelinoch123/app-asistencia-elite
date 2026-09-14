import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF0F2744);
  static const Color primaryLight = Color(0xFFDDE9FF);
  static const Color secondaryBlue = Color(0xFF0051D5);
  static const Color accentCyan = Color(0xFF6FFBBE);
  static const Color statusPresent = Color(0xFF10B981);
  static const Color statusLate = Color(0xFFF59E0B);
  static const Color statusAbsent = Color(0xFFEF4444);
  static const Color surface = Color(0xFFF8F9FF);
  static const Color onSurface = Color(0xFF0D1C2F);
  static const Color onSurfaceVariant = Color(0xFF44474D);

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1024;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isDesktop(context)) return const EdgeInsets.all(32);
    if (isTablet(context)) return const EdgeInsets.all(24);
    return const EdgeInsets.all(16);
  }
}