import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Laiko/vietos pasiūlymai mačams — viena vieta vietoj tiesioginių Supabase kvietimų ekranuose.
class MatchProposalService {
  MatchProposalService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> submitProposal({
    required String matchId,
    required String proposerId,
    required DateTime dateTime,
    required String location,
  }) async {
    await _client.from('matches').update({
      'proposed_date': dateTime.toIso8601String(),
      'proposed_location': location,
      'proposer_id': proposerId,
      'is_proposal_active': true,
    }).eq('id', matchId);

    await _client.from('match_chat').insert({
      'match_id': matchId,
      'user_id': proposerId,
      'content':
          "📅 Pasiūlė laiką: ${DateFormat('MM-dd HH:mm').format(dateTime)} @ $location",
    });
  }

  static Future<int> submitBulkProposals({
    required List<String> matchIds,
    required String proposerId,
    required DateTime dateTime,
    required String location,
  }) async {
    var sent = 0;
    for (final matchId in matchIds) {
      await submitProposal(
        matchId: matchId,
        proposerId: proposerId,
        dateTime: dateTime,
        location: location,
      );
      sent++;
    }
    return sent;
  }

  static Future<void> acceptProposal({
    required String matchId,
    required String userId,
    required DateTime proposedDate,
    required String? proposedLocation,
  }) async {
    await _client.from('matches').update({
      'match_date': proposedDate.toIso8601String(),
      'location': proposedLocation,
      'is_proposal_active': false,
      'proposed_date': null,
      'status': 'scheduled',
    }).eq('id', matchId);

    await _client.from('match_chat').insert({
      'match_id': matchId,
      'user_id': userId,
      'content': "✅ Sutiko su laiku! Sėkmės mače.",
    });
  }

  static Future<void> rejectProposal({
    required String matchId,
    required String userId,
  }) async {
    await _client.from('matches').update({
      'is_proposal_active': false,
      'proposed_date': null,
    }).eq('id', matchId);

    await _client.from('match_chat').insert({
      'match_id': matchId,
      'user_id': userId,
      'content': "❌ Netinka laikas. Siūlau derinti kitą.",
    });
  }
}
