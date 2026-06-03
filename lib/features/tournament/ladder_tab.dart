import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_mode_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/query_limits.dart';

class LadderTab extends StatefulWidget {
  final String tournamentId;
  final String? currentUserId;

  const LadderTab({super.key, required this.tournamentId, this.currentUserId});

  @override
  State<LadderTab> createState() => _LadderTabState();
}

class _LadderTabState extends State<LadderTab> {
  bool _isLoading = true;
  List<dynamic> _ladderPlayers = [];
  List<dynamic> _myPastMatches = []; // Užšaldymo istorijai
  int _myPosition = 999;

  @override
  void initState() {
    super.initState();
    _loadLadder();
  }

  Future<void> _loadLadder() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('tournament_participants')
          .select()
          .eq('tournament_id', widget.tournamentId)
          .limit(QueryLimits.tournamentParticipants);

      List<dynamic> players = List.from(response);

      players.sort((a, b) {
        int posA = a['ladder_position'] ?? 999;
        int posB = b['ladder_position'] ?? 999;
        return posA.compareTo(posB);
      });

      if (widget.currentUserId != null) {
        final me = players.firstWhere(
          (p) => p['user_id'] == widget.currentUserId,
          orElse: () => null,
        );
        if (me != null) {
          _myPosition = me['ladder_position'] ?? 999;
        }

        // PATAISYTA: Pridėtas šauktukas (!) prie widget.currentUserId!
        final matches = await Supabase.instance.client
            .from('matches')
            .select()
            .eq('tournament_id', widget.tournamentId)
            .eq('stage', 'ladder')
            .eq('player1_id', widget.currentUserId!)
            .eq('status', 'completed')
            .limit(QueryLimits.tournamentMatches);
        _myPastMatches = matches;
      }

