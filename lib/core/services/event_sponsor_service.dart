import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class EventSponsor {
  final String id;
  final String eventId;
  final String logoUrl;
  final Uint8List? logoBytes; // draft preview (create flow)
  final String? name;
  final String? sponsorLabel;
  final String? websiteUrl;
  final bool isMain;
  final int displayOrder;

  EventSponsor({
    required this.id,
    required this.eventId,
    required this.logoUrl,
    this.logoBytes,
    this.name,
    this.sponsorLabel,
    this.websiteUrl,
    required this.isMain,
    required this.displayOrder,
  });

  factory EventSponsor.fromJson(Map<String, dynamic> j) {
    return EventSponsor(
      id: j['id']?.toString() ?? '',
      eventId: j['event_id']?.toString() ?? '',
      logoUrl: j['logo_url']?.toString() ?? '',
      name: j['name']?.toString(),
      sponsorLabel: j['sponsor_label']?.toString(),
      websiteUrl: j['website_url']?.toString(),
      isMain: j['is_main'] == true,
      displayOrder: (j['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class EventSponsorService {
  EventSponsorService._();

  static final _client = Supabase.instance.client;

  static Future<List<EventSponsor>> listByEvent(String eventId) async {
    final data = await _client
        .from('event_sponsors')
        .select('id, event_id, logo_url, name, sponsor_label, website_url, is_main, display_order, created_at')
        .eq('event_id', eventId)
        .order('display_order');
    return (data as List)
        .whereType<Map>()
        .map((j) => EventSponsor.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  static Future<EventSponsor> add({
    required String eventId,
    required String logoUrl,
    String? name,
    String? sponsorLabel,
    String? websiteUrl,
    bool isMain = false,
    required int displayOrder,
  }) async {
    final row = await _client
        .from('event_sponsors')
        .insert({
          'event_id': eventId,
          'logo_url': logoUrl,
          'name': name,
          'sponsor_label': sponsorLabel,
          'website_url': websiteUrl,
          'is_main': isMain,
          'display_order': displayOrder,
        })
        .select()
        .single();
    return EventSponsor.fromJson(Map<String, dynamic>.from(row as Map));
  }

  static Future<void> remove(String id) async {
    await _client.from('event_sponsors').delete().eq('id', id);
  }

  static Future<void> setMain(String id) async {
    await _client.from('event_sponsors').update({'is_main': true}).eq('id', id);
  }

  static Future<void> update(
    String id, {
    String? name,
    String? sponsorLabel,
    String? websiteUrl,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (sponsorLabel != null) payload['sponsor_label'] = sponsorLabel;
    if (websiteUrl != null) payload['website_url'] = websiteUrl;
    if (payload.isEmpty) return;
    await _client.from('event_sponsors').update(payload).eq('id', id);
  }
}

