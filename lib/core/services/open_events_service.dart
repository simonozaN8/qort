import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/event_organizer_policy.dart';
import '../constants/query_limits.dart';

/// Rikiavimo režimas turnyrų / renginių kalendoriui.
enum OpenEventsSortMode {
  /// Naujausi viršuje (created_at DESC).
  newest,

  /// Artimiausi viršuje (start_date ASC); tik start_date >= šiandien.
  soonest,

  /// Daugiausiai registracijų (participants_count DESC).
  mostPopular,
}

/// Vieši atviri renginiai ir turnyrai (kalendorius / „Atrask“).
class OpenEventsService {
  OpenEventsService._();

  static const _eventsSelect = '''
      id, created_at, owner_id,
      name, sport, location, description, organizer,
      organizer_email, organizer_phone,
      image_url, image_flip_horizontal, cover_filter_preset, start_date, end_date,
      status, approval_status, registration_deadline,
      tournaments(id, name, format_code, gender, min_rp, max_rp, entry_fee),
      event_sponsors(id, logo_url, name, sponsor_label, website_url, is_main, display_order),
      pricing_tiers(id, event_id, name, price, valid_until, display_order)
    ''';

  static Future<List<dynamic>> loadOpenEvents({
    int limit = QueryLimits.tournamentList,
    OpenEventsSortMode sortMode = OpenEventsSortMode.newest,
  }) async {
    final client = Supabase.instance.client;

    final eventsBase = client.from('events').select(_eventsSelect).eq(
          'status',
          'open',
        ).eq(
          'approval_status',
          EventOrganizerPolicy.approvalApproved,
        );

    final tournamentsBase = client.from('tournaments').select().eq(
          'status',
          'open',
        );

    final List<dynamic> eventsRes;
    final List<dynamic> tournamentsRes;

    switch (sortMode) {
      case OpenEventsSortMode.newest:
      case OpenEventsSortMode.mostPopular:
        eventsRes = await eventsBase.order('created_at', ascending: false).limit(
              limit,
            );
        tournamentsRes = await tournamentsBase
            .order('created_at', ascending: false)
            .limit(limit);
        break;
      case OpenEventsSortMode.soonest:
        final today = DateTime.now().toIso8601String().substring(0, 10);
        eventsRes = await eventsBase
            .gte('start_date', today)
            .order('start_date', ascending: true, nullsFirst: false)
            .limit(limit);
        tournamentsRes = await tournamentsBase
            .gte('start_date', today)
            .order('start_date', ascending: true, nullsFirst: false)
            .limit(limit);
        break;
    }

    final tournamentIds = <String>{};
    for (final event in eventsRes) {
      if (event is! Map) continue;
      for (final t in (event['tournaments'] as List? ?? [])) {
        if (t is Map && t['id'] != null) {
          tournamentIds.add(t['id'].toString());
        }
      }
    }
    for (final t in tournamentsRes) {
      if (t is Map && t['id'] != null) {
        tournamentIds.add(t['id'].toString());
      }
    }

    final counts = await _loadParticipantCounts(client, tournamentIds.toList());
    _attachParticipantsCounts(eventsRes, counts, isEventList: true);
    _attachParticipantsCounts(tournamentsRes, counts, isEventList: false);

    final combined = <dynamic>[];

    final filteredEvents = eventsRes.where((e) {
      final tournaments = e['tournaments'] as List?;
      return tournaments != null && tournaments.isNotEmpty;
    }).toList();

    for (final e in filteredEvents) {
      e['is_parent_event'] = true;
      combined.add(e);
    }

    for (final t in tournamentsRes) {
      if (t['event_id'] == null) {
        t['is_parent_event'] = false;
        combined.add(t);
      }
    }

    combined.sort((a, b) => _compare(a, b, sortMode));

    if (combined.length > limit) {
      return combined.sublist(0, limit);
    }
    return combined;
  }

  static Future<Map<String, int>> _loadParticipantCounts(
    SupabaseClient client,
    List<String> tournamentIds,
  ) async {
    if (tournamentIds.isEmpty) return {};

    final data = await client
        .from('tournament_participants')
        .select('tournament_id')
        .inFilter('tournament_id', tournamentIds);

    final counts = <String, int>{};
    for (final row in data) {
      final tid = row['tournament_id']?.toString();
      if (tid != null) {
        counts[tid] = (counts[tid] ?? 0) + 1;
      }
    }
    return counts;
  }

  static void _attachParticipantsCounts(
    List<dynamic> items,
    Map<String, int> counts, {
    required bool isEventList,
  }) {
    for (final item in items) {
      if (item is! Map) continue;
      if (isEventList) {
        var total = 0;
        for (final t in (item['tournaments'] as List? ?? [])) {
          if (t is Map) {
            total += counts[t['id']?.toString()] ?? 0;
          }
        }
        item['participants_count'] = total;
      } else {
        item['participants_count'] = counts[item['id']?.toString()] ?? 0;
      }
    }
  }

  static int _compare(
    dynamic a,
    dynamic b,
    OpenEventsSortMode sortMode,
  ) {
    switch (sortMode) {
      case OpenEventsSortMode.newest:
        final dateA = a['created_at']?.toString() ?? '';
        final dateB = b['created_at']?.toString() ?? '';
        return dateB.compareTo(dateA);
      case OpenEventsSortMode.soonest:
        final startA = a['start_date']?.toString();
        final startB = b['start_date']?.toString();
        final aMissing = startA == null || startA.isEmpty;
        final bMissing = startB == null || startB.isEmpty;
        if (aMissing && bMissing) return 0;
        if (aMissing) return 1;
        if (bMissing) return -1;
        return startA.compareTo(startB);
      case OpenEventsSortMode.mostPopular:
        final countA = (a['participants_count'] as num?)?.toInt() ?? 0;
        final countB = (b['participants_count'] as num?)?.toInt() ?? 0;
        return countB.compareTo(countA);
    }
  }
}
