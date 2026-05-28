import 'package:flutter/material.dart';

/// MainWrapper apatinė juosta + iškilęs „+“ (žr. qort_bottom_nav.dart).
class AppShellLayout {
  AppShellLayout._();

  /// Juostos turinio aukštis (su etiketėmis).
  static const double bottomNavBarHeight = 60;

  /// FAB iškyšimas virš juostos.
  static const double fabOverlap = 36;

  static double bottomNavTotalHeight(BuildContext context) {
    return bottomNavBarHeight + fabOverlap + MediaQuery.paddingOf(context).bottom;
  }

  /// Scroll turiniui, kad paskutiniai elementai nebūtų po FAB.
  static double scrollBottomPadding(BuildContext context) {
    return 100.0 + MediaQuery.paddingOf(context).bottom;
  }
}
