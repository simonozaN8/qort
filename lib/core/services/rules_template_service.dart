import 'package:supabase_flutter/supabase_flutter.dart';

class RulesTemplate {
  final String id;
  final String sport;
  final String language;
  final String title;
  final String content;
  final bool isDefault;
  final int version;

  RulesTemplate({
    required this.id,
    required this.sport,
    required this.language,
    required this.title,
    required this.content,
    required this.isDefault,
    required this.version,
  });

  factory RulesTemplate.fromJson(Map<String, dynamic> j) {
    return RulesTemplate(
      id: j['id']?.toString() ?? '',
      sport: j['sport']?.toString() ?? '',
      language: j['language']?.toString() ?? 'lt',
      title: j['title']?.toString() ?? '',
      content: j['content']?.toString() ?? '',
      isDefault: j['is_default'] == true,
      version: (j['version'] as num?)?.toInt() ?? 1,
    );
  }
}

class RulesTemplateService {
  RulesTemplateService._();

  static final _client = Supabase.instance.client;

  /// Mapina QORT sporto pavadinimą į template sport code'ą.
  static String sportToCode(String sportName) {
    final lower = sportName.toLowerCase().trim();
    switch (lower) {
      case 'tenisas':
        return 'tennis';
      case 'padelis':
        return 'padel';
      case 'badmintonas':
        return 'badminton';
      case 'pickleball':
        return 'pickleball';
      case 'skvošas':
        return 'squash';
      case 'stalo tenisas':
        return 'table_tennis';
      case 'paplūdimio tenisas':
        return 'beach_tennis';
      default:
        return lower.replaceAll(' ', '_');
    }
  }

  static Future<List<RulesTemplate>> listForSport(
    String sport, {
    String language = 'lt',
  }) async {
    try {
      final data = await _client
          .from('rules_templates')
          .select()
          .eq('sport', sportToCode(sport))
          .eq('language', language)
          .order('is_default', ascending: false);
      return (data as List)
          .whereType<Map>()
          .map((j) => RulesTemplate.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<RulesTemplate?> getDefaultForSport(
    String sport, {
    String language = 'lt',
  }) async {
    try {
      final data = await _client
          .from('rules_templates')
          .select()
          .eq('sport', sportToCode(sport))
          .eq('language', language)
          .eq('is_default', true)
          .maybeSingle();
      if (data == null) return null;
      return RulesTemplate.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      return null;
    }
  }
}
