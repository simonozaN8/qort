import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/query_limits.dart';
import '../../core/services/event_archive_service.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_design_system.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/theme/qort_theme.dart';
import '../../core/utils/sport_icons.dart';
import '../tournament/event_detail_screen.dart';
import 'add_external_record_screen.dart';

class MyResultsScreen extends StatefulWidget {
  final int initialTab;

  const MyResultsScreen({super.key, this.initialTab = 0});

  @override
  State<MyResultsScreen> createState() => _MyResultsScreenState();
}

class _MyResultsScreenState extends State<MyResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: p.textPrimary),
        title: Text(
          'Mano rezultatai',
          style: GoogleFonts.oswald(
            color: p.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFEAB308),
          unselectedLabelColor: p.textSecondary,
          indicatorColor: const Color(0xFFEAB308),
          tabs: const [
            Tab(
              text: 'Turnyrai',
              icon: Icon(LucideIcons.trophy, size: 16),
            ),
            Tab(
              text: 'Mačai',
              icon: Icon(LucideIcons.swords, size: 16),
            ),
            Tab(
              text: 'Išoriniai',
              icon: Icon(LucideIcons.plusCircle, size: 16),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ArchiveTab(),
          _MatchesTab(),
          _ExternalRecordsTab(),
        ],
      ),
    );
  }
}

// ─── TAB 1: QORT turnyrų archyvas ───────────────────────────────────────────

class _ArchiveTab extends StatefulWidget {
  const _ArchiveTab();

