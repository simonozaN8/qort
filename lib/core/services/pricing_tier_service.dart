import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/datetime_utils.dart';

class PricingTier {
  final String id;
  final String eventId;
  final String name;
  final double price;
  final DateTime? validUntil;
  final int displayOrder;

  PricingTier({
    required this.id,
    required this.eventId,
    required this.name,
    required this.price,
    this.validUntil,
    required this.displayOrder,
  });

  factory PricingTier.fromJson(Map<String, dynamic> j) {
    DateTime? validUntil;
    final rawUntil = j['valid_until'];
    if (rawUntil != null) {
      validUntil = DateTimeUtils.fromIso(rawUntil.toString());
    }
    return PricingTier(
      id: j['id']?.toString() ?? '',
      eventId: j['event_id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      price: (j['price'] as num?)?.toDouble() ?? 0,
      validUntil: validUntil,
      displayOrder: (j['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'name': name,
        'price': price,
        if (validUntil != null)
          'valid_until': DateTimeUtils.toIsoUtc(validUntil!),
        'display_order': displayOrder,
      };

  bool isActive() {
    if (validUntil == null) return true;
    return DateTime.now().isBefore(validUntil!);
  }

  bool isExpired() {
    if (validUntil == null) return false;
    return DateTime.now().isAfter(validUntil!);
  }
}

class PricingTierService {
  PricingTierService._();

  static final _client = Supabase.instance.client;

  static List<PricingTier> parseList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((j) => PricingTier.fromJson(Map<String, dynamic>.from(j)))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// Pakopos iš renginio JSON arba sintetinė „Įprasta“ iš pirmo turnyro entry_fee.
  static List<PricingTier> resolveForEvent(
    Map<String, dynamic> event, {
    String? eventIdOverride,
  }) {
    final fromDb = parseList(event['pricing_tiers']);
    if (fromDb.isNotEmpty) return fromDb;

    final eventId = eventIdOverride ?? event['id']?.toString() ?? '';
    final tournaments = event['tournaments'];
    if (tournaments is! List || tournaments.isEmpty) return [];

    final first = tournaments.first;
    if (first is! Map) return [];
    final fee = (first['entry_fee'] as num?)?.toDouble();
    if (fee == null) return [];

    return [
      PricingTier(
        id: '',
        eventId: eventId,
        name: 'Įprasta',
        price: fee,
        validUntil: null,
        displayOrder: 0,
      ),
    ];
  }

  /// Pagrindinė rodoma kaina — pigiausia tarp šiuo metu aktyvių pakopų.
  static double? currentPrice(List<PricingTier> tiers) {
    return getEffectiveTier(tiers)?.price;
  }

  /// Pigiausia aktyvi pakopa (Early Bird laimi prieš Įprastą).
  static PricingTier? getEffectiveTier(List<PricingTier> tiers) {
    if (tiers.isEmpty) return null;

    final now = DateTime.now();
    final active = tiers.where((t) {
      if (t.validUntil == null) return true;
      return t.validUntil!.isAfter(now);
    }).toList();

    if (active.isEmpty) {
      final sorted = [...tiers]
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return sorted.last;
    }

    active.sort((a, b) => a.price.compareTo(b.price));
    return active.first;
  }

  static Future<List<PricingTier>> listByEvent(String eventId) async {
    final data = await _client
        .from('pricing_tiers')
        .select()
        .eq('event_id', eventId)
        .order('display_order');
    return parseList(data);
  }

  static Future<PricingTier> add({
    required String eventId,
    required String name,
    required double price,
    DateTime? validUntil,
    required int displayOrder,
  }) async {
    final payload = <String, dynamic>{
      'event_id': eventId,
      'name': name,
      'price': price,
      'display_order': displayOrder,
    };
    if (validUntil != null) {
      payload['valid_until'] = DateTimeUtils.toIsoUtc(validUntil);
    }
    final row = await _client.from('pricing_tiers').insert(payload).select().single();
    return PricingTier.fromJson(Map<String, dynamic>.from(row as Map));
  }

  static Future<void> update({
    required String id,
    String? name,
    double? price,
    DateTime? validUntil,
    bool clearValidUntil = false,
    int? displayOrder,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (price != null) payload['price'] = price;
    if (displayOrder != null) payload['display_order'] = displayOrder;
    if (clearValidUntil) {
      payload['valid_until'] = null;
    } else if (validUntil != null) {
      payload['valid_until'] = DateTimeUtils.toIsoUtc(validUntil);
    }
    if (payload.isEmpty) return;
    await _client.from('pricing_tiers').update(payload).eq('id', id);
  }

  static Future<void> remove(String id) async {
    await _client.from('pricing_tiers').delete().eq('id', id);
  }

  static Future<void> updateEventRegistrationDeadline({
    required String eventId,
    DateTime? deadline,
    bool clear = false,
  }) async {
    await _client.from('events').update({
      if (clear) 'registration_deadline': null else if (deadline != null)
        'registration_deadline': DateTimeUtils.toIsoUtc(deadline),
    }).eq('id', eventId);
  }

  /// Aktyvi pakopa chronologine tvarka (pirma pagal display_order su galiojančia data).
  /// Rodomai „pagrindinei“ kainai naudok [getEffectiveTier].
  static PricingTier? getCurrentTier(List<PricingTier> tiers) {
    return getEffectiveTier(tiers);
  }
}
