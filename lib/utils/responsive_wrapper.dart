import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class ResponsiveHelper {
  // Screen breakpoints
  static const double mobileWidth = 600;
  static const double tabletWidth = 1024;
  static const double desktopWidth = 1440;

  // Check if web with large screen
  static bool isDesktopWeb(BuildContext context) {
    return kIsWeb && MediaQuery.of(context).size.width >= mobileWidth;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileWidth && width < desktopWidth;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileWidth;
  }

  // Get adaptive value
  static T responsive<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktopWeb(context)) return desktop;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
}

// Adaptive Scaffold - switches between mobile and desktop layouts
class AdaptiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  const AdaptiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.drawer,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Mobile: Normal scaffold with bottom nav
    if (ResponsiveHelper.isMobile(context)) {
      return Scaffold(
        appBar: appBar,
        body: body,
        drawer: drawer,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        backgroundColor: backgroundColor,
      );
    }

    // Desktop: Sidebar layout (no bottom nav)
    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFFF2F2F7),
      body: Row(
        children: [
          // Sidebar (converted from drawer)
          if (drawer != null)
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: drawer!,
            ),
          
          // Main content
          Expanded(
            child: Column(
              children: [
                if (appBar != null) appBar!,
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    padding: const EdgeInsets.all(24),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
