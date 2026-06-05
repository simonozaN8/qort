import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/event_organizer_policy.dart';

class EventApprovalService {
  EventApprovalService._();

  static Future<List<Map<String, dynamic>>> fetchPendingEvents() async {
    final res = await Supabase.instance.client
        .from('events')
        .select()
        .eq('approval_status', EventOrganizerPolicy.approvalPending)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<void> approveEvent(String eventId, {String? adminNote}) async {
    final client = Supabase.instance.client;
    final reviewer = client.auth.currentUser?.id;

    await client
        .from('events')
        .update({
          'approval_status': EventOrganizerPolicy.approvalApproved,
          'status': 'open',
          'payment_status': EventOrganizerPolicy.paymentConfirmed,
          'admin_review_note': adminNote,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'reviewed_by': reviewer,
        })
        .eq('id', eventId);

    await client
        .from('tournaments')
        .update({'status': 'open'})
        .eq('event_id', eventId);
  }

  static Future<void> rejectEvent({
    required String eventId,
    required String reason,
  }) async {
    final client = Supabase.instance.client;
    final reviewer = client.auth.currentUser?.id;

    await client
        .from('events')
        .update({
          'approval_status': EventOrganizerPolicy.approvalRejected,
          'rejection_reason': reason,
          'admin_review_note': reason,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'reviewed_by': reviewer,
        })
        .eq('id', eventId);
  }
}
