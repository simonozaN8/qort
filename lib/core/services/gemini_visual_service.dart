import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/gemini_config.dart';

/// Gemini sugeneruoto ekrano specifikacija.
class QortVisualSpec {
  final String title;
  final String subtitle;
  final String mode;
  final String accentHex;
  final List<QortVisualSection> sections;
  final String? imagePrompt;

  const QortVisualSpec({
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.accentHex,
    required this.sections,
    this.imagePrompt,
  });

  factory QortVisualSpec.fromJson(Map<String, dynamic> json) {
    final sectionsRaw = json['sections'];
    final sections = sectionsRaw is List
        ? sectionsRaw
            .whereType<Map>()
            .map((e) => QortVisualSection.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <QortVisualSection>[];

    return QortVisualSpec(
      title: json['title']?.toString() ?? 'QORT Ekranas',
      subtitle: json['subtitle']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'competition',
      accentHex: json['accent_hex']?.toString() ?? '#3B82F6',
      sections: sections,
      imagePrompt: json['image_prompt']?.toString(),
    );
  }
}

class QortVisualSection {
  final String label;
  final String body;
  final String iconHint;

  const QortVisualSection({
    required this.label,
    required this.body,
    required this.iconHint,
  });

  factory QortVisualSection.fromJson(Map<String, dynamic> json) {
    return QortVisualSection(
      label: json['label']?.toString() ?? 'Sekcija',
      body: json['body']?.toString() ?? '',
      iconHint: json['icon_hint']?.toString() ?? 'trophy',
    );
  }
}

class GeminiVisualResult {
  final bool ok;
  final String message;
  final QortVisualSpec? spec;
  final Uint8List? imageBytes;

  const GeminiVisualResult({
    required this.ok,
    required this.message,
    this.spec,
    this.imageBytes,
  });
}

/// Gemini Flash — ekranų generavimas pagal QORT dizaino sistemą.
class GeminiVisualService {
  GeminiVisualService._();

  static const _models = [
    GeminiConfig.modelFlash,
    GeminiConfig.modelFallback,
    GeminiConfig.modelFallbackLite,
  ];

  static const _systemPrompt = '''
Tu esi QORT sporto app UI dizaineris. Generuok TIK validų JSON (be markdown).
Stilius: profesionalus, Material 3, maxWidth 520px.
Režimai: competition (#3B82F6), training (#16C56E), blitz (#7C3AED).

JSON schema:
{
  "title": "string",
  "subtitle": "string",
  "mode": "competition|training|blitz",
  "accent_hex": "#RRGGBB",
  "image_prompt": "trumpas hero aprašymas",
  "sections": [
    {"label": "SEKCIJA", "body": "turinys", "icon_hint": "trophy|target|zap|bell|user"}
  ]
}
''';

  static Future<GeminiVisualResult> generateScreenSpec(String userPrompt) async {
    if (!GeminiConfig.isConfigured) {
      return const GeminiVisualResult(
        ok: false,
        message:
            'Gemini API raktas nenustatytas. Paleiskite su --dart-define=GEMINI_API_KEY=...',
      );
    }

    Object? lastError;
    for (final modelName in _models) {
      try {
        final model = _createModel(modelName);
        final response = await model.generateContent([
          Content.text('$_systemPrompt\n\nUžklausa: $userPrompt'),
        ]);

        final text = response.text?.trim();
        if (text == null || text.isEmpty) continue;

        final json = _extractJson(text);
        if (json == null) continue;

        final usedFallback = modelName != GeminiConfig.modelFlash;
        return GeminiVisualResult(
          ok: true,
          message: usedFallback
              ? 'Sugeneruota ($modelName).'
              : 'Ekrano vizualas sugeneruotas.',
          spec: QortVisualSpec.fromJson(json),
        );
      } catch (e) {
        lastError = e;
        debugPrint('Gemini $modelName: $e');
      }
    }

    return GeminiVisualResult(
      ok: false,
      message: _friendlyError(lastError),
    );
  }

  static Future<GeminiVisualResult> generateHeroImage(String imagePrompt) async {
    return const GeminiVisualResult(
      ok: false,
      message: 'Hero vaizdų generavimas laikinai išjungtas — naudokite spec preview.',
    );
  }

  static GenerativeModel _createModel(String modelName) {
    return GenerativeModel(
      model: modelName,
      apiKey: GeminiConfig.apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.6,
        responseMimeType: 'application/json',
      ),
    );
  }

  static String _friendlyError(Object? error) {
    final raw = error?.toString() ?? 'Nežinoma klaida';
    if (raw.contains('quota') || raw.contains('Quota exceeded')) {
      return 'Viršytas Gemini API limitas. Patikrinkite kvotą Google AI Studio '
          'arba bandykite vėliau.';
    }
    if (raw.contains('not found') || raw.contains('NOT_FOUND')) {
      return 'Modelis nepasiekiamas šiuo API raktu. Naudokite galiojantį '
          'GEMINI_API_KEY iš Google AI Studio.';
    }
    if (raw.contains('API key')) {
      return 'Neteisingas GEMINI_API_KEY. Patikrinkite --dart-define reikšmę.';
    }
    return 'Nepavyko sugeneruoti. $raw';
  }

  static Map<String, dynamic>? _extractJson(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {}

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }
}
