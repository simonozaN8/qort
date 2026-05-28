import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/constants/query_limits.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/utils/sport_icons.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _isLoading = true;
  String? _selectedSport;
  List<String> _userSports = [];

  // Visi matčai (QORT + išoriniai)
  List<Map<String, dynamic>> _allMatches = [];

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

      // Užkrauname viską paraleliai
      final results = await Future.wait([
        supabase.from('user_sports').select('sport').eq('user_id', myId),
        supabase
            .from('external_records')
            .select()
            .eq('user_id', myId)
            .order('date_played', ascending: false)
            .limit(QueryLimits.insightsRecords),
        supabase
            .from('matches')
            .select('*, tournaments(name, sport)')
            .or('player1_id.eq.$myId,player2_id.eq.$myId')
            .eq('status', 'completed')
            .order('match_date', ascending: false)
            .limit(QueryLimits.insightsRecords),
      ]);

      // Vartotojo sportai
      _userSports = (results[0] as List)
          .map((s) => s['sport'] as String)
          .toList();

      // Sujungiame visus matčus į vieną sąrašą su unifikuota struktūra
      final all = <Map<String, dynamic>>[];

      // Išoriniai
      for (var r in (results[1] as List)) {
        final iWon = r['i_won'] as bool?;
        if (iWon == null && r['record_type'] != 'tournament') continue;
        all.add({
          'date': r['date_played'],
          'sport': r['sport'],
          'i_won': iWon ?? false,
          'opponent_name': r['opponent_name'] ?? '?',
          'opponent_id': r['opponent_user_id'],
          'source': 'external',
          'type': r['record_type'],
        });
      }

      // QORT
      for (var m in (results[2] as List)) {
        final amIPlayer1 = m['player1_id'] == myId;
        final oppId = amIPlayer1 ? m['player2_id'] : m['player1_id'];
        all.add({
          'date': m['match_date'] ?? m['created_at'],
          'sport': (m['tournaments'] as Map?)?['sport'] ?? '',
          'i_won': m['winner_id'] == myId,
          'opponent_name': '?', // Užkrausim atskirai
          'opponent_id': oppId,
          'source': 'qort',
          'type': 'qort',
        });
      }

      // Užkrauname varžovų vardus
      final opponentIds = all
          .map((m) => m['opponent_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (opponentIds.isNotEmpty) {
        final profiles = await supabase
            .from('profiles')
            .select('id, nickname, name')
            .inFilter('id', opponentIds);

        final names = <String, String>{};
        for (var p in (profiles as List)) {
          names[p['id']] = (p['nickname'] as String?)?.isNotEmpty == true
              ? p['nickname']
              : p['name'] ?? '?';
        }

        for (var m in all) {
          if (m['opponent_id'] != null && names.containsKey(m['opponent_id'])) {
            m['opponent_name'] = names[m['opponent_id']];
          }
        }
      }

      // Rūšiuojame pagal datą
      all.sort((a, b) {
        if (a['date'] == null) return 1;
        if (b['date'] == null) return -1;
        return b['date'].toString().compareTo(a['date'].toString());
      });

      if (mounted) {
        setState(() {
          _allMatches = all;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant duomenis: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Filtruojame pagal pasirinktą sportą
  List<Map<String, dynamic>> get _filteredMatches {
    if (_selectedSport == null) return _allMatches;
    return _allMatches.where((m) => m['sport'] == _selectedSport).toList();
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
          "ĮŽVALGOS",
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : _allMatches.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _loadData,
              color: accentColor,
              backgroundColor: QortColors.surface,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Sporto filtras
                  if (_userSports.isNotEmpty) _buildSportFilter(),
                  const SizedBox(height: 16),

                  // Bendras suvestinė
                  _buildSummaryCard(),
                  const SizedBox(height: 16),

                  // Aktyvumas
                  _buildActivityCard(),
                  const SizedBox(height: 16),

                  // Win rate pagal sportą
                  if (_selectedSport == null) ...[
                    _buildSportsBreakdownCard(),
                    const SizedBox(height: 16),
                  ],

                  // Top varžovai
                  _buildTopOpponentsCard(),
                  const SizedBox(height: 16),

                  // Paskutinių 10 matčų forma
                  _buildRecentFormCard(),
                ],
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
            const Icon(LucideIcons.barChart3, size: 64, color: QortColors.navInactive),
            const SizedBox(height: 16),
            Text(
              "Įžvalgos atsiras\nkai turėsi rezultatų",
              textAlign: TextAlign.center,
              style: GoogleFonts.bebasNeue(
                fontSize: 22,
                color: QortColors.textPrimary,
                letterSpacing: 1.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Sužaisk QORT turnyrą arba pridėk\nsavo praeitus matčus.",
              textAlign: TextAlign.center,
              style: TextStyle(color: QortColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _sportChip("Visi sportai", null),
          const SizedBox(width: 8),
          ..._userSports.map(
            (sport) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _sportChip(sport, sport),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sportChip(String label, String? value) {
    final isSelected = _selectedSport == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedSport = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withOpacity(0.2) : QortColors.border,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orange : QortColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) ...[
              SportIcons.icon(
                value,
                size: 14,
                color: isSelected ? Colors.orange : QortColors.primary,
              ),
              const SizedBox(width: 6),
            ] else
              Icon(
                LucideIcons.layoutGrid,
                size: 14,
                color: isSelected ? Colors.orange : QortColors.textSecondary,
              ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.orange : QortColors.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === BENDRA SUVESTINĖ ===
  Widget _buildSummaryCard() {
    final matches = _filteredMatches;
    final total = matches.length;
    final wins = matches.where((m) => m['i_won'] == true).length;
    final losses = total - wins;
    final winRate = total > 0 ? (wins / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.15),
            QortColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            _selectedSport ?? "VISI SPORTAI",
            style: GoogleFonts.bebasNeue(
              color: QortColors.textSecondary,
              letterSpacing: 2,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryNumber("$total", "MATČAI", Colors.white),
              _summaryNumber("$wins", "PERGALĖS", Colors.green),
              _summaryNumber("$losses", "PRALAIMĖJIMAI", Colors.red),
              _summaryNumber("$winRate%", "WIN RATE", const Color(0xFF3B82F6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryNumber(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.bebasNeue(
            color: color,
            fontSize: 32,
            letterSpacing: 1,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: QortColors.textSecondary,
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // === AKTYVUMAS ===
  Widget _buildActivityCard() {
    final matches = _filteredMatches;
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    int thisMonth = 0;
    int lastMonth = 0;

    for (var m in matches) {
      if (m['date'] == null) continue;
      final date = DateTime.tryParse(m['date'].toString());
      if (date == null) continue;

      if (date.isAfter(thisMonthStart) ||
          date.isAtSameMomentAs(thisMonthStart)) {
        thisMonth++;
      } else if (date.isAfter(lastMonthStart) ||
          date.isAtSameMomentAs(lastMonthStart)) {
        lastMonth++;
      }
    }

    final diff = thisMonth - lastMonth;
    final diffPercent = lastMonth > 0
        ? ((diff / lastMonth) * 100).round()
        : (thisMonth > 0 ? 100 : 0);

    String message;
    Color msgColor;
    IconData msgIcon;

    if (lastMonth == 0 && thisMonth > 0) {
      message = "Pradėjai aktyviai žaisti šį mėnesį";
      msgColor = Colors.green;
      msgIcon = LucideIcons.trendingUp;
    } else if (diff > 0) {
      message = "Aktyvesnis nei praeitą mėnesį (+$diffPercent%)";
      msgColor = Colors.green;
      msgIcon = LucideIcons.trendingUp;
    } else if (diff < 0) {
      message = "Mažiau aktyvus nei praeitą mėnesį ($diffPercent%)";
      msgColor = Colors.orange;
      msgIcon = LucideIcons.trendingDown;
    } else if (thisMonth == 0) {
      message = "Šį mėnesį dar nesužaidei";
      msgColor = Colors.grey;
      msgIcon = LucideIcons.minus;
    } else {
      message = "Aktyvumas toks pat kaip praeitą mėnesį";
      msgColor = QortColors.textSecondary;
      msgIcon = LucideIcons.minus;
    }

    return _insightCard(
      icon: LucideIcons.calendarDays,
      title: "AKTYVUMAS",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _activityBlock(
                  "$thisMonth",
                  DateFormat('yyyy MMM', 'lt').format(now),
                  Colors.white,
                ),
              ),
              Container(width: 1, height: 40, color: QortColors.border),
              Expanded(
                child: _activityBlock(
                  "$lastMonth",
                  DateFormat('yyyy MMM', 'lt').format(lastMonthStart),
                  QortColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: msgColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(msgIcon, color: msgColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: msgColor, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityBlock(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.bebasNeue(color: color, fontSize: 28)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  // === SPORTŲ ANALIZĖ ===
  Widget _buildSportsBreakdownCard() {
    final stats = <String, Map<String, int>>{};

    for (var m in _allMatches) {
      final sport = m['sport'] as String? ?? 'Kitas';
      stats.putIfAbsent(sport, () => {'wins': 0, 'losses': 0});
      if (m['i_won'] == true) {
        stats[sport]!['wins'] = stats[sport]!['wins']! + 1;
      } else {
        stats[sport]!['losses'] = stats[sport]!['losses']! + 1;
      }
    }

    if (stats.isEmpty) return const SizedBox.shrink();

    // Rūšiuojame pagal matčų skaičių
    final sortedSports = stats.entries.toList()
      ..sort((a, b) {
        final totalA = a.value['wins']! + a.value['losses']!;
        final totalB = b.value['wins']! + b.value['losses']!;
        return totalB.compareTo(totalA);
      });

    return _insightCard(
      icon: LucideIcons.layers,
      title: "PAGAL SPORTĄ",
      child: Column(
        children: sortedSports.map((entry) {
          final wins = entry.value['wins']!;
          final losses = entry.value['losses']!;
          final total = wins + losses;
          final winRate = total > 0 ? (wins / total * 100).round() : 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: QortColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      "$wins-$losses",
                      style: const TextStyle(
                        color: QortColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _winRateColor(winRate).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "$winRate%",
                        style: TextStyle(
                          color: _winRateColor(winRate),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 6, color: Colors.red.withOpacity(0.3)),
                      FractionallySizedBox(
                        widthFactor: winRate / 100,
                        child: Container(
                          height: 6,
                          color: Colors.green.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // === TOP VARŽOVAI ===
  Widget _buildTopOpponentsCard() {
    final stats = <String, Map<String, dynamic>>{};

    for (var m in _filteredMatches) {
      final name = m['opponent_name'] as String? ?? '?';
      if (name == '?') continue;
      stats.putIfAbsent(name, () => {'wins': 0, 'losses': 0, 'total': 0});
      stats[name]!['total'] = (stats[name]!['total'] as int) + 1;
      if (m['i_won'] == true) {
        stats[name]!['wins'] = (stats[name]!['wins'] as int) + 1;
      } else {
        stats[name]!['losses'] = (stats[name]!['losses'] as int) + 1;
      }
    }

    if (stats.isEmpty) return const SizedBox.shrink();

    // Top 5 pagal matčų skaičių
    final sorted = stats.entries.toList()
      ..sort(
        (a, b) => (b.value['total'] as int).compareTo(a.value['total'] as int),
      );
    final top = sorted.take(5).toList();

    return _insightCard(
      icon: LucideIcons.users,
      title: "DAŽNIAUSI VARŽOVAI",
      child: Column(
        children: top.map((entry) {
          final wins = entry.value['wins'] as int;
          final losses = entry.value['losses'] as int;
          final total = entry.value['total'] as int;
          final winRate = total > 0 ? (wins / total * 100).round() : 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: QortColors.border,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.user,
                    color: QortColors.textSecondary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: QortColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "$total ${total == 1 ? 'matčas' : 'matčai'}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "${wins}W-${losses}L",
                  style: const TextStyle(color: QortColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _winRateColor(winRate).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "$winRate%",
                    style: TextStyle(
                      color: _winRateColor(winRate),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // === PASKUTINIŲ 10 MATČŲ FORMA ===
  Widget _buildRecentFormCard() {
    final recent = _filteredMatches.take(10).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    final wins = recent.where((m) => m['i_won'] == true).length;

    // Skaičiuojame ilgiausią dabartinę pergalių seriją
    int currentStreak = 0;
    bool? streakType;
    for (var m in recent) {
      final won = m['i_won'] == true;
      if (streakType == null) {
        streakType = won;
        currentStreak = 1;
      } else if (streakType == won) {
        currentStreak++;
      } else {
        break;
      }
    }

    return _insightCard(
      icon: LucideIcons.activity,
      title: "PASKUTINIŲ 10 FORMA",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pilulių eilutė (naujausi - kairėje)
          Row(
            children: recent.map((m) {
              final won = m['i_won'] == true;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 32,
                  decoration: BoxDecoration(
                    color: won
                        ? Colors.green.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: won ? Colors.green : Colors.red,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    won ? "W" : "L",
                    style: TextStyle(
                      color: won ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Iš ${recent.length} matčų — $wins pergalės (${(wins / recent.length * 100).round()}%)",
                  style: const TextStyle(color: QortColors.textSecondary, fontSize: 13),
                ),
              ),
              if (currentStreak > 1) ...[
                Icon(
                  streakType == true
                      ? LucideIcons.flame
                      : LucideIcons.cloudRain,
                  color: streakType == true ? Colors.orange : Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  "${currentStreak}x ${streakType == true ? 'W' : 'L'}",
                  style: TextStyle(
                    color: streakType == true ? Colors.orange : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // === HELPERIS: KORTELĖS APLANKAS ===
  Widget _insightCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: QortColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF3B82F6), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.bebasNeue(
                  color: QortColors.textSecondary,
                  letterSpacing: 1.5,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Color _winRateColor(int rate) {
    if (rate >= 60) return Colors.green;
    if (rate >= 40) return Colors.orange;
    return Colors.red;
  }
}
