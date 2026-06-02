import 'package:flutter/material.dart';

/// Spalvų preset'ai turnyro cover preview / rodymui (matrix saugomas kode).
class TournamentCoverColorFilters {
  TournamentCoverColorFilters._();

  static const original = 'original';
  static const darkenLight = 'darken_light';
  static const darkenMedium = 'darken_medium';
  static const darkenHeavy = 'darken_heavy';
  static const brighten = 'brighten';

  static const presets = <String, String>{
    original: 'Originalas',
    darkenLight: 'Šiek tiek tamsiau',
    darkenMedium: 'Vidutiniškai tamsiau',
    darkenHeavy: 'Stipriai tamsiau',
    brighten: 'Pašviesinti',
  };

  static ColorFilter? filterForPreset(String? preset) {
    switch (preset) {
      case darkenLight:
        return const ColorFilter.matrix([
          0.85, 0, 0, 0, 0,
          0, 0.85, 0, 0, 0,
          0, 0, 0.85, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case darkenMedium:
        return const ColorFilter.matrix([
          0.65, 0, 0, 0, 0,
          0, 0.65, 0, 0, 0,
          0, 0, 0.65, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case darkenHeavy:
        return const ColorFilter.matrix([
          0.45, 0, 0, 0, 0,
          0, 0.45, 0, 0, 0,
          0, 0, 0.45, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case brighten:
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, 15,
          0, 1.2, 0, 0, 15,
          0, 0, 1.2, 0, 15,
          0, 0, 0, 1, 0,
        ]);
      case original:
      default:
        return null;
    }
  }

  static Widget filteredImage({
    required String imageUrl,
    required String? preset,
    required Widget Function(String url) imageBuilder,
  }) {
    final child = imageBuilder(imageUrl);
    final filter = filterForPreset(preset);

    Widget result = child;
    if (filter != null) {
      result = ColorFiltered(colorFilter: filter, child: result);
    }

    return result;
  }
}
