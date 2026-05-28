import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/event_organizer_policy.dart';
import '../../core/constants/query_limits.dart';
import '../../core/services/event_approval_service.dart';

// Įsitikinkite, kad šie failai yra tame pačiame aplanke
import 'create_tournament_screen.dart';
import 'admin_tournament_control_screen.dart';
import '../design/design_variants_screen.dart';
import '../../core/theme/qort_palette_extension.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> _tournaments = [];
  List<Map<String, dynamic>> _pendingEvents = [];
  Map<String, String> _ownerLabels = {};
  bool _isLoading = true;
  bool _loadingPending = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadTournaments(), _loadPendingEvents()]);
  }

  Future<void> _loadPendingEvents() async {
    setState(() => _loadingPending = true);
    try {
      final events = await EventApprovalService.fetchPendingEvents();
      final ownerIds = events
          .map((e) => e['owner_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final labels = <String, String>{};
      if (ownerIds.isNotEmpty) {
        final profiles = await Supabase.instance.client
            .from('profiles')
            .select('id, nickname, name, surname')
            .inFilter('id', ownerIds);
        for (final p in profiles as List) {
          final id = p['id']?.toString();
          if (id == null) continue;
          final nick = p['nickname']?.toString();
          if (nick != null && nick.isNotEmpty) {
            labels[id] = nick;
          } else {
            final parts = [p['name'], p['surname']]
                .whereType<String>()
                .where((s) => s.isNotEmpty);
            labels[id] = parts.isEmpty ? id.substring(0, 8) : parts.join(' ');
          }
        }
      }
      if (mounted) {
        setState(() {
          _pendingEvents = events;
          _ownerLabels = labels;
          _loadingPending = false;
        });
      }
    } catch (e) {
      debugPrint('Klaida kraunant paraiškas: $e');
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _loadTournaments() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Rikiuojame pagal sukūrimo datą (naujausi viršuje)
      final response = await Supabase.instance.client
          .from('tournaments')
          .select()
          .order('created_at', ascending: false)
          .limit(QueryLimits.adminTournaments);

      if (mounted) {
        setState(() {
          _tournaments = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant turnyrus: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Ištrinimo funkcija
  Future<void> _deleteTournament(String id) async {
    try {
      await Supabase.instance.client.from('tournaments').delete().eq('id', id);
      _loadTournaments(); // Atnaujiname sąrašą
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Turnyras ištrintas"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Klaida trinant: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final accentColor = p.accent;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: Row(
          children: [
            Icon(LucideIcons.shieldAlert, color: accentColor),
            const SizedBox(width: 10),
            Text(
              "PARTNER DASHBOARD",
              style: GoogleFonts.bebasNeue(
                color: p.textPrimary,
                fontSize: 24,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Dizaino variantai',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DesignVariantsScreen(),
              ),
            ),
            icon: Icon(LucideIcons.palette, color: p.textSecondary),
          ),
          IconButton(
            onPressed: _loadAll,
            icon: Icon(LucideIcons.refreshCw, color: p.textSecondary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- KURTI MYGTUKAS ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateEventScreen(),
                    ),
                  ).then((_) => _loadAll());
                },
                icon: const Icon(LucideIcons.plusCircle, color: Colors.white),
                label: Text(
                  "KURTI NAUJĄ TURNYRĄ",
                  style: GoogleFonts.bebasNeue(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),

            Text(
              "PARAIŠKOS RENGINIAMS (${_pendingEvents.length})",
              style: GoogleFonts.oswald(color: Colors.amber, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mokama paslauga — patvirtinkite ar atminkite, kad viešame kalendoriuje '
              'nerodytų nepatvirtintų turnyrų.',
              style: TextStyle(color: QortColors.textSecondary, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 12),
            if (_loadingPending)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                ),
              )
            else if (_pendingEvents.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: QortColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: QortColors.border),
                ),
                child: const Text(
                  'Nėra laukiančių paraiškų.',
                  style: TextStyle(color: QortColors.textSecondary),
                ),
              )
            else
              ..._pendingEvents.map(_buildPendingEventCard),
            const SizedBox(height: 28),

            Text(
              "MANO TURNYRAI (${_tournaments.length})",
              style: GoogleFonts.oswald(
                color: QortColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),

            _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: accentColor),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tournaments.length,
                    itemBuilder: (context, index) {
                      final t = _tournaments[index];
                      return GestureDetector(
                        // --- NUORODA Į NAUJĄ PULTĄ ---
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AdminTournamentControlScreen(tournament: t),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: QortColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: QortColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 48,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: t['is_published'] == true
                                      ? Colors.green
                                      : Colors.orange,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t['name'] ?? "Be pavadinimo",
                                      style: GoogleFonts.oswald(
                                        color: QortColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${t['sport']} • ${t['stages_setup'] != null && (t['stages_setup'] as List).isNotEmpty ? 'Elite Mode' : 'Standard'}",
                                      style: const TextStyle(
                                        color: QortColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  LucideIcons.trash2,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _deleteTournament(t['id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingEventCard(Map<String, dynamic> e) {
    final ownerId = e['owner_id']?.toString();
    final owner = ownerId != null ? (_ownerLabels[ownerId] ?? 'Organizatorius') : '—';
    final fee = e['organizer_service_fee'];
    final feeStr = fee != null
        ? '${(fee is num ? fee.toDouble() : double.tryParse(fee.toString()) ?? EventOrganizerPolicy.serviceFeeEur).toStringAsFixed(0)} €'
        : EventOrganizerPolicy.feeLabel();
    final note = e['organizer_note']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e['name']?.toString() ?? 'Be pavadinimo',
            style: GoogleFonts.oswald(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            '$owner · ${e['sport'] ?? ''} · ${e['location'] ?? ''} · $feeStr',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(note, style: const TextStyle(color: QortColors.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectPending(e['id'].toString()),
                  icon: const Icon(LucideIcons.x, size: 16),
                  label: const Text('ATMESTI'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approvePending(e['id'].toString()),
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: const Text('PATVIRTINTI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approvePending(String eventId) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Patvirtinti renginį?', style: TextStyle(color: QortColors.textPrimary)),
        content: TextField(
          controller: noteCtrl,
          style: const TextStyle(color: QortColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Pastaba organizatoriui (neprivaloma)',
            labelStyle: TextStyle(color: QortColors.textSecondary),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Atšaukti'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Patvirtinti'),
          ),
        ],
      ),
    );
    final adminNote = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (ok != true) return;
    try {
      await EventApprovalService.approveEvent(
        eventId,
        adminNote: adminNote.isEmpty ? null : adminNote,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Renginys patvirtintas — matomas viešame kalendoriuje'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Klaida: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectPending(String eventId) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Atmesti paraišką?', style: TextStyle(color: QortColors.textPrimary)),
        content: TextField(
          controller: noteCtrl,
          style: const TextStyle(color: QortColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Priežastis (rekomenduojama)',
            labelStyle: TextStyle(color: QortColors.textSecondary),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Atšaukti'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Atmesti'),
          ),
        ],
      ),
    );
    if (ok != true) {
      noteCtrl.dispose();
      return;
    }
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    try {
      await EventApprovalService.rejectEvent(
        eventId,
        adminNote: note.isEmpty ? null : note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paraiška atmesta'), backgroundColor: Colors.orange),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Klaida: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
