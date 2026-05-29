import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/widgets/qort_form_help.dart';
import 'user_picker_field.dart';
import '../teams/team_model.dart';

class AddExternalRecordScreen extends StatefulWidget {
  const AddExternalRecordScreen({super.key});

  @override
  State<AddExternalRecordScreen> createState() =>
      _AddExternalRecordScreenState();
}

class _AddExternalRecordScreenState extends State<AddExternalRecordScreen> {
  // Žingsnis: 0 = tipas, 1 = sportas, 2 = detalės
  final int _step = 0;
  bool _isSaving = false;
  bool _isLoadingSports = true;

  // Vartotojo pasirinkimai
  String _recordType = "friendly"; // friendly | tournament
  String _matchFormat = "1v1"; // "1v1" | "2v2" | "team"

  // Komandinio matčo duomenys (kai _matchFormat == "team")
  String? _selectedTeamId;
  String? _selectedTeamName;
  List<String> _selectedMemberIds = []; // kurie nariai žaidė
  final List<String> _guestNames = []; // svečiai (tik draugiškuose)
  String? _opponentTeamName; // varžovų komandos pavadinimas (tekstas)
  String? _opponentTeamId; // varžovų QORT komanda (jei egzistuoja)
  final _myTeamScoreCtrl = TextEditingController();
  final _opponentTeamScoreCtrl = TextEditingController();

  // Mano komandos (užkraunamos iš DB pagal pasirinktą sportą)
  List<Team> _myTeams = [];
  bool _isLoadingMyTeams = false;
  List<TeamMember> _selectedTeamMembers = [];
  final _guestNameCtrl = TextEditingController();

  // Varžovų komandų paieška
  List<Team> _opponentTeamSearchResults = [];
  bool _isSearchingOpponent = false;
  final _opponentTeamSearchCtrl = TextEditingController();

  String? _selectedSport;
  DateTime _datePlayed = DateTime.now();

  // Sportai iš sports_catalog
  List<Map<String, dynamic>> _sportsCatalog = [];

  // Turnyro duomenys
  final _tournamentNameCtrl = TextEditingController();
  final _organizerCtrl = TextEditingController();

  // Status — ar turnyras dar vyksta, ar baigtas
  String _status = "in_progress"; // in_progress | completed
  final _placeCtrl = TextEditingController();
  final _totalParticipantsCtrl = TextEditingController();

  // Varžovas (1v1)
  String? _opponentUserId;
  String? _opponentName;

  // Partneris (2v2)
  String? _partnerUserId;
  String? _partnerName;

  // Varžovas 2 (2v2)
  String? _opponent2UserId;
  String? _opponent2Name;

  // Rezultatas - setų sąrašas
  final List<Map<String, TextEditingController>> _sets = [
    {'mine': TextEditingController(), 'opponent': TextEditingController()},
  ];
  bool? _iWon;
  bool _showAdvancedFormats = false;
  bool _useSimpleScore = true;
  final _simpleMyCtrl = TextEditingController();
  final _simpleOppCtrl = TextEditingController();

  /// Tik galutinė vieta be atskiro mačo (išorinis turnyras).
  bool _placementOnly = false;

  // Notes
  final _notesCtrl = TextEditingController();

  final _opponentPickerKey = GlobalKey<UserPickerFieldState>();
  final _partnerPickerKey = GlobalKey<UserPickerFieldState>();
  final _opponent2PickerKey = GlobalKey<UserPickerFieldState>();

  @override
  void initState() {
    super.initState();
    _loadSportsCatalog();
  }

  @override
  void dispose() {
    _tournamentNameCtrl.dispose();
    _organizerCtrl.dispose();
    _placeCtrl.dispose();
    _totalParticipantsCtrl.dispose();
    for (var set in _sets) {
      set['mine']?.dispose();
      set['opponent']?.dispose();
    }
    _notesCtrl.dispose();
    _myTeamScoreCtrl.dispose();
    _opponentTeamScoreCtrl.dispose();
    _guestNameCtrl.dispose();
    _opponentTeamSearchCtrl.dispose();
    _simpleMyCtrl.dispose();
    _simpleOppCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSportsCatalog() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        if (mounted) setState(() => _isLoadingSports = false);
        return;
      }

      final userSportsResponse = await Supabase.instance.client
          .from('user_sports')
          .select('sport')
          .eq('user_id', session.user.id);

      final userSportNames = (userSportsResponse as List)
          .map((s) => s['sport'] as String)
          .toList();

