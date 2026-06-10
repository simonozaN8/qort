import 'package:supabase_flutter/supabase_flutter.dart';

/// Renginių būsenų lifecycle (DB funkcija + admin veiksmai).
class EventLifecycleService {
  EventLifecycleService._();

  static final _client = Supabase.instance.client;

  /// Paleidžia DB funkciją — atnaujina būsenas pagal start_date / end_date.
  static Future<void> updateLifecycle() async {
    await _client.rpc('update_event_lifecycle');
  }

  /// Nustato event + susietų turnyrų būseną (super admin).
  static Future<void> setEventStatus({
    required String eventId,
    required String status,
  }) async {
    await _client.from('events').update({'status': status}).eq('id', eventId);
    await _client
        .from('tournaments')
        .update({'status': status})
        .eq('event_id', eventId);
  }

  /// Standalone turnyras be event_id.
  static Future<void> setTournamentStatus({
    required String tournamentId,
    required String status,
  }) async {
    await _client
        .from('tournaments')
        .update({'status': status})
        .eq('id', tournamentId);
  }
}
