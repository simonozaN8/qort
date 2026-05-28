import '../models/sport_catalog_entry.dart';

/// Lygių pavadinimai iš `sports_catalog.levels_config`.
class SportLevels {
  SportLevels._();

  static List<Map<String, dynamic>> rows(SportCatalogEntry? entry) {
    if (entry == null || entry.levelsConfig.isEmpty) {
      return List.generate(
        5,
        (i) => {
          'level_value': i + 1,
          'name': 'Lygis ${i + 1}',
          'desc': '',
        },
      );
    }
    return List<Map<String, dynamic>>.from(entry.levelsConfig);
  }

  static double minValue(SportCatalogEntry? entry) {
    final r = rows(entry);
    return (r.first['level_value'] as num?)?.toDouble() ?? 1;
  }

  static double maxValue(SportCatalogEntry? entry) {
    final r = rows(entry);
    return (r.last['level_value'] as num?)?.toDouble() ?? 5;
  }

  static String nameFor(SportCatalogEntry? entry, int levelValue) {
    final r = rows(entry);
    for (final row in r) {
      if ((row['level_value'] as num?)?.toInt() == levelValue) {
        final n = row['name']?.toString();
        if (n != null && n.isNotEmpty) return n;
      }
    }
    return 'Lygis $levelValue';
  }

  static String rangeLabel(SportCatalogEntry? entry, int minV, int maxV) {
    if (minV == maxV) return nameFor(entry, minV);
    return '${nameFor(entry, minV)} – ${nameFor(entry, maxV)}';
  }

  static String descFor(SportCatalogEntry? entry, int levelValue) {
    final r = rows(entry);
    for (final row in r) {
      if ((row['level_value'] as num?)?.toInt() == levelValue) {
        return row['desc']?.toString() ?? '';
      }
    }
    return '';
  }

  static SportCatalogEntry? entryFromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    try {
      return SportCatalogEntry.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// RP viršutinė riba pagal `rating_config.level_rp_caps`.
  static int maxRpForLevel(SportCatalogEntry? entry, int levelValue) {
    final caps = entry?.ratingConfig['level_rp_caps'];
    if (caps is List && caps.isNotEmpty) {
      final idx = levelValue - 1;
      if (idx >= 0 && idx < caps.length) {
        return (caps[idx] as num).toInt();
      }
      return (caps.last as num).toInt();
    }
    const fallback = [1000, 1500, 2000, 2500, 3000];
    final idx = (levelValue - 1).clamp(0, fallback.length - 1);
    return fallback[idx];
  }
}
