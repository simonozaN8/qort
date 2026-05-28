import 'package:supabase_flutter/supabase_flutter.dart';



import '../models/sport_catalog_entry.dart';



/// Užkrauna ir cache'ina `sports_catalog` (Fazė 1).

class SportsCatalogService {

  static List<SportCatalogEntry>? _cache;

  static DateTime? _cachedAt;

  static const _cacheTtl = Duration(minutes: 10);



  static Future<List<SportCatalogEntry>> fetchActive({bool force = false}) async {

    if (!force &&

        _cache != null &&

        _cachedAt != null &&

        DateTime.now().difference(_cachedAt!) < _cacheTtl) {

      return _cache!;

    }



    final res = await Supabase.instance.client

        .from('sports_catalog')

        .select()

        .eq('is_active', true)

        .order('sort_order', ascending: true)

        .order('name', ascending: true);



    final list = (res as List)
        .map((row) => SportCatalogEntry.fromJson(Map<String, dynamic>.from(row)))
        .where((s) => !s.isCombat && !s.isMassStart)
        .toList();

    _cache = list;

    _cachedAt = DateTime.now();

    return list;

  }



  static Future<SportCatalogEntry?> byName(String name) async {

    final all = await fetchActive();

    try {

      return all.firstWhere((s) => s.name == name);

    } catch (_) {

      return null;

    }

  }



  static Future<List<String>> activeSportNames() async {

    final all = await fetchActive();

    return all.map((s) => s.name).toList();

  }



  static Future<Map<String, List<SportCatalogEntry>>> byFamily() async {

    final all = await fetchActive();

    final map = <String, List<SportCatalogEntry>>{};

    for (final s in all) {

      final key = s.family ?? 'Kita';

      map.putIfAbsent(key, () => []).add(s);

    }

    return map;

  }



  static Future<List<Map<String, dynamic>>> fetchActiveMaps({
    bool force = false,
  }) async {
    final all = await fetchActive(force: force);
    return all.map((e) => e.toJsonMap()).toList();
  }

  static void invalidateCache() => _cache = null;
}


