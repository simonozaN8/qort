import 'package:shared_preferences/shared_preferences.dart';

import '../theme/qort_palette.dart';

/// Išsaugo vartotojo pasirinktą QORT vizualinį variantą.
class ThemePreferenceService {
  static const _key = 'qort_theme_variant_id';

  static Future<String> loadVariantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? QortPalette.proDark.id;
  }

  static Future<QortPalette> loadPalette() async {
    final id = await loadVariantId();
    return QortPalette.fromId(id);
  }

  static Future<void> saveVariantId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
  }
}
