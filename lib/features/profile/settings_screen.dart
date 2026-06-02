import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/sport_catalog_entry.dart';
import '../../core/services/sports_catalog_service.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../design/gemini_visual_studio_screen.dart';
import '../admin/sport_image_pool_screen.dart';
import '../../core/widgets/qort_theme_picker.dart';
import '../../core/utils/sport_levels.dart';
import '../../core/utils/sport_icons.dart';
import 'user_model.dart';

class SettingsScreen extends StatefulWidget {
  final UserProfile user;

  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Map<String, SportDetails> _tempSports;
  String? _sportToAdd;
  bool _isLoading = false;

  // NAUJI KINTAMIEJI KATALOGUI IŠ SUPABASE
  bool _isLoadingCatalog = true;
  List<Map<String, dynamic>> _catalog = [];

  @override
  void initState() {
    super.initState();
    _tempSports = {for (var sport in widget.user.sportsList) sport.name: sport};
    _fetchCatalog(); // Parsiunčiame sporto šakas iš Supabase
  }

  // --- TRAUKIAME SPORTO ŠAKAS IŠ DUOMENŲ BAZĖS ---
  Future<void> _fetchCatalog() async {
    try {
      final maps = await SportsCatalogService.fetchActiveMaps(force: true);

      if (mounted) {
        setState(() {
          _catalog = maps;
          _syncLevelDescriptionsFromCatalog();
          _isLoadingCatalog = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant katalogą: $e");
      if (mounted) setState(() => _isLoadingCatalog = false);
    }
  }

  Future<void> _saveToSupabase() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final supabase = Supabase.instance.client;

      final existingRows = await supabase
          .from('user_sports')
          .select('id, sport')
          .eq('user_id', userId);

      for (final row in existingRows as List) {
        final sportName = row['sport'] as String;
        if (!_tempSports.containsKey(sportName)) {
          await supabase.from('user_sports').delete().eq('id', row['id']);
        }
      }

      for (final sport in _tempSports.values) {
        final entry = _catalogEntryFor(sport.name);
        final description = sport.description.isNotEmpty
            ? sport.description
            : SportLevels.descFor(entry, sport.level);

        final existing = await supabase
            .from('user_sports')
            .select('id')
            .eq('user_id', userId)
            .eq('sport', sport.name)
            .maybeSingle();

        final payload = {
          'level': sport.level,
          'description': description,
          'sport_bio': sport.sportBio,
          'official_rp': sport.rp,
          'global_score': sport.rp,
        };

        if (existing != null) {
          await supabase
              .from('user_sports')
              .update(payload)
              .eq('id', existing['id']);
        } else {
          await supabase.from('user_sports').insert({
            'user_id': userId,
            'sport': sport.name,
            ...payload,
            'rating_category': 'open',
            'matches_won': 0,
            'matches_lost': 0,
            'rp_history': sport.rpHistory.isEmpty ? [] : sport.rpHistory,
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pakeitimai išsaugoti!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Klaida išsaugant: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI LOGIKA ---

  void _addSportByName(String name) {
    if (_tempSports.containsKey(name)) return;
    final entry = _catalogEntryFor(name);
    setState(() {
      _tempSports[name] = SportDetails(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        level: 1,
        description: SportLevels.descFor(entry, 1),
        sportBio: "",
        rp: 1000,
      );
      _sportToAdd = null;
    });
  }

  void _addSport() {
    if (_sportToAdd != null) _addSportByName(_sportToAdd!);
  }

  void _removeSport(String sport) {
    setState(() {
      _tempSports.remove(sport);
    });
  }

  void _syncLevelDescriptionsFromCatalog() {
    for (final name in _tempSports.keys.toList()) {
      final old = _tempSports[name]!;
      final entry = _catalogEntryFor(name);
      final desc = SportLevels.descFor(entry, old.level);
      if (desc.isEmpty) continue;
      _tempSports[name] = SportDetails(
        id: old.id,
        name: old.name,
        level: old.level,
        description: desc,
        sportBio: old.sportBio,
        rp: old.rp,
        rpHistory: old.rpHistory,
      );
    }
  }

  SportCatalogEntry? _catalogEntryFor(String sportName) {
    try {
      final map = _catalog.firstWhere((c) => c['name'] == sportName);
      return SportLevels.entryFromMap(map);
    } catch (_) {
      return null;
    }
  }

  void _updateSportLevel(String sport, double newLevel) {
    if (!_tempSports.containsKey(sport)) return;
    final old = _tempSports[sport]!;
    final entry = _catalogEntryFor(sport);
    final lv = newLevel.round();
    final desc = SportLevels.descFor(entry, lv);

    setState(() {
      _tempSports[sport] = SportDetails(
        id: old.id,
        name: old.name,
        level: lv,
        description: desc.isNotEmpty ? desc : old.description,
        sportBio: old.sportBio,
        rp: old.rp,
        rpHistory: old.rpHistory,
      );
    });
  }

  void _updateSportBio(String sport, String newBio) {
    if (!_tempSports.containsKey(sport)) return;
    final old = _tempSports[sport]!;

    setState(() {
      _tempSports[sport] = SportDetails(
        id: old.id,
        name: old.name,
        level: old.level,
        description: old.description,
        sportBio: newBio,
        rp: old.rp,
        rpHistory: old.rpHistory,
      );
    });
  }

  IconData _getIconForSport(String? iconName, [String? sportName]) =>
      SportIcons.forSport(sportName ?? '', iconName: iconName);

  // --- IŠMANUSIS SELEKTORIUS ---
  void _showSportSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final options = _catalog
            .where((c) => !_tempSports.containsKey(c['name']))
            .toList()
          ..sort((a, b) {
            final fa = a['family']?.toString() ?? 'Kita';
            final fb = b['family']?.toString() ?? 'Kita';
            final fc = fa.compareTo(fb);
            if (fc != 0) return fc;
            return (a['name'] as String).compareTo(b['name'] as String);
          });

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: QortColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: QortColors.border, width: 1)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: QortColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "PASIRINKITE SPORTĄ",
                style: GoogleFonts.bebasNeue(
                  color: QortColors.textPrimary,
                  fontSize: 24,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: _isLoadingCatalog
                    ? const Center(child: CircularProgressIndicator())
                    : options.isEmpty
                    ? const Center(
                        child: Text(
                          "Visos sporto šakos jau pridėtos!",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final sportItem = options[index];
                          return InkWell(
                            onTap: () {
                              final name = sportItem['name'] as String;
                              _addSportByName(name);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: QortColors.border),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _getIconForSport(
                                      sportItem['icon_name']?.toString(),
                                      sportItem['name']?.toString(),
                                    ),
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sportItem['name'],
                                          style: const TextStyle(
                                            color: QortColors.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (sportItem['family'] != null)
                                          Text(
                                            sportItem['family'].toString(),
                                            style: const TextStyle(
                                              color: QortColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    color: QortColors.navInactive,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text(
          "REDAGUOTI SPORTO ŠAKAS",
          style: GoogleFonts.bebasNeue(
            letterSpacing: 1,
            color: p.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: p.textPrimary),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _saveToSupabase,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.primary,
                    ),
                  )
                : Icon(LucideIcons.save, color: p.primary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const QortThemePicker(),
            const SizedBox(height: 20),
            Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SportImagePoolScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.image, color: p.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI sporto vaizdų pool',
                              style: TextStyle(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Gemini 2.5 Flash Image — šablonai turnyrų viršelėms',
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, color: p.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GeminiVisualStudioScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.sparkles, color: p.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI vizualų studija',
                              style: TextStyle(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Gemini Flash 2.5 — generuok ekranus ir hero vaizdus',
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, color: p.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: QortColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PRIDĖTI NAUJĄ SPORTĄ",
                    style: GoogleFonts.oswald(
                      color: QortColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _showSportSelector,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: QortColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: QortColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _sportToAdd ?? "Pasirinkti...",
                                  style: TextStyle(
                                    color: _sportToAdd == null
                                        ? Colors.grey
                                        : QortColors.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                Icon(
                                  LucideIcons.chevronDown,
                                  color: Colors.grey[600],
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      InkWell(
                        onTap: _addSport,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _sportToAdd != null
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _sportToAdd != null
                                  ? Colors.blue
                                  : Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            LucideIcons.plus,
                            color: _sportToAdd != null
                                ? Colors.blue
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),
            Text(
              "MANO SPORTO SĄRAŠAS",
              style: GoogleFonts.oswald(
                color: QortColors.textPrimary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),

            if (_tempSports.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "Sąrašas tuščias",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._tempSports.entries.map((entry) {
                final sport = entry.value;
                final catalogEntry = _catalogEntryFor(sport.name);
                final levelMin = SportLevels.minValue(catalogEntry);
                final levelMax = SportLevels.maxValue(catalogEntry);
                double sliderValue = sport.level.toDouble().clamp(
                  levelMin,
                  levelMax,
                );
                final levelName = SportLevels.nameFor(catalogEntry, sport.level);
                final levelDesc = SportLevels.descFor(catalogEntry, sport.level);

                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: QortColors.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: QortColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            sport.name,
                            style: GoogleFonts.bebasNeue(
                              fontSize: 22,
                              color: QortColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeSport(sport.name),
                            icon: const Icon(
                              LucideIcons.trash2,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: QortColors.border),

                      // RODO TIKRĄJĮ LYGIO PAVADINIMĄ
                      Text(
                        levelName,
                        style: GoogleFonts.bebasNeue(
                          color: p.primary,
                          fontSize: 20,
                          letterSpacing: 1,
                        ),
                      ),
                      if (levelDesc.isNotEmpty)
                        Text(
                          levelDesc,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            SportLevels.nameFor(catalogEntry, levelMin.round()),
                            style: const TextStyle(
                              color: QortColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            SportLevels.nameFor(catalogEntry, levelMax.round()),
                            style: const TextStyle(
                              color: QortColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: sliderValue,
                        min: levelMin,
                        max: levelMax,
                        divisions: (levelMax - levelMin).round().clamp(1, 20),
                        label: levelName,
                        activeColor: p.primary,
                        inactiveColor: p.border,
                        onChanged: (val) => _updateSportLevel(sport.name, val),
                      ),

                      TextField(
                        key: ValueKey('bio_${sport.name}_${sport.sportBio}'),
                        controller: TextEditingController(text: sport.sportBio),
                        onSubmitted: (val) => _updateSportBio(sport.name, val),
                        style: const TextStyle(
                          color: QortColors.textPrimary,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              "Asmeninė pastaba (neprivaloma, pvz. žaidžiu savaitgaliais)",
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.black54,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 30),

            // ATSIJUNGIMO MYGTUKAS
            const Divider(color: QortColors.border),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: QortColors.surface,
                    title: const Text(
                      "Atsijungti?",
                      style: TextStyle(color: QortColors.textPrimary),
                    ),
                    content: const Text(
                      "Reikės iš naujo prisijungti, kad galėtum naudotis programėle.",
                      style: TextStyle(color: QortColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Atšaukti"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          "Atsijungti",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;

                try {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) {
                    // Grįžtam į pagrindinį ekraną - AuthGate automatiškai
                    // nukreips į Login
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                } catch (e) {
                  debugPrint("Klaida atsijungiant: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Klaida atsijungiant"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.logOut, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      "ATSIJUNGTI",
                      style: GoogleFonts.bebasNeue(
                        color: Colors.red,
                        letterSpacing: 1.5,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
