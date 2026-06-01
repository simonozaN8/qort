import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_design_system.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/widgets/qort_form_help.dart';
import '../design/design_variants_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/query_limits.dart';
import '../../core/utils/datetime_utils.dart';
import 'package:intl/intl.dart';
import '../tournament/tournament_detail_screen.dart';
import '../tournament/tournament_engine.dart';

class AdminTournamentControlScreen extends StatefulWidget {
  final Map<String, dynamic> tournament;
  const AdminTournamentControlScreen({super.key, required this.tournament});

  @override
  State<AdminTournamentControlScreen> createState() =>
      _AdminTournamentControlScreenState();
}

class _AdminTournamentControlScreenState
    extends State<AdminTournamentControlScreen> {
  bool _isLoading = false;
  List<dynamic> _participants = [];
  List<dynamic> _existingMatches = [];
  List<dynamic> _disputedMatches = [];
  Map<String, bool> _globalInjuries = {};

  List<Map<String, dynamic>> _stages = [];

  List<String> _tournamentDivisions = [];
  List<String> _tabs = ["BENDRA INFO"];
  String _selectedTab = "BENDRA INFO";

  bool _isParticipantsExpanded = false;
  final Map<String, String> _orphanGroupByUserId = {};

  String _venueType = "Aikštelė";
  List<String> _venueTypes = [];
  final List<String> _defaultVenueTypes = [
    "Aikštelė",
    "Kortas",
    "Stalas",
    "Takelis",
    "Lenta",
    "Trasa",
    "Salė",
    "Sektorius",
    "Kitas (įrašyti savo...)",
  ];
  final TextEditingController _customVenueCtrl = TextEditingController();

  final List<String> _schedulingOptions = [
    "Tik Žaidėjai (Patys tariasi)",
    "Mišrus (Org. nuo Atkrintamųjų)",
    "Organizatorius (Veda viską)",
  ];

  final List<String> _allFormats = [
    "Round Robin (Grupės)",
    "Kvalifikacija (Single Elimination)",
    "Single Elimination (Atkrintamosios)",
    "Double Elimination (Dvigubo minuso)",
    "Swiss System (Šveicariška sistema)",
    "Ladder (Piramidė)",
    "Americano",
    "Mexicano",
    "Paguodos turnyras (Consolation)",
  ];

  static const Set<String> _comingSoonFormats = {
    'Double Elimination (Dvigubo minuso)',
    'Americano',
    'Mexicano',
  };

  bool _isComingSoonFormat(String format) => _comingSoonFormats.contains(format);

  bool _isLadderFormat(String format) =>
      format.contains('Ladder') || format.contains('Piramidė');

  String _formatDropdownLabel(String format) {
    if (_isComingSoonFormat(format)) return '$format (Ruošiamas)';
    return format;
  }

  static const Map<String, String> _formatDescriptions = {
    'Round Robin (Grupės)':
        'Visi žaidžia prieš visus grupėse. Taškai už pergales — geriausi keliauja toliau.',
    'Kvalifikacija (Single Elimination)':
        'Atkrintamosios iki pagrindinio etapo. Laimėtojai patenka į kitą fazę, kiti iškrenta.',
    'Single Elimination (Atkrintamosios)':
        'Nugalėtojai lieka, pralaimėtojai iškrenta po vieno mačo.',
    'Double Elimination (Dvigubo minuso)':
        'Žaidėjas iškrenta po antro pralaimėjimo. (Formatas ruošiamas.)',
    'Swiss System (Šveicariška sistema)':
        'Kiekvienas raundas — naujas varžovas pagal rezultatus. Taškų sistema kaip grupėse.',
    'Ladder (Piramidė)':
        'Pozicijos lentelėje — žaidėjai gali iššaukti aukščiau esančius. Challenge rankiniu būdu.',
    'Americano':
        'Partneriai keičiasi kiekvieno raundo metu. (Formatas ruošiamas.)',
    'Mexicano':
        'Dinaminis partnerių paskirstymas pagal rezultatus. (Formatas ruošiamas.)',
    'Paguodos turnyras (Consolation)':
        'Antras kelias pralaimėjusiems — kovos dėl consolation vietų.',
  };

  String _formatDescription(String format) =>
      _formatDescriptions[format] ??
      'Pasirinkite etapo formatą pagal turnyro struktūrą.';

  void _showComingSoonFormatNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Šis formatas dar ruošiamas. Pasirink Round Robin arba Single Elimination.',
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  final List<String> _placesOptions = [
    "Tik nugalėtoją",
    "Dėl 3 vietos",
    "Visas vietas (5, 7, 9...)",
  ];

  @override
  void initState() {
    super.initState();
    _venueTypes = List.from(_defaultVenueTypes);
    _loadData();
  }

  String _generateUuid() {
    final r = Random();
    String h(int l) =>
        List.generate(l, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${h(8)}-${h(4)}-4${h(3)}-a${h(3)}-${h(12)}';
  }

  Map<String, dynamic> _createDefaultStage(int index, String division) {
    return {
      'id': 'stage_${DateTime.now().millisecondsSinceEpoch}_$index',
      'name': '$index ETAPAS',
      'format': 'Round Robin (Grupės)',
      'division': division,
      'group_count': 2,
      'advancing_players': 2,
      'allow_ties': false,
      'points_for_win': 3,
      'points_for_tie': 1,
      'points_for_loss': 0,
      'scheduling_type': 'Tik Žaidėjai (Patys tariasi)',
      'playoff_places': 'Tik nugalėtoją',
      'start_date': null,
      'end_date': null,
      'advance_to': 'none',
      'drop_to': 'none',
      'advance_mode': 'final',
      'drop_mode': 'out',
    };
  }

  List<Map<String, dynamic>> _stagesWithDeferredRouting() {
    return _stages.where((s) {
      final adv = s['advance_to']?.toString() ?? 'none';
      final drp = s['drop_to']?.toString() ?? 'none';
      return adv == 'later' || drp == 'later';
    }).toList();
  }

  Widget _buildDeferredRoutingBanner() {
    final deferred = _stagesWithDeferredRouting();
    if (deferred.isEmpty) return const SizedBox.shrink();

    return Column(
      children: deferred.map((stage) {
        final name = stage['name']?.toString() ?? 'Etapas';
        final adv = stage['advance_to']?.toString() == 'later';
        final drp = stage['drop_to']?.toString() == 'later';
        final parts = <String>[];
        if (adv) parts.add('laimėtojų');
        if (drp) parts.add('pralaimėtojų');
        final routingLabel = parts.join(' ir ');

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.alertTriangle,
                size: 20,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$name turi atidėtą $routingLabel routing\'ą. '
                  'Po etapo pabaigos sukurk sekantį etapą.',
                  style: const TextStyle(
                    color: QortColors.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _stagesForDivision(String division) {
    return _stages.where((s) => s['division'] == division).toList();
  }

  String _stageDisplayName(String stageId, List<Map<String, dynamic>> stages) {
    for (final s in stages) {
      if (s['id'].toString() == stageId) {
        return s['name']?.toString() ?? 'Etapas';
      }
    }
    return 'Etapas';
  }

  String _routingTargetLabel(Map<String, dynamic> stage) {
    final name = stage['name']?.toString() ?? 'Etapas';
    final format = stage['format']?.toString() ?? '';
    if (format.isEmpty) return name;
    return '$name ($format)';
  }

  Map<String, dynamic>? _findStageById(
    String stageId,
    List<Map<String, dynamic>> stages,
  ) {
    for (final s in stages) {
      if (s['id'].toString() == stageId) return s;
    }
    return null;
  }

  Widget _buildStageRoutingFlow({
    required String advanceTo,
    required String dropTo,
    required List<Map<String, dynamic>> divStages,
  }) {
    if (advanceTo == 'none' && dropTo == 'none') {
      return const SizedBox.shrink();
    }

    Widget buildFlowRow({
      required String branch,
      required bool isAdvance,
      required String targetId,
    }) {
      if (targetId == 'later') {
        final accentColor =
            isAdvance ? QortDesignSystem.training : QortDesignSystem.error;
        final emoji = isAdvance ? '🏆' : '💔';
        final label = isAdvance ? 'Laimėtojai' : 'Pralaimėtojai';
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  branch,
                  style: const TextStyle(
                    color: QortDesignSystem.textMuted,
                    fontSize: 13,
                    height: 1.35,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Text(emoji, style: const TextStyle(fontSize: 13, height: 1.35)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$label → Sekantis etapas (vėliau)',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      final target = _findStageById(targetId, divStages);
      final accentColor =
          isAdvance ? QortDesignSystem.training : QortDesignSystem.error;
      final emoji = isAdvance ? '🏆' : '💔';
      final label = isAdvance ? 'Laimėtojai' : 'Pralaimėtojai';
      final targetLabel =
          target != null ? _routingTargetLabel(target) : '(nerastas etapas)';
      final textColor =
          target != null ? accentColor : QortDesignSystem.textMuted;

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                branch,
                style: TextStyle(
                  color: QortDesignSystem.textMuted,
                  fontSize: 13,
                  height: 1.35,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Text(emoji, style: const TextStyle(fontSize: 13, height: 1.35)),
            const SizedBox(width: 6),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, height: 1.35),
                  children: [
                    TextSpan(
                      text: '$label → ',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: targetLabel,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (target == null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  LucideIcons.alertTriangle,
                  size: 14,
                  color: QortDesignSystem.warning,
                ),
              ),
          ],
        ),
      );
    }

    final rows = <Widget>[];
    final hasAdvance = advanceTo != 'none';
    final hasDrop = dropTo != 'none';

    if (hasAdvance) {
      rows.add(
        buildFlowRow(
          branch: hasDrop ? '├──' : '└──',
          isAdvance: true,
          targetId: advanceTo,
        ),
      );
    }
    if (hasDrop) {
      rows.add(
        buildFlowRow(
          branch: '└──',
          isAdvance: false,
          targetId: dropTo,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              width: 2,
              height: 20,
              color: QortDesignSystem.borderDefault,
            ),
          ),
          ...rows,
        ],
      ),
    );
  }

  List<String> _validRoutingIdsForDivision(String division) {
    return [
      'none',
      'later',
      ..._stagesForDivision(division).map((s) => s['id'].toString()),
    ];
  }

  List<DropdownMenuItem<String>> _buildRoutingDropdownItems({
    required String division,
    required String excludeStageId,
    required bool forAdvance,
    List<Map<String, dynamic>> extraStages = const [],
  }) {
    final noneLabel = forAdvance
        ? 'Niekur — finalas (čia baigiasi kelias)'
        : 'Niekur — iškrenta iš turnyro';

    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: 'none', child: Text(noneLabel)),
      DropdownMenuItem(
        value: 'later',
        child: Text(
          forAdvance
              ? 'Sukursiu sekantį etapą vėliau'
              : 'Sukursiu paguodos etapą vėliau',
        ),
      ),
    ];

    final seen = <String>{'none', 'later'};
    for (final s in [
      ..._stagesForDivision(division),
      ...extraStages,
    ]) {
      final sId = s['id'].toString();
      if (sId == excludeStageId || seen.contains(sId)) continue;
      seen.add(sId);
      items.add(
        DropdownMenuItem(
          value: sId,
          child: Text(_routingTargetLabel(s)),
        ),
      );
    }
    return items;
  }

  /// Grąžina (A, B) porą, jei divizione aptiktas routing ciklas.
  (String, String)? _findRoutingCycleInDivision(String division) {
    final divStages = _stagesForDivision(division);
    if (divStages.length < 2) return null;

    final ids = divStages.map((s) => s['id'].toString()).toSet();
    final adjacency = <String, List<String>>{for (final id in ids) id: []};

    for (final s in divStages) {
      final id = s['id'].toString();
      for (final key in ['advance_to', 'drop_to']) {
        final target = s[key]?.toString() ?? 'none';
        if (target != 'none' &&
            target != 'later' &&
            ids.contains(target)) {
          adjacency[id]!.add(target);
        }
      }
    }

    final visiting = <String>{};
    final visited = <String>{};
    String? cycleA;
    String? cycleB;

    bool dfs(String node, List<String> path) {
      if (visiting.contains(node)) {
        final idx = path.indexOf(node);
        if (idx >= 0) {
          cycleA = path[idx];
          cycleB = idx + 1 < path.length ? path[idx + 1] : node;
        } else if (path.isNotEmpty) {
          cycleA = path.last;
          cycleB = node;
        } else {
          cycleA = node;
          cycleB = node;
        }
        return true;
      }
      if (visited.contains(node)) return false;

      visiting.add(node);
      path.add(node);
      for (final next in adjacency[node] ?? []) {
        if (dfs(next, path)) return true;
      }
      path.removeLast();
      visiting.remove(node);
      visited.add(node);
      return false;
    }

    for (final id in ids) {
      if (!visited.contains(id) && dfs(id, [])) {
        return (
          _stageDisplayName(cycleA!, divStages),
          _stageDisplayName(cycleB!, divStages),
        );
      }
    }
    return null;
  }

  /// Prieš save: self-reference ir neegzistuojantys target'ai → reset į none.
  bool _sanitizeStageRouting({bool showMessages = false}) {
    var changed = false;
    final messages = <String>[];

    for (var i = 0; i < _stages.length; i++) {
      final stage = _stages[i];
      final stageId = stage['id'].toString();
      final division = stage['division']?.toString() ?? '';
      final validIds = _validRoutingIdsForDivision(division);

      for (final key in ['advance_to', 'drop_to']) {
        final value = stage[key]?.toString() ?? 'none';
        if (value == stageId) {
          stage[key] = 'none';
          changed = true;
          messages.add('Etapas negali nukreipti į save patį.');
        } else if (value != 'none' &&
            value != 'later' &&
            !validIds.contains(value)) {
          stage[key] = 'none';
          changed = true;
          messages.add(
            'Nuoroda į neegzistuojantį etapą pašalinta (${stage['name']}).',
          );
        }
      }
    }

    if (showMessages && messages.isNotEmpty && mounted) {
      for (final msg in messages.toSet()) {
        _showInfo(msg);
      }
    }
    return changed;
  }

  Map<String, List<String>> _stageWarningsForDivision(String division) {
    final divStages = _stagesForDivision(division);
    final warnings = <String, List<String>>{};

    void addWarning(String stageId, String message) {
      warnings.putIfAbsent(stageId, () => []).add(message);
    }

    final targetIds = <String>{};
    for (final s in divStages) {
      for (final key in ['advance_to', 'drop_to']) {
        final target = s[key]?.toString() ?? 'none';
        if (target != 'none' && target != 'later') targetIds.add(target);
      }
    }

    for (var i = 0; i < divStages.length; i++) {
      final stage = divStages[i];
      final stageId = stage['id'].toString();
      final advanceTo = stage['advance_to']?.toString() ?? 'none';
      final dropTo = stage['drop_to']?.toString() ?? 'none';
      final hasOutgoing =
          advanceTo != 'none' || dropTo != 'none';
      final isTarget = targetIds.contains(stageId);
      final isLast = i == divStages.length - 1;

      if (advanceTo == 'none' &&
          dropTo == 'none' &&
          !isLast &&
          divStages.length > 1) {
        addWarning(
          stageId,
          'Šis etapas neturi tęsinio — žaidėjai sustos čia.',
        );
      }

      if (!isTarget && !hasOutgoing && divStages.length > 1) {
        addWarning(
          stageId,
          'Šis etapas atjungtas nuo pagrindinio srauto.',
        );
      }
    }

    return warnings;
  }

  Future<bool> _validateStagesBeforeSave() async {
    if (_sanitizeStageRouting(showMessages: true)) {
      setState(() {});
    }

    for (final division in _tournamentDivisions) {
      final cycle = _findRoutingCycleInDivision(division);
      if (cycle == null) continue;

      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: QortColors.surface,
          title: const Text(
            'Ciklas tarp etapų',
            style: TextStyle(color: QortColors.textPrimary),
          ),
          content: Text(
            'Aptiktas ciklas tarp etapų: [${cycle.$1}] ↔ [${cycle.$2}]. '
            'Etapas negali nukreipti atgal.',
            style: const TextStyle(color: QortColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Supratau'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _openAddStageWizard(String division) async {
    final divCount = _stagesForDivision(division).length;
    final nextIndex = divCount + 1;
    final initialDraft = _createDefaultStage(nextIndex, division);
    initialDraft['id'] =
        'stage_${DateTime.now().millisecondsSinceEpoch}_$nextIndex';

    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: QortColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        final sheetHeight = MediaQuery.sizeOf(ctx).height * 0.88;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: sheetHeight,
            child: _AddStageWizardSheet(
              division: division,
              initialDraft: initialDraft,
              existingStages: _stagesForDivision(division)
                  .map((s) => Map<String, dynamic>.from(s))
                  .toList(),
              createDefaultStage: _createDefaultStage,
              allFormats: _allFormats,
              comingSoonFormats: _comingSoonFormats,
              placesOptions: _placesOptions,
              formatDropdownLabel: _formatDropdownLabel,
              formatDescription: _formatDescription,
              isLadderFormat: _isLadderFormat,
              isComingSoonFormat: _isComingSoonFormat,
              onComingSoonFormat: _showComingSoonFormatNotice,
              buildRoutingItems: ({
                required String division,
                required String excludeStageId,
                required bool forAdvance,
                required List<Map<String, dynamic>> extraStages,
              }) =>
                  _buildRoutingDropdownItems(
                    division: division,
                    excludeStageId: excludeStageId,
                    forAdvance: forAdvance,
                    extraStages: extraStages,
                  ),
              routingTargetLabelForId: (targetId, extraStages) {
                if (targetId == 'none') return null;
                if (targetId == 'later') {
                  return 'Sukursiu sekantį etapą vėliau';
                }
                final all = [
                  ..._stagesForDivision(division),
                  ...extraStages,
                ];
                final stage = _findStageById(targetId, all);
                return stage != null ? _routingTargetLabel(stage) : null;
              },
            ),
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _stages.addAll(result));
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tId = widget.tournament['id'];
      final client = Supabase.instance.client;

      await TournamentEngine.reconcileBracketAdvances(tId.toString());

      _tournamentDivisions = [];
      if (widget.tournament['divisions'] != null) {
        for (var div in widget.tournament['divisions']) {
          if (div is Map && div['name'] != null) {
            if (!_tournamentDivisions.contains(div['name'])) {
              _tournamentDivisions.add(div['name']);
            }
          } else if (div is String) {
            if (!_tournamentDivisions.contains(div)) {
              _tournamentDivisions.add(div);
            }
          }
        }
      }

      _tabs = ["BENDRA INFO"];
      if (_tournamentDivisions.isNotEmpty) {
        _tabs.addAll(_tournamentDivisions);
      } else {
        _tabs.add("Visi");
        _tournamentDivisions.add("Visi");
      }
      if (!_tabs.contains(_selectedTab)) _selectedTab = _tabs.first;

      final pData = await client
          .from('tournament_participants')
          .select()
          .eq('tournament_id', tId)
          .limit(QueryLimits.tournamentParticipants);

      Map<String, bool> tempGlobalInjuries = {};
      if (pData.isNotEmpty) {
        List<String> userIds = pData
            .map((p) => p['user_id'].toString())
            .toList();
        try {
          final profData = await client
              .from('profiles')
              .select('id, is_injured')
              .inFilter('id', userIds);
          for (var prof in profData) {
            tempGlobalInjuries[prof['id'].toString()] =
                prof['is_injured'] == true;
          }
        } catch (_) {}
      }

      final mData = await client
          .from('matches')
          .select()
          .eq('tournament_id', tId)
          .limit(QueryLimits.tournamentMatches);
      final dMatches = mData.where((m) => m['status'] == 'disputed').toList();

      try {
        final tData = await client
            .from('tournaments')
            .select('stages_config, venue_type')
            .eq('id', tId)
            .maybeSingle();
        if (tData != null) {
          if (tData['venue_type'] != null &&
              tData['venue_type'].toString().isNotEmpty) {
            String vt = tData['venue_type'];
            if (!_venueTypes.contains(vt)) {
              _venueTypes.insert(_venueTypes.length - 1, vt);
            }
            _venueType = vt;
          }

          if (tData['stages_config'] != null) {
            List<dynamic> loadedStages = tData['stages_config'] is List
                ? List.from(tData['stages_config'])
                : [tData['stages_config']];
            if (loadedStages.isNotEmpty) {
              _stages = loadedStages.asMap().entries.map((e) {
                var stageMap = Map<String, dynamic>.from(e.value);
                if (stageMap['id'] == null) {
                  stageMap['id'] =
                      'stage_${DateTime.now().millisecondsSinceEpoch}_${e.key}';
                }
                if (stageMap['advance_to'] == null) {
                  stageMap['advance_to'] = 'none';
                }
                if (stageMap['drop_to'] == null) stageMap['drop_to'] = 'none';
                if (stageMap['division'] == null) {
                  stageMap['division'] = _tournamentDivisions.first;
                }
                return stageMap;
              }).toList();
            } else {
              _stages = [];
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _participants = pData;
          _globalInjuries = tempGlobalInjuries;
          _existingMatches = mData;
          _disputedMatches = dMatches;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError("Klaida: $e");
    }
  }

  Future<void> _generateBots() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> bots = [];
      int count = 1;

      for (String div in _tournamentDivisions) {
        for (int i = 0; i < 12; i++) {
          // Sugeneruojame 12 botų rimtam testui
          bots.add({
            'tournament_id': widget.tournament['id'],
            'user_id': _generateUuid(),
            'team_name': 'Test Botas $count ($div)',
            'division': div,
            'status': 'active',
          });
          count++;
        }
      }

      await Supabase.instance.client
          .from('tournament_participants')
          .insert(bots);
      _showSuccess("Sėkmingai sugeneruota ${bots.length} testinių žaidėjų!");
      _loadData();
    } catch (e) {
      _showError("Nepavyko sukurti botų. Klaida: $e");
      setState(() => _isLoading = false);
    }
  }

  void _goToMatches() {
    var updatedTournament = Map<String, dynamic>.from(widget.tournament);
    updatedTournament['stages_config'] = _stages;
    updatedTournament['venue_type'] = _venueType;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TournamentDetailScreen(
          tournament: updatedTournament,
          initialTabIndex: 3,
        ),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final canSave = await _validateStagesBeforeSave();
      if (!canSave) {
        setState(() => _isLoading = false);
        return;
      }

      String finalVenueType = _venueType;
      if (_venueType == "Kitas (įrašyti savo...)") {
        finalVenueType = _customVenueCtrl.text.trim();
        if (finalVenueType.isEmpty) finalVenueType = "Aikštelė";
      }

      await Supabase.instance.client
          .from('tournaments')
          .update({'stages_config': _stages, 'venue_type': finalVenueType})
          .eq('id', widget.tournament['id']);

      _showSuccess("Nustatymai sėkmingai išsaugoti!");
      _loadData();
    } catch (e) {
      _showError("Klaida išsaugant nustatymus: $e");
    }
  }

  Future<void> _generateGroups() async {
    setState(() => _isLoading = true);
    try {
      await _saveSettings();
      await TournamentEngine.generateTournamentMatches(
        widget.tournament['id'].toString(),
      );
      await TournamentEngine.processInjuries(
        widget.tournament['id'].toString(),
      );
      _showSuccess("Mačai sugeneruoti sėkmingai!");
      _loadData();
    } catch (e) {
      _showError("Klaida generuojant mačus: $e");
    }
  }

  Future<void> _resetMatches() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('matches')
          .delete()
          .eq('tournament_id', widget.tournament['id']);
      await Supabase.instance.client
          .from('tournament_participants')
          .update({
            'manual_rank': null,
            'is_injured': false,
            'ladder_position': null,
            'is_checked_in': false,
            'payment_status': 'pending',
          })
          .eq('tournament_id', widget.tournament['id']);
      _showSuccess("Turnyras pilnai išvalytas!");
    } catch (e) {
      _showError("Klaida valant turnyrą: $e");
    }
    _loadData();
  }

  // NAUJA FUNKCIJA TAŠKŲ DALINIMUI IR UŽDARYMUI
  Future<void> _closeTournamentAndDistributePoints() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(LucideIcons.award, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(
              "BAIGTI TURNYRĄ?",
              style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 24),
            ),
          ],
        ),
        content: const Text(
          "Ar tikrai norite baigti šį turnyrą/divizioną ir išdalinti RP/XP taškus dalyviams? Šio veiksmo atšaukti nebus galima, o turnyras bus užrakintas.",
          style: TextStyle(color: QortColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Atšaukti", style: TextStyle(color: QortColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "TAIP, BAIGTI IR IŠDALINTI",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await TournamentEngine.distributePointsAndCloseTournament(
        widget.tournament['id'].toString(),
      );
      _showSuccess(
        "Turnyras sėkmingai baigtas! Taškai ir reitingai išdalinti.",
      );
      setState(() {
        widget.tournament['status'] = 'completed';
      });
      _loadData();
    } catch (e) {
      _showError("Klaida uždarant turnyrą: $e");
    }
  }

  void _openBulkScheduler(
    List<dynamic> divMatches,
    List<dynamic> divParticipants,
    List<dynamic> divStages,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkScheduleScreen(
          matches: divMatches,
          participants: divParticipants,
          stages: divStages,
          venueType: _venueType == "Kitas (įrašyti savo...)"
              ? (_customVenueCtrl.text.isEmpty
                    ? "Aikštelė"
                    : _customVenueCtrl.text)
              : _venueType,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _showBroadcastDialog() {
    TextEditingController msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Siųsti pranešimą visiems",
          style: TextStyle(color: QortColors.textPrimary),
        ),
        content: TextField(
          controller: msgCtrl,
          maxLines: 3,
          style: const TextStyle(color: QortColors.textPrimary),
          decoration: InputDecoration(
            hintText:
                "Pvz.: Turnyras vėluos 30 min. Prašome rinktis prie 1 korto.",
            hintStyle: const TextStyle(color: QortColors.textSecondary),
            filled: true,
            fillColor: QortColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Atšaukti", style: TextStyle(color: QortColors.textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD946EF),
            ),
            icon: const Icon(LucideIcons.send, color: QortColors.textPrimary, size: 16),
            label: const Text(
              "SIŲSTI",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              if (msgCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await Supabase.instance.client.from('tournament_chat').insert({
                  'tournament_id': widget.tournament['id'],
                  'user_id': Supabase.instance.client.auth.currentUser!.id,
                  'message': "📢 [ORGANIZATORIUS]: ${msgCtrl.text.trim()}",
                });
                _showSuccess("Pranešimas išsiųstas visiems žaidėjams!");
              } catch (e) {
                _showError("Nepavyko išsiųsti: $e");
              }
              setState(() => _isLoading = false);
            },
          ),
        ],
      ),
    );
  }

  void _handleParticipantAction(String action, dynamic participant) async {
    String pId = participant['id'].toString();
    String uId = participant['user_id'].toString();
    bool isCheckedIn = participant['is_checked_in'] == true;
    bool isPaidCash = participant['payment_status'] == 'paid_cash';

    if (action == 'replace') {
      _showReplacementDialog(pId, uId);
      return;
    }

    if (action == 'delete') {
      if (_existingMatches.isNotEmpty) {
        _showError(
          "Negalima ištrinti dalyvio, nes turnyro mačai jau sugeneruoti. Naudokite žaidėjo keitimą arba suteikite W/O (Traumą).",
        );
        return;
      }
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client
            .from('tournament_participants')
            .delete()
            .eq('id', pId);
        _showSuccess("Dalyvis sėkmingai pašalintas iš turnyro.");
        _loadData();
      } catch (e) {
        _showError("Klaida ištrinant: $e");
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (action == 'wo') {
        await Supabase.instance.client
            .from('tournament_participants')
            .update({'is_injured': true})
            .eq('id', pId);
        await TournamentEngine.processInjuries(
          widget.tournament['id'].toString(),
        );
        _showSuccess("Mačai anuliuoti (Suteiktas W/O).");
      } else if (action == 'undo_wo') {
        await TournamentEngine.revertLocalInjury(
          widget.tournament['id'].toString(),
          pId,
          uId,
        );
        _showSuccess("Trauma atšaukta, W/O panaikintas.");
      } else if (action == 'toggle_checkin') {
        await Supabase.instance.client
            .from('tournament_participants')
            .update({'is_checked_in': !isCheckedIn})
            .eq('id', pId);
        _showSuccess(
          isCheckedIn
              ? "Žaidėjo atvykimas atšauktas."
              : "Žaidėjas atžymėtas kaip atvykęs!",
        );
      } else if (action == 'toggle_payment') {
        await Supabase.instance.client
            .from('tournament_participants')
            .update({'payment_status': isPaidCash ? 'pending' : 'paid_cash'})
            .eq('id', pId);
        _showSuccess(
          isPaidCash
              ? "Mokėjimas atšauktas."
              : "Pažymėta, kad sumokėjo grynais!",
        );
      }
      _loadData();
    } catch (e) {
      _showError("Klaida: $e");
      setState(() => _isLoading = false);
    }
  }

  void _showReplacementDialog(
    String injuredParticipantId,
    String injuredUserId,
  ) {
    List<dynamic> possibleReplacements = _participants
        .where((p) => p['id'].toString() != injuredParticipantId)
        .toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: QortColors.background,
        title: const Text(
          "Pasirinkite pavaduojantį žaidėją",
          style: TextStyle(color: QortColors.textPrimary, fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: possibleReplacements.length,
            itemBuilder: (context, index) {
              var replacement = possibleReplacements[index];
              return ListTile(
                title: Text(
                  replacement['team_name'] ?? 'Nežinomas',
                  style: const TextStyle(color: QortColors.textPrimary),
                ),
                trailing: const Icon(
                  LucideIcons.arrowRightLeft,
                  color: Colors.blue,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _executePlayerSwap(
                    injuredUserId,
                    replacement['user_id'].toString(),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _executePlayerSwap(String oldUserId, String newUserId) async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final res1 = await client
          .from('matches')
          .update({'player1_id': newUserId})
          .eq('tournament_id', widget.tournament['id'])
          .inFilter('status', ['pending', 'active'])
          .eq('player1_id', oldUserId)
          .select();
      final res2 = await client
          .from('matches')
          .update({'player2_id': newUserId})
          .eq('tournament_id', widget.tournament['id'])
          .inFilter('status', ['pending', 'active'])
          .eq('player2_id', oldUserId)
          .select();

      if (res1.isEmpty && res2.isEmpty) {
        _showError("DĖMESIO: Šis žaidėjas neturi jokių aktyvių mačų!");
      } else {
        _showSuccess(
          "Žaidėjas sėkmingai pakeistas visuose nesužaistuose mačuose!",
        );
      }
      _loadData();
    } catch (e) {
      _showError("Klaida keičiant žaidėją: $e");
    }
  }

  void _resolveDisputeDialog(Map<String, dynamic> match) {
    TextEditingController s1Ctrl = TextEditingController();
    TextEditingController s2Ctrl = TextEditingController();

    String p1Name = "Žaidėjas 1";
    String p2Name = "Žaidėjas 2";
    for (var p in _participants) {
      if (p['user_id'] == match['player1_id']) {
        p1Name = p['team_name'] ?? p1Name;
      }
      if (p['user_id'] == match['player2_id']) {
        p2Name = p['team_name'] ?? p2Name;
      }
    }

    final disputeReason = match['dispute_reason']?.toString().trim() ?? '';
    final disputeById = match['dispute_by_user_id']?.toString();
    final disputeByName = disputeById != null
        ? _participantDisplayName(disputeById)
        : 'Nežinomas žaidėjas';
    final disputeAtRaw = match['dispute_created_at']?.toString();
    String disputeAtLabel = '';
    if (disputeAtRaw != null && disputeAtRaw.isNotEmpty) {
      final dt = DateTime.tryParse(disputeAtRaw);
      if (dt != null) {
        disputeAtLabel = DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(LucideIcons.shieldAlert, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              "SPRĘSTI GINČĄ",
              style: GoogleFonts.bebasNeue(color: Colors.red, fontSize: 24),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (disputeReason.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.messageSquare,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              disputeByName,
                              style: const TextStyle(
                                color: QortColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (disputeAtLabel.isNotEmpty)
                            Text(
                              disputeAtLabel,
                              style: const TextStyle(
                                color: QortColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        disputeReason,
                        style: const TextStyle(
                          color: QortColors.textPrimary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                "Įveskite galutinį, teisingą rezultatą. Tai uždarys mačą.",
                style: TextStyle(color: QortColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      p1Name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Text(" VS ", style: TextStyle(color: QortColors.textSecondary)),
                  Expanded(
                    child: Text(
                      p2Name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: s1Ctrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: QortColors.textPrimary, fontSize: 20),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black45,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      ":",
                      style: TextStyle(color: QortColors.textSecondary, fontSize: 20),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: s2Ctrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: QortColors.textPrimary, fontSize: 20),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black45,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Atšaukti", style: TextStyle(color: QortColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              int s1 = int.tryParse(s1Ctrl.text) ?? 0;
              int s2 = int.tryParse(s2Ctrl.text) ?? 0;

              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await TournamentEngine.finalizeMatchAndAdvance(
                  matchId: match['id'].toString(),
                  scoreP1: s1,
                  scoreP2: s2,
                  completionNote: 'Admin dispute resolution',
                  scoreStr: '$s1:$s2 (Admin išspręsta)',
                );

                _showSuccess("Ginčas išspręstas!");
                _loadData();
              } catch (e) {
                _showError("Klaida: $e");
                setState(() => _isLoading = false);
              }
            },
            child: const Text(
              "PATVIRTINTI GINČO BAIGTĮ",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayoffPreviewDialog(String stageId, String stageName) async {
    setState(() => _isLoading = true);
    try {
      final result = await TournamentEngine.calculatePlayoffQualifiers(
        widget.tournament['id'].toString(),
        stageId,
      );
      if (!mounted) return;
      List<dynamic> qualified = List.from(result['qualified']);
      List<dynamic> eliminated = List.from(result['eliminated']);
      setState(() => _isLoading = false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "$stageName - REZULTATŲ PERŽIŪRA",
                            style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: QortColors.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        "IŠEINA Į PAGRINDINĮ MEDĮ (KVALIFIKAVOSI)",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: qualified.length,
                        itemBuilder: (context, index) {
                          var q = qualified[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              LucideIcons.checkCircle2,
                              color: Colors.green,
                            ),
                            title: Text(
                              q['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "Grupė ${q['group']} • ${q['points']} tšk.",
                              style: const TextStyle(
                                color: QortColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () {
                                _showSwapDialog(context, q, eliminated, (
                                  replacement,
                                ) {
                                  setModalState(() {
                                    qualified.remove(q);
                                    eliminated.add(q);
                                    eliminated.remove(replacement);
                                    qualified.add(replacement);
                                  });
                                });
                              },
                              child: const Text(
                                "SUKEISTI",
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD946EF),
                        ),
                        icon: const Icon(
                          LucideIcons.gitCommit,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "TVIRTINTI IR PERDUOTI ŽAIDĖJUS TOLIAU",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _saveSettings();
                          setState(() => _isLoading = true);

                          await TournamentEngine.transitionToPlayoffs(
                            widget.tournament['id'].toString(),
                            stageId,
                            qualified,
                            eliminated,
                          );
                          await TournamentEngine.processInjuries(
                            widget.tournament['id'].toString(),
                          );

                          _showSuccess(
                            "Sekantys etapai sėkmingai sugeneruoti!",
                          );
                          _loadData();
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      _showError("Klaida: $e");
    }
  }

  void _showSwapDialog(
    BuildContext context,
    Map<String, dynamic> playerToReplace,
    List<dynamic> eliminated,
    Function(Map<String, dynamic>) onSwap,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: QortColors.background,
        title: Text(
          "Pakeisti žaidėją: ${playerToReplace['name']}",
          style: const TextStyle(color: QortColors.textPrimary, fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: eliminated.length,
            itemBuilder: (context, index) {
              var e = eliminated[index];
              return ListTile(
                title: Text(
                  e['name'],
                  style: const TextStyle(color: QortColors.textPrimary),
                ),
                subtitle: Text(
                  "Grupė ${e['group']} • ${e['points']} tšk.",
                  style: const TextStyle(color: QortColors.textSecondary, fontSize: 12),
                ),
                trailing: const Icon(
                  LucideIcons.arrowRightLeft,
                  color: Colors.blue,
                ),
                onTap: () {
                  onSwap(e);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  void _showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green),
      );
    }
  }

  void _showInfo(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: QortDesignSystem.info,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _selectStageDate(int stageIndex, String field) async {
    DateTime? current = _stages[stageIndex][field] != null
        ? DateTime.parse(_stages[stageIndex][field])
        : null;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _stages[stageIndex][field] = DateTimeUtils.toIsoUtc(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        title: Text(
          "VALDYMO PULTAS",
          style: GoogleFonts.bebasNeue(
            color: p.textPrimary,
            fontSize: 24,
            letterSpacing: 1,
          ),
        ),
        iconTheme: IconThemeData(color: p.textPrimary),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.palette, color: p.textSecondary),
            tooltip: 'Dizaino variantai',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DesignVariantsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD946EF)),
            )
          : Column(
              children: [
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border(bottom: BorderSide(color: p.border)),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    itemBuilder: (ctx, i) {
                      bool isSel = _selectedTab == _tabs[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(
                            _tabs[i].toUpperCase(),
                            style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : p.chipUnselectedText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: p.chipSelected,
                          backgroundColor: p.chipUnselectedBg,
                          side: BorderSide(
                            color: isSel ? p.chipSelected : p.border,
                          ),
                          showCheckmark: false,
                          onSelected: (v) =>
                              setState(() => _selectedTab = _tabs[i]),
                        ),
                      );
                    },
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      24 + MediaQuery.of(context).padding.bottom + 48,
                    ),
                    child: _selectedTab == "BENDRA INFO"
                        ? _buildBendraInfo()
                        : _buildDivisionView(_selectedTab),
                  ),
                ),
              ],
            ),
    );
  }

  String _participantDisplayName(dynamic userId) {
    if (userId == null) return '—';
    final id = userId.toString();
    for (final p in _participants) {
      if (p['user_id']?.toString() == id) {
        return p['team_name']?.toString() ?? 'Be vardo';
      }
    }
    return 'Žaidėjas';
  }

  Widget _buildDisputesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shieldAlert, color: Colors.red, size: 22),
              const SizedBox(width: 8),
              Text(
                'GINČAI (${_disputedMatches.length})',
                style: GoogleFonts.bebasNeue(
                  color: Colors.red,
                  fontSize: 22,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._disputedMatches.map((match) {
            final p1 = _participantDisplayName(match['player1_id']);
            final p2 = _participantDisplayName(match['player2_id']);
            final stage = _stageDisplayName(
              match['stage']?.toString() ?? '',
              _stages,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '• $p1 vs $p2 ($stage)',
                      style: const TextStyle(
                        color: QortColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _resolveDisputeDialog(
                      Map<String, dynamic>.from(match as Map),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      backgroundColor: Colors.red.withValues(alpha: 0.15),
                    ),
                    child: const Text(
                      'SPRĘSTI',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Set<String> _routingTargetStageIds() {
    final ids = <String>{};
    for (final s in _stages) {
      final adv = s['advance_to']?.toString();
      final drop = s['drop_to']?.toString();
      if (adv != null && adv.isNotEmpty && adv != 'none') ids.add(adv);
      if (drop != null && drop.isNotEmpty && drop != 'none') ids.add(drop);
    }
    return ids;
  }

  Map<String, dynamic>? _firstRoundRobinStage() {
    final targets = _routingTargetStageIds();
    for (final s in _stages) {
      final stageId = s['id']?.toString() ?? '';
      if (targets.contains(stageId)) continue;
      if (TournamentEngine.isRoundRobinFormat(s['format']?.toString())) {
        return Map<String, dynamic>.from(s);
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _orphanParticipants() {
    final inMatches = <String>{};
    for (final m in _existingMatches) {
      final p1 = m['player1_id']?.toString();
      final p2 = m['player2_id']?.toString();
      if (p1 != null && p1.isNotEmpty) inMatches.add(p1);
      if (p2 != null && p2.isNotEmpty) inMatches.add(p2);
    }

    final rrStage = _firstRoundRobinStage();
    final division = rrStage?['division']?.toString() ?? 'Visi';

    return _participants
        .where((p) {
          final uid = p['user_id']?.toString();
          if (uid == null || uid.isEmpty || inMatches.contains(uid)) {
            return false;
          }
          if (division != 'Visi') {
            final pDiv = p['division']?.toString();
            if (pDiv != null && pDiv.isNotEmpty && pDiv != division) {
              return false;
            }
          }
          return true;
        })
        .map((p) => Map<String, dynamic>.from(p as Map<String, dynamic>))
        .toList();
  }

  List<String> _distinctGroupNamesForStage(String stageId) {
    final names = <String>{};
    for (final m in _existingMatches) {
      if (m['stage']?.toString() != stageId) continue;
      final g = m['group_name']?.toString().trim();
      if (g != null && g.isNotEmpty) names.add(g);
    }
    final list = names.toList()..sort();
    return list;
  }

  Future<void> _addOrphanToGroup(
    Map<String, dynamic> participant,
    String groupName,
  ) async {
    final stage = _firstRoundRobinStage();
    if (stage == null) return;

    setState(() => _isLoading = true);
    try {
      final count = await TournamentEngine.addParticipantToGroup(
        tournamentId: widget.tournament['id'].toString(),
        stageId: stage['id'].toString(),
        userId: participant['user_id'].toString(),
        groupName: groupName,
      );
      if (mounted) {
        _showSuccess(
          count > 0 ? 'Mačai sugeneruoti ($count)' : 'Naujų mačų nereikėjo',
        );
      }
      await _loadData();
    } catch (e) {
      _showError('Nepavyko pridėti į grupę: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildOrphanParticipantsCard() {
    final rrStage = _firstRoundRobinStage();
    if (rrStage == null || _existingMatches.isEmpty) {
      return const SizedBox.shrink();
    }

    final orphans = _orphanParticipants();
    if (orphans.isEmpty) return const SizedBox.shrink();

    final stageId = rrStage['id'].toString();
    final groups = _distinctGroupNamesForStage(stageId);
    if (groups.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.alertTriangle,
                size: 18,
                color: Colors.amber.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dalyviai be sugeneruotų mačų: ${orphans.length}',
                  style: GoogleFonts.inter(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Etapas: ${rrStage['name'] ?? 'Grupės'} — pridėkite į esamą grupę (round-robin).',
            style: TextStyle(
              color: Colors.amber.shade900.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ...orphans.map((p) {
            final uid = p['user_id'].toString();
            final name = p['team_name']?.toString() ?? 'Dalyvis';
            final selected =
                _orphanGroupByUserId[uid] ?? groups.first;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: QortColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: groups.contains(selected) ? selected : groups.first,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(
                        color: QortColors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF202025),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        ...groups.map(
                          (g) => DropdownMenuItem(value: g, child: Text(g)),
                        ),
                        // TODO: „Sukurti naują grupę“ — atskiras flow.
                      ],
                      onChanged: _isLoading
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => _orphanGroupByUserId[uid] = v);
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isLoading
                        ? null
                        : () => _addOrphanToGroup(
                              p,
                              _orphanGroupByUserId[uid] ?? groups.first,
                            ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'PRIDĖTI',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBendraInfo() {
    final p = context.qortPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade800],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.users, color: QortColors.textPrimary, size: 35),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "BENDRAI UŽSIREGISTRAVĘ DALYVIAI",
                      style: GoogleFonts.oswald(
                        color: QortColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      "${_participants.length} ŽAIDĖJAI",
                      style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 28,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        _buildDeferredRoutingBanner(),

        _buildOrphanParticipantsCard(),

        if (_disputedMatches.isNotEmpty) ...[
          _buildDisputesSection(),
          const SizedBox(height: 20),
        ],

        _btn(
          "🤖 GENERUOTI BOTUS TESTAVIMUI",
          LucideIcons.bot,
          Colors.greenAccent,
          _generateBots,
        ),
        const SizedBox(height: 15),
        _btn(
          "📢 MASINIS PRANEŠIMAS VISIEMS",
          LucideIcons.mic,
          Colors.yellow,
          _showBroadcastDialog,
        ),
        const SizedBox(height: 15),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: QortColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: QortColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "ŽAIDIMO ERDVĖ (Globalu)",
                style: TextStyle(
                  color: Colors.purpleAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const QortFieldHelpLabel(
                label: "Kaip vadinsime aikšteles visame turnyre?",
                help: QortFormHelpTexts.adminVenueType,
              ),
              _buildDropdown(
                "Vietos Tipas",
                _venueType,
                _venueTypes,
                (v) => setState(() => _venueType = v!),
              ),
              if (_venueType == "Kitas (įrašyti savo...)") ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _customVenueCtrl,
                  style: const TextStyle(color: QortColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: "Pvz.: Ringas, Baseinas...",
                    filled: true,
                    fillColor: const Color(0xFF202025),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                  onPressed: _saveSettings,
                  child: const Text(
                    "IŠSAUGOTI ERDVĘ",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 50),
        Center(
          child: TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text(
                    "Ištrinti viską?",
                    style: TextStyle(color: QortColors.textPrimary),
                  ),
                  content: const Text(
                    "Tai ištrins visus mačus ir rezultatus visuose divizionuose. Ar tikrai norite tęsti?",
                    style: TextStyle(color: QortColors.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Atšaukti"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetMatches();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        "Taip, Ištrinti",
                        style: TextStyle(color: QortColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(
              LucideIcons.rotateCcw,
              color: Colors.red,
              size: 16,
            ),
            label: const Text(
              "IŠTRINTI VISKĄ IR PERKURTI",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivisionView(String division) {
    final p = context.qortPalette;
    List<dynamic> divParticipants = _participants
        .where((p) => p['division'] == division || p['division'] == null)
        .toList();
    List<dynamic> divStages = _stages
        .where((s) => s['division'] == division)
        .toList();
    List<String> divStageIds = divStages
        .map((s) => s['id'].toString())
        .toList();
    List<dynamic> divMatches = _existingMatches
        .where((m) => divStageIds.contains(m['stage']))
        .toList();

    bool hasMatches = divMatches.isNotEmpty;
    bool isCompleted = widget.tournament['status'] == 'completed';

    final validRoutingIds = _validRoutingIdsForDivision(division);
    final stageWarnings = _stageWarningsForDivision(division);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(
                  () => _isParticipantsExpanded = !_isParticipantsExpanded,
                ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DALYVIAI (${divParticipants.length})",
                              style: GoogleFonts.bebasNeue(
                                color: p.success,
                                fontSize: 22,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              "Atvykimas, traumos ir mokėjimai",
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isParticipantsExpanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        color: p.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_isParticipantsExpanded)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 10,
                    bottom: 10,
                  ),
                  child: Column(
                    children: divParticipants.asMap().entries.map((entry) {
                      final participant = entry.value;
                      final rowAlt = entry.key.isOdd;
                      bool isGlobalInjured =
                          _globalInjuries[participant['user_id']] == true;
                      bool isLocalInjured = participant['is_injured'] == true;
                      bool isCheckedIn = participant['is_checked_in'] == true;
                      bool isPaidCash =
                          participant['payment_status'] == 'paid_cash';
                      bool isPaidOnline =
                          participant['payment_status'] == 'paid_online';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: rowAlt ? p.listRowAlt : p.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (isGlobalInjured || isLocalInjured)
                                ? Colors.red.withOpacity(0.5)
                                : p.border,
                          ),
                        ),
                        child: ListTile(
                          title: Row(
                            children: [
                              Text(
                                participant['team_name'] ?? 'Dalyvis',
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isCheckedIn)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(
                                    LucideIcons.mapPin,
                                    color: Colors.green,
                                    size: 14,
                                  ),
                                ),
                              if (isPaidCash || isPaidOnline)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    LucideIcons.euro,
                                    color: isPaidOnline
                                        ? Colors.blue
                                        : Colors.orange,
                                    size: 14,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            (isGlobalInjured || isLocalInjured)
                                ? "Traumuotas (W/O aktyvus)"
                                : "Atvyko: ${isCheckedIn ? 'TAIP' : 'NE'} • Apmokėjimas: ${isPaidOnline ? 'BANKU' : (isPaidCash ? 'GRYNAIS' : 'LAUKIA')}",
                            style: TextStyle(
                              color: (isGlobalInjured || isLocalInjured)
                                  ? Colors.red
                                  : p.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: Icon(
                              LucideIcons.moreVertical,
                              color: p.textSecondary,
                            ),
                            color: p.surface,
                            onSelected: (action) => _handleParticipantAction(
                              action,
                              participant,
                            ),
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'toggle_checkin',
                                    child: Text(
                                      isCheckedIn
                                          ? 'Atšaukti Check-in'
                                          : 'Pažymėti, kad ATVYKO',
                                      style: TextStyle(
                                        color: isCheckedIn
                                            ? Colors.grey
                                            : Colors.greenAccent,
                                      ),
                                    ),
                                  ),
                                  if (!isPaidOnline)
                                    PopupMenuItem<String>(
                                      value: 'toggle_payment',
                                      child: Text(
                                        isPaidCash
                                            ? 'Atšaukti Grynuosius'
                                            : 'Sumokėjo GRYNAIS',
                                        style: TextStyle(
                                          color: isPaidCash
                                              ? Colors.grey
                                              : Colors.orangeAccent,
                                        ),
                                      ),
                                    ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem<String>(
                                    value: 'replace',
                                    child: Text(
                                      'Pakeisti kitu žaidėju',
                                      style: TextStyle(color: QortColors.textPrimary),
                                    ),
                                  ),
                                  if (!hasMatches)
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text(
                                        'Ištrinti dalyvį',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  if (!isLocalInjured)
                                    const PopupMenuItem<String>(
                                      value: 'wo',
                                      child: Text(
                                        'Uždėti Traumą (W/O)',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  if (isLocalInjured)
                                    const PopupMenuItem<String>(
                                      value: 'undo_wo',
                                      child: Text(
                                        'Atšaukti Traumą (Undo W/O)',
                                        style: TextStyle(color: Colors.green),
                                      ),
                                    ),
                                ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "DIVIZIONO ETAPAI",
              style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 22,
                letterSpacing: 1,
              ),
            ),
            Text(
              "${divStages.length} Etapai",
              style: const TextStyle(color: QortColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 15),

        ...divStages.asMap().entries.map((entry) {
          int idx = entry.key;
          Map<String, dynamic> stage = entry.value;
          String format = stage['format'] ?? "Round Robin (Grupės)";
          String stageName = stage['name']?.toString() ?? "${idx + 1} ETAPAS";
          final rawAdvanceTo = stage['advance_to']?.toString() ?? 'none';
          final rawDropTo = stage['drop_to']?.toString() ?? 'none';
          final divStagesTyped = divStages
              .map((s) => Map<String, dynamic>.from(s as Map))
              .toList();

          if (!validRoutingIds.contains(stage['advance_to'])) {
            stage['advance_to'] = 'none';
          }
          if (!validRoutingIds.contains(stage['drop_to'])) {
            stage['drop_to'] = 'none';
          }

          int realIdx = _stages.indexOf(stage);
          final stageId = stage['id'].toString();
          final cardWarnings = stageWarnings[stageId] ?? const [];

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: p.primary.withOpacity(0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: stageName)
                            ..selection = TextSelection.collapsed(
                              offset: stageName.length,
                            ),
                          onChanged: (val) => _stages[realIdx]['name'] = val,
                          style: const TextStyle(
                            color: QortColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (cardWarnings.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Tooltip(
                            message: cardWarnings.join('\n'),
                            child: const Icon(
                              LucideIcons.alertTriangle,
                              color: QortDesignSystem.warning,
                              size: 18,
                            ),
                          ),
                        ),
                      if (!isCompleted)
                        IconButton(
                          icon: const Icon(
                            LucideIcons.trash2,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _stages.removeAt(realIdx)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStageField(
                        label: "Etapo Formatas",
                        help: QortFormHelpTexts.stageFormat,
                        child: _buildStageFormatDropdown(format, realIdx),
                      ),
                      if (_isLadderFormat(format)) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Ladder formatas: pozicijos paskirstomos automatiškai. '
                          'Challenge mačai organizuojami rankiniu būdu (funkcionalumas plečiamas).',
                          style: TextStyle(
                            color: Colors.amber.withValues(alpha: 0.95),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildStageField(
                        label: "Tvarkaraščio Valdymas šiam etapui",
                        help: QortFormHelpTexts.stageScheduling,
                        child: _buildDropdown(
                          "Valdymas",
                          stage['scheduling_type'] ??
                              "Tik Žaidėjai (Patys tariasi)",
                          _schedulingOptions,
                          (v) => setState(
                            () => _stages[realIdx]['scheduling_type'] = v!,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const QortFieldHelpLabel(
                        label: "Etapo Terminai (Tęstiniams turnyrams)",
                        help:
                            '${QortFormHelpTexts.stageStartDate}\n\n${QortFormHelpTexts.stageEndDate}',
                        labelStyle: TextStyle(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: QortColors.textPrimary,
                                backgroundColor: QortColors.background,
                                side: const BorderSide(color: QortColors.border),
                              ),
                              icon: const Icon(
                                LucideIcons.calendar,
                                size: 14,
                                color: QortColors.primary,
                              ),
                              label: Text(
                                stage['start_date'] != null
                                    ? DateFormat('yyyy-MM-dd').format(
                                        DateTime.parse(stage['start_date']),
                                      )
                                    : "Pradžia",
                                style: const TextStyle(
                                  color: QortColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () =>
                                  _selectStageDate(realIdx, 'start_date'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: QortColors.textPrimary,
                                backgroundColor: QortColors.background,
                                side: const BorderSide(color: QortColors.border),
                              ),
                              icon: const Icon(
                                LucideIcons.calendarX,
                                size: 14,
                                color: QortColors.primary,
                              ),
                              label: Text(
                                stage['end_date'] != null
                                    ? DateFormat('yyyy-MM-dd').format(
                                        DateTime.parse(stage['end_date']),
                                      )
                                    : "Pabaiga",
                                style: const TextStyle(
                                  color: QortColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () =>
                                  _selectStageDate(realIdx, 'end_date'),
                            ),
                          ),
                        ],
                      ),

                      if (format.contains("Grupės") ||
                          format.contains("Swiss")) ...[
                        const SizedBox(height: 20),
                        const Divider(color: QortColors.border),
                        const SizedBox(height: 15),
                        _buildStageField(
                          label: "Į kiek grupių dalinsime?",
                          help: QortFormHelpTexts.stageGroupCount,
                          trailing: Text(
                            "Gausis ~${divParticipants.isNotEmpty ? (divParticipants.length / (stage['group_count'] ?? 2)).toStringAsFixed(1) : 0} žaid./gr.",
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                          child: _buildDropdown(
                            "Grupių skaičius",
                            (_stages[realIdx]['group_count'] ?? 2).toString(),
                            ["1", "2", "3", "4", "6", "8"],
                            (v) => setState(
                              () => _stages[realIdx]['group_count'] =
                                  int.parse(v!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStageField(
                          label: "Kiek žaidėjų išeina į kitą etapą iš grupės?",
                          help: QortFormHelpTexts.stageAdvancing,
                          child: _buildDropdown(
                            "Išeinančių skaičius",
                            (_stages[realIdx]['advancing_players'] ?? 2)
                                .toString(),
                            ["1", "2", "3", "4", "8"],
                            (v) => setState(
                              () => _stages[realIdx]['advancing_players'] =
                                  int.parse(v!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Taškų sistema",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStageField(
                          label: "Ar galimos lygiosios?",
                          help: QortFormHelpTexts.stageAllowTies,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Switch(
                                value: stage['allow_ties'] ?? false,
                                activeThumbColor: Colors.orange,
                                inactiveThumbColor: QortColors.textSecondary,
                                onChanged: (val) => setState(
                                  () => _stages[realIdx]['allow_ties'] = val,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStageField(
                                label: "Pergalė",
                                help: QortFormHelpTexts.stagePointsWin,
                                child: _buildDropdown(
                                  "Pergalė",
                                  (stage['points_for_win'] ?? 3).toString(),
                                  ["1", "2", "3", "4", "5"],
                                  (v) => setState(
                                    () => _stages[realIdx]['points_for_win'] =
                                        int.parse(v!),
                                  ),
                                ),
                              ),
                            ),
                            if (stage['allow_ties'] == true) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStageField(
                                  label: "Lygiosios",
                                  help: QortFormHelpTexts.stagePointsTie,
                                  child: _buildDropdown(
                                    "Lygiosios",
                                    (stage['points_for_tie'] ?? 1).toString(),
                                    ["0", "1", "2"],
                                    (v) => setState(
                                      () => _stages[realIdx]['points_for_tie'] =
                                          int.parse(v!),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStageField(
                                label: "Pralaimėjimas",
                                help: QortFormHelpTexts.stagePointsLoss,
                                child: _buildDropdown(
                                  "Pralaimėjimas",
                                  (stage['points_for_loss'] ?? 0).toString(),
                                  ["0", "1", "2"],
                                  (v) => setState(
                                    () => _stages[realIdx]['points_for_loss'] =
                                        int.parse(v!),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (format.contains("Elimination") ||
                          format.contains("Atkrintamosios") ||
                          format.contains("Kvalifikacija") ||
                          format.contains("Paguodos")) ...[
                        const SizedBox(height: 20),
                        const Divider(color: QortColors.border),
                        const SizedBox(height: 15),
                        _buildStageField(
                          label: "Kiek vietų išžaisti?",
                          help: QortFormHelpTexts.stagePlayoffPlaces,
                          child: _buildDropdown(
                            "Vietos",
                            stage['playoff_places'] ?? "Tik nugalėtoją",
                            _placesOptions,
                            (v) => setState(
                              () => _stages[realIdx]['playoff_places'] = v!,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Divider(color: QortColors.border),
                      const SizedBox(height: 15),
                      const Row(
                        children: [
                          Icon(
                            LucideIcons.gitMerge,
                            color: Colors.green,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "KRYŽKELĖS (Kur keliauja žaidėjai po etapo?)",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      _buildStageField(
                        label: '🏆 KUR KELIAUJA LAIMĖTOJAI?',
                        help: QortFormHelpTexts.stageAdvanceTo,
                        labelStyle: GoogleFonts.bebasNeue(
                          color: QortDesignSystem.training,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                        child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: QortDesignSystem.training.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: QortDesignSystem.training.withValues(alpha: 0.45),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: validRoutingIds.contains(stage['advance_to'])
                                ? stage['advance_to']
                                : 'none',
                            isExpanded: true,
                            dropdownColor: QortColors.surface,
                            style: const TextStyle(
                              color: QortColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            items: _buildRoutingDropdownItems(
                              division: division,
                              excludeStageId: stageId,
                              forAdvance: true,
                            ),
                            onChanged: (v) => setState(
                              () => _stages[realIdx]['advance_to'] = v!,
                            ),
                          ),
                        ),
                      ),
                      ),

                      const SizedBox(height: 12),
                      _buildStageField(
                        label: '💔 KUR KELIAUJA PRALAIMĖTOJAI?',
                        help: QortFormHelpTexts.stageDropTo,
                        labelStyle: GoogleFonts.bebasNeue(
                          color: QortDesignSystem.error,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                        child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: QortDesignSystem.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: QortDesignSystem.error.withValues(alpha: 0.45),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: validRoutingIds.contains(stage['drop_to'])
                                ? stage['drop_to']
                                : 'none',
                            isExpanded: true,
                            dropdownColor: QortColors.surface,
                            style: const TextStyle(
                              color: QortColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            items: _buildRoutingDropdownItems(
                              division: division,
                              excludeStageId: stageId,
                              forAdvance: false,
                            ),
                            onChanged: (v) => setState(
                              () => _stages[realIdx]['drop_to'] = v!,
                            ),
                          ),
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
              _buildStageRoutingFlow(
                advanceTo: rawAdvanceTo,
                dropTo: rawDropTo,
                divStages: divStagesTyped,
              ),
              const SizedBox(height: 20),
            ],
          );
        }),

        if (!isCompleted)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(LucideIcons.plus, color: Colors.blue),
              label: const Text(
                "PRIDĖTI NAUJĄ ETAPĄ ŠIAM DIVIZIONUI",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => _openAddStageWizard(division),
            ),
          ),

        if (!isCompleted)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(LucideIcons.save, color: QortColors.textPrimary),
                label: const Text(
                  "IŠSAUGOTI ETAPUS",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _saveSettings,
              ),
            ),
          ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(LucideIcons.info, size: 16, color: QortColors.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Slinkite žemyn — apačioje taškų sistema, kryžkelės ir veiksmai.',
                  style: TextStyle(
                    color: QortColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "DIVIZIONO VEIKSMAI",
          style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),

        if (!isCompleted)
          _btn(
            "1. GENERUOTI MAČUS (Visam turnyrui)",
            LucideIcons.playCircle,
            const Color(0xFFD946EF),
            _generateGroups,
            on: !hasMatches,
          ),

        if (hasMatches) ...[
          if (!isCompleted) ...[
            const SizedBox(height: 15),
            _btn(
              "TVARKARAŠČIO PLANUOKLIS",
              LucideIcons.calendarClock,
              Colors.blueAccent,
              () => _openBulkScheduler(divMatches, divParticipants, divStages),
            ),
          ],

          const SizedBox(height: 15),

          if (!isCompleted)
            ...divStages.map((stage) {
              bool hasActiveMatches = divMatches.any(
                (m) => m['stage'] == stage['id'],
              );
              bool hasRouting =
                  stage['advance_to'] != 'none' || stage['drop_to'] != 'none';

              if (hasActiveMatches && hasRouting) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: _btn(
                    "BAIGTI: ${stage['name']} -> PERDUOTI TOLIAU",
                    LucideIcons.gitMerge,
                    Colors.orange,
                    () => _showPlayoffPreviewDialog(
                      stage['id'].toString(),
                      stage['name']?.toString() ?? 'Etapas',
                    ),
                    on: true,
                  ),
                );
              }
              return const SizedBox();
            }),

          _btn(
            "PERŽIŪRĖTI REZULTATUS",
            LucideIcons.trophy,
            Colors.green,
            _goToMatches,
          ),

          // --- NAUJAS UŽDARYMO MYGTUKAS ---
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: _btn(
                "🏆 BAIGTI TURNYRĄ IR IŠDALINTI TAŠKUS",
                LucideIcons.award,
                Colors.redAccent,
                _closeTournamentAndDistributePoints,
              ),
            ),

          if (isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    const Icon(
                      LucideIcons.checkCircle,
                      color: Colors.green,
                      size: 30,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "TURNYRAS BAIGTAS IR UŽRAKINTAS",
                      style: GoogleFonts.bebasNeue(
                        color: Colors.green,
                        fontSize: 24,
                        letterSpacing: 1,
                      ),
                    ),
                    const Text(
                      "RP ir XP taškai sėkmingai išdalinti žaidėjams.",
                      style: TextStyle(color: QortColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          // --------------------------------
        ],
      ],
    );
  }

  Widget _buildStageField({
    required String label,
    required String help,
    required Widget child,
    Widget? trailing,
    TextStyle? labelStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: QortFieldHelpLabel(
                label: label,
                help: help,
                labelStyle: labelStyle ??
                    const TextStyle(
                      color: QortColors.textSecondary,
                      fontSize: 12,
                    ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        child,
      ],
    );
  }

  Widget _buildStageFormatDropdown(String value, int realIdx) {
    final items = List<String>.from(_allFormats);
    if (!items.contains(value)) items.add(value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: QortColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: QortColors.background,
          style: const TextStyle(color: QortColors.textPrimary, fontSize: 14),
          items: items.map((format) {
            final comingSoon = _isComingSoonFormat(format);
            return DropdownMenuItem<String>(
              value: format,
              enabled: !comingSoon,
              child: Text(
                _formatDropdownLabel(format),
                style: TextStyle(
                  color: comingSoon ? QortColors.textSecondary : QortColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (selected) {
            if (selected == null) return;
            if (_isComingSoonFormat(selected)) {
              _showComingSoonFormatNotice();
              return;
            }
            setState(() => _stages[realIdx]['format'] = selected);
          },
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    if (!items.contains(value)) items.add(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: QortColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: QortColors.background,
          style: const TextStyle(color: QortColors.textPrimary, fontSize: 14),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _btn(String t, IconData i, Color c, VoidCallback f, {bool on = true}) {
    return Opacity(
      opacity: on ? 1 : 0.5,
      child: Material(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: on ? f : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(
                color: on ? c.withOpacity(0.5) : QortColors.border,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(i, color: c),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    t,
                    style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Icon(LucideIcons.chevronRight, color: Colors.white30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BulkScheduleScreen extends StatefulWidget {
  final List<dynamic> matches;
  final List<dynamic> participants;
  final List<dynamic> stages;
  final String venueType;

  const BulkScheduleScreen({
    super.key,
    required this.matches,
    required this.participants,
    required this.stages,
    required this.venueType,
  });

  @override
  State<BulkScheduleScreen> createState() => _BulkScheduleScreenState();
}

class _BulkScheduleScreenState extends State<BulkScheduleScreen> {
  bool _isLoading = false;
  late List<dynamic> _localMatches;

  @override
  void initState() {
    super.initState();
    _localMatches = List.from(widget.matches);
  }

  String _getPlayerName(String? id) {
    if (id == null) return "TBD (Laukiama)";
    for (var p in widget.participants) {
      if (p['user_id'] == id) return p['team_name'] ?? "Žaidėjas";
    }
    return "Nežinomas";
  }

  Future<void> _shiftAllTimes(int minutes) async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      for (int i = 0; i < _localMatches.length; i++) {
        var m = _localMatches[i];
        if (m['scheduled_time'] != null &&
            m['status'] != 'completed' &&
            m['status'] != 'cancelled') {
          DateTime dt = DateTimeUtils.fromIso(
            m['scheduled_time'].toString(),
          ).add(Duration(minutes: minutes));
          String newIso = DateTimeUtils.toIsoUtc(dt);
          await client
              .from('matches')
              .update({'scheduled_time': newIso})
              .eq('id', m['id']);
          _localMatches[i]['scheduled_time'] = newIso;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Laikai sėkmingai pastumti!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Klaida: $e"), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _showEditDialog(Map<String, dynamic> match, int index) {
    DateTime? selectedDate = match['scheduled_time'] != null
        ? DateTimeUtils.fromIso(match['scheduled_time'].toString())
        : null;
    TimeOfDay? selectedTime = selectedDate != null
        ? TimeOfDay.fromDateTime(selectedDate)
        : null;
    TextEditingController locationCtrl = TextEditingController(
      text: match['location_name']?.toString() ?? '',
    );
    TextEditingController venueCtrl = TextEditingController(
      text: match['venue_name']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return QortFormDialog.shell(
            title: Text(
              "Redaguoti Mačą #${match['match_num'] ?? '?'}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const QortHelpBanner(
                    title: 'Tvarkaraščio planavimas',
                    bullets: QortFormHelpTexts.bulkSchedule,
                    accentColor: Colors.blue,
                  ),
                  Text(
                    "${_getPlayerName(match['player1_id'])} VS ${_getPlayerName(match['player2_id'])}",
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Data",
                      style: TextStyle(color: QortColors.textSecondary),
                    ),
                    subtitle: Text(
                      selectedDate != null
                          ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                          : "Nepasirinkta",
                      style: const TextStyle(color: QortColors.textPrimary),
                    ),
                    trailing: const Icon(
                      LucideIcons.calendar,
                      color: Colors.blue,
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setModalState(() => selectedDate = d);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Laikas",
                      style: TextStyle(color: QortColors.textSecondary),
                    ),
                    subtitle: Text(
                      selectedTime != null
                          ? selectedTime!.format(context)
                          : "Nepasirinkta",
                      style: const TextStyle(color: QortColors.textPrimary),
                    ),
                    trailing: const Icon(LucideIcons.clock, color: Colors.blue),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (t != null) setModalState(() => selectedTime = t);
                    },
                  ),
                  TextField(
                    controller: locationCtrl,
                    style: const TextStyle(color: QortColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: "Arena / Aikštynas",
                      labelStyle: TextStyle(color: QortColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: QortColors.border),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.purpleAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: venueCtrl,
                    style: const TextStyle(color: QortColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: widget.venueType,
                      labelStyle: const TextStyle(color: QortColors.textSecondary),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: QortColors.border),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              QortFormDialog.cancelButton(ctx),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text(
                  "IŠSAUGOTI",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  String? isoTime;
                  if (selectedDate != null && selectedTime != null) {
                    isoTime = DateTimeUtils.toIsoUtc(
                      DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      ),
                    );
                  }
                  setState(() => _isLoading = true);
                  Navigator.pop(ctx);
                  try {
                    await Supabase.instance.client
                        .from('matches')
                        .update({
                          'scheduled_time': isoTime,
                          'location_name': locationCtrl.text.trim(),
                          'venue_name': venueCtrl.text.trim(),
                        })
                        .eq('id', match['id']);
                    setState(() {
                      _localMatches[index]['scheduled_time'] = isoTime;
                      _localMatches[index]['location_name'] = locationCtrl.text
                          .trim();
                      _localMatches[index]['venue_name'] = venueCtrl.text
                          .trim();
                      _isLoading = false;
                    });
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Klaida: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<dynamic>> grouped = {};
    for (var m in _localMatches) {
      String stageId = m['stage']?.toString() ?? '';
      String stageLabel = "Kiti Mačai";
      var matchingStages = widget.stages
          .where((s) => s['id'] == stageId)
          .toList();
      if (matchingStages.isNotEmpty) {
        stageLabel = (matchingStages.first['name'] ?? "Etapas")
            .toString()
            .toUpperCase();
      }
      grouped.putIfAbsent(stageLabel, () => []).add(m);
    }

    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: QortColors.surface,
        title: Text(
          "TVARKARAŠČIO PLANUOKLIS",
          style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        iconTheme: const IconThemeData(color: QortColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.clock4, color: Colors.orange),
            onPressed: () => _shiftAllTimes(30),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : ListView(
              padding: const EdgeInsets.all(15),
              children: [
                const QortHelpBanner(
                  title: 'Tvarkaraščio planuoklis',
                  bullets: QortFormHelpTexts.bulkSchedule,
                  accentColor: Colors.blue,
                ),
                ...grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 15, bottom: 10),
                      child: Text(
                        entry.key,
                        style: GoogleFonts.bebasNeue(
                          color: Colors.blueAccent,
                          fontSize: 24,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    ...entry.value.map((m) {
                      int idx = _localMatches.indexOf(m);
                      String st = m['scheduled_time'] != null
                          ? DateFormat('MM-dd HH:mm').format(
                              DateTimeUtils.fromIso(m['scheduled_time'].toString()),
                            )
                          : "Nepaskirta";
                      return Card(
                        color: QortColors.surface,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            "${_getPlayerName(m['player1_id'])} VS ${_getPlayerName(m['player2_id'])}",
                            style: const TextStyle(
                              color: QortColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            st,
                            style: TextStyle(
                              color: st == "Nepaskirta"
                                  ? QortColors.textSecondary
                                  : Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            LucideIcons.edit,
                            color: QortColors.textSecondary,
                          ),
                          onTap: () => _showEditDialog(m, idx),
                        ),
                      );
                    }),
                  ],
                );
              }),
              ],
            ),
    );
  }
}

typedef _WizardRoutingItemsBuilder = List<DropdownMenuItem<String>> Function({
  required String division,
  required String excludeStageId,
  required bool forAdvance,
  required List<Map<String, dynamic>> extraStages,
});

typedef _CreateDefaultStageFn = Map<String, dynamic> Function(
  int index,
  String division,
);

typedef _WizardRoutingLabelFn = String? Function(
  String targetId,
  List<Map<String, dynamic>> extraStages,
);

// ── Turnyro etapų medžio diagrama ──

class _TreeStageNode {
  static const boxWidth = 128.0;
  static const boxHeight = 56.0;

  final String id;
  final String label;
  final String format;
  final String participantsHint;
  final bool isDraft;
  final bool isDeferred;
  Offset position;

  _TreeStageNode({
    required this.id,
    required this.label,
    required this.format,
    required this.participantsHint,
    this.isDraft = false,
    this.isDeferred = false,
    this.position = Offset.zero,
  });
}

class _TreeEdge {
  final Offset from;
  final Offset to;
  final bool isAdvance;

  const _TreeEdge({
    required this.from,
    required this.to,
    required this.isAdvance,
  });
}

class _TreeLayoutResult {
  final List<_TreeStageNode> nodes;
  final List<_TreeEdge> edges;
  final double width;
  final double height;

  const _TreeLayoutResult({
    required this.nodes,
    required this.edges,
    required this.width,
    required this.height,
  });
}

class _TreeLayoutEngine {
  static const _hGap = 28.0;
  static const _vGap = 52.0;
  static const _pad = 16.0;

  static String _participantsHint(Map<String, dynamic> stage) {
    final initial = stage['initial_participants'];
    if (initial != null) return '$initial dalyv.';
    final groups = (stage['group_count'] as num?)?.toInt();
    final adv = (stage['advancing_players'] as num?)?.toInt();
    if (groups != null && adv != null) {
      return '$groups grp. × top $adv';
    }
    return '—';
  }

  static _TreeLayoutResult compute({
    required List<Map<String, dynamic>> stages,
    String? draftStageId,
  }) {
    if (stages.isEmpty) {
      return const _TreeLayoutResult(
        nodes: [],
        edges: [],
        width: 200,
        height: 80,
      );
    }

    final stageById = <String, Map<String, dynamic>>{};
    for (final s in stages) {
      stageById[s['id'].toString()] = s;
    }

    final childRefs = <String>{};
    final childrenOf = <String, List<({String id, bool advance})>>{};

    void linkChild(String parentId, String rawTarget, bool advance) {
      if (rawTarget == 'none') return;
      final childId = rawTarget == 'later'
          ? '_later_${advance ? 'adv' : 'drop'}_$parentId'
          : rawTarget;
      childrenOf.putIfAbsent(parentId, () => []);
      if (childrenOf[parentId]!.any((c) => c.id == childId)) return;
      childrenOf[parentId]!.add((id: childId, advance: advance));
      if (!childId.startsWith('_later_')) {
        childRefs.add(childId);
      }
    }

    for (final s in stages) {
      final id = s['id'].toString();
      linkChild(id, s['advance_to']?.toString() ?? 'none', true);
      linkChild(id, s['drop_to']?.toString() ?? 'none', false);
    }

    var roots = stageById.keys.where((id) => !childRefs.contains(id)).toList();
    if (roots.isEmpty) roots = [stageById.keys.first];

    final nodes = <_TreeStageNode>[];
    final edges = <_TreeEdge>[];
    var cursorX = _pad;

    for (final rootId in roots) {
      cursorX += _layoutSubtree(
        rootId: rootId,
        stageById: stageById,
        childrenOf: childrenOf,
        draftStageId: draftStageId,
        depth: 0,
        leftX: cursorX,
        nodes: nodes,
        edges: edges,
      );
      cursorX += _hGap;
    }

    var maxX = _pad * 2;
    var maxY = _pad * 2;
    for (final n in nodes) {
      maxX = max(maxX, n.position.dx + _TreeStageNode.boxWidth + _pad);
      maxY = max(maxY, n.position.dy + _TreeStageNode.boxHeight + _pad);
    }

    return _TreeLayoutResult(
      nodes: nodes,
      edges: edges,
      width: maxX,
      height: maxY,
    );
  }

  static double _layoutSubtree({
    required String rootId,
    required Map<String, Map<String, dynamic>> stageById,
    required Map<String, List<({String id, bool advance})>> childrenOf,
    required String? draftStageId,
    required int depth,
    required double leftX,
    required List<_TreeStageNode> nodes,
    required List<_TreeEdge> edges,
  }) {
    final children = childrenOf[rootId] ?? [];

    if (children.isEmpty) {
      _addNode(
        rootId: rootId,
        stageById: stageById,
        draftStageId: draftStageId,
        depth: depth,
        x: leftX,
        nodes: nodes,
      );
      return _TreeStageNode.boxWidth;
    }

    var childLeft = leftX;
    final childCenters = <double>[];
    for (final child in children) {
      final w = _layoutSubtree(
        rootId: child.id,
        stageById: stageById,
        childrenOf: childrenOf,
        draftStageId: draftStageId,
        depth: depth + 1,
        leftX: childLeft,
        nodes: nodes,
        edges: edges,
      );
      childCenters.add(childLeft + w / 2);
      childLeft += w + _hGap;
    }

    final subtreeWidth = childLeft - leftX - _hGap;
    final parentCenterX = (childCenters.first + childCenters.last) / 2;
    final parentX = parentCenterX - _TreeStageNode.boxWidth / 2;

    final parentNode = _addNode(
      rootId: rootId,
      stageById: stageById,
      draftStageId: draftStageId,
      depth: depth,
      x: parentX,
      nodes: nodes,
    );

    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final childNode = nodes.firstWhere((n) => n.id == child.id);
      final from = Offset(
        parentNode.position.dx + _TreeStageNode.boxWidth / 2,
        parentNode.position.dy + _TreeStageNode.boxHeight,
      );
      final to = Offset(
        childNode.position.dx + _TreeStageNode.boxWidth / 2,
        childNode.position.dy,
      );
      edges.add(_TreeEdge(from: from, to: to, isAdvance: child.advance));
    }

    return subtreeWidth;
  }

  static _TreeStageNode _addNode({
    required String rootId,
    required Map<String, Map<String, dynamic>> stageById,
    required String? draftStageId,
    required int depth,
    required double x,
    required List<_TreeStageNode> nodes,
  }) {
    if (nodes.any((n) => n.id == rootId)) {
      return nodes.firstWhere((n) => n.id == rootId);
    }

    final isDeferred = rootId.startsWith('_later_');
    Map<String, dynamic>? stage = stageById[rootId];
    late _TreeStageNode node;

    if (isDeferred) {
      node = _TreeStageNode(
        id: rootId,
        label: 'Sekantis etapas',
        format: 'Sukursiu vėliau',
        participantsHint: '—',
        isDeferred: true,
        position: Offset(x, _pad + depth * (_TreeStageNode.boxHeight + _vGap)),
      );
    } else {
      stage ??= {'id': rootId, 'name': 'Etapas', 'format': ''};
      node = _TreeStageNode(
        id: rootId,
        label: stage['name']?.toString() ?? 'Etapas',
        format: stage['format']?.toString() ?? '',
        participantsHint: _participantsHint(stage),
        isDraft: rootId == draftStageId,
        position: Offset(x, _pad + depth * (_TreeStageNode.boxHeight + _vGap)),
      );
    }

    nodes.add(node);
    return node;
  }
}

class _TournamentTreePainter extends CustomPainter {
  final List<_TreeEdge> edges;

  _TournamentTreePainter({required this.edges});

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final paint = Paint()
        ..color = edge.isAdvance
            ? QortDesignSystem.training
            : QortDesignSystem.error
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final midY = (edge.from.dy + edge.to.dy) / 2;
      final path = Path()
        ..moveTo(edge.from.dx, edge.from.dy)
        ..lineTo(edge.from.dx, midY)
        ..lineTo(edge.to.dx, midY)
        ..lineTo(edge.to.dx, edge.to.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TournamentTreePainter oldDelegate) =>
      oldDelegate.edges != edges;
}

class _TournamentTreeDiagram extends StatelessWidget {
  final List<Map<String, dynamic>> savedStages;
  final Map<String, dynamic> draftStage;
  final List<Map<String, dynamic>> pendingChildStages;

  const _TournamentTreeDiagram({
    required this.savedStages,
    required this.draftStage,
    required this.pendingChildStages,
  });

  List<Map<String, dynamic>> get _allStages {
    final seen = <String>{};
    final list = <Map<String, dynamic>>[];
    for (final s in [
      ...savedStages,
      ...pendingChildStages,
      draftStage,
    ]) {
      final id = s['id'].toString();
      if (seen.add(id)) list.add(s);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final layout = _TreeLayoutEngine.compute(
      stages: _allStages,
      draftStageId: draftStage['id'].toString(),
    );

    if (layout.nodes.isEmpty) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        child: const Text(
          'Pridėk etapą — medis pasirodys čia.',
          style: TextStyle(color: QortDesignSystem.textMuted, fontSize: 12),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: QortColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QortColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: layout.width,
            height: layout.height,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(layout.width, layout.height),
                  painter: _TournamentTreePainter(edges: layout.edges),
                ),
                ...layout.nodes.map((node) {
                  final borderColor = node.isDraft
                      ? QortDesignSystem.training
                      : node.isDeferred
                          ? const Color(0xFFF59E0B)
                          : QortColors.border;
                  return Positioned(
                    left: node.position.dx,
                    top: node.position.dy,
                    child: Tooltip(
                      message: '${node.label}\n${node.format}\n'
                          '${node.participantsHint}',
                      child: Container(
                        width: _TreeStageNode.boxWidth,
                        height: _TreeStageNode.boxHeight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: node.isDraft
                              ? QortDesignSystem.training
                                  .withValues(alpha: 0.12)
                              : QortColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: borderColor,
                            width: node.isDraft ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              node.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: QortColors.textPrimary,
                                fontSize: 11,
                                fontWeight: node.isDraft
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                            ),
                            Text(
                              node.isDeferred
                                  ? 'vėliau'
                                  : node.participantsHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: QortDesignSystem.textMuted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddStageWizardSheet extends StatefulWidget {
  final String division;
  final Map<String, dynamic> initialDraft;
  final List<Map<String, dynamic>> existingStages;
  final _CreateDefaultStageFn createDefaultStage;
  final List<String> allFormats;
  final Set<String> comingSoonFormats;
  final List<String> placesOptions;
  final String Function(String format) formatDropdownLabel;
  final String Function(String format) formatDescription;
  final bool Function(String format) isLadderFormat;
  final bool Function(String format) isComingSoonFormat;
  final VoidCallback onComingSoonFormat;
  final _WizardRoutingItemsBuilder buildRoutingItems;
  final _WizardRoutingLabelFn routingTargetLabelForId;

  const _AddStageWizardSheet({
    required this.division,
    required this.initialDraft,
    required this.existingStages,
    required this.createDefaultStage,
    required this.allFormats,
    required this.comingSoonFormats,
    required this.placesOptions,
    required this.formatDropdownLabel,
    required this.formatDescription,
    required this.isLadderFormat,
    required this.isComingSoonFormat,
    required this.onComingSoonFormat,
    required this.buildRoutingItems,
    required this.routingTargetLabelForId,
  });

  @override
  State<_AddStageWizardSheet> createState() => _AddStageWizardSheetState();
}

class _AddStageWizardSheetState extends State<_AddStageWizardSheet> {
  static const _stepLabels = [
    'Pagrindinis',
    'Nustatymai',
    'Kryžkelės',
    'Peržiūra',
  ];

  late Map<String, dynamic> _draft;
  int _step = 0;
  bool _step2Skipped = false;
  final List<Map<String, dynamic>> _pendingChildStages = [];

  @override
  void initState() {
    super.initState();
    _draft = Map<String, dynamic>.from(widget.initialDraft);
    _draft.putIfAbsent('advance_to', () => 'none');
    _draft.putIfAbsent('drop_to', () => 'none');
    if (!_draft.containsKey('advance_mode')) {
      _draft['advance_mode'] = switch (_draft['advance_to']?.toString()) {
        'later' => 'later',
        'none' => 'final',
        _ => 'existing',
      };
    }
    if (!_draft.containsKey('drop_mode')) {
      _draft['drop_mode'] = switch (_draft['drop_to']?.toString()) {
        'later' => 'later',
        'none' => 'out',
        _ => 'existing',
      };
    }
  }

  List<String> _routingTargetIds({required bool forAdvance}) {
    final items = widget.buildRoutingItems(
      division: widget.division,
      excludeStageId: _draftId,
      forAdvance: forAdvance,
      extraStages: [..._pendingChildStages],
    );
    return items
        .map((i) => i.value)
        .whereType<String>()
        .where((v) => v != 'none' && v != 'later')
        .toList();
  }

  List<Map<String, dynamic>> get _extraStagesForRouting => [
        ..._pendingChildStages,
      ];

  String get _format => _draft['format']?.toString() ?? 'Round Robin (Grupės)';

  String get _draftId => _draft['id'].toString();

  bool get _skipFormatSettingsStep => widget.isLadderFormat(_format);

  bool get _hasGroupSettings =>
      _format.contains('Grupės') || _format.contains('Swiss');

  bool get _hasEliminationSettings =>
      _format.contains('Elimination') ||
      _format.contains('Atkrintamosios') ||
      _format.contains('Kvalifikacija') ||
      _format.contains('Paguodos');

  void _goNext() {
    if (_step == 0) {
      final name = _draft['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Įveskite etapo pavadinimą.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_skipFormatSettingsStep) {
        setState(() {
          _step2Skipped = true;
          _step = 2;
        });
        return;
      }
      setState(() {
        _step2Skipped = false;
        _step = 1;
      });
      return;
    }
    if (_step == 1) {
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      setState(() => _step = 3);
    }
  }

  void _goBack() {
    if (_step == 2 && _step2Skipped) {
      setState(() => _step = 0);
      return;
    }
    if (_step == 2) {
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      setState(() => _step = 0);
      return;
    }
    if (_step == 3) {
      setState(() => _step = 2);
    }
  }

  void _confirmAdd() {
    final stages = [
      ..._pendingChildStages.map((s) => Map<String, dynamic>.from(s)),
      Map<String, dynamic>.from(_draft),
    ];
    Navigator.pop(context, stages);
  }

  void _applyRoutingMode({
    required String modeKey,
    required String targetKey,
    required String mode,
    required bool forAdvance,
  }) {
    setState(() {
      _draft[modeKey] = mode;
      switch (mode) {
        case 'final':
        case 'out':
          _draft[targetKey] = 'none';
          break;
        case 'later':
          _draft[targetKey] = 'later';
          break;
        case 'existing':
          final ids = _routingTargetIds(forAdvance: forAdvance);
          final current = _draft[targetKey]?.toString();
          if (current == null ||
              current == 'none' ||
              current == 'later' ||
              !ids.contains(current)) {
            _draft[targetKey] = ids.isNotEmpty ? ids.first : 'none';
            if (ids.isEmpty) {
              _draft[modeKey] = forAdvance ? 'final' : 'out';
            }
          }
          break;
        case 'create_now':
          break;
      }
    });
  }

  Future<void> _openChildWizard(String targetKey) async {
    final forAdvance = targetKey == 'advance_to';
    final nextIndex =
        widget.existingStages.length + _pendingChildStages.length + 1;
    final childDraft = widget.createDefaultStage(nextIndex, widget.division);
    childDraft['id'] =
        'stage_${DateTime.now().millisecondsSinceEpoch}_$nextIndex';
    childDraft['name'] = forAdvance ? 'Finalas' : 'Paguodos turnyras';
    childDraft['format'] = 'Single Elimination (Atkrintamosios)';
    childDraft['playoff_places'] =
        forAdvance ? 'Dėl 3 vietos' : 'Visas vietos (5, 7, 9...)';

    final result =
        await Navigator.of(context, rootNavigator: true).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: QortColors.surface,
          body: SafeArea(
            child: _AddStageWizardSheet(
              division: widget.division,
              initialDraft: childDraft,
              existingStages: [
                ...widget.existingStages,
                ..._pendingChildStages,
                Map<String, dynamic>.from(_draft),
              ],
              createDefaultStage: widget.createDefaultStage,
              allFormats: widget.allFormats,
              comingSoonFormats: widget.comingSoonFormats,
              placesOptions: widget.placesOptions,
              formatDropdownLabel: widget.formatDropdownLabel,
              formatDescription: widget.formatDescription,
              isLadderFormat: widget.isLadderFormat,
              isComingSoonFormat: widget.isComingSoonFormat,
              onComingSoonFormat: widget.onComingSoonFormat,
              buildRoutingItems: widget.buildRoutingItems,
              routingTargetLabelForId: widget.routingTargetLabelForId,
            ),
          ),
        ),
      ),
    );

    if (!mounted || result == null || result.isEmpty) return;

    setState(() {
      for (final stage in result) {
        final id = stage['id'].toString();
        if (!_pendingChildStages.any((s) => s['id'].toString() == id) &&
            id != _draftId) {
          _pendingChildStages.add(Map<String, dynamic>.from(stage));
        }
      }
      final created = result.last;
      _draft[targetKey] = created['id'];
      _draft[forAdvance ? 'advance_mode' : 'drop_mode'] = 'existing';
    });
  }

  Widget _buildExistingTargetDropdown({
    required String targetKey,
    required bool forAdvance,
  }) {
    final accent =
        forAdvance ? QortDesignSystem.training : QortDesignSystem.error;
    final value = _draft[targetKey]?.toString() ?? 'none';
    final items = widget.buildRoutingItems(
      division: widget.division,
      excludeStageId: _draftId,
      forAdvance: forAdvance,
      extraStages: _extraStagesForRouting,
    );
    final filteredItems = items
        .where((i) => i.value != 'none' && i.value != 'later')
        .toList();
    final validItemValues =
        filteredItems.map((i) => i.value).whereType<String>().toList();
    var dropdownValue = value;
    if (!validItemValues.contains(dropdownValue)) {
      dropdownValue =
          validItemValues.isNotEmpty ? validItemValues.first : 'none';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: filteredItems.isEmpty
            ? const Text(
                'Nėra kitų etapų — sukurk naują arba pasirink „vėliau“.',
                style: TextStyle(fontSize: 12, color: QortColors.textSecondary),
              )
            : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: validItemValues.contains(dropdownValue)
                      ? dropdownValue
                      : validItemValues.first,
                  isExpanded: true,
                  dropdownColor: QortColors.surface,
                  items: filteredItems,
                  onChanged: (v) => setState(() => _draft[targetKey] = v),
                ),
              ),
      ),
    );
  }

  Widget _buildRoutingChoiceSection({
    required String title,
    required Color accent,
    required String modeKey,
    required String targetKey,
    required bool forAdvance,
    required List<(String mode, String label)> options,
  }) {
    final mode = _draft[modeKey]?.toString() ??
        (forAdvance ? 'final' : 'out');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.bebasNeue(
            color: accent,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        ...options.map((opt) {
          return RadioListTile<String>(
            value: opt.$1,
            groupValue: mode,
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: accent,
            title: Text(opt.$2, style: const TextStyle(fontSize: 13)),
            onChanged: (v) {
              if (v == null) return;
              if (v == 'create_now') {
                _openChildWizard(targetKey);
                return;
              }
              _applyRoutingMode(
                modeKey: modeKey,
                targetKey: targetKey,
                mode: v,
                forAdvance: forAdvance,
              );
            },
          );
        }),
        if (mode == 'existing')
          _buildExistingTargetDropdown(
            targetKey: targetKey,
            forAdvance: forAdvance,
          ),
      ],
    );
  }

  Widget _wizardDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final options = List<String>.from(items);
    if (!options.contains(value)) options.add(value);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: QortColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: QortColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: QortColors.surface,
          style: const TextStyle(
            color: QortColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: options
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Row(
            children: List.generate(4 * 2 - 1, (i) {
              if (i.isOdd) {
                final lineStep = i ~/ 2;
                final isPast = lineStep < _step;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isPast
                        ? QortDesignSystem.training.withValues(alpha: 0.5)
                        : QortDesignSystem.borderSubtle,
                  ),
                );
              }
              final stepIndex = i ~/ 2;
              final isCurrent = stepIndex == _step;
              final isPast = stepIndex < _step;
              final isSkipped =
                  stepIndex == 1 && _step2Skipped && _step >= 2;

              Color fillColor;
              Color borderColor;
              if (isCurrent) {
                fillColor = QortDesignSystem.training;
                borderColor = QortDesignSystem.training;
              } else if (isPast || isSkipped) {
                fillColor = QortDesignSystem.textMuted;
                borderColor = QortDesignSystem.textMuted;
              } else {
                fillColor = Colors.transparent;
                borderColor = QortDesignSystem.borderDefault;
              }

              return Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fillColor,
                  border: Border.all(color: borderColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${stepIndex + 1}',
                  style: TextStyle(
                    color: isCurrent || isPast || isSkipped
                        ? QortColors.textPrimary
                        : QortDesignSystem.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              4,
              (i) => Expanded(
                child: Text(
                  _stepLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: i == _step
                        ? QortDesignSystem.training
                        : QortDesignSystem.textMuted,
                    fontSize: 10,
                    fontWeight: i == _step ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Basic() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PAGRINDINIS',
          style: GoogleFonts.bebasNeue(
            color: QortColors.textPrimary,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Etapo pavadinimas',
          style: GoogleFonts.bebasNeue(
            color: QortDesignSystem.textSecondary,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: TextEditingController(text: _draft['name']?.toString())
            ..selection = TextSelection.collapsed(
              offset: (_draft['name']?.toString() ?? '').length,
            ),
          onChanged: (v) => _draft['name'] = v,
          style: const TextStyle(
            color: QortColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: QortColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: QortColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: QortColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: QortDesignSystem.training.withValues(alpha: 0.7),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Etapo formatas',
          style: GoogleFonts.bebasNeue(
            color: QortDesignSystem.textSecondary,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          decoration: BoxDecoration(
            color: QortColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: QortColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _format,
              isExpanded: true,
              dropdownColor: QortColors.surface,
              style: const TextStyle(
                color: QortColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              items: widget.allFormats.map((format) {
                final comingSoon = widget.isComingSoonFormat(format);
                return DropdownMenuItem<String>(
                  value: format,
                  enabled: !comingSoon,
                  child: Text(
                    widget.formatDropdownLabel(format),
                    style: TextStyle(
                      color: comingSoon
                          ? QortColors.textSecondary
                          : QortColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (selected) {
                if (selected == null) return;
                if (widget.isComingSoonFormat(selected)) {
                  widget.onComingSoonFormat();
                  return;
                }
                setState(() => _draft['format'] = selected);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: QortDesignSystem.training.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: QortDesignSystem.training.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            widget.formatDescription(_format),
            style: const TextStyle(
              color: QortColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2FormatSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FORMATO NUSTATYMAI',
          style: GoogleFonts.bebasNeue(
            color: QortColors.textPrimary,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _format,
          style: const TextStyle(
            color: QortDesignSystem.textMuted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),
        if (_hasGroupSettings) ...[
          Text(
            'Į kiek grupių dalinsime?',
            style: GoogleFonts.bebasNeue(
              color: QortDesignSystem.textSecondary,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          _wizardDropdown(
            value: (_draft['group_count'] ?? 2).toString(),
            items: const ['1', '2', '3', '4', '6', '8'],
            onChanged: (v) =>
                setState(() => _draft['group_count'] = int.parse(v!)),
          ),
          const SizedBox(height: 28),
          Text(
            'Kiek žaidėjų išeina į kitą etapą iš grupės?',
            style: GoogleFonts.bebasNeue(
              color: QortDesignSystem.textSecondary,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          _wizardDropdown(
            value: (_draft['advancing_players'] ?? 2).toString(),
            items: const ['1', '2', '3', '4', '8'],
            onChanged: (v) =>
                setState(() => _draft['advancing_players'] = int.parse(v!)),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ar galimos lygiosios?',
                style: GoogleFonts.bebasNeue(
                  color: QortDesignSystem.textSecondary,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
              Switch(
                value: _draft['allow_ties'] == true,
                activeThumbColor: QortDesignSystem.training,
                onChanged: (v) => setState(() => _draft['allow_ties'] = v),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Taškų sistema',
            style: GoogleFonts.bebasNeue(
              color: Colors.orange,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pergalė',
            style: TextStyle(
              color: QortColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          _wizardDropdown(
            value: (_draft['points_for_win'] ?? 3).toString(),
            items: const ['1', '2', '3', '4', '5'],
            onChanged: (v) =>
                setState(() => _draft['points_for_win'] = int.parse(v!)),
          ),
          if (_draft['allow_ties'] == true) ...[
            const SizedBox(height: 20),
            const Text(
              'Lygiosios',
              style: TextStyle(
                color: QortColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _wizardDropdown(
              value: (_draft['points_for_tie'] ?? 1).toString(),
              items: const ['0', '1', '2'],
              onChanged: (v) =>
                  setState(() => _draft['points_for_tie'] = int.parse(v!)),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Pralaimėjimas',
            style: TextStyle(
              color: QortColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          _wizardDropdown(
            value: (_draft['points_for_loss'] ?? 0).toString(),
            items: const ['0', '1', '2'],
            onChanged: (v) =>
                setState(() => _draft['points_for_loss'] = int.parse(v!)),
          ),
        ],
        if (_hasEliminationSettings) ...[
          Text(
            'Kiek vietų išžaisti?',
            style: GoogleFonts.bebasNeue(
              color: QortDesignSystem.textSecondary,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          _wizardDropdown(
            value: _draft['playoff_places']?.toString() ?? 'Tik nugalėtoją',
            items: widget.placesOptions,
            onChanged: (v) => setState(() => _draft['playoff_places'] = v),
          ),
        ],
        if (!_hasGroupSettings && !_hasEliminationSettings)
          const Text(
            'Šiam formatui papildomi nustatymai nereikalingi.',
            style: TextStyle(color: QortColors.textSecondary, fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildStep3Routing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KAS TOLIAU?',
          style: GoogleFonts.bebasNeue(
            color: QortColors.textPrimary,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nurodykite, kur keliauja laimėtojai ir pralaimėtojai po šio etapo.',
          style: TextStyle(
            color: QortColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'TURNYRO STRUKTŪRA',
          style: GoogleFonts.bebasNeue(
            color: QortDesignSystem.textMuted,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: _TournamentTreeDiagram(
            savedStages: widget.existingStages,
            draftStage: _draft,
            pendingChildStages: _pendingChildStages,
          ),
        ),
        const SizedBox(height: 24),
        _buildRoutingChoiceSection(
          title: '🏆 KUR KELIAUJA LAIMĖTOJAI?',
          accent: QortDesignSystem.training,
          modeKey: 'advance_mode',
          targetKey: 'advance_to',
          forAdvance: true,
          options: const [
            ('existing', 'Į esamą etapą'),
            ('final', 'Čia finalas (turnyro pabaiga)'),
            ('create_now', 'Sukurti naują etapą dabar'),
            ('later', 'Sukursiu sekantį etapą vėliau'),
          ],
        ),
        const SizedBox(height: 24),
        _buildRoutingChoiceSection(
          title: '💔 KUR KELIAUJA PRALAIMĖTOJAI?',
          accent: QortDesignSystem.error,
          modeKey: 'drop_mode',
          targetKey: 'drop_to',
          forAdvance: false,
          options: const [
            ('existing', 'Į esamą etapą (paguoda / kitas)'),
            ('out', 'Iškrenta iš turnyro'),
            ('create_now', 'Sukurti naują etapą dabar'),
            ('later', 'Sukursiu sekantį etapą vėliau'),
          ],
        ),
      ],
    );
  }

  String _routingSummaryLine(String fieldKey, {required bool forAdvance}) {
    final modeKey = forAdvance ? 'advance_mode' : 'drop_mode';
    final mode = _draft[modeKey]?.toString();
    if (mode == 'later') return 'Sukursiu sekantį etapą vėliau';
    if (mode == 'final' || (mode == null && !forAdvance && (_draft[fieldKey]?.toString() ?? 'none') == 'none')) {
      if (forAdvance) return 'Niekur — finalas (čia baigiasi kelias)';
    }
    if (mode == 'out') return 'Niekur — iškrenta iš turnyro';

    final targetId = _draft[fieldKey]?.toString() ?? 'none';
    if (targetId == 'none') {
      return forAdvance
          ? 'Niekur — finalas (čia baigiasi kelias)'
          : 'Niekur — iškrenta iš turnyro';
    }
    if (targetId == 'later') return 'Sukursiu sekantį etapą vėliau';
    return widget.routingTargetLabelForId(
          targetId,
          _extraStagesForRouting,
        ) ??
        '(nerastas etapas)';
  }

  String _settingsSummary() {
    if (_skipFormatSettingsStep) {
      return 'Ladder — papildomi nustatymai nereikalingi';
    }
    if (_hasGroupSettings) {
      final ties = _draft['allow_ties'] == true;
      final tiePts = _draft['points_for_tie'] ?? 1;
      final tiePart = ties ? '/$tiePts' : '';
      return '${_draft['group_count'] ?? 2} grupės, '
          '${_draft['advancing_players'] ?? 2} išeina, '
          'taškai ${_draft['points_for_win'] ?? 3}$tiePart/${_draft['points_for_loss'] ?? 0}';
    }
    if (_hasEliminationSettings) {
      return _draft['playoff_places']?.toString() ?? 'Tik nugalėtoją';
    }
    return '—';
  }

  Widget _reviewRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: QortColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? QortColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PERŽIŪRA',
          style: GoogleFonts.bebasNeue(
            color: QortColors.textPrimary,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Patikrinkite pasirinkimus prieš pridedant etapą.',
          style: TextStyle(
            color: QortColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: QortColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: QortColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reviewRow('Pavadinimas', _draft['name']?.toString() ?? '—'),
              _reviewRow('Formatas', _format),
              _reviewRow('Nustatymai', _settingsSummary()),
              _reviewRow(
                '🏆 Laimėtojai →',
                _routingSummaryLine('advance_to', forAdvance: true),
                valueColor: QortDesignSystem.training,
              ),
              _reviewRow(
                '💔 Pralaimėtojai →',
                _routingSummaryLine('drop_to', forAdvance: false),
                valueColor: QortDesignSystem.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return _buildStep1Basic();
      case 1:
        return _buildStep2FormatSettings();
      case 2:
        return _buildStep3Routing();
      case 3:
        return _buildStep4Review();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: QortColors.surface,
        border: Border(top: BorderSide(color: QortDesignSystem.borderSubtle)),
      ),
      child: Row(
        children: [
          if (_step == 0)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Atšaukti',
                style: TextStyle(color: QortColors.textSecondary),
              ),
            )
          else
            TextButton.icon(
              onPressed: _goBack,
              icon: const Icon(LucideIcons.arrowLeft, size: 16),
              label: const Text('Atgal'),
              style: TextButton.styleFrom(
                foregroundColor: QortColors.textSecondary,
              ),
            ),
          const Spacer(),
          if (_step < 3)
            ElevatedButton.icon(
              onPressed: _goNext,
              icon: const Icon(LucideIcons.arrowRight, size: 16),
              label: const Text('Pirmyn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: QortDesignSystem.training,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _confirmAdd,
              icon: const Icon(LucideIcons.check, size: 16),
              label: const Text('PRIDĖTI ETAPĄ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: QortDesignSystem.training,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: QortDesignSystem.borderDefault,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'NAUJAS ETAPAS',
                  style: GoogleFonts.bebasNeue(
                    color: QortColors.textPrimary,
                    fontSize: 22,
                    letterSpacing: 1,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, color: QortColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Text(
          widget.division,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: QortDesignSystem.textMuted,
            fontSize: 12,
          ),
        ),
        _buildStepIndicator(),
        const Divider(height: 1, color: QortColors.border),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: _buildStepBody(),
          ),
        ),
        _buildNavBar(),
      ],
    );
  }
}
