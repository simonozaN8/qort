import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_notification_service.dart';
import 'user_profile_loader.dart';

/// Ginčo pateikimas — DB RPC + organizatoriaus pranešimas.
class MatchDisputeService {
  MatchDisputeService._();

  static Future<void> submitDispute({
    required String matchId,
    required String reason,
    required String submittedByUserId,
  }) async {
    final client = Supabase.instance.client;
    final trimmed = reason.trim();
    if (trimmed.length < 10) {
      throw Exception('Skundo aprašymas per trumpas (min. 10 simbolių).');
    }

    final matchRow = await client
        .from('matches')
        .select('tournament_id')
        .eq('id', matchId)
        .maybeSingle();
    if (matchRow == null) {
      throw Exception('Mačas nerastas.');
    }

    final tournamentId = matchRow['tournament_id']?.toString();
    if (tournamentId == null || tournamentId.isEmpty) {
      throw Exception('Turnyras nerastas.');
    }

    final tRow = await client
        .from('tournaments')
        .select('owner_id')
        .eq('id', tournamentId)
        .maybeSingle();
    final organizerId = tRow?['owner_id']?.toString();

    await client.rpc('submit_match_dispute', params: {
      'p_match_id': matchId,
      'p_reason': trimmed,
    });

    final names = await UserProfileLoader.loadDisplayNames([submittedByUserId]);
    final playerName = names[submittedByUserId] ?? 'Žaidėjas';

    if (organizerId != null && organizerId.isNotEmpty) {
      await PushNotificationService.notifyOrganizerOfDispute(
        tournamentId: tournamentId,
        matchId: matchId,
        organizerUserId: organizerId,
        playerDisplayName: playerName,
        disputeReason: trimmed,
      );
    }
  }
}
