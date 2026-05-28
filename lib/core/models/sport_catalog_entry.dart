// Viena sporto šaka iš sports_catalog (Fazė 1).

import 'dart:convert';

class SportCatalogEntry {

  final String name;

  final String? family;

  final String participantType;

  final String scoringType;

  final List<String> allowedFormats;

  final List<String> ratingCategories;

  final Map<String, dynamic> ratingConfig;

  final List<Map<String, dynamic>> levelsConfig;

  final bool isActive;
  final bool isCombat;
  final bool isMassStart;
  final int sortOrder;
  final String? description;



  const SportCatalogEntry({

    required this.name,

    this.family,

    required this.participantType,

    required this.scoringType,

    required this.allowedFormats,

    required this.ratingCategories,

    required this.ratingConfig,

    required this.levelsConfig,

    this.isActive = true,
    this.isCombat = false,
    this.isMassStart = false,
    this.sortOrder = 100,
    this.description,

  });



  factory SportCatalogEntry.fromJson(Map<String, dynamic> json) {

    return SportCatalogEntry(

      name: json['name']?.toString() ?? '',

      family: json['family']?.toString(),

      participantType: json['participant_type']?.toString() ?? 'individual',

      scoringType: json['scoring_type']?.toString() ?? 'points',

      allowedFormats: _parseStringJsonArray(
        json['allowed_formats'],
        fallback: const ['1v1'],
      ),

      ratingCategories: _parseStringJsonArray(
        json['rating_categories'],
        fallback: const ['open'],
      ),

      ratingConfig: json['rating_config'] is Map

          ? Map<String, dynamic>.from(json['rating_config'] as Map)

          : {'model': 'level_rp', 'base_rp': 1000},

      levelsConfig: json['levels_config'] is List

          ? (json['levels_config'] as List)

              .map((e) => Map<String, dynamic>.from(e as Map))

              .toList()

          : [],

      isActive: json['is_active'] != false,
      isCombat: json['is_combat'] == true,
      isMassStart: json['is_mass_start'] == true,
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '100') ?? 100,

      description: json['description']?.toString(),

    );

  }



  static List<String> _parseStringJsonArray(
    dynamic raw, {
    required List<String> fallback,
  }) {
    if (raw == null) return fallback;
    if (raw is List) {
      final list =
          raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      return list.isEmpty ? fallback : list;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final list = decoded
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
          return list.isEmpty ? fallback : list;
        }
      } catch (_) {}
    }
    return fallback;
  }



  String get defaultRatingCategory =>

      ratingCategories.isNotEmpty ? ratingCategories.first : 'open';



  int get levelCount {

    if (levelsConfig.isEmpty) return 5;

    return levelsConfig.length;

  }



  int get maxLevelValue {

    if (levelsConfig.isEmpty) return 5;

    return levelsConfig

        .map((l) => int.tryParse(l['level_value']?.toString() ?? '1') ?? 1)

        .reduce((a, b) => a > b ? a : b);

  }

  Map<String, dynamic> toJsonMap() => {
        'name': name,
        'family': family,
        'participant_type': participantType,
        'scoring_type': scoringType,
        'allowed_formats': allowedFormats,
        'rating_config': ratingConfig,
        'rating_categories': ratingCategories,
        'levels_config': levelsConfig,
        'is_active': isActive,
        'sort_order': sortOrder,
        'description': description,
      };
}


