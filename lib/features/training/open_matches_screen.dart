import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/services/demo_flow_service.dart';
import '../../core/services/user_sports_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/query_limits.dart';
import '../../core/models/sport_catalog_entry.dart';
import '../../core/services/sports_catalog_service.dart';
import '../../core/theme/qort_design_system.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/constants/app_shell_layout.dart';
import '../../core/theme/qort_theme.dart';
import '../../core/utils/sport_icons.dart';
import '../../core/utils/sport_levels.dart';
import '../../core/widgets/qort_ambient_background.dart';
import '../../core/widgets/qort_components.dart';
import '../../core/widgets/qort_form_help.dart';
import '../profile/user_model.dart';
import '../profile/status_avatar.dart';

class OpenMatchesScreen extends StatefulWidget {
  final UserProfile user;
  final bool openCreateDialog;

  const OpenMatchesScreen({
    super.key,
    required this.user,
    this.openCreateDialog = false,
  });

  @override
  State<OpenMatchesScreen> createState() => _OpenMatchesScreenState();
}

class _OpenMatchesScreenState extends State<OpenMatchesScreen> {
  bool _isLoading = true;
  List<dynamic> _notices = [];
  String _searchCity = "";

  @override
  void initState() {
    super.initState();
    _searchCity = widget.user.city;
    _fetchNotices();
    if (widget.openCreateDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCreateNoticeDialog();
      });
    }
  }

  Future<void> _fetchNotices() async {
    setState(() => _isLoading = true);
    try {
      final mySportsNames = widget.user.sportsList.map((s) => s.name).toList();

      if (mySportsNames.isEmpty) {
        setState(() {
          _notices = [];
          _isLoading = false;
        });
        return;
      }

      var query = Supabase.instance.client
          .from('open_matches')
          .select('*, profiles(nickname, photo_url, xp)')
          .inFilter('sport', mySportsNames)
          .eq('status', 'open');

      if (_searchCity.isNotEmpty) {
        query = query.ilike('location', '%$_searchCity%');
      }

      final response = await query
          .order('match_date', ascending: true)
          .limit(QueryLimits.openMatchesFeed);

      if (mounted) {
        setState(() {
          _notices = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant skelbimus: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // TRYNIMO FUNKCIJA (Su XP apsauga nuo sukčiavimo)
  Future<void> _deleteNotice(String noticeId) async {
    try {
      // 1. Minusuojame 25 XP iš autoriaus, kuriuos jis gavo kurdamas skelbimą
      final myProfile = await Supabase.instance.client
          .from('profiles')
          .select('xp')
          .eq('id', widget.user.id)
          .single();
      int currentXp = myProfile['xp'] ?? 0;
      int newXp = currentXp >= 25
          ? currentXp - 25
          : 0; // Neleidžiame XP nukristi žemiau nulio

      await Supabase.instance.client
          .from('profiles')
          .update({'xp': newXp})
          .eq('id', widget.user.id);

      // 2. Ištriname skelbimą
      await Supabase.instance.client
          .from('open_matches')
          .delete()
          .eq('id', noticeId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Skelbimas ištrintas. Jums minusuota 25 XP."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      _fetchNotices();
    } catch (e) {
      debugPrint("Klaida trinant: $e");
    }
  }

  // PATIKRA: AR GALI KURTI ŠIANDIEN
  Future<bool> _canPostToday() async {
    final startOfDay = DateTime.now()
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0)
        .toUtc()
        .toIso8601String();
    final res = await Supabase.instance.client
        .from('open_matches')
        .select('id')
        .eq('creator_id', widget.user.id)
        .gte('created_at', startOfDay);
    return (res as List).isEmpty;
  }

  // SKELBIMO KŪRIMAS (+25 XP)
  Future<void> _createNotice(Map<String, dynamic> noticeData) async {
    bool canPost = await _canPostToday();
    if (!canPost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Galite paskelbti tik 1 mačą per dieną!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('open_matches').insert(noticeData);

      await UserSportsService.addXp(widget.user.id, 25);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Skelbimas sėkmingai sukurtas! Gavote +25 XP."),
            backgroundColor: Colors.green,
          ),
        );
      }
      _fetchNotices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Klaida: $e"), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // PRISIJUNGIMO FUNKCIJA (+15 XP ABIEMS)
  Future<void> _joinMatch(Map<String, dynamic> notice) async {
    if (notice['creator_id'] == widget.user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Negalite prisijungti prie savo paties skelbimo!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Pakeičiame skelbimo statusą
      await Supabase.instance.client
          .from('open_matches')
          .update({'status': 'closed'})
          .eq('id', notice['id']);

      // 2. Sukuriame mačą (susitarimą) `matches` lentelėje
      await Supabase.instance.client.from('matches').insert({
        'player1_id': notice['creator_id'],
        'player2_id': widget.user.id,
        'match_date': notice['match_date'],
        'location': notice['location'],
        'status':
            'scheduled', // ARBA 'active' priklausomai nuo jūsų loginės struktūros
      });

      await UserSportsService.addXp(notice['creator_id'] as String, 15);
      await UserSportsService.addXp(widget.user.id, 15);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Sėkmingai prisijungėte! Mačas suderintas. Gavote +15 XP.",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      _fetchNotices(); // Atnaujina sąrašą (skelbimas dings iš 'open')
    } catch (e) {
      debugPrint("Klaida prisijungiant: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Klaida: $e"), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _runTrainingDemo() async {
    if (!kDebugMode) return;
    if (widget.user.sportsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profilyje pridėkite sporto šaką.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final sport = widget.user.sportsList.first.name;
    final result = await DemoFlowService.simulateTrainingSparring(
      userId: widget.user.id,
      sportName: sport,
      level: widget.user.sportsList.first.level,
      city: widget.user.city,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.ok ? Colors.green : Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
    if (result.ok) _fetchNotices();
  }

  Future<void> _showCreateNoticeDialog() async {
    if (widget.user.sportsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pirmiausia profilyje pridėkite sporto šaką!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    List<SportCatalogEntry> catalog = [];
    try {
      catalog = await SportsCatalogService.fetchActive();
    } catch (_) {}

    SportCatalogEntry? entryForSport(String sport) {
      for (final e in catalog) {
        if (e.name == sport) return e;
      }
      return null;
    }

    RangeValues levelRangeFor(String sport, int myLevel) {
      final entry = entryForSport(sport);
      final minL = SportLevels.minValue(entry);
      final maxL = SportLevels.maxValue(entry);
      final lo = (myLevel - 1.0).clamp(minL, maxL);
      var hi = (myLevel + 1.0).clamp(minL, maxL);
      if (hi < lo) hi = lo;
      return RangeValues(lo, hi);
    }

    String selectedSport = widget.user.sportsList.first.name;
    int myLevelForSport = widget.user.sportsList.first.level;

    RangeValues opponentLevelRange =
        levelRangeFor(selectedSport, myLevelForSport);

    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final TextEditingController locationCtrl = TextEditingController(
      text: widget.user.city,
    );

    bool hasCourt = false;
    final TextEditingController priceCtrl = TextEditingController();
    String priceSplit = "Dalinamės per pusę";

    String selectedFormat = "1v1";

    showModalBottomSheet(
      context: context,
      backgroundColor: QortColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateModal) {
            final sportEntry = entryForSport(selectedSport);
            final levelMin = SportLevels.minValue(sportEntry);
            final levelMax = SportLevels.maxValue(sportEntry);
            final levelRows = SportLevels.rows(sportEntry);
            final levelDivisions =
                levelRows.length > 1 ? levelRows.length - 1 : null;
            final myLevelDesc = SportLevels.descFor(sportEntry, myLevelForSport);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: QortColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      "SUKURTI SKELBIMĄ",
                      style: GoogleFonts.bebasNeue(
                        fontSize: 28,
                        color: QortColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const QortHelpBanner(
                      title: 'Atviras mačas / treniruotė',
                      bullets: QortFormHelpTexts.trainingListing,
                      accentColor: Colors.orange,
                    ),
                    const SizedBox(height: 16),

                    // SPORTAS
                    DropdownButtonFormField<String>(
                      initialValue: selectedSport,
                      dropdownColor: QortColors.background,
                      style: const TextStyle(color: QortColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: "Sporto šaka",
                        labelStyle: TextStyle(color: QortColors.textSecondary),
                        filled: true,
                        fillColor: QortColors.background,
                        border: OutlineInputBorder(),
                      ),
                      items: widget.user.sportsList.map((s) {
                        return DropdownMenuItem(
                          value: s.name,
                          child: Row(
                            children: [
                              SportIcons.icon(s.name, size: 18),
                              const SizedBox(width: 10),
                              Text(s.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateModal(() {
                            selectedSport = val;
                            myLevelForSport = widget.user.sportsList
                                .firstWhere((s) => s.name == val)
                                .level;
                            opponentLevelRange =
                                levelRangeFor(val, myLevelForSport);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // MANO LYGIS
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Tavo lygis ($selectedSport): ${SportLevels.nameFor(sportEntry, myLevelForSport)}",
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (myLevelDesc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              myLevelDesc,
                              style: const TextStyle(
                                color: QortColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // IEŠKOMAS VARŽOVO LYGIS
                    Text(
                      "Ieškomas varžovo lygis: ${SportLevels.rangeLabel(sportEntry, opponentLevelRange.start.round(), opponentLevelRange.end.round())}",
                      style: const TextStyle(color: QortColors.textPrimary),
                    ),
                    RangeSlider(
                      values: opponentLevelRange,
                      min: levelMin,
                      max: levelMax,
                      divisions: levelDivisions,
                      activeColor: Colors.orange,
                      inactiveColor: QortColors.navInactive,
                      labels: RangeLabels(
                        SportLevels.nameFor(
                          sportEntry,
                          opponentLevelRange.start.round(),
                        ),
                        SportLevels.nameFor(
                          sportEntry,
                          opponentLevelRange.end.round(),
                        ),
                      ),
                      onChanged: (RangeValues values) {
                        setStateModal(() {
                          opponentLevelRange = values;
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // FORMATAS
                    DropdownButtonFormField<String>(
                      initialValue: selectedFormat,
                      dropdownColor: QortColors.background,
                      style: const TextStyle(color: QortColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: "Formatas",
                        labelStyle: TextStyle(color: QortColors.textSecondary),
                        filled: true,
                        fillColor: QortColors.background,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "1v1",
                          child: Text("1v1 (Pavienis)"),
                        ),
                        DropdownMenuItem(
                          value: "2v2",
                          child: Text("2v2 (Dvejetai)"),
                        ),
                        DropdownMenuItem(
                          value: "3x3",
                          child: Text("3x3 (Komanda)"),
                        ),
                        DropdownMenuItem(
                          value: "5v5",
                          child: Text("5v5 (Komanda)"),
                        ),
                      ],
                      onChanged: (val) =>
                          setStateModal(() => selectedFormat = val!),
                    ),
                    const SizedBox(height: 15),

                    // DATA IR LAIKAS
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: QortColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            icon: const Icon(
                              LucideIcons.calendar,
                              color: Colors.orange,
                              size: 16,
                            ),
                            label: Text(
                              selectedDate == null
                                  ? "Data"
                                  : DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(selectedDate!),
                              style: const TextStyle(color: QortColors.textPrimary),
                            ),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 30),
                                ),
                              );
                              if (d != null) {
                                setStateModal(() => selectedDate = d);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: QortColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            icon: const Icon(
                              LucideIcons.clock,
                              color: Colors.orange,
                              size: 16,
                            ),
                            label: Text(
                              selectedTime == null
                                  ? "Laikas"
                                  : selectedTime!.format(context),
                              style: const TextStyle(color: QortColors.textPrimary),
                            ),
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (t != null) {
                                setStateModal(() => selectedTime = t);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // LOKACIJA
                    TextField(
                      controller: locationCtrl,
                      style: const TextStyle(color: QortColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: "Miestas / Arena",
                        labelStyle: TextStyle(color: QortColors.textSecondary),
                        filled: true,
                        fillColor: QortColors.background,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // AIKŠTELĖ IR KAINA
                    SwitchListTile(
                      title: const Text(
                        "Turiu užsakytą aikštelę",
                        style: TextStyle(color: QortColors.textPrimary),
                      ),
                      activeThumbColor: Colors.orange,
                      contentPadding: EdgeInsets.zero,
                      value: hasCourt,
                      onChanged: (val) => setStateModal(() => hasCourt = val),
                    ),

                    if (hasCourt) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: QortColors.textPrimary),
                              decoration: const InputDecoration(
                                labelText: "Kaina (Visiems)",
                                labelStyle: TextStyle(color: QortColors.textSecondary),
                                suffixText: "€",
                                suffixStyle: TextStyle(color: QortColors.textPrimary),
                                filled: true,
                                fillColor: QortColors.background,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: priceSplit,
                              dropdownColor: QortColors.background,
                              style: const TextStyle(
                                color: QortColors.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: QortColors.background,
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: "Dalinamės per pusę",
                                  child: Text("Dalinamės per pusę"),
                                ),
                                DropdownMenuItem(
                                  value: "Apmoku aš",
                                  child: Text("Apmoku aš (Nemokama)"),
                                ),
                                DropdownMenuItem(
                                  value: "Apmoka varžovas",
                                  child: Text("Apmoka varžovas"),
                                ),
                              ],
                              onChanged: (val) =>
                                  setStateModal(() => priceSplit = val!),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 25),

                    // SUBMIT
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () {
                          if (selectedDate == null ||
                              selectedTime == null ||
                              locationCtrl.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Užpildykite pagrindinius laukus (Data, Laikas, Vieta)!",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          final dt = DateTime(
                            selectedDate!.year,
                            selectedDate!.month,
                            selectedDate!.day,
                            selectedTime!.hour,
                            selectedTime!.minute,
                          );
                          final noticeData = {
                            'creator_id': widget.user.id,
                            'sport': selectedSport,
                            'level': myLevelForSport, // Siunčiame tavo lygį
                            'min_level': opponentLevelRange.start.toInt(),
                            'max_level': opponentLevelRange.end.toInt(),
                            'match_date': dt.toUtc().toIso8601String(),
                            'location': locationCtrl.text.trim(),
                            'has_court': hasCourt,
                            'court_price': hasCourt
                                ? priceCtrl.text.trim()
                                : "",
                            'price_split': hasCourt ? priceSplit : "",
                            'format': selectedFormat,
                            'is_team':
                                selectedFormat.contains('x') ||
                                selectedFormat == '5v5',
                          };
                          Navigator.pop(context);
                          _createNotice(noticeData);
                        },
                        child: const Text(
                          "SKELBTI",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // POKALBIO MOCKUP LOGIKA
  void _openChatWithCreator(String creatorName) {
    // Ateityje čia bus nukreipimas į tavo tikrą Chat langą.
    // Kol kas parodome, kad funkcija veikia:
    showModalBottomSheet(
      context: context,
      backgroundColor: QortColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pokalbis su $creatorName",
                style: GoogleFonts.oswald(color: QortColors.textPrimary, fontSize: 20),
              ),
              const SizedBox(height: 10),
              const Text(
                "Ši funkcija atidarys tiesioginių žinučių (DM) langą su skelbimo autoriumi detalių derinimui.",
                style: TextStyle(color: QortColors.textSecondary),
              ),
              const Spacer(),
              TextField(
                style: const TextStyle(color: QortColors.textPrimary),
                decoration: InputDecoration(
                  hintText: "Rašyti žinutę...",
                  hintStyle: const TextStyle(color: QortColors.textSecondary),
                  filled: true,
                  fillColor: Colors.black45,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  suffixIcon: const Icon(
                    LucideIcons.send,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final accent = QortDesignSystem.training;

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          QortAmbientBackground(palette: p),
          Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'TRENIRUOTĖS · ATVIRI MAČAI',
                    style: QortDesignSystem.h2.copyWith(color: p.textSecondary),
                  ),
                ),
                if (kDebugMode)
                  IconButton(
                    tooltip: 'Demo: skelbimas → mačas',
                    icon: Icon(LucideIcons.flaskConical, color: accent),
                    onPressed: _isLoading ? null : _runTrainingDemo,
                  ),
                IconButton(
                  icon: Icon(LucideIcons.plusCircle, color: accent),
                  onPressed: _showCreateNoticeDialog,
                ),
              ],
            ),
          ),
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                'Demo (kolonėlė): sukuria skelbimą, priima varžovą iš DB ir užbaigia sparingo mačą.',
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(QortDesignSystem.space4),
            child: QortInput(
              hint: 'Ieškoti mieste (pvz. Nida)...',
              prefixIcon: LucideIcons.mapPin,
              onSubmitted: (val) {
                setState(() => _searchCity = val.trim());
                _fetchNotices();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: accent))
                : _notices.isEmpty
                ? QortEmptyState(
                    icon: LucideIcons.clipboardList,
                    title: 'Skelbimų dar nėra',
                    message:
                        'Tavo mieste pasirinktoms sporto šakoms skelbimų nerasta. Būk pirmas ir sukurk kvietimą!',
                    actionLabel: 'Sukurti skelbimą',
                    onAction: _showCreateNoticeDialog,
                    accent: accent,
                  )
                : RefreshIndicator(
                    onRefresh: _fetchNotices,
                    color: accent,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        AppShellLayout.scrollBottomPadding(context),
                      ),
                      itemCount: _notices.length,
                      itemBuilder: (context, index) {
                        final notice = _notices[index];
                        final creator = notice['profiles'];
                        final date = DateTime.parse(
                          notice['match_date'],
                        ).toLocal();
                        final bool hasCourt = notice['has_court'] ?? false;
                        final bool isTeam = notice['is_team'] ?? false;

                        // Saugus duomenų traukimas
                        final int minLvl = notice['min_level'] ?? 1;
                        final int maxLvl = notice['max_level'] ?? 5;
                        final String price = notice['court_price'] ?? "";
                        final String split = notice['price_split'] ?? "";

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: QortColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: QortColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // AUTORIAUS HEADERIS
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      StatusAvatar(
                                        imageUrl: creator['photo_url'] ?? "",
                                        displayName:
                                            creator['nickname'] ?? "Žaidėjas",
                                        radius: 18,
                                        xp: creator['xp'] ?? 0,
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            creator['nickname'] ?? "Žaidėjas",
                                            style: const TextStyle(
                                              color: QortColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            "Autoriaus Lygis: ${notice['level']}",
                                            style: const TextStyle(
                                              color: QortColors.textSecondary,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (notice['creator_id'] ==
                                          widget.user.id)
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(
                                            LucideIcons.trash2,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _deleteNotice(notice['id']),
                                        ),
                                      if (notice['creator_id'] ==
                                          widget.user.id)
                                        const SizedBox(width: 15),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          notice['sport']
                                              .toString()
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),

                              // FORMATAS IR IEŠKOMAS LYGIS
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${notice['format']} FORMATAS",
                                    style: GoogleFonts.oswald(
                                      color: QortColors.textPrimary,
                                      fontSize: 18,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    "IEŠKO LYGIO: $minLvl - $maxLvl",
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // DATA IR LOKACIJA
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.calendar,
                                    size: 14,
                                    color: QortColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('MM-dd HH:mm').format(date),
                                    style: const TextStyle(
                                      color: QortColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  const Icon(
                                    LucideIcons.mapPin,
                                    size: 14,
                                    color: QortColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      notice['location'],
                                      style: const TextStyle(
                                        color: QortColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),

                              // BADŽAI IR KAINA
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _infoBadge(
                                    hasCourt
                                        ? "AIKŠTELĖ YRA"
                                        : "IEŠKOME AIKŠTELĖS",
                                    hasCourt ? Colors.green : Colors.blueGrey,
                                  ),
                                  if (isTeam)
                                    _infoBadge(
                                      "KOMANDINIS",
                                      Colors.purpleAccent,
                                    ),
                                  if (hasCourt && split.isNotEmpty)
                                    _infoBadge(
                                      price.isNotEmpty
                                          ? "$price€ ($split)"
                                          : split,
                                      Colors.amber,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // MYGTUKAI
                              Row(
                                children: [
                                  // POKALBIS MYGTUKAS
                                  Expanded(
                                    flex: 1,
                                    child: OutlinedButton(
                                      onPressed: () => _openChatWithCreator(
                                        creator['nickname'] ?? "Žaidėjas",
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: QortColors.navInactive,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Icon(
                                        LucideIcons.messageCircle,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // PRISIJUNGTI MYGTUKAS
                                  Expanded(
                                    flex: 3,
                                    child: ElevatedButton(
                                      onPressed: () => _joinMatch(notice),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        "PRISIJUNGTI",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
          ),
        ),
      ),
        ],
      ),
    );
  }

  Widget _infoBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
