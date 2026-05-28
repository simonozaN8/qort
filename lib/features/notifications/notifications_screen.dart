import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/services/team_name_service.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/theme/qort_mode_colors.dart';
import '../../core/theme/qort_theme.dart';
import '../../core/utils/sport_icons.dart';
import '../../core/widgets/qort_live_scaffold.dart';
import '../../core/widgets/qort_section_header.dart';
import '../profile/user_model.dart';
import '../teams/team_model.dart';

/// Universalus pranešimų ekranas
/// Šiuo metu rodo:
/// - Komandos pakvietimus
/// Ateityje plečiamas:
/// - Mini protokolo užklausos (taškų įvedimas)
/// - Sistemos pranešimai
class NotificationsScreen extends StatefulWidget {
  final AppMode currentMode;

  const NotificationsScreen({super.key, this.currentMode = AppMode.competition});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<TeamInvitation> _teamInvitations = [];
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final myId = session.user.id;
      final supabase = Supabase.instance.client;

      // Komandos pakvietimai
      final invitations = await supabase
          .from('team_invitations')
          .select('''
            *,
            teams(id, name, sport, level, logo_url),
            inviter:profiles!team_invitations_invited_by_fkey(nickname, name, surname)
          ''')
          .eq('invited_user_id', myId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final teamInv = (invitations as List)
          .map((json) => TeamInvitation.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _teamInvitations = teamInv;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant pranešimus: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respondToInvitation(TeamInvitation inv, bool accept) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('team_invitations')
          .update({
            'status': accept ? 'accepted' : 'declined',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', inv.id);

      if (accept) {
        await supabase.from('team_members').insert({
          'team_id': inv.teamId,
          'user_id': inv.invitedUserId,
          'role': 'member',
        });
        await TeamNameService.syncTeamDisplayName(inv.teamId);
      }

      _hasChanges = true;

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

      _loadAll();
    } catch (e) {
      debugPrint("Klaida atsakant: $e");
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

  /// Bendras pranešimų skaičius
  int get _totalCount => _teamInvitations.length;

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final accent = switch (widget.currentMode) {
      AppMode.training => QortModeColors.training,
      AppMode.blitz => QortModeColors.blitz,
      AppMode.competition => QortModeColors.competition,
    };

    if (_isLoading) {
      return QortLiveScaffold(
        mode: widget.currentMode,
        title: 'Pranešimai',
        heroHeadline: 'Pranešimai',
        subtitle: 'Kraunama…',
        onRefresh: _loadAll,
        child: Center(child: CircularProgressIndicator(color: accent)),
      );
    }

    if (_totalCount == 0) {
      return QortLiveScaffold(
        mode: widget.currentMode,
        title: 'Pranešimai',
        heroHeadline: 'Viskas perskaityta',
        subtitle: 'Nauji pakvietimai atsiras čia',
        onRefresh: _loadAll,
        child: _buildEmpty(),
      );
    }

    return QortLiveScaffold(
      mode: widget.currentMode,
      title: 'Pranešimai',
      heroHeadline: '$_totalCount nauji',
      subtitle: 'Komandų pakvietimai ir kiti pranešimai',
      onRefresh: _loadAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_teamInvitations.isNotEmpty) ...[
            QortSectionHeader(
              title: 'Komandų pakvietimai',
              count: _teamInvitations.length,
              accent: accent,
              icon: LucideIcons.users,
            ),
            const SizedBox(height: 12),
            ..._teamInvitations.map(_buildInvitationCard),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final p = context.qortPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(LucideIcons.bellOff, size: 56, color: p.navInactive),
          const SizedBox(height: 16),
          Text(
            'VISKAS PERSKAITYTA',
            style: GoogleFonts.bebasNeue(
              fontSize: 22,
              color: p.textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kai gausi pakvietimus ar kitus pranešimus,\njie atsiras čia.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(TeamInvitation inv) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: QortTheme.card(context.qortPalette),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                            : "Pakvietimas į komandą",
                        style: const TextStyle(
                          color: QortColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(inv.createdAt),
                        style: const TextStyle(
                          color: QortColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: QortColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: QortColors.border),
              ),
              child: Row(
                children: [
                  SportIcons.badge(inv.teamSport, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv.teamName,
                          style: const TextStyle(
                            color: QortColors.textPrimary,
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
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _respondToInvitation(inv, false),
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
                    onPressed: () => _respondToInvitation(inv, true),
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
