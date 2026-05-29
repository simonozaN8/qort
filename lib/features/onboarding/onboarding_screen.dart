import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/sports_catalog_service.dart';
import '../../core/utils/sport_icons.dart';
import '../../main_wrapper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _isSaving = false;
  bool _isLoadingCatalog = true;

  // Sporto šakų katalogas iš Supabase
  List<Map<String, dynamic>> _sportsCatalog = [];

  // Vartotojo pasirinkimai
  final List<String> _selectedSports = [];
  // sport_name -> level_value (skaičius)
  final Map<String, int> _selectedLevels = {};
  String _nickname = "";

  @override
  void initState() {
    super.initState();
    _loadSportsCatalog();
  }

  // 1. Užkrauname sporto šakas iš Supabase
  Future<void> _loadSportsCatalog() async {
    try {
      final entries = await SportsCatalogService.fetchActive(force: true);

      if (mounted) {
        setState(() {
          _sportsCatalog = entries.map((e) => e.toJsonMap()).toList();
          _isLoadingCatalog = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant sportus: $e");
      if (mounted) {
        setState(() => _isLoadingCatalog = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Nepavyko užkrauti sporto šakų: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- PAGRINDINĖ LOGIKA ---
  Future<void> _nextStep() async {
    // Validacija prieš einant į kitą žingsnį
    if (_step == 0) {
      if (_selectedSports.isEmpty) {
        _showError("Pasirink bent vieną sporto šaką");
        return;
      }
      setState(() => _step++);
      return;
    }

    if (_step == 1) {
      // Patikriname, ar visiems pasirinktiems sportams parinkti lygiai
      for (var sport in _selectedSports) {
        if (!_selectedLevels.containsKey(sport)) {
          _showError("Pasirink lygį visoms sporto šakoms");
          return;
        }
      }
      setState(() => _step++);
      return;
    }

    // PASKUTINIS ŽINGSNIS (2): išsaugome į Supabase
    if (_nickname.trim().isEmpty) {
      _showError("Įvesk slapyvardį");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw Exception("Vartotojas neprisijungęs");
      }

      final userId = session.user.id;
      final supabase = Supabase.instance.client;

      // 1. Atnaujiname profilį
      await supabase
          .from('profiles')
          .update({'nickname': _nickname.trim(), 'onboarding_complete': true})
          .eq('id', userId);

      // 2. Įrašome kiekvieną sporto šaką + lygį į user_sports
      for (var sport in _selectedSports) {
        final level = _selectedLevels[sport]!;
        final sportData = _sportsCatalog.firstWhere(
          (s) => s['name'] == sport,
          orElse: () => {},
        );

        // Surandam aprašymą iš katalogo
        String description = "";
        if (sportData.isNotEmpty && sportData['levels_config'] != null) {
          final levels = sportData['levels_config'] as List;
          final levelData = levels.firstWhere(
            (l) => l['level_value'] == level,
            orElse: () => null,
          );
          if (levelData != null) {
            description = levelData['desc'] ?? '';
          }
        }

        await supabase.from('user_sports').insert({
          'user_id': userId,
          'sport': sport,
          'level': level,
          'rating_category': 'open',
          'description': description,
          'official_rp': 1200,
          'global_score': 1200,
          'matches_won': 0,
          'matches_lost': 0,
          'rp_history': [],
        });
      }

      // 3. SharedPreferences kaip atsarginė kopija
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      await prefs.setString('user_nickname', _nickname.trim());

      if (!mounted) return;

      // 4. Į pagrindinę programą
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainWrapper()),
      );
    } catch (e) {
      debugPrint("Klaida išsaugant onboarding: $e");
      if (mounted) {
        _showError("Nepavyko išsaugoti: $e");
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _previousStep() {
    if (_step > 0) {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = QortColors.background;
    const accentColor = Color(0xFF3B82F6);

    if (_isLoadingCatalog) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // VIRŠUTINĖ JUOSTA: progresas + atgal mygtukas
              Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      onPressed: _isSaving ? null : _previousStep,
                      icon: const Icon(
                        LucideIcons.arrowLeft,
                        color: Colors.white,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Row(
                      children: List.generate(3, (i) {
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: i <= _step ? accentColor : QortColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 30),

              // TURINYS PAGAL ŽINGSNĮ
              Expanded(
                child: SingleChildScrollView(
                  child: _buildStepContent(accentColor),
                ),
              ),

              // MYGTUKAS
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _step < 2 ? "TOLIAU" : "PRADĖTI",
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

  Widget _buildStepContent(Color accentColor) {
    if (_step == 0) {
      return _buildSportsStep(accentColor);
    } else if (_step == 1) {
      return _buildLevelsStep(accentColor);
    } else {
      return _buildNicknameStep(accentColor);
    }
  }

  // --- ŽINGSNIS 0: Sporto šakų pasirinkimas ---
  Widget _buildSportsStep(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Kokias sporto šakas\nžaidi?",
          style: GoogleFonts.bebasNeue(
            fontSize: 36,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Pasirink visas, kuriomis domiesi",
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _sportsCatalog.map((sport) {
            final name = sport['name'] as String;
            final isSelected = _selectedSports.contains(name);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedSports.remove(name);
                    _selectedLevels.remove(name);
                  } else {
                    _selectedSports.add(name);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor : QortColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? accentColor : QortColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SportIcons.icon(
                      name,
                      size: 18,
                      color: isSelected ? Colors.white : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- ŽINGSNIS 1: Lygių pasirinkimas kiekvienai sporto šakai ---
  Widget _buildLevelsStep(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Koks tavo lygis?",
          style: GoogleFonts.bebasNeue(fontSize: 36, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          "Kiekvienai sporto šakai parink lygį atskirai",
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Kiekvienai pasirinktai sporto šakai - savo lygių sąrašas
        ..._selectedSports.map((sportName) {
          final sportData = _sportsCatalog.firstWhere(
            (s) => s['name'] == sportName,
            orElse: () => {},
          );

          if (sportData.isEmpty || sportData['levels_config'] == null) {
            return const SizedBox.shrink();
          }

          final levels = sportData['levels_config'] as List;

          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sporto pavadinimas
                Row(
                  children: [
                    SportIcons.icon(sportName, size: 20, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      sportName.toUpperCase(),
                      style: GoogleFonts.bebasNeue(
                        fontSize: 22,
                        color: accentColor,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Lygių sąrašas šiam sportui
                ...levels.map((level) {
                  final levelValue = level['level_value'] as int;
                  final levelName = level['name'] as String;
                  final levelDesc = level['desc'] as String? ?? '';
                  final isSelected = _selectedLevels[sportName] == levelValue;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedLevels[sportName] = levelValue;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor
                            : QortColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? accentColor : QortColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : QortColors.border,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              levelValue.toString(),
                              style: TextStyle(
                                color: isSelected ? accentColor : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  levelName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (levelDesc.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    levelDesc,
                                    style: TextStyle(
                                      color: isSelected
                                          ? QortColors.textSecondary
                                          : Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  // --- ŽINGSNIS 2: Slapyvardis ---
  Widget _buildNicknameStep(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Koks tavo slapyvardis?",
          style: GoogleFonts.bebasNeue(fontSize: 36, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          "Pagal jį tave matys kiti žaidėjai",
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 24),
        TextField(
          onChanged: (value) => _nickname = value,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: "Pvz. JonasPro",
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: QortColors.surface,
            contentPadding: const EdgeInsets.all(20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
