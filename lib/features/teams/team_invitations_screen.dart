import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/services/team_name_service.dart';
import 'team_model.dart';

class TeamInvitationsScreen extends StatefulWidget {
  const TeamInvitationsScreen({super.key});

  @override
  State<TeamInvitationsScreen> createState() => _TeamInvitationsScreenState();
}

class _TeamInvitationsScreenState extends State<TeamInvitationsScreen> {
  bool _isLoading = true;
  List<TeamInvitation> _invitations = [];
  bool _hasResponded = false;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() => _isLoading = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final myId = session.user.id;
      final supabase = Supabase.instance.client;

      // Užkrauname pending pakvietimus su komandos ir kvietėjo info
      final response = await supabase
          .from('team_invitations')
          .select('''
            *,
            teams(id, name, sport, level),
            inviter:profiles!team_invitations_invited_by_fkey(nickname, name, surname)
          ''')
          .eq('invited_user_id', myId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final invitations = (response as List)
          .map((json) => TeamInvitation.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _invitations = invitations;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant pakvietimus: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(TeamInvitation inv, bool accept) async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Atnaujiname pakvietimo statusą
      await supabase
          .from('team_invitations')
          .update({
            'status': accept ? 'accepted' : 'declined',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', inv.id);

      // 2. Jei sutiko - pridedame į komandą
      if (accept) {
        await supabase.from('team_members').insert({
          'team_id': inv.teamId,
          'user_id': inv.invitedUserId,
          'role': 'member',
        });
        await TeamNameService.syncTeamDisplayName(inv.teamId);
      }

      _hasResponded = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? "Prisijungei prie komandos \"${inv.teamName}\"!"
                  : "Pakvietimas atmestas",
            ),
            backgroundColor: accept ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      _loadInvitations();
    } catch (e) {
      debugPrint("Klaida atsakant į pakvietimą: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Klaida. Pabandyk dar kartą."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = QortColors.background;
    const accentColor = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          "PAKVIETIMAI",
          style: GoogleFonts.bebasNeue(
            color: Colors.white,
            letterSpacing: 2,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context, _hasResponded),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : _invitations.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _loadInvitations,
              color: accentColor,
              backgroundColor: QortColors.surface,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _invitations.length,
                itemBuilder: (context, i) =>
                    _buildInvitationCard(_invitations[i]),
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
            const Icon(LucideIcons.bellOff, size: 64, color: QortColors.navInactive),
            const SizedBox(height: 16),
            Text(
              "NĖRA PAKVIETIMŲ",
              style: GoogleFonts.bebasNeue(
                fontSize: 22,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Kai kažkas tave pakvies į komandą,\npranešimas atsiras čia.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationCard(TeamInvitation inv) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: QortColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: QortColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Antraštė
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.userPlus,
                    color: Color(0xFF3B82F6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.inviterName.isNotEmpty
                            ? "${inv.inviterName} kviečia"
                            : "Pakvietimas",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(inv.createdAt),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Komandos info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: QortColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.shield,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv.teamName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          inv.teamSport,
                          style: const TextStyle(
                            color: QortColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Mygtukai
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _respond(inv, false),
                    icon: const Icon(LucideIcons.x, size: 16),
                    label: const Text("ATMESTI"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.15),
                      foregroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _respond(inv, true),
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text("PRISIJUNGTI"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
