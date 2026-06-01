import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app ir (ateityje) FCM push pranešimai.
///
/// Dabar: įrašai į `user_notifications` (per DB RPC `submit_match_dispute`).
/// FCM / VAPID / Edge Function šiame projekte dar **neimplementuoti**.
class PushNotificationService {
  PushNotificationService._();

  /// Po sėkmingo gincho RPC — vieta būsimam FCM hook'ui.
  /// Galima prijungti Supabase Edge Function ant `user_notifications` INSERT.
  static Future<void> notifyOrganizerOfDispute({
    required String tournamentId,
    required String matchId,
    required String organizerUserId,
    required String playerDisplayName,
    required String disputeReason,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[PushNotificationService] dispute → organizer=$organizerUserId '
        'tournament=$tournamentId match=$matchId '
        'from=$playerDisplayName reason=${disputeReason.length > 60 ? '${disputeReason.substring(0, 60)}...' : disputeReason}',
      );
    }

    // FCM stub: kai bus device_tokens lentelė + Edge Function, kviesk čia:
    // await Supabase.instance.client.functions.invoke('send_push', body: {...});

    // In-app pranešimas jau sukurtas DB RPC viduje — nieko papildomai.
    await Future<void>.value();
  }

  /// Neperskaitytų in-app pranešimų skaičius.
  static Future<int> unreadCount(String userId) async {
    try {
      final rows = await Supabase.instance.client
          .from('user_notifications')
          .select('id')
          .eq('user_id', userId)
          .isFilter('read_at', null);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }
}
