import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'team_model.dart';
import '../../core/constants/query_limits.dart';
import '../../core/services/team_name_service.dart';
import '../../core/utils/team_naming_rules.dart';
import '../profile/user_picker_field.dart';

class TeamProfileScreen extends StatefulWidget {
  final String teamId;
  const TeamProfileScreen({super.key, required this.teamId});

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  bool _isLoading = true;
  Team? _team;
  List<TeamMember> _members = [];
  bool _hasChanges = false;
  String? _myUserId;
  bool get _isCreator =>
      _team != null && _myUserId != null && _team!.creatorId == _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = Supabase.instance.client.auth.currentSession?.user.id;
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Komanda
      final teamResp = await supabase
          .from('teams')
          .select()
          .eq('id', widget.teamId)
          .single();

      // Nariai su profiliais ir lygiais
      final membersResp = await supabase
          .from('team_members')
          .select('''
            *,
            profiles(id, nickname, name, surname, photo_url)
          ''')
          .eq('team_id', widget.teamId)
          .limit(QueryLimits.teamMembers);

      final memberRows = List<Map<String, dynamic>>.from(membersResp as List);
      final userIds = memberRows.map((m) => m['user_id'] as String).toList();
      final levelsByUser = <String, int>{};

      if (userIds.isNotEmpty) {
        final sportLevels = await supabase
            .from('user_sports')
            .select('user_id, level')
            .inFilter('user_id', userIds)
            .eq('sport', teamResp['sport']);
        for (var row in sportLevels as List) {
          levelsByUser[row['user_id'].toString()] =
              int.tryParse(row['level']?.toString() ?? '1') ?? 1;
        }
      }

      final memberList = <TeamMember>[];
      for (var m in memberRows) {
        m['level'] = levelsByUser[m['user_id'].toString()] ?? 1;
        memberList.add(TeamMember.fromJson(m));
      }

      // Apskaičiuojame komandos lygį (aukščiausias narys)
      final calculatedLevel = Team.calculateLevel(memberList);

      // Jei lygis pasikeitė - atnaujiname
      if (calculatedLevel != teamResp['level']) {
        await supabase
            .from('teams')
            .update({'level': calculatedLevel})
            .eq('id', widget.teamId);
        teamResp['level'] = calculatedLevel;
      }

      teamResp['members'] = membersResp;

