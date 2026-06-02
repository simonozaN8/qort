import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Attribution privalomas Unsplash / Pexels / Pixabay (terms).
class StockImageAttribution extends StatelessWidget {
  final Map<String, dynamic> data;

  const StockImageAttribution({super.key, required this.data});

  static String capitalizeSource(String? source) {
    if (source == null || source.isEmpty) return '';
    if (source.length == 1) return source.toUpperCase();
    return source[0].toUpperCase() + source.substring(1);
  }

  static bool shouldShow(Map<String, dynamic> data) {
    final src = data['image_source']?.toString();
    return src != null && src.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow(data)) return const SizedBox.shrink();

    final photographer = data['image_photographer']?.toString() ?? 'Unknown';
    final source = capitalizeSource(data['image_source']?.toString());
    final sourceUrl = data['image_source_url']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: sourceUrl != null && sourceUrl.isNotEmpty
            ? () async {
                final uri = Uri.tryParse(sourceUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            : null,
        child: Text(
          'Photo by $photographer · $source',
          style: const TextStyle(fontSize: 10, color: Colors.white54),
        ),
      ),
    );
  }
}
