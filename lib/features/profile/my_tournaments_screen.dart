import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/event_organizer_policy.dart';
import '../../core/theme/qort_colors.dart';
import '../admin/tournament_draft_preview_screen.dart';
import '../tournament/event_detail_screen.dart';

class MyTournamentsScreen extends StatefulWidget {
  const MyTournamentsScreen({super.key});

  @override
  State<MyTournamentsScreen> createState() => _MyTournamentsScreenState();
}

class _MyTournamentsScreenState extends State<MyTournamentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  static const _tabs = [
    ('Visi', null),
    ('Draft', EventOrganizerPolicy.approvalDraft),
    ('Laukia', EventOrganizerPolicy.approvalPending),
    ('Patvirtinti', EventOrganizerPolicy.approvalApproved),
    ('Atmesti', EventOrganizerPolicy.approvalRejected),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadMyEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyEvents() async {
    setState(() => _loading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final data = await Supabase.instance.client
          .from('events')
          .select('*, tournaments(*)')
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _events = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredEvents {
    final filter = _tabs[_tabController.index].$2;
    if (filter == null) return _events;
    return _events
        .where((e) => e['approval_status']?.toString() == filter)
        .toList();
  }

  void _openEvent(Map<String, dynamic> event) {
    final id = event['id']?.toString();
    if (id == null) return;

    final status = event['approval_status']?.toString();
    if (status == EventOrganizerPolicy.approvalApproved) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TournamentDraftPreviewScreen(eventId: id),
        ),
      );
    }
  }

  (Color, String) _statusBadge(String? status) {
    switch (status) {
      case EventOrganizerPolicy.approvalDraft:
        return (Colors.grey, 'Draft');
      case EventOrganizerPolicy.approvalPending:
        return (const Color(0xFFEAB308), 'Laukia');
      case EventOrganizerPolicy.approvalApproved:
        return (Colors.greenAccent, 'Patvirtintas');
      case EventOrganizerPolicy.approvalRejected:
        return (Colors.redAccent, 'Atmestas');
      default:
        return (Colors.grey, status ?? '—');
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEvents;

    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: QortColors.surface,
        foregroundColor: QortColors.textPrimary,
        title: Text(
          'Mano turnyrai',
          style: GoogleFonts.bebasNeue(fontSize: 24, letterSpacing: 1),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFFEAB308),
          labelColor: const Color(0xFFEAB308),
          unselectedLabelColor: QortColors.textSecondary,
          tabs: _tabs.map((t) => Tab(text: t.$1)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadMyEvents,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFEAB308)),
            )
          : filtered.isEmpty
              ? Center(
                  child: Text(
                    'Turnyrų nėra',
                    style: TextStyle(color: QortColors.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMyEvents,
                  color: const Color(0xFFEAB308),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final event = filtered[index];
                      final (badgeColor, badgeLabel) = _statusBadge(
                        event['approval_status']?.toString(),
                      );

                      return Card(
                        color: QortColors.surface,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: QortColors.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            event['name']?.toString() ?? 'Be pavadinimo',
                            style: const TextStyle(
                              color: QortColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${event['sport'] ?? '—'} · '
                                  '${_formatDate(event['start_date'])} → '
                                  '${_formatDate(event['end_date'])}',
                                  style: const TextStyle(
                                    color: QortColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: badgeColor.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevronRight,
                            color: QortColors.textSecondary,
                          ),
                          onTap: () => _openEvent(event),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