  @override
  State<_ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<_ArchiveTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _events = [];
  List<String> _availableSports = [];
  List<String> _availableCities = [];
  List<int> _availableYears = [];
  String _sport = 'VISI';
  int? _year;
  String? _city;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    _loadArchive();
  }

  void _deriveFilterOptions(List<Map<String, dynamic>> allEvents) {
    final sports = <String>{};
    final cities = <String>{};
    final years = <int>{};

    for (final event in allEvents) {
      final sport = event['sport']?.toString().trim() ?? '';
      if (sport.isNotEmpty) sports.add(sport);

      final location = event['location']?.toString().trim() ?? '';
      if (location.isNotEmpty) cities.add(location);

      final startStr = event['start_date']?.toString();
      if (startStr != null) {
        final dt = DateTime.tryParse(startStr);
        if (dt != null) years.add(dt.year);
      }
    }

    _availableSports = sports.toList()..sort();
    _availableCities = cities.toList()..sort();
    _availableYears = years.toList()..sort((a, b) => b.compareTo(a));

    if (_sport != 'VISI' && !_availableSports.contains(_sport)) _sport = 'VISI';
    if (_city != null && !_availableCities.contains(_city)) _city = null;
    if (_year != null && !_availableYears.contains(_year)) _year = null;
  }

  void _applyFilters() {
    _events = _allEvents.where((event) {
      if (_sport != 'VISI') {
        final eventSport = event['sport']?.toString().trim() ?? '';
        if (eventSport.toLowerCase() != _sport.toLowerCase()) return false;
      }
      if (_year != null) {
        final startStr = event['start_date']?.toString();
        final dt = startStr != null ? DateTime.tryParse(startStr) : null;
        if (dt == null || dt.year != _year) return false;
      }
      if (_city != null) {
        final location =
            event['location']?.toString().trim().toLowerCase() ?? '';
        if (location != _city!.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _loadArchive() async {
    setState(() => _isLoading = true);
    try {
      final data = await EventArchiveService.loadUserHistory(userId: _userId);
      if (!mounted) return;
      setState(() {
        _allEvents = data;
        _deriveFilterOptions(data);
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Klaida kraunant archyvą: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openFilters() async {
    if (_availableSports.isEmpty &&
        _availableCities.isEmpty &&
        _availableYears.isEmpty) {
      return;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: QortColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ArchiveFilterSheet(
        sports: _availableSports,
        cities: _availableCities,
        years: _availableYears,
        initialSport: _sport,
        initialYear: _year,
        initialCity: _city,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _sport = result['sport'] as String? ?? 'VISI';
      _year = result['year'] as int?;
      _city = result['city'] as String?;
      _applyFilters();
    });
  }

  Map<String, dynamic>? _userParticipation(Map<String, dynamic> event) {
    if (_userId == null) return null;
    final tournaments = event['tournaments'] as List? ?? [];
    for (final t in tournaments) {
      if (t is! Map) continue;
      final participants = t['tournament_participants'] as List? ?? [];
      for (final p in participants) {
        if (p is Map && p['user_id']?.toString() == _userId) {
          return {'tournament': t, 'participant': p};
        }
      }
    }
    return null;
  }

  String _resultLabel(Map<String, dynamic>? participation) {
    if (participation == null) return '';
    final p = participation['participant'] as Map<String, dynamic>;
    final place = p['final_place'];
    final rp = p['earned_rp'];
    final xp = p['earned_xp'];
    final parts = <String>[];
    if (place != null) parts.add('$place. vieta');
    if (rp != null && (rp as num) > 0) parts.add('+$rp RP');
    if (xp != null && (xp as num) > 0) parts.add('+$xp XP');
    return parts.isEmpty ? 'Dalyvavo' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final hasFilters = _availableSports.isNotEmpty ||
        _availableCities.isNotEmpty ||
        _availableYears.isNotEmpty;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (hasFilters)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: IconButton(
                icon: const Icon(LucideIcons.slidersHorizontal),
                color: p.textSecondary,
                tooltip: 'Filtrai',
                onPressed: _openFilters,
              ),
            ),
          ),
        Expanded(
          child: _allEvents.isEmpty
              ? _emptyState(
                  p,
                  icon: LucideIcons.archive,
                  message: 'Nėra pasibaigusių turnyrų',
                )
              : _events.isEmpty
                  ? _emptyState(
                      p,
                      icon: LucideIcons.filterX,
                      message: 'Pagal pasirinktus filtrus turnyrų nerasta',
                      action: TextButton(
                        onPressed: () => setState(() {
                          _sport = 'VISI';
                          _year = null;
                          _city = null;
                          _applyFilters();
                        }),
                        child: const Text('Išvalyti filtrus'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadArchive,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          final participation = _userParticipation(event);
                          final startDate = event['start_date']?.toString();
                          final dateLabel = startDate != null
                              ? DateFormat('yyyy-MM-dd')
                                  .format(DateTime.parse(startDate))
                              : '—';
                          final sport = event['sport']?.toString().toUpperCase() ??
                              'SPORTAS';
                          final status = event['status']?.toString() ?? '';
                          final statusLabel = status == 'cancelled'
                              ? 'Atšauktas'
                              : 'Pasibaigęs';

                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EventDetailScreen(event: event),
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: p.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: QortColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      SportIcons.badge(sport, size: 24),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          event['name']?.toString() ??
                                              'Renginys',
                                          style: const TextStyle(
                                            color: QortColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: status == 'cancelled'
                                              ? Colors.red
                                                  .withValues(alpha: 0.15)
                                              : Colors.grey
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: status == 'cancelled'
                                                ? Colors.redAccent
                                                : p.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(LucideIcons.calendar,
                                          size: 14, color: p.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(dateLabel,
                                          style: TextStyle(
                                              color: p.textSecondary,
                                              fontSize: 12)),
                                      const SizedBox(width: 12),
                                      Icon(LucideIcons.mapPin,
                                          size: 14, color: p.textSecondary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          event['location']?.toString() ??
                                              'Vieta nenustatyta',
                                          style: TextStyle(
                                              color: p.textSecondary,
                                              fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (participation != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _resultLabel(participation),
                                      style: const TextStyle(
                                        color: Color(0xFFEAB308),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

// ─── TAB 2: QORT mačai ───────────────────────────────────────────────────────

class _MatchesTab extends StatefulWidget {
  const _MatchesTab();

  @override
  State<_MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<_MatchesTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _matches = [];

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final myId = session.user.id;
      final supabase = Supabase.instance.client;

      final qortMatches = List<Map<String, dynamic>>.from(
        await supabase
            .from('matches')
            .select('*, tournaments(name, sport)')
            .or('player1_id.eq.$myId,player2_id.eq.$myId')
            .eq('status', 'completed')
            .order('match_date', ascending: false)
            .limit(QueryLimits.myRecords),
      );

      final opponentIds = <String>{};
      for (final m in qortMatches) {
        if (m['player1_id'] != myId && m['player1_id'] != null) {
          opponentIds.add(m['player1_id'].toString());
        }
        if (m['player2_id'] != myId && m['player2_id'] != null) {
          opponentIds.add(m['player2_id'].toString());
        }
      }

      final opponentNames = <String, String>{};
      if (opponentIds.isNotEmpty) {
        final profiles = await supabase
            .from('profiles')
            .select('id, nickname, name')
            .inFilter('id', opponentIds.toList());
        for (final p in profiles as List) {
          final name = (p['nickname'] as String?)?.isNotEmpty == true
              ? p['nickname']
              : p['name'] ?? '?';
          opponentNames[p['id'].toString()] = name.toString();
        }
      }

      for (final m in qortMatches) {
        m['_i_won'] = m['winner_id'] == myId;
        final oppId = m['player1_id'] == myId
            ? m['player2_id']
            : m['player1_id'];
        m['_opponent_name'] = opponentNames[oppId?.toString()] ?? '?';
        final matchDetails = m['match_details'] as Map<String, dynamic>?;
        m['_score_str'] = matchDetails?['score_str'] as String? ?? '';
        m['_am_i_player1'] = m['player1_id'] == myId;
        m['_tournament_name'] =
            (m['tournaments'] as Map?)?['name'] ?? 'QORT turnyras';
        m['_sport'] = (m['tournaments'] as Map?)?['sport'] ?? '';
        m['_date'] = m['match_date'] ?? m['created_at'];
      }

      if (mounted) {
        setState(() {
          _matches = qortMatches;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Klaida kraunant mačus: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_matches.isEmpty) {
      return _emptyState(
        context.qortPalette,
        icon: LucideIcons.swords,
        message: 'Nėra sužaistų QORT mačų',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMatches,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _matches.length,
        itemBuilder: (context, index) =>
            _QortMatchCard(match: _matches[index]),
      ),
    );
  }
}

// ─── TAB 3: Išoriniai įrašai ────────────────────────────────────────────────

class _ExternalRecordsTab extends StatefulWidget {
  const _ExternalRecordsTab();

  @override
  State<_ExternalRecordsTab> createState() => _ExternalRecordsTabState();
}

class _ExternalRecordsTabState extends State<_ExternalRecordsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final myId = session.user.id;
      final supabase = Supabase.instance.client;

      final externalRecords = List<Map<String, dynamic>>.from(
        await supabase
            .from('external_records')
            .select()
            .eq('user_id', myId)
            .order('date_played', ascending: false)
            .limit(QueryLimits.myRecords),
      );

      if (externalRecords.isNotEmpty) {
        final recordIds =
            externalRecords.map((r) => r['id'] as String).toList();
        final setsResponse = await supabase
            .from('match_sets')
            .select()
            .inFilter('record_id', recordIds)
            .order('set_number');
        final allSets = List<Map<String, dynamic>>.from(setsResponse);
        for (final record in externalRecords) {
          record['sets'] = allSets
              .where((s) => s['record_id'] == record['id'])
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          _records = externalRecords;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Klaida kraunant išorinius įrašus: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openAddScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddExternalRecordScreen()),
    );
    if (result == true) _loadRecords();
  }

  Future<void> _deleteRecord(String recordId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: QortColors.surface,
        title: const Text('Ištrinti įrašą?',
            style: TextStyle(color: QortColors.textPrimary)),
        content: const Text('Šio veiksmo negalima atšaukti.',
            style: TextStyle(color: QortColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Atšaukti'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ištrinti', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('match_sets')
          .delete()
          .eq('record_id', recordId);
      await Supabase.instance.client
          .from('external_records')
          .delete()
          .eq('id', recordId);
      _loadRecords();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nepavyko ištrinti: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openAddScreen,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Pridėti įrašą'),
              style: ElevatedButton.styleFrom(
                backgroundColor: QortDesignSystem.competition,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _records.isEmpty
                  ? _emptyState(
                      p,
                      icon: LucideIcons.fileQuestion,
                      message: 'Nėra išorinių įrašų',
                      action: ElevatedButton.icon(
                        onPressed: _openAddScreen,
                        icon: const Icon(LucideIcons.plus),
                        label: const Text('Pridėti pirmą įrašą'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QortColors.primary,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRecords,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _records.length,
                        itemBuilder: (context, index) => _ExternalRecordCard(
                          record: _records[index],
                          onDelete: () =>
                              _deleteRecord(_records[index]['id']),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

// ─── Bendri widget'ai ────────────────────────────────────────────────────────

Widget _emptyState(
  dynamic p, {
  required IconData icon,
  required String message,
  Widget? action,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: p.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(color: p.textSecondary),
              textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    ),
  );
}

class _QortMatchCard extends StatelessWidget {
  final Map<String, dynamic> match;

  const _QortMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final iWon = match['_i_won'] as bool;
    final opponentName = match['_opponent_name'] as String;
    final tournamentName = match['_tournament_name'] as String;
    final sport = match['_sport'] as String;
    final scoreStr = match['_score_str'] as String;
    final amIPlayer1 = match['_am_i_player1'] as bool;
    final stage = match['stage'] as String? ?? '';
    final groupName = match['group_name'] as String? ?? '';

    final setsList = <Map<String, String>>[];
    String? specialNote;

    if (scoreStr.isNotEmpty) {
      final normalized = scoreStr
          .trim()
          .replaceAll(',', ' ')
          .replaceAll('-', ':')
          .replaceAll(RegExp(r'\s+'), ' ');

      if (!normalized.contains(':')) {
        specialNote = scoreStr;
      } else {
        for (final part in normalized.split(' ')) {
          if (!part.contains(':')) continue;
          final scores = part.split(':');
          if (scores.length == 2) {
            setsList.add({
              'my': amIPlayer1 ? scores[0].trim() : scores[1].trim(),
              'opp': amIPlayer1 ? scores[1].trim() : scores[0].trim(),
            });
          }
        }
        if (setsList.isEmpty) specialNote = scoreStr;
      }
    }

    final borderColor = iWon ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.trophy,
                  size: 18, color: Color(0xFFEAB308)),
              const SizedBox(width: 8),
              Text(
                'QORT TURNYRAS',
                style: GoogleFonts.bebasNeue(
                  color: const Color(0xFFEAB308),
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(match['_date']),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tournamentName,
            style: const TextStyle(
              color: QortColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (stage.isNotEmpty || groupName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (stage.isNotEmpty) _formatStage(stage),
                if (groupName.isNotEmpty) groupName,
              ].join(' • '),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'vs $opponentName',
            style: const TextStyle(
              color: QortColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (setsList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ...setsList.map(
                  (set) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: QortColors.border,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '${set['my']}:${set['opp']}',
                      style: const TextStyle(
                        color: QortColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                _wlBadge(iWon),
              ],
            ),
          ] else if (specialNote != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(specialNote,
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                _wlBadge(iWon),
              ],
            ),
          ],
          if (sport.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: QortColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(sport,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExternalRecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onDelete;

  const _ExternalRecordCard({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    const accentColor = QortColors.primary;
    final isTournament = record['record_type'] == 'tournament';
    final status = record['status'] ?? 'completed';
    final iWon = record['i_won'] as bool?;
    final isTeam = record['is_team_match'] == true;

    Color borderColor = Colors.white12;
    if (!isTournament && iWon != null) {
      borderColor = iWon ? Colors.green : Colors.red;
    }
    if (isTournament && status == 'in_progress') {
      borderColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isTournament ? LucideIcons.trophy : LucideIcons.users,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                isTournament ? 'TURNYRAS' : 'DRAUGIŠKAS',
                style: GoogleFonts.bebasNeue(
                  color: accentColor,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(record['date_played']),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(LucideIcons.trash2,
                    size: 16, color: Colors.white30),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isTournament)
            _ExternalTournamentContent(record: record, status: status)
          else
            _ExternalFriendlyContent(
                record: record, isTeam: isTeam, iWon: iWon),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: QortColors.border,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              record['sport'] ?? '',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (record['notes'] != null &&
              (record['notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              record['notes'],
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExternalTournamentContent extends StatelessWidget {
  final Map<String, dynamic> record;
  final String status;

  const _ExternalTournamentContent(
      {required this.record, required this.status});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          record['tournament_name'] ?? '',
          style: const TextStyle(
            color: QortColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (record['organizer'] != null) ...[
          const SizedBox(height: 4),
          Text(record['organizer'],
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
        const SizedBox(height: 8),
        if (status == 'in_progress')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Text('VYKSTA',
                style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          )
        else if (record['place_taken'] != null)
          Row(
            children: [
              Icon(LucideIcons.medal,
                  size: 16, color: _placeColor(record['place_taken'])),
              const SizedBox(width: 6),
              Text(
                '${record['place_taken']} vieta',
                style: TextStyle(
                  color: _placeColor(record['place_taken']),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (record['total_participants'] != null) ...[
                const SizedBox(width: 4),
                Text('iš ${record['total_participants']}',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ],
          ),
      ],
    );
  }
}

class _ExternalFriendlyContent extends StatelessWidget {
  final Map<String, dynamic> record;
  final bool isTeam;
  final bool? iWon;

  const _ExternalFriendlyContent({
    required this.record,
    required this.isTeam,
    required this.iWon,
  });

  @override
  Widget build(BuildContext context) {
    final sets = (record['sets'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isTeam) ...[
          Text('Su: ${record['partner_name'] ?? '?'}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            'Prieš: ${record['opponent_name'] ?? '?'} ir ${record['opponent2_name'] ?? '?'}',
            style: const TextStyle(
              color: QortColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ] else
          Text(
            'vs ${record['opponent_name'] ?? '?'}',
            style: const TextStyle(
              color: QortColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (sets.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ...sets.map(
                (set) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: QortColors.border,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    '${set['my_score']}:${set['opponent_score']}',
                    style: const TextStyle(
                      color: QortColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (iWon != null) _wlBadge(iWon!),
            ],
          ),
        ] else if (iWon != null) ...[
          const SizedBox(height: 8),
          _wlBadge(iWon!, large: true),
        ],
      ],
    );
  }
}

Widget _wlBadge(bool iWon, {bool large = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: iWon
          ? Colors.green.withValues(alpha: 0.25)
          : Colors.red.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      large ? (iWon ? 'Laimėjau' : 'Pralaimėjau') : (iWon ? 'W' : 'L'),
      style: TextStyle(
        color: iWon ? Colors.green : Colors.red,
        fontWeight: FontWeight.bold,
        fontSize: large ? 13 : 14,
      ),
    ),
  );
}

String _formatStage(String stage) {
  if (stage == 'group') return 'Grupė';
  if (stage == 'playoffs') return 'Pliai-of';
  if (stage == 'ladder') return 'Laiptai';
  return stage;
}

Color _placeColor(int place) {
  if (place == 1) return const Color(0xFFFFD700);
  if (place == 2) return const Color(0xFFC0C0C0);
  if (place == 3) return const Color(0xFFCD7F32);
  return Colors.white;
}

String _formatDate(dynamic date) {
  if (date == null) return '';
  try {
    return DateFormat('yyyy-MM-dd').format(DateTime.parse(date.toString()));
  } catch (_) {
    return date.toString();
  }
}

class _ArchiveFilterSheet extends StatefulWidget {
  final List<String> sports;
  final List<String> cities;
  final List<int> years;
  final String initialSport;
  final int? initialYear;
  final String? initialCity;

  const _ArchiveFilterSheet({
    required this.sports,
    required this.cities,
    required this.years,
    required this.initialSport,
    this.initialYear,
    this.initialCity,
  });

  @override
  State<_ArchiveFilterSheet> createState() => _ArchiveFilterSheetState();
}

class _ArchiveFilterSheetState extends State<_ArchiveFilterSheet> {
  late String _sport;
  int? _year;
  String? _city;

  @override
  void initState() {
    super.initState();
    _sport = widget.initialSport;
    _year = widget.initialYear;
    _city = widget.initialCity;
  }

  @override
  Widget build(BuildContext context) {
    final sportOptions = ['VISI', ...widget.sports];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FILTRAI', style: QortTheme.sectionTitle(context.qortPalette)),
            if (widget.sports.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('SPORTAS',
                  style: QortTheme.sectionTitle(context.qortPalette)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sportOptions.map((s) {
                  return FilterChip(
                    label: Text(s == 'VISI' ? 'Visi sportai' : s),
                    selected: _sport == s,
                    onSelected: (_) => setState(() => _sport = s),
                  );
                }).toList(),
              ),
            ],
            if (widget.years.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('METAI',
                  style: QortTheme.sectionTitle(context.qortPalette)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Visi metai'),
                    selected: _year == null,
                    onSelected: (_) => setState(() => _year = null),
                  ),
                  ...widget.years.map(
                    (y) => FilterChip(
                      label: Text('$y'),
                      selected: _year == y,
                      onSelected: (_) => setState(() => _year = y),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.cities.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('MIESTAS',
                  style: QortTheme.sectionTitle(context.qortPalette)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Visi miestai'),
                    selected: _city == null,
                    onSelected: (_) => setState(() => _city = null),
                  ),
                  ...widget.cities.map(
                    (c) => FilterChip(
                      label: Text(c),
                      selected: _city == c,
                      onSelected: (_) => setState(() => _city = c),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: QortDesignSystem.competition,
                ),
                onPressed: () => Navigator.pop(context, {
                  'sport': _sport,
                  'year': _year,
                  'city': _city,
                }),
                child: const Text('Taikyti'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