      if (mounted) {
        setState(() {
          _ladderPlayers = players;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant piramidę: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _challengePlayer(Map<String, dynamic> targetPlayer) async {
    if (widget.currentUserId == null) return;

    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;

      final existingMatches = await client
          .from('matches')
          .select()
          .eq('tournament_id', widget.tournamentId)
          .eq('stage', 'ladder')
          .inFilter('status', ['pending', 'played_waiting'])
          .limit(QueryLimits.tournamentMatches);

      bool alreadyChallenged = existingMatches.any((m) {
        bool condition1 =
            m['player1_id'] == widget.currentUserId &&
            m['player2_id'] == targetPlayer['user_id'];
        bool condition2 =
            m['player1_id'] == targetPlayer['user_id'] &&
            m['player2_id'] == widget.currentUserId;
        return condition1 || condition2;
      });

      if (alreadyChallenged) {
        _showMessage(
          "Jūs jau turite aktyvų mačą su šiuo varžovu!",
          Colors.orange,
        );
        setState(() => _isLoading = false);
        return;
      }

      // PATAISYTA: Pridėtas šauktukas (!) prie widget.currentUserId!
      await client.from('matches').insert({
        'tournament_id': widget.tournamentId,
        'player1_id': widget.currentUserId!,
        'player2_id': targetPlayer['user_id'],
        'status': 'pending',
        'stage': 'ladder',
        'round': 0,
        'match_num': 0,
        'score_p1': 0,
        'score_p2': 0,
        'created_at': DateTime.now().toIso8601String(),
        'match_details': {'note': 'Iššūkis mestas iš piramidės'},
      });

      _showMessage(
        "Iššūkis sėkmingai mestas! Pereikite į MAČAI skiltį.",
        Colors.green,
      );
    } catch (e) {
      _showMessage("Nepavyko mesti iššūkio: $e", Colors.red);
    } finally {
      if (mounted) {
        _loadLadder();
      }
    }
  }

  void _showMessage(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
    }
  }

  // --- MATEMATIKA: Nustato, kurioje eilutėje yra pozicija ---
  int _getTier(int pos) {
    if (pos >= 999) return 999;
    int tier = 1;
    int maxPosInTier = 1;
    while (pos > maxPosInTier) {
      tier++;
      maxPosInTier += tier;
    }
    return tier;
  }

  List<List<dynamic>> _buildPiramidTiers() {
    List<List<dynamic>> tiers = [];
    int itemsInCurrentTier = 0;
    int targetItemsInTier = 1;
    List<dynamic> currentTier = [];

    for (var player in _ladderPlayers) {
      currentTier.add(player);
      itemsInCurrentTier++;

      if (itemsInCurrentTier == targetItemsInTier) {
        tiers.add(currentTier);
        targetItemsInTier++;
        itemsInCurrentTier = 0;
        currentTier = [];
      }
    }
    if (currentTier.isNotEmpty) {
      tiers.add(currentTier);
    }
    return tiers;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: QortModeColors.competition),
      );
    }

    if (_ladderPlayers.isEmpty) {
      return Center(
        child: Text(
          "Piramidė dar nesugeneruota.",
          style: GoogleFonts.oswald(color: QortColors.textSecondary, fontSize: 18),
        ),
      );
    }

    final tiers = _buildPiramidTiers();

    return RefreshIndicator(
      onRefresh: _loadLadder,
      color: QortModeColors.competition,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: tiers.map((tierPlayers) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: tierPlayers.map((player) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _buildPlayerCard(player),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> player) {
    final pos = player['ladder_position'] ?? 999;
    final isMe = player['user_id'] == widget.currentUserId;

    // OFICIALIOS TAISYKLĖS (Filtrai)
    int targetPos = pos;
    int myTier = _getTier(_myPosition);
    int targetTier = _getTier(targetPos);

    bool isRowValid = (myTier - targetTier) == 1; // 1. Tik 1 eilute aukščiau
    bool isPosValid =
        (_myPosition - targetPos) <= 5; // 2. Ne daugiau 5 pozicijų

    // 3. Užšaldymas (7 dienos, jei pralaimėjai kaip metėjas)
    bool isFrozen = false;
    for (var m in _myPastMatches) {
      if (m['player2_id'] == player['user_id'] &&
          m['winner_id'] == player['user_id']) {
        if (m['created_at'] != null) {
          DateTime matchDate = DateTime.parse(m['created_at']);
          if (DateTime.now().difference(matchDate).inDays < 7) {
            isFrozen = true;
          }
        }
      }
    }

    final bool isAboveMe = targetPos < _myPosition;
    final bool canChallenge =
        widget.currentUserId != null &&
        !isMe &&
        isAboveMe &&
        isRowValid &&
        isPosValid &&
        !isFrozen;

    Color rankColor = Colors.grey;
    if (pos == 1) rankColor = const Color(0xFFFFD700);
    if (pos == 2) rankColor = const Color(0xFFC0C0C0);
    if (pos == 3) rankColor = const Color(0xFFCD7F32);

    return Container(
      width: 140,
      height: 160,
      decoration: BoxDecoration(
        color: isMe
            ? QortModeColors.competition.withValues(alpha: 0.1)
            : QortColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? QortModeColors.competition : QortColors.border,
          width: isMe ? 2 : 1,
        ),
        boxShadow: [
          if (pos == 1)
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: rankColor, width: 2),
            ),
            child: Center(
              child: Text(
                pos == 999 ? "-" : "$pos",
                style: GoogleFonts.bebasNeue(color: rankColor, fontSize: 22),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              player['team_name'] ?? "Nežinomas",
              style: GoogleFonts.oswald(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 12),

          if (isMe)
            const Text(
              "TAI JŪS",
              style: TextStyle(
                color: QortModeColors.competition,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            )
          else if (canChallenge)
            SizedBox(
              height: 30,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.2),
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: const BorderSide(color: Colors.redAccent),
                  elevation: 0,
                ),
                onPressed: () => _challengePlayer(player),
                child: const Text(
                  "⚔️ IŠŠŪKIS",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else if (!isMe && isAboveMe)
            Text(
              isFrozen ? "UŽŠALDYTA (7d)" : "PER TOLI",
              style: const TextStyle(
                color: QortColors.navInactive,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            )
          else if (!isMe && !isAboveMe)
            const Text(
              "ŽEMIAU TAVĘS",
              style: TextStyle(color: QortColors.navInactive, fontSize: 10),
            ),
        ],
      ),
    );
  }
}
