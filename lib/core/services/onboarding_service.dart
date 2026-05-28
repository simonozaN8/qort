import 'package:shared_preferences/shared_preferences.dart';

/// Vienkartinis intro po pirmos sesijos (v3 — 6 žingsniai, taisytas layout).
class OnboardingService {
  static const _key = 'qort_home_intro_v3_done';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Testavimui / profilis — parodyti intro iš naujo.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
