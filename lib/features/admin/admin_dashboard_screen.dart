import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/event_organizer_policy.dart';
import '../../core/constants/query_limits.dart';
import '../../core/services/event_approval_service.dart';
import '../../core/services/event_lifecycle_service.dart';

// Įsitikinkite, kad šie failai yra tame pačiame aplanke
import 'create_tournament_screen.dart';
import 'admin_tournament_control_screen.dart';
import 'tournament_draft_preview_screen.dart';
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
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    await _loadIsSuperAdmin();
    await _loadAll();
  }

  Future<void> _loadIsSuperAdmin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('is_super_admin')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _isSuperAdmin = data['is_super_admin'] as bool? ?? false;
        });
      }
    } catch (e) {
      debugPrint('Klaida kraunant super admin statusą: $e');
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadTournaments(), _loadPendingEvents()]);
  }

  Future<void> _loadPendingEvents() async {
    if (!_isSuperAdmin) {
      if (mounted) {
        setState(() {
          _pendingEvents = [];
          _loadingPending = false;
        });
      }
      return;
    }

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

  Future<void> _deleteTournament(Map<String, dynamic> t) async {
    final eventId = t['event_id']?.toString();
    final tournamentId = t['id']?.toString();

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'PAVOJINGA OPERACIJA',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ištrynus turnyrą:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '✅ Mačai išlieka (be turnyro nuorodos)',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            Text(
              '✅ Dalyviai išlieka istorijoje',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            Text(
              '✅ RP / XP taškai išlieka',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            Text(
              '❌ Kainodara dingsta',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            Text(
              '❌ Pokalbis dingsta',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            Text(
              '❌ Rėmėjai dingsta',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              'REKOMENDUOJAMA: vietoj ištrynimo naudok „Archyvuoti“ — '
              'turnyras lieka DB, bet paslepiamas iš sąrašų.',
              style: TextStyle(color: Color(0xFFEAB308), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Atšaukti', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'archive'),
            child: const Text(
              'Archyvuoti',
              style: TextStyle(color: Color(0xFFEAB308)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('IŠTRINTI', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (action == null || action.isEmpty) return;

    try {
      final client = Supabase.instance.client;

      if (action == 'archive') {
        if (eventId != null && eventId.isNotEmpty) {
          await EventLifecycleService.setEventStatus(
            eventId: eventId,
            status: 'archived',
          );
        } else if (tournamentId != null && tournamentId.isNotEmpty) {
          await EventLifecycleService.setTournamentStatus(
            tournamentId: tournamentId,
            status: 'archived',
          );
        }

        await _loadTournaments();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnyras archyvuotas'),
            backgroundColor: Color(0xFFEAB308),
          ),
        );
        return;
      }

      if (action == 'delete') {
        if (eventId != null && eventId.isNotEmpty) {
          await client.from('events').delete().eq('id', eventId);
        } else if (tournamentId != null && tournamentId.isNotEmpty) {
          await client.from('tournaments').delete().eq('id', tournamentId);
        }

        await _loadTournaments();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnyras ištrintas'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Klaida: $e')),
      );
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

            if (_isSuperAdmin) ...[
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
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: QortColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: QortColors.border),
                ),
                child: ListTile(
                  leading: const Icon(
                    LucideIcons.refreshCw,
                    color: Color(0xFFEAB308),
                  ),
                  title: const Text(
                    'Atnaujinti turnyrų statusus',
                    style: TextStyle(
                      color: QortColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Pažymėti pasibaigusius kaip "finished"',
                    style: TextStyle(color: QortColors.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(
                    LucideIcons.chevronRight,
                    color: QortColors.textSecondary,
                    size: 18,
                  ),
                  onTap: () async {
                    try {
                      await EventLifecycleService.updateLifecycle();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Statusai atnaujinti')),
                      );
                      await _loadAll();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Klaida: $e')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 28),
            ],

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
                                onPressed: () => _deleteTournament(
                                  Map<String, dynamic>.from(t as Map),
                                ),
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
    final owner =
        ownerId != null ? (_ownerLabels[ownerId] ?? 'Organizatorius') : '—';
    final fee = e['organizer_service_fee'];
    final feeStr = fee != null
        ? '${(fee is num ? fee.toDouble() : double.tryParse(fee.toString()) ?? EventOrganizerPolicy.serviceFeeEur).toStringAsFixed(0)} €'
        : EventOrganizerPolicy.feeLabel();
    final note = e['organizer_note']?.toString();
    final eventId = e['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        title: Text(
          e['name']?.toString() ?? 'Be pavadinimo',
          style: GoogleFonts.oswald(color: Colors.white, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$owner · ${e['sport'] ?? ''} · ${e['location'] ?? ''} · $feeStr',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note,
                  style: const TextStyle(
                    color: QortColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.eye, color: Color(0xFFEAB308)),
            SizedBox(width: 4),
            Text(
              'Peržiūrėti',
              style: TextStyle(color: Color(0xFFEAB308)),
            ),
          ],
        ),
        onTap: eventId.isEmpty
            ? null
            : () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TournamentDraftPreviewScreen(
                      eventId: eventId,
                      superAdminMode: true,
                    ),
                  ),
                );
                if (result == true && mounted) {
                  await _loadPendingEvents();
                }
              },
      ),
    );
  }
}
