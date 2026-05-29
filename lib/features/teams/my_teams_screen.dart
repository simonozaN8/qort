import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'team_model.dart';
import 'create_team_screen.dart';
import 'team_profile_screen.dart';
import '../../core/constants/query_limits.dart';
import '../../core/models/sport_catalog_entry.dart';
import '../../core/services/sports_catalog_service.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/utils/sport_icons.dart';
import '../../core/utils/sport_levels.dart';
import 'team_invitations_screen.dart';

class MyTeamsScreen extends StatefulWidget {
  const MyTeamsScreen({super.key});

  @override
  State<MyTeamsScreen> createState() => _MyTeamsScreenState();
}

class _MyTeamsScreenState extends State<MyTeamsScreen> {
  bool _isLoading = true;
  List<Team> _teams = [];
  int _pendingInvitations = 0;
  Map<String, SportCatalogEntry> _catalogBySport = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final myId = session.user.id;
      final supabase = Supabase.instance.client;

      // Užkrauname paraleliai
      final results = await Future.wait([
        // Komandos, kuriose vartotojas yra narys
        supabase
            .from('team_members')
            .select('*, teams(*)')
            .eq('user_id', myId)
            .limit(QueryLimits.myTeams),
        // Laukiantys kvietimai
        supabase
            .from('team_invitations')
            .select('id')
            .eq('invited_user_id', myId)
            .eq('status', 'pending'),
      ]);
      final catalogEntries = await SportsCatalogService.fetchActive();
      _catalogBySport = {for (final e in catalogEntries) e.name: e};

      final membershipRows = results[0] as List;
      final teamIds = membershipRows
          .map((item) => (item['teams'] as Map?)?['id']?.toString())
          .whereType<String>()
          .toList();

      final memberCounts = <String, int>{};
      if (teamIds.isNotEmpty) {
        final allMembers = await supabase
            .from('team_members')
            .select('team_id')
            .inFilter('team_id', teamIds);
        for (var row in allMembers as List) {
          final tid = row['team_id'].toString();
          memberCounts[tid] = (memberCounts[tid] ?? 0) + 1;
        }
      }

      final teams = <Team>[];
      for (var item in membershipRows) {
        final teamData = item['teams'] as Map<String, dynamic>?;
        if (teamData != null) {
          final tid = teamData['id'].toString();
          teamData['member_count'] = memberCounts[tid] ?? 0;
          teams.add(Team.fromJson(teamData));
        }
      }

      // Pakvietimai
      final pendingCount = (results[1] as List).length;

      if (mounted) {
        setState(() {
          _teams = teams;
          _pendingInvitations = pendingCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant komandas: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCreate() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTeamScreen()),
    );
    if (created == true) _loadData();
  }

  void _openTeam(Team team) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TeamProfileScreen(teamId: team.id)),
    );
    if (changed == true) _loadData();
  }

  void _openInvitations() async {
    final responded = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TeamInvitationsScreen()),
    );
    if (responded == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = QortColors.primary;

    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: QortColors.surface,
        elevation: 0,
        title: Text(
          "MANO KOMANDOS",
          style: GoogleFonts.bebasNeue(
            color: QortColors.textPrimary,
            letterSpacing: 2,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: QortColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Pakvietimų ikona
          Stack(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.bell, color: QortColors.textPrimary),
                onPressed: _openInvitations,
              ),
              if (_pendingInvitations > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      "$_pendingInvitations",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Sukurti
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _openCreate,
              icon: const Icon(LucideIcons.plus, color: accentColor, size: 18),
              label: Text(
                "KURTI",
                style: GoogleFonts.bebasNeue(
                  color: accentColor,
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: accentColor.withOpacity(0.15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : _teams.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _loadData,
              color: accentColor,
              backgroundColor: QortColors.surface,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _teams.length,
                itemBuilder: (context, i) => _buildTeamCard(_teams[i]),
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.users, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              "DAR NETURI KOMANDŲ",
              style: GoogleFonts.bebasNeue(
                fontSize: 22,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Sukurk savo komandą ir kviesk\nbendraminčius žaisti kartu.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openCreate,
              icon: const Icon(LucideIcons.plus),
              label: const Text("SUKURTI KOMANDĄ"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(Team team) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _openTeam(team),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: QortColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              // Logo / placeholder
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  image: team.logoUrl != null && team.logoUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(team.logoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: team.logoUrl == null || team.logoUrl!.isEmpty
                    ? const Icon(
                        LucideIcons.shield,
                        color: Color(0xFF3B82F6),
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SportIcons.icon(
                                team.sport,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                team.sport,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            SportLevels.nameFor(
                              _catalogBySport[team.sport],
                              team.level,
                            ),
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${team.memberCount} narių",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: Colors.white30,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