      if (userSportNames.isEmpty) {
        final allSports = await Supabase.instance.client
            .from('sports_catalog')
            .select()
            .eq('is_active', true)
            .order('name');

        if (mounted) {
          setState(() {
            _sportsCatalog = List<Map<String, dynamic>>.from(allSports);
            _isLoadingSports = false;
          });
        }
        return;
      }

      final response = await Supabase.instance.client
          .from('sports_catalog')
          .select()
          .eq('is_active', true)
          .inFilter('name', userSportNames)
          .order('name');

      if (mounted) {
        setState(() {
          _sportsCatalog = List<Map<String, dynamic>>.from(response);
          _isLoadingSports = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant sportus: $e");
      if (mounted) setState(() => _isLoadingSports = false);
    }
  }

  // Užkraunam vartotojo komandas, filtruotas pagal pasirinktą sportą
  Future<void> _loadMyTeams() async {
    if (_selectedSport == null) return;

    setState(() => _isLoadingMyTeams = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final userId = session.user.id;
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('team_members')
          .select('''
            team_id,
            teams!inner(*)
          ''')
          .eq('user_id', userId);

      final allTeams = (response as List)
          .map((row) => Team.fromJson(row['teams'] as Map<String, dynamic>))
          .where((team) => team.sport == _selectedSport)
          .toList();

      if (mounted) {
        setState(() {
          _myTeams = allTeams;
          _isLoadingMyTeams = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant komandas: $e");
      if (mounted) setState(() => _isLoadingMyTeams = false);
    }
  }

  // Užkraunam komandos narius, kai komanda pasirenkama
  Future<void> _loadTeamMembers(String teamId) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('team_members')
          .select('''
            *,
            profiles!team_members_user_id_fkey(nickname, name, surname, photo_url)
          ''')
          .eq('team_id', teamId);

      final members = (response as List)
          .map((json) => TeamMember.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _selectedTeamMembers = members;
          _selectedMemberIds = [];
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant narius: $e");
    }
  }

  // QORT komandų paieška (varžovams)
  Future<void> _searchOpponentTeams(String query) async {
    if (query.trim().length < 2) {
      setState(() => _opponentTeamSearchResults = []);
      return;
    }

    setState(() => _isSearchingOpponent = true);

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('teams')
          .select()
          .eq('sport', _selectedSport ?? '')
          .ilike('name', '%${query.trim()}%')
          .limit(10);

      final results = (response as List)
          .map((json) => Team.fromJson(json))
          .where((t) => !_myTeams.any((myTeam) => myTeam.id == t.id))
          .toList();

      if (mounted) {
        setState(() {
          _opponentTeamSearchResults = results;
          _isSearchingOpponent = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida ieškant komandų: $e");
      if (mounted) setState(() => _isSearchingOpponent = false);
    }
  }

  void _commitPendingPickerText() {
    if (_recordType != 'friendly') return;

    if (_matchFormat == '1v1') {
      _applyPickerCommit(_opponentPickerKey, (userId, name) {
        _opponentUserId = userId;
        _opponentName = name;
      });
    } else if (_matchFormat == '2v2') {
      _applyPickerCommit(_partnerPickerKey, (userId, name) {
        _partnerUserId = userId;
        _partnerName = name;
      });
      _applyPickerCommit(_opponentPickerKey, (userId, name) {
        _opponentUserId = userId;
        _opponentName = name;
      });
      _applyPickerCommit(_opponent2PickerKey, (userId, name) {
        _opponent2UserId = userId;
        _opponent2Name = name;
      });
    }
  }

  void _applyPickerCommit(
    GlobalKey<UserPickerFieldState> key,
    void Function(String? userId, String name) apply,
  ) {
    final state = key.currentState;
    if (state == null) return;

    final (userId, name) = state.commitPendingText();
    if (name.trim().isEmpty) return;

    apply(userId, name.trim());
  }

  Future<void> _save() async {
    _commitPendingPickerText();

    // Validacija
    if (_selectedSport == null) {
      _showError("Pasirink sporto šaką");
      return;
    }

    if (_recordType == "tournament") {
      if (_tournamentNameCtrl.text.trim().isEmpty) {
        _showError('Įvesk turnyro pavadinimą');
        return;
      }
      if (_status == 'completed') {
        final place = int.tryParse(_placeCtrl.text.trim());
        if (place == null || place < 1) {
          _showError('Įvesk galutinę vietą (pvz. 3)');
          return;
        }
      }
    }

    if (_recordType == "friendly" &&
        _matchFormat == "1v1" &&
        (_opponentName == null || _opponentName!.trim().isEmpty)) {
      _showError("Pasirink varžovą");
      return;
    }

    if (_recordType == 'friendly' && _matchFormat != 'team') {
      if (_iWon == null && !_hasScoreInput()) {
        _showError('Įvesk rezultatą arba pasirink, ar laimėjai');
        return;
      }
    }

    // 2v2 formato validacija
    if (_recordType == "friendly" && _matchFormat == "2v2") {
      if (_partnerName == null || _partnerName!.trim().isEmpty) {
        _showError("Pasirink partnerį");
        return;
      }
      if (_opponentName == null || _opponentName!.trim().isEmpty) {
        _showError("Pasirink pirmą varžovą");
        return;
      }
      if (_opponent2Name == null || _opponent2Name!.trim().isEmpty) {
        _showError("Pasirink antrą varžovą");
        return;
      }
    }

    // Komandinio matčo validacija
    if (_matchFormat == "team") {
      if (_selectedTeamId == null) {
        _showError("Pasirink savo komandą");
        return;
      }
      if (_opponentTeamName == null || _opponentTeamName!.trim().isEmpty) {
        _showError("Įvesk varžovų komandos pavadinimą");
        return;
      }
      if (_myTeamScoreCtrl.text.trim().isEmpty ||
          _opponentTeamScoreCtrl.text.trim().isEmpty) {
        _showError("Įvesk komandų rezultatus");
        return;
      }
      // Patikrinam, ar pasirinkta pakankamai narių
      final selectedTeam = _myTeams.firstWhere(
        (t) => t.id == _selectedTeamId,
        orElse: () => _myTeams.first,
      );
      final totalSelected = _selectedMemberIds.length + _guestNames.length;
      if (totalSelected < selectedTeam.playersOnCourt) {
        _showError(
          "Pasirink bent ${selectedTeam.playersOnCourt} narių (${selectedTeam.format ?? ''})",
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception("Vartotojas neprisijungęs");

      final userId = session.user.id;

      final data = <String, dynamic>{
        'user_id': userId,
        'record_type': _recordType,
        'sport': _selectedSport,
        'date_played': DateFormat('yyyy-MM-dd').format(_datePlayed),
        'is_team_match': _matchFormat != "1v1",
        'match_format': _matchFormat,
        'status': _status,
      };

      if (_recordType == "tournament") {
        data['tournament_name'] = _tournamentNameCtrl.text.trim();
        if (_organizerCtrl.text.trim().isNotEmpty) {
          data['organizer'] = _organizerCtrl.text.trim();
        }
        if (_status == "completed") {
          data['place_taken'] = int.tryParse(_placeCtrl.text);
          data['total_participants'] = int.tryParse(
            _totalParticipantsCtrl.text,
          );
        }
      } else {
        // Friendly match
        data['opponent_name'] = _opponentName;
        if (_opponentUserId != null) {
          data['opponent_user_id'] = _opponentUserId;
        }

        // 2v2 (dvejetai) duomenys
        if (_matchFormat == "2v2") {
          data['partner_name'] = _partnerName;
          if (_partnerUserId != null) {
            data['partner_user_id'] = _partnerUserId;
          }
          data['opponent2_name'] = _opponent2Name;
          if (_opponent2UserId != null) {
            data['opponent2_user_id'] = _opponent2UserId;
          }
        }

        // Komandinio matčo duomenys
        if (_matchFormat == "team") {
          data['team_id'] = _selectedTeamId;
          data['opponent_team_name'] = _opponentTeamName;
          if (_opponentTeamId != null) {
            data['opponent_team_id'] = _opponentTeamId;
          }
          data['my_score'] = _myTeamScoreCtrl.text.trim();
          data['opponent_score'] = _opponentTeamScoreCtrl.text.trim();
          // Automatiškai nustatom i_won pagal taškus
          final myScore = int.tryParse(_myTeamScoreCtrl.text.trim()) ?? 0;
          final oppScore =
              int.tryParse(_opponentTeamScoreCtrl.text.trim()) ?? 0;
          if (myScore != oppScore) {
            data['i_won'] = myScore > oppScore;
          }
        }

        // i_won (kas laimėjo) - tik 1v1 ir 2v2
        if (_matchFormat != "team" && _iWon != null) {
          data['i_won'] = _iWon;
        }
      }

      if (_recordType == 'friendly' &&
          _matchFormat != 'team' &&
          _useSimpleScore) {
        _applySimpleScoreToSets();
      }

      if (_notesCtrl.text.trim().isNotEmpty) {
        data['notes'] = _notesCtrl.text.trim();
      }

      // Įrašome pagrindinį įrašą
      final insertResponse = await Supabase.instance.client
          .from('external_records')
          .insert(data)
          .select()
          .single();

      final recordId = insertResponse['id'];

      // Įrašome setus (jei yra) - tik 1v1/2v2 draugiškuose
      if (_recordType == "friendly" && _matchFormat != "team") {
        for (int i = 0; i < _sets.length; i++) {
          final set = _sets[i];
          final mine = set['mine']?.text.trim() ?? '';
          final opp = set['opponent']?.text.trim() ?? '';

          if (mine.isNotEmpty && opp.isNotEmpty) {
            await Supabase.instance.client.from('match_sets').insert({
              'record_id': recordId,
              'set_number': i + 1,
              'my_score': mine,
              'opponent_score': opp,
            });
          }
        }
      }

      // Įrašome komandinio matčo narius (jei team formatas)
      if (_matchFormat == "team") {
        // Komandos narių įrašymas
        for (final memberId in _selectedMemberIds) {
          await Supabase.instance.client.from('match_player_stats').insert({
            'record_id': recordId,
            'user_id': memberId,
            'team_id': _selectedTeamId,
            'is_guest': false,
          });
        }
        // Svečių įrašymas
        for (final guestName in _guestNames) {
          await Supabase.instance.client.from('match_player_stats').insert({
            'record_id': recordId,
            'guest_name': guestName,
            'team_id': _selectedTeamId,
            'is_guest': true,
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Rezultatas išsaugotas"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Klaida išsaugant: $e");
      if (mounted) {
        _showError("Nepavyko išsaugoti: $e");
        setState(() => _isSaving = false);
      }
    }
  }

  bool _hasScoreInput() {
    if (_useSimpleScore) {
      return _simpleMyCtrl.text.trim().isNotEmpty &&
          _simpleOppCtrl.text.trim().isNotEmpty;
    }
    for (final set in _sets) {
      if ((set['mine']?.text.trim().isNotEmpty ?? false) &&
          (set['opponent']?.text.trim().isNotEmpty ?? false)) {
        return true;
      }
    }
    return false;
  }

  void _applySimpleScoreToSets() {
    _sets[0]['mine']?.text = _simpleMyCtrl.text.trim();
    _sets[0]['opponent']?.text = _simpleOppCtrl.text.trim();
    final mine = int.tryParse(_simpleMyCtrl.text.trim()) ?? 0;
    final opp = int.tryParse(_simpleOppCtrl.text.trim()) ?? 0;
    if (mine != opp) {
      _iWon = mine > opp;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datePlayed,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              surface: Color(0xFF18181B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _datePlayed = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final accentColor = p.primary;

    if (_isLoadingSports) {
      return Scaffold(
        backgroundColor: p.background,
        body: Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: Text(
          "IŠORINIS ĮRAŠAS",
          style: GoogleFonts.bebasNeue(
            color: p.textPrimary,
            letterSpacing: 2,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.x, color: p.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const QortHelpBanner(
                        title: 'Sporto pasas',
                        bullets: [QortFormHelpTexts.externalRecordIntro],
                      ),
                      const SizedBox(height: 16),
                      _buildDateSection(accentColor),
                      const SizedBox(height: 20),
                      _buildTypeSection(accentColor),
                      const SizedBox(height: 20),
                      _buildSportSection(accentColor),
                      const SizedBox(height: 20),
                      if (_recordType == "tournament")
                        _buildTournamentFields(accentColor)
                      else ...[
                        _buildFriendlyFields(accentColor),
                        if (_matchFormat != 'team') ...[
                          const SizedBox(height: 20),
                          _buildFriendlyScoreSection(accentColor),
                        ],
                      ],
                      const SizedBox(height: 20),
                      _buildNotesField(accentColor),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "IŠSAUGOTI",
                          style: GoogleFonts.bebasNeue(
                            fontSize: 22,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === TIPO PASIRINKIMAS ===
  Widget _buildTypeSection(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("KOKS REZULTATAS?"),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _typeButton(
                "Draugiškas mačas",
                LucideIcons.users,
                "friendly",
                accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _typeButton(
                "Išorinis turnyras",
                LucideIcons.trophy,
                "tournament",
                accentColor,
              ),
            ),
          ],
        ),
        if (_recordType == 'friendly') ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _showAdvancedFormats = !_showAdvancedFormats),
              icon: Icon(
                _showAdvancedFormats
                    ? LucideIcons.chevronUp
                    : LucideIcons.chevronDown,
                size: 16,
                color: accentColor,
              ),
              label: Text(
                _showAdvancedFormats
                    ? 'Slėpti formatus'
                    : 'Daugiau formatų (2v2, komanda)',
                style: TextStyle(color: accentColor, fontSize: 12),
              ),
            ),
          ),
          if (_showAdvancedFormats) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _formatButton("1v1", "1v1", accentColor)),
                const SizedBox(width: 8),
                Expanded(child: _formatButton("2v2", "2v2", accentColor)),
                const SizedBox(width: 8),
                Expanded(
                  child: _formatButton("Komanda", "team", accentColor),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Formatas: 1 prieš 1',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ],
      ],
    );
  }

  Widget _formatButton(String label, String value, Color accentColor) {
    final isSelected = _matchFormat == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _matchFormat = value;
          if (value != "team") {
            _selectedTeamId = null;
            _selectedTeamName = null;
            _selectedMemberIds.clear();
            _guestNames.clear();
            _opponentTeamName = null;
            _opponentTeamId = null;
          }
          if (value != "2v2") {
            _partnerUserId = null;
            _partnerName = null;
            _opponent2UserId = null;
            _opponent2Name = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.2)
              : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? accentColor : Colors.white12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeButton(
    String label,
    IconData icon,
    String value,
    Color accentColor,
  ) {
    final isSelected = _recordType == value;
    return GestureDetector(
      onTap: () => setState(() => _recordType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? accentColor : Colors.white12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === SPORTO ŠAKOS PASIRINKIMAS ===
  Widget _buildSportSection(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("SPORTO ŠAKA"),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButton<String>(
            value: _selectedSport,
            hint: const Text("Pasirink", style: TextStyle(color: Colors.grey)),
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF18181B),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            items: _sportsCatalog.map((sport) {
              return DropdownMenuItem<String>(
                value: sport['name'] as String,
                child: Text(sport['name'] as String),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSport = value;
                // Pakeitus sportą - išvalom komandų pasirinkimus
                _selectedTeamId = null;
                _selectedTeamName = null;
                _selectedMemberIds.clear();
                _guestNames.clear();
                _myTeams = [];
                _opponentTeamName = null;
                _opponentTeamId = null;
                _opponentTeamSearchCtrl.clear();
                _opponentTeamSearchResults.clear();
              });
            },
          ),
        ),
      ],
    );
  }

  // === DATA ===
  Widget _buildDateSection(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("DATA"),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.calendar, color: Colors.grey, size: 20),
                const SizedBox(width: 12),
                Text(
                  DateFormat('yyyy-MM-dd').format(_datePlayed),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // === TURNYRO LAUKAI (tik ne QORT platformoje) ===
  Widget _buildTournamentFields(Color accentColor) {
    final p = context.qortPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.info, color: accentColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'QORT turnyro rezultatus įvedi iš Pagrindinio, kai mačas '
                  'suderintas. Čia — tik turnyras kitoje platformoje.',
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _label("TURNYRO PAVADINIMAS"),
        const SizedBox(height: 8),
        _textField(_tournamentNameCtrl, "Pvz. LTU Open 2026"),
        const SizedBox(height: 16),
        _label("ORGANIZATORIUS (NEPRIVALOMA)"),
        const SizedBox(height: 8),
        _textField(_organizerCtrl, "Pvz. Lietuvos teniso sąjunga"),
        const SizedBox(height: 16),
        SwitchListTile(
          value: _placementOnly,
          onChanged: (v) => setState(() {
            _placementOnly = v;
            if (v) _status = 'completed';
          }),
          activeThumbColor: accentColor,
          title: Text(
            'Tik galutinė vieta (be atskiro mačo)',
            style: TextStyle(color: p.textPrimary, fontSize: 13),
          ),
          subtitle: Text(
            'Įrašote vietą turnyre, kuris nebuvo QORT sistemoje.',
            style: TextStyle(color: p.textSecondary, fontSize: 11),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        _label("STATUSAS"),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _statusButton("Vyksta", "in_progress", accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: _statusButton("Baigtas", "completed", accentColor)),
          ],
        ),
        if (_status == "completed") ...[
          const SizedBox(height: 16),
          const QortFieldHelpLabel(
            label: 'GALUTINĖ VIETA',
            help: QortFormHelpTexts.externalRecordPlacement,
          ),
          const SizedBox(height: 8),
          _textField(_placeCtrl, "Pvz. 3", isNumber: true),
          const SizedBox(height: 16),
          _label("DALYVIŲ KIEKIS"),
          const SizedBox(height: 8),
          _textField(_totalParticipantsCtrl, "Pvz. 32", isNumber: true),
        ],
      ],
    );
  }

  Widget _buildFriendlyScoreSection(Color accentColor) {
    final p = context.qortPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const QortFieldHelpLabel(
          label: 'REZULTATAS IR LAIMĖTOJAS',
          help: QortFormHelpTexts.externalRecordScore,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _winChip('Laimėjau', true, accentColor, p),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _winChip('Pralaimėjau', false, accentColor, p),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _winChip('Lygiosios', null, accentColor, p),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilterChip(
                label: const Text('Vienas rezultatas'),
                selected: _useSimpleScore,
                onSelected: (v) => setState(() => _useSimpleScore = true),
                selectedColor: accentColor.withValues(alpha: 0.25),
                checkmarkColor: accentColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilterChip(
                label: const Text('Setai'),
                selected: !_useSimpleScore,
                onSelected: (v) => setState(() => _useSimpleScore = false),
                selectedColor: accentColor.withValues(alpha: 0.25),
                checkmarkColor: accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_useSimpleScore)
          Row(
            children: [
              Expanded(
                child: _scoreBox('Aš', _simpleMyCtrl, accentColor),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _scoreBox('Varžovas', _simpleOppCtrl, accentColor),
              ),
            ],
          )
        else
          ..._buildSetsEditor(accentColor),
      ],
    );
  }

  Widget _winChip(
    String label,
    bool? won,
    Color accent,
    dynamic p,
  ) {
    final selected = _iWon == won;
    return GestureDetector(
      onTap: () => setState(() => _iWon = won),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.2) : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? accent : Colors.white12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreBox(String hint, TextEditingController ctrl, Color accent) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      onChanged: (_) {
        final mine = int.tryParse(_simpleMyCtrl.text.trim());
        final opp = int.tryParse(_simpleOppCtrl.text.trim());
        if (mine != null && opp != null && mine != opp) {
          setState(() => _iWon = mine > opp);
        }
      },
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        filled: true,
        fillColor: accent.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  List<Widget> _buildSetsEditor(Color accentColor) {
    return [
      ...List.generate(_sets.length, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                'Setas ${i + 1}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _sets[i]['mine'],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Aš',
                    filled: true,
                    fillColor: Color(0xFF18181B),
                  ),
                ),
              ),
              const Text(' : ', style: TextStyle(color: Colors.white54)),
              Expanded(
                child: TextField(
                  controller: _sets[i]['opponent'],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Varž.',
                    filled: true,
                    fillColor: Color(0xFF18181B),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
      TextButton.icon(
        onPressed: _sets.length < 5
            ? () {
                setState(() {
                  _sets.add({
                    'mine': TextEditingController(),
                    'opponent': TextEditingController(),
                  });
                });
              }
            : null,
        icon: const Icon(LucideIcons.plus, size: 16),
        label: const Text('Pridėti setą'),
      ),
    ];
  }

  Widget _statusButton(String label, String value, Color accentColor) {
    final isSelected = _status == value;
    return GestureDetector(
      onTap: () => setState(() => _status = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? accentColor : Colors.white12),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // === DRAUGIŠKO MATČO LAUKAI ===
  Widget _buildFriendlyFields(Color accentColor) {
    // 1v1 - vienas varžovas
    if (_matchFormat == "1v1") {
      return UserPickerField(
        key: _opponentPickerKey,
        label: "VARŽOVAS",
        hintText: "Įrašyk vardą arba slapyvardį",
        filterBySport: _selectedSport,
        onUserSelected: (userId, displayName) {
          setState(() {
            _opponentUserId = userId;
            _opponentName = displayName;
          });
        },
      );
    }

    // 2v2 - dvejetai
    if (_matchFormat == "2v2") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserPickerField(
            key: _partnerPickerKey,
            label: "MANO PARTNERIS",
            hintText: "Įrašyk vardą arba slapyvardį",
            filterBySport: _selectedSport,
            onUserSelected: (userId, displayName) {
              setState(() {
                _partnerUserId = userId;
                _partnerName = displayName;
              });
            },
          ),
          const SizedBox(height: 16),
          UserPickerField(
            key: _opponentPickerKey,
            label: "VARŽOVAS 1",
            hintText: "Įrašyk vardą arba slapyvardį",
            filterBySport: _selectedSport,
            onUserSelected: (userId, displayName) {
              setState(() {
                _opponentUserId = userId;
                _opponentName = displayName;
              });
            },
          ),
          const SizedBox(height: 16),
          UserPickerField(
            key: _opponent2PickerKey,
            label: "VARŽOVAS 2",
            hintText: "Įrašyk vardą arba slapyvardį",
            filterBySport: _selectedSport,
            onUserSelected: (userId, displayName) {
              setState(() {
                _opponent2UserId = userId;
                _opponent2Name = displayName;
              });
            },
          ),
        ],
      );
    }

    // team - komandinis matčas
    if (_matchFormat == "team") {
      return _buildTeamMatchFields(accentColor);
    }

    return const SizedBox.shrink();
  }

  // === KOMANDINIO MATČO PAGRINDINIS LAUKAS ===
  Widget _buildTeamMatchFields(Color accentColor) {
    // Užkraunam komandas pirmą kartą
    if (_myTeams.isEmpty && !_isLoadingMyTeams && _selectedSport != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMyTeams();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SLUOKSNIS 1: MANO KOMANDA
        _label("MANO KOMANDA"),
        const SizedBox(height: 8),
        _buildMyTeamSelector(accentColor),

        // SLUOKSNIS 2 + 3: NARIAI + SVEČIAI
        if (_selectedTeamId != null) ...[
          const SizedBox(height: 20),
          _label("KURIE NARIAI ŽAIDĖ"),
          const SizedBox(height: 8),
          _buildMembersSelector(accentColor),
        ],

        // SLUOKSNIS 4: VARŽOVŲ KOMANDA
        if (_selectedTeamId != null) ...[
          const SizedBox(height: 20),
          _label("VARŽOVŲ KOMANDA"),
          const SizedBox(height: 8),
          _buildOpponentTeamPicker(accentColor),
        ],

        // SLUOKSNIS 5: REZULTATAS
        if (_selectedTeamId != null &&
            (_opponentTeamName != null && _opponentTeamName!.isNotEmpty)) ...[
          const SizedBox(height: 20),
          _label("REZULTATAS"),
          const SizedBox(height: 8),
          _buildTeamScoreInput(accentColor),
        ],
      ],
    );
  }

  // === SLUOKSNIS 1: MANO KOMANDOS PASIRINKIMAS ===
  Widget _buildMyTeamSelector(Color accentColor) {
    if (_isLoadingMyTeams) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              "Kraunamos komandos...",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_myTeams.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.orange, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Tu neturi $_selectedSport komandų. Sukurk komandą per Profilis → Mano komandos.",
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _myTeams.map((team) {
        final isSelected = _selectedTeamId == team.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedTeamId = team.id;
                _selectedTeamName = team.name;
                _selectedMemberIds.clear();
                _opponentTeamName = null;
                _opponentTeamId = null;
                _opponentTeamSearchCtrl.clear();
                _opponentTeamSearchResults.clear();
              });
              _loadTeamMembers(team.id);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withOpacity(0.15)
                    : const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? accentColor : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      image: team.logoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(team.logoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: team.logoUrl == null
                        ? Icon(LucideIcons.shield, color: accentColor, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (team.format != null && team.format!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  team.format!,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      LucideIcons.checkCircle2,
                      color: accentColor,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // === SLUOKSNIS 2 + 3: NARIŲ PASIRINKIMAS + SVEČIAI ===
  Widget _buildMembersSelector(Color accentColor) {
    final selectedTeam = _myTeams.firstWhere(
      (t) => t.id == _selectedTeamId,
      orElse: () => _myTeams.first,
    );
    final required = selectedTeam.playersOnCourt;
    final selectedCount = _selectedMemberIds.length;
    final guestsCount = _guestNames.length;
    final totalSelected = selectedCount + guestsCount;
    final canAddMoreGuests =
        totalSelected < required && _recordType == "friendly";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Skaičiavimas
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: totalSelected >= required
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                totalSelected >= required
                    ? LucideIcons.checkCircle2
                    : LucideIcons.alertCircle,
                color: totalSelected >= required ? Colors.green : Colors.orange,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                "Pasirinkta: $totalSelected / $required (${selectedTeam.format ?? ''})",
                style: TextStyle(
                  color: totalSelected >= required
                      ? Colors.green
                      : Colors.orange,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Komandos nariai
        if (_selectedTeamMembers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "Komanda neturi narių",
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ..._selectedTeamMembers.map((member) {
            final isChecked = _selectedMemberIds.contains(member.userId);
            final displayName = member.nickname.isNotEmpty
                ? member.nickname
                : "${member.name} ${member.surname}".trim();

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isChecked) {
                      _selectedMemberIds.remove(member.userId);
                    } else {
                      _selectedMemberIds.add(member.userId);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isChecked
                        ? accentColor.withOpacity(0.15)
                        : const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isChecked ? accentColor : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isChecked
                            ? LucideIcons.checkSquare
                            : LucideIcons.square,
                        color: isChecked ? accentColor : Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                          image:
                              (member.photoUrl != null &&
                                  member.photoUrl!.isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(member.photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child:
                            (member.photoUrl == null ||
                                member.photoUrl!.isEmpty)
                            ? const Icon(
                                LucideIcons.user,
                                color: Colors.white54,
                                size: 16,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isChecked
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (member.role == 'creator')
                        const Icon(
                          LucideIcons.crown,
                          color: Colors.amber,
                          size: 14,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),

        // Svečių sąrašas
        if (_guestNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._guestNames.asMap().entries.map((entry) {
            final index = entry.key;
            final name = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.userPlus,
                      color: Colors.purple,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "$name (svečias)",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.x,
                        color: Colors.red,
                        size: 16,
                      ),
                      onPressed: () {
                        setState(() {
                          _guestNames.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        // Svečio pridėjimas
        if (canAddMoreGuests) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _guestNameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Svečio vardas",
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        setState(() {
                          _guestNames.add(value.trim());
                          _guestNameCtrl.clear();
                        });
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    LucideIcons.plusCircle,
                    color: Colors.purple,
                    size: 20,
                  ),
                  onPressed: () {
                    final value = _guestNameCtrl.text.trim();
                    if (value.isNotEmpty) {
                      setState(() {
                        _guestNames.add(value);
                        _guestNameCtrl.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // === SLUOKSNIS 4: VARŽOVŲ KOMANDOS PASIRINKIMAS ===
  Widget _buildOpponentTeamPicker(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Paieškos laukas
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: _opponentTeamSearchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Ieškok QORT komandos arba įrašyk pavadinimą...",
              hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
              prefixIcon: Icon(
                LucideIcons.search,
                color: Colors.white54,
                size: 18,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            ),
            onChanged: (value) {
              _searchOpponentTeams(value);
              setState(() {
                _opponentTeamName = value.trim().isEmpty ? null : value.trim();
                _opponentTeamId = null;
              });
            },
          ),
        ),

        // Paieškos rezultatai
        if (_isSearchingOpponent) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  "Ieškoma...",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ] else if (_opponentTeamSearchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._opponentTeamSearchResults.map((team) {
            final isSelected = _opponentTeamId == team.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _opponentTeamId = team.id;
                    _opponentTeamName = team.name;
                    _opponentTeamSearchCtrl.text = team.name;
                    _opponentTeamSearchResults.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withOpacity(0.15)
                        : const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? accentColor : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          image: team.logoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(team.logoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: team.logoUrl == null
                            ? Icon(
                                LucideIcons.shield,
                                color: accentColor,
                                size: 14,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (team.format != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                "${team.format} · ${team.city ?? ''}",
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(LucideIcons.shield, color: accentColor, size: 14),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],

        // Statusas
        if (_opponentTeamName != null && _opponentTeamName!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _opponentTeamId != null
                  ? Colors.green.withOpacity(0.1)
                  : Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _opponentTeamId != null
                    ? Colors.green.withOpacity(0.3)
                    : Colors.amber.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _opponentTeamId != null
                      ? LucideIcons.checkCircle2
                      : LucideIcons.info,
                  color: _opponentTeamId != null ? Colors.green : Colors.amber,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _opponentTeamId != null
                        ? "QORT komanda: $_opponentTeamName"
                        : "Išorinė komanda: $_opponentTeamName",
                    style: TextStyle(
                      color: _opponentTeamId != null
                          ? Colors.green
                          : Colors.amber,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // === SLUOKSNIS 5: REZULTATAS ===
  Widget _buildTeamScoreInput(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedTeamName ?? "MANO KOMANDA",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _myTeamScoreCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "0",
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    filled: true,
                    fillColor: accentColor.withOpacity(0.1),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: accentColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              ":",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _opponentTeamName ?? "VARŽOVAI",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _opponentTeamScoreCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: "0",
                    hintStyle: TextStyle(
                      color: Colors.white24,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    filled: true,
                    fillColor: Colors.white12,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === PASTABOS ===
  Widget _buildNotesField(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("PASTABOS (NEPRIVALOMA)"),
        const SizedBox(height: 8),
        _textField(_notesCtrl, "Pvz. žaidžiau po treniruotės", maxLines: 3),
      ],
    );
  }

  // === HELPERIS: TEXT FIELD ===
  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF18181B),
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
      ),
    );
  }

  // === HELPERIS: LABEL ===
  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.bebasNeue(
        color: Colors.white70,
        letterSpacing: 1.5,
        fontSize: 13,
      ),
    );
  }
}
