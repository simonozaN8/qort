import 'package:supabase_flutter/supabase_flutter.dart';

class SportImageTemplate {
  final String id;
  final String sportCode;
  final String imageUrl;
  final String aspectRatio;
  final String? styleTag;

  SportImageTemplate({
    required this.id,
    required this.sportCode,
    required this.imageUrl,
    required this.aspectRatio,
    this.styleTag,
  });

  factory SportImageTemplate.fromJson(Map<String, dynamic> j) {
    return SportImageTemplate(
      id: j['id']?.toString() ?? '',
      sportCode: j['sport_code']?.toString() ?? '',
      imageUrl: j['image_url']?.toString() ?? '',
      aspectRatio: j['aspect_ratio']?.toString() ?? '16:9',
      styleTag: j['style_tag']?.toString(),
    );
  }
}

class ImageGenerationQuota {
  final int used;
  final int limit;
  final bool isSuperAdmin;

  const ImageGenerationQuota({
    required this.used,
    required this.limit,
    required this.isSuperAdmin,
  });

  factory ImageGenerationQuota.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return const ImageGenerationQuota(used: 0, limit: 3, isSuperAdmin: false);
    }
    return ImageGenerationQuota(
      used: (j['used'] as num?)?.toInt() ?? 0,
      limit: (j['limit'] as num?)?.toInt() ?? 3,
      isSuperAdmin: j['is_super_admin'] == true,
    );
  }

  bool get canGenerate => isSuperAdmin || used < limit;

  String get label {
    if (isSuperAdmin) return 'Super-admin: be limitų';
    return 'Generavimai šiandien: $used / $limit';
  }
}

class SportImagePoolResult {
  final List<SportImageTemplate> templates;
  final ImageGenerationQuota quota;

  const SportImagePoolResult({
    required this.templates,
    required this.quota,
  });
}

class SportImageService {
  SportImageService._();

  static final _client = Supabase.instance.client;

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Unexpected response: $data');
  }

  static void _ensureOk(FunctionResponse response) {
    final data = response.data;
    if (response.status != 200) {
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      throw Exception('Edge function failed (${response.status}): $data');
    }
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }

  static List<SportImageTemplate> _parseTemplates(List? raw) {
    return (raw ?? [])
        .whereType<Map>()
        .map((t) => SportImageTemplate.fromJson(Map<String, dynamic>.from(t)))
        .toList();
  }

  static SportImagePoolResult _parseResult(Map<String, dynamic> json) {
    return SportImagePoolResult(
      templates: _parseTemplates(json['templates'] as List?),
      quota: ImageGenerationQuota.fromJson(
        json['quota'] is Map
            ? Map<String, dynamic>.from(json['quota'] as Map)
            : null,
      ),
    );
  }

  /// Esami cache vaizdai sporto šakai (LT pavadinimas, pvz. „Tenisas“).
  static Future<SportImagePoolResult> listPool(String sportCode) async {
    final response = await _client.functions.invoke(
      'generate-tournament-images',
      body: {'mode': 'list_pool', 'sport_code': sportCode},
    );

    _ensureOk(response);
    return _parseResult(_asMap(response.data));
  }

  /// Sugeneruoja 3 naujus variantus į cache (Gemini ~20–30 s).
  static Future<SportImagePoolResult> generatePool(String sportCode) async {
    final response = await _client.functions.invoke(
      'generate-tournament-images',
      body: {'mode': 'pool_generate', 'sport_code': sportCode},
    );

    if (response.status == 429) {
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      throw Exception('Pasiektas dienos generavimo limitas (429)');
    }

    _ensureOk(response);
    return _parseResult(_asMap(response.data));
  }
}
