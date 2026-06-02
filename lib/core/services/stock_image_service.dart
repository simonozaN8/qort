import 'package:supabase_flutter/supabase_flutter.dart';

class StockImage {
  final String imageUrl;
  final String thumbUrl;
  final String photographer;
  final String source;
  final String sourceUrl;
  final int width;
  final int height;

  StockImage({
    required this.imageUrl,
    required this.thumbUrl,
    required this.photographer,
    required this.source,
    required this.sourceUrl,
    required this.width,
    required this.height,
  });

  factory StockImage.fromJson(Map<String, dynamic> j) {
    return StockImage(
      imageUrl: j['image_url']?.toString() ?? '',
      thumbUrl: j['thumb_url']?.toString() ?? '',
      photographer: j['photographer']?.toString() ?? '',
      source: j['source']?.toString() ?? '',
      sourceUrl: j['source_url']?.toString() ?? '',
      width: (j['width'] as num?)?.toInt() ?? 0,
      height: (j['height'] as num?)?.toInt() ?? 0,
    );
  }
}

class StockImageService {
  StockImageService._();

  static final _client = Supabase.instance.client;

  static Future<List<StockImage>> search({
    required String sportCode,
    String? customQuery,
    int page = 1,
  }) async {
    final response = await _client.functions.invoke(
      'search-tournament-images',
      body: {
        'sport_code': sportCode,
        if (customQuery != null && customQuery.isNotEmpty)
          'custom_query': customQuery,
        'page': page,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      throw Exception('search failed: $data');
    }

    final data = response.data;
    if (data is! Map) {
      throw Exception('Unexpected search response: $data');
    }

    final images = (data['images'] as List?) ?? [];
    return images
        .whereType<Map>()
        .map((i) => StockImage.fromJson(Map<String, dynamic>.from(i)))
        .toList();
  }
}