      if (mounted) {
        setState(() {
          _team = Team.fromJson(teamResp);
          _members = memberList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant komandą: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openInvite() {
    showDialog(
      context: context,
      builder: (_) => _InviteDialog(
        teamId: widget.teamId,
        teamSport: _team?.sport ?? '',
        teamFormat: _team?.format,
        existingMemberIds: _members.map((m) => m.userId).toList(),
        onInvited: () {
          _hasChanges = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Pakvietimas išsiųstas"),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  Future<void> _removeMember(TeamMember member) async {
    if (member.isCreator) return; // kūrėjo negalima šalinti

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: QortColors.surface,
        title: const Text(
          "Pašalinti narį?",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "${member.displayName} bus pašalintas iš komandos.",
          style: const TextStyle(color: QortColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Atšaukti"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Pašalinti", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('team_members')
          .delete()
          .eq('id', member.id);
      await TeamNameService.syncTeamDisplayName(widget.teamId);
      _hasChanges = true;
      _loadTeam();
    } catch (e) {
      debugPrint("Klaida šalinant narį: $e");
    }
  }

  Future<void> _deleteTeam() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: QortColors.surface,
        title: const Text(
          "Ištrinti komandą?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Visi nariai bus pašalinti. Šio veiksmo atšaukti negalima.",
          style: TextStyle(color: QortColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Atšaukti"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ištrinti", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('teams')
          .delete()
          .eq('id', widget.teamId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Klaida trinant komandą: $e");
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
          _team?.name.toUpperCase() ?? "KOMANDA",
          style: GoogleFonts.bebasNeue(
            color: Colors.white,
            letterSpacing: 2,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
        actions: [
          if (_isCreator)
            IconButton(
              icon: const Icon(LucideIcons.trash2, color: Colors.red),
              onPressed: _deleteTeam,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : _team == null
          ? const Center(
              child: Text(
                "Komanda nerasta",
                style: TextStyle(color: Colors.white),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Komandos antraštė
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withOpacity(0.2),
                        QortColors.surface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          image:
                              _team!.logoUrl != null &&
                                  _team!.logoUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(_team!.logoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _team!.logoUrl == null || _team!.logoUrl!.isEmpty
                            ? const Icon(
                                LucideIcons.shield,
                                color: accentColor,
                                size: 40,
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _team!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          // Sportas
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: QortColors.border,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _team!.sport,
                              style: const TextStyle(
                                color: QortColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          // Formatas (NAUJAS)
                          if (_team!.format != null &&
                              _team!.format!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF3B82F6,
                                ).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _team!.format!,
                                style: const TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          // Lygis
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Lygis ${_team!.level}",
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // Miestas (jei yra)
                          if (_team!.city != null && _team!.city!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: QortColors.border,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.mapPin,
                                    size: 11,
                                    color: QortColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _team!.city!,
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
                      if (_team!.description != null &&
                          _team!.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _team!.description!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Nariai
                Row(
                  children: [
                    Text(
                      "NARIAI (${_members.length})",
                      style: GoogleFonts.bebasNeue(
                        color: QortColors.textSecondary,
                        letterSpacing: 1.5,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (_isCreator && _members.length < _team!.maxTeamSize)
                      TextButton.icon(
                        onPressed: _openInvite,
                        icon: const Icon(
                          LucideIcons.userPlus,
                          size: 14,
                          color: accentColor,
                        ),
                        label: const Text(
                          "PAKVIESTI",
                          style: TextStyle(color: accentColor, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._members.map((m) => _buildMemberTile(m)),

                // Skaičiuojam min narių pagal formatą iš DB
                Builder(
                  builder: (context) {
                    // Imame iš teamo duomenų
                    final teamData = _team!;
                    // players_on_court iš DB (saugomas teams lentelėje)
                    final minRequired = teamData.playersOnCourt;

                    if (_members.length >= minRequired) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.alertTriangle,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "${teamData.format ?? ''} komandai reikia min. $minRequired narių (turi ${_members.length})",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
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
    );
  }

  Widget _buildMemberTile(TeamMember m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: QortColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: m.isCreator ? Colors.amber.withOpacity(0.3) : QortColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: QortColors.border,
                shape: BoxShape.circle,
                image: m.photoUrl != null && m.photoUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(m.photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: m.photoUrl == null || m.photoUrl!.isEmpty
                  ? const Icon(
                      LucideIcons.user,
                      color: QortColors.textSecondary,
                      size: 18,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        m.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (m.isCreator) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          LucideIcons.crown,
                          color: Colors.amber,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    "Lygis ${m.level}",
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (_isCreator && !m.isCreator)
              IconButton(
                icon: const Icon(
                  LucideIcons.userMinus,
                  color: Colors.red,
                  size: 18,
                ),
                onPressed: () => _removeMember(m),
              ),
          ],
        ),
      ),
    );
  }
}

// === KVIETIMO DIALOGAS ===
class _InviteDialog extends StatefulWidget {
  final String teamId;
  final String teamSport;
  final String? teamFormat;
  final List<String> existingMemberIds;
  final VoidCallback onInvited;

  const _InviteDialog({
    required this.teamId,
    required this.teamSport,
    this.teamFormat,
    required this.existingMemberIds,
    required this.onInvited,
  });

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  String? _selectedUserId;
  String? _selectedName;
  bool _isSending = false;

  Future<void> _send() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pasirink QORT vartotoją"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (widget.existingMemberIds.contains(_selectedUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Šis vartotojas jau yra komandos narys"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      // Patikriname, ar jau nėra pending pakvietimo
      final existing = await Supabase.instance.client
          .from('team_invitations')
          .select('id')
          .eq('team_id', widget.teamId)
          .eq('invited_user_id', _selectedUserId!)
          .eq('status', 'pending')
          .maybeSingle();

      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Šis vartotojas jau pakviestas"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await Supabase.instance.client.from('team_invitations').insert({
        'team_id': widget.teamId,
        'invited_user_id': _selectedUserId,
        'invited_by': session.user.id,
        'status': 'pending',
      });

      widget.onInvited();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Klaida siunčiant pakvietimą: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: QortColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PAKVIESTI Į KOMANDĄ",
              style: GoogleFonts.bebasNeue(
                color: Colors.white,
                letterSpacing: 1.5,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            UserPickerField(
              label: "VARTOTOJAS",
              hintText: "Įrašyk slapyvardį",
              filterBySport: widget.teamSport,
              onUserSelected: (userId, displayName) {
                setState(() {
                  _selectedUserId = userId;
                  _selectedName = displayName;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              TeamNamingRules.usesParticipantNames(
                    widget.teamSport,
                    widget.teamFormat,
                  )
                  ? "Pakvietus antrą žaidėją komandos pavadinimas bus atnaujintas "
                      "automatiškai (vardas ir pavardė / vardas ir pavardė)."
                  : "Pakviesti galima tik registruotus QORT vartotojus, kurie pasirinko šios komandos sporto šaką.",
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "ATŠAUKTI",
                      style: TextStyle(color: QortColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_isSending ? "..." : "PAKVIESTI"),
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
