import 'package:flutter/foundation.dart';

import '../services/theme_preference_service.dart';
import 'qort_palette.dart';

/// Globalus pasirinkto vizualinio varianto būsenos valdiklis.
class QortThemeNotifier extends ChangeNotifier {
  QortThemeNotifier._();

  static final QortThemeNotifier instance = QortThemeNotifier._();

  QortPalette palette = QortPalette.proDark;

  Future<void> load() async {
    palette = await ThemePreferenceService.loadPalette();
    notifyListeners();
  }

  Future<void> apply(QortPalette newPalette) async {
    palette = newPalette;
    await ThemePreferenceService.saveVariantId(newPalette.id);
    notifyListeners();
  }
}
