import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Gemini API konfigūracija.
/// Įrašykite raktą į `.env` (GEMINI_API_KEY=...) arba naudokite
/// `--dart-define=GEMINI_API_KEY=...` build metu.
class GeminiConfig {
  static String get apiKey {
    final fromDotenv = dotenv.env['GEMINI_API_KEY']?.trim();
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    return const String.fromEnvironment('GEMINI_API_KEY');
  }

  /// Gemini Flash 2.5 — UI/vizualų generavimui.
  static const String modelFlash = 'gemini-2.5-flash';

  /// Atsarginiai modeliai.
  static const String modelFallback = 'gemini-2.0-flash';
  static const String modelFallbackLite = 'gemini-2.0-flash-lite';

  static bool get isConfigured => apiKey.isNotEmpty;
}
