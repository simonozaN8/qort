import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/event_organizer_policy.dart';
import '../../core/services/event_approval_service.dart';
import '../../core/theme/qort_colors.dart';
import '../tournament/event_detail_screen.dart';
import 'create_tournament_screen.dart';

class TournamentDraftPreviewScreen extends StatefulWidget {
  final String eventId;
  final bool superAdminMode;

  const TournamentDraftPreviewScreen({
    super.key,
    required this.eventId,
    this.superAdminMode = false,
  });

  @override
  State<TournamentDraftPreviewScreen> createState() =>
      _TournamentDraftPreviewScreenState();
}

class _TournamentDraftPreviewScreenState
    extends State<TournamentDraftPreviewScreen> {
  String _approvalStatus = EventOrganizerPolicy.approvalDraft;
  String? _rejectionReason;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('events')
          .select('approval_status, rejection_reason')
          .eq('id', widget.eventId)
          .single();
      if (mounted) {
        setState(() {
          _approvalStatus =
              data['approval_status']?.toString() ??
                  EventOrganizerPolicy.approvalDraft;
          _rejectionReason = data['rejection_reason']?.toString();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusBanner(String status) {
    if (widget.superAdminMode) {
      return 'SUPER ADMIN PERŽIŪRA — patikrink turnyrą ir patvirtink arba atmink.';
    }
    switch (status) {
      case EventOrganizerPolicy.approvalDraft:
        return 'ŠIS TURNYRAS YRA DRAFT\'AS — matomas tik tau. Patikrink ir spausk „PUBLIKUOTI".';
      case EventOrganizerPolicy.approvalPending:
        return 'LAUKIA SUPER ADMIN TVIRTINIMO. Tavo turnyras pateiktas peržiūrai.';
      case EventOrganizerPolicy.approvalRejected:
        return 'TURNYRAS ATMESTAS. Pataisyk ir publikuok iš naujo.';
      case EventOrganizerPolicy.approvalApproved:
        return 'TURNYRAS PATVIRTINTAS — MATOMAS VIEŠAI ✓';
    }
    return '';
  }

  Future<void> _editTournament() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEventScreen(editEventId: widget.eventId),
      ),
    );
    await _reload();
  }

  Future<void> _publishTournament() async {
    if (_approvalStatus == EventOrganizerPolicy.approvalPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turnyras jau laukia tvirtinimo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_approvalStatus == EventOrganizerPolicy.approvalApproved) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Publikuoti turnyrą?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Po publikavimo super admin tikrins ar turnyras atitinka taisykles. '
          'Patvirtinimas paprastai užtrunka iki 24 val.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Atšaukti'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEAB308),
            ),
            child: const Text(
              'Publikuoti',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await Supabase.instance.client.from('events').update({
      'approval_status': EventOrganizerPolicy.approvalPending,
      'rejection_reason': null,
    }).eq('id', widget.eventId);

    await _reload();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turnyras pateiktas tvirtinimui'),
          backgroundColor: Color(0xFFEAB308),
        ),
      );
    }
  }

  Future<void> _approveAsAdmin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Patvirtinti turnyrą?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Turnyras taps viešai matomas.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Atšaukti'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Patvirtinti'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await EventApprovalService.approveEvent(widget.eventId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Klaida: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectAsAdmin() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Atmesti turnyrą',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Įvesk priežastį — organizatorius matys ją.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText:
                    'Pvz. Neaiškios taisyklės, netinkamas pavadinimas...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Atšaukti'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Atmesti'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      reasonCtrl.dispose();
      return;
    }

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (reason.isEmpty) return;

    try {
      await EventApprovalService.rejectEvent(
        eventId: widget.eventId,
        reason: reason,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Klaida: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildOwnerButtons() {
    final isApproved = _approvalStatus == EventOrganizerPolicy.approvalApproved;
    final isPending = _approvalStatus == EventOrganizerPolicy.approvalPending;
    final canPublish = !isApproved && !isPending;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _editTournament,
            child: const Text('Redaguoti'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: canPublish ? _publishTournament : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEAB308),
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFF3F3F46),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              isPending
                  ? 'LAUKIA TVIRTINIMO'
                  : _approvalStatus == EventOrganizerPolicy.approvalRejected
                      ? 'PUBLIKUOTI IŠ NAUJO'
                      : 'PUBLIKUOTI - SIŲSTI TVIRTINTI',
              style: const TextStyle(
                fontFamily: 'Anton',
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuperAdminButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _rejectAsAdmin,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'ATMESTI',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'Anton',
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _approveAsAdmin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'PATVIRTINTI - PUBLIKUOTI',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Anton',
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = _approvalStatus == EventOrganizerPolicy.approvalApproved;
    final showBottomBar = widget.superAdminMode || !isApproved;

    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: QortColors.surface,
        foregroundColor: QortColors.textPrimary,
        title: Text(
          widget.superAdminMode ? 'Admin peržiūra' : 'Peržiūra',
          style: GoogleFonts.bebasNeue(fontSize: 22, letterSpacing: 1),
        ),
      ),
      body: Column(
        children: [
          if (_loading)
            const LinearProgressIndicator(
              color: Color(0xFFEAB308),
              minHeight: 2,
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFEAB308).withValues(alpha: 0.15),
            child: Row(
              children: [
                Icon(
                  widget.superAdminMode
                      ? LucideIcons.shieldAlert
                      : LucideIcons.fileText,
                  color: const Color(0xFFEAB308),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusBanner(_approvalStatus),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          if (!widget.superAdminMode &&
              _approvalStatus == EventOrganizerPolicy.approvalRejected &&
              _rejectionReason != null &&
              _rejectionReason!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade900.withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SUPER ADMIN KOMENTARAS:',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _rejectionReason!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: EventDetailScreen(
              event: {'id': widget.eventId},
              previewMode: true,
            ),
          ),
        ],
      ),
      bottomNavigationBar: showBottomBar
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: widget.superAdminMode
                    ? _buildSuperAdminButtons()
                    : _buildOwnerButtons(),
              ),
            )
          : null,
    );
  }
}
