import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/web_safe_area_bottom.dart';

/// MainWrapper apatinė juosta + iškilęs „+“ (žr. qort_bottom_nav.dart).
class AppShellLayout {
  AppShellLayout._();

  /// Juostos turinio aukštis (su etiketėmis).
  static const double bottomNavBarHeight = 60;

  /// FAB iškyšimas virš juostos.
  static const double fabOverlap = 36;

  /// Apatinis safe area (iPhone home indicator, PWA standalone).
  static double bottomSafeInset(BuildContext context) {
    final media = MediaQuery.of(context);
    final view = media.viewPadding.bottom;
    if (view > 0) return view;
    final pad = media.padding.bottom;
    if (pad > 0) return pad;
    if (kIsWeb) {
      final webInset = readWebBottomSafeInset();
      if (webInset > 0) return webInset;
    }
    return 0;
  }

  static double bottomNavTotalHeight(BuildContext context) {
    return bottomNavBarHeight + fabOverlap + bottomSafeInset(context);
  }

  /// Scroll turiniui, kad paskutiniai elementai nebūtų po FAB.
  static double scrollBottomPadding(BuildContext context) {
    return 100.0 + bottomSafeInset(context);
  }
}
