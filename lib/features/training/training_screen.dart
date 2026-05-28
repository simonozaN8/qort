import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/user_profile_loader.dart';
import '../../core/theme/qort_colors.dart';
import '../profile/user_model.dart';
import '../profile/status_avatar.dart';
import 'open_matches_screen.dart'; // PASTATYTAS NAUJAS IMPORTAS

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  UserProfile? _user;
  bool _isLoading = true;
  String _selectedSportName = "";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final profile = await UserProfileLoader.loadById(session.user.id);

      if (mounted) {
        setState(() {
          _user = profile;
          if (_user != null && _user!.sportsList.isNotEmpty) {
            _selectedSportName = _user!.sportsList.first.name;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant treniruočių profilį: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getDrillsForSport(String sportName) {
    String s = sportName.toLowerCase();

    Map<String, dynamic> sparringDrill = {
      "title": "Atviri Mačai (Skelbimai)",
      "time": "60-90 MIN",
      "xp": 150,
      "icon": LucideIcons.clipboardList,
      "isOpenMatch": true,
    };

    if (s.contains('tenis')) {
      return [
        {
          "title": "Padavimų technika",
          "time": "45 MIN",
          "xp": 50,
          "icon": LucideIcons.target,
        },
        {
          "title": "Kojų darbas ir judėjimas",
          "time": "30 MIN",
          "xp": 40,
          "icon": LucideIcons.activity,
        },
        sparringDrill,
      ];
    } else if (s.contains('padel')) {
      return [
        {
          "title": "Sienos gynyba",
          "time": "45 MIN",
          "xp": 60,
          "icon": LucideIcons.shield,
        },
        sparringDrill,
      ];
    } else if (s.contains('krepšin')) {
      return [
        {
          "title": "Metimų serija",
          "time": "30 MIN",
          "xp": 50,
          "icon": LucideIcons.circleDot,
        },
        sparringDrill,
      ];
    } else if (s.contains('futbol')) {
      return [
        {
          "title": "Smūgiai į vartus",
          "time": "45 MIN",
          "xp": 60,
          "icon": LucideIcons.crosshair,
        },
        sparringDrill,
      ];
    }

    return [
      {
        "title": "Bazinė technika",
        "time": "45 MIN",
        "xp": 50,
        "icon": LucideIcons.activity,
      },
      sparringDrill,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: QortColors.background,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ),
      );
    }

    if (_user == null || _user!.sportsList.isEmpty) {
      return Scaffold(
        backgroundColor: QortColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.dumbbell, color: QortColors.navInactive, size: 80),
              const SizedBox(height: 20),
              Text(
                "NĖRA PASIRINKTŲ SPORTO ŠAKŲ",
                style: GoogleFonts.bebasNeue(
                  color: QortColors.textPrimary,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Eikite į Profilį ir pridėkite bent vieną\nsporto šaką, kad matytumėte treniruotes.",
                textAlign: TextAlign.center,
                style: TextStyle(color: QortColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final currentSport = _user!.sportsList.firstWhere(
      (s) => s.name == _selectedSportName,
      orElse: () => _user!.sportsList.first,
    );

    final drills = _getDrillsForSport(_selectedSportName);
    final int mockHours = (currentSport.matchesPlayed * 1.5).round() + 15;
    final int mockSessions = currentSport.matchesPlayed + 8;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 15),

                // HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "TRENIRUOTĖS",
                      style: GoogleFonts.bebasNeue(
                        color: QortColors.textPrimary,
                        fontSize: 32,
                        letterSpacing: 1,
                      ),
                    ),
                    StatusAvatar(
                      imageUrl: _user!.photoUrl,
                      displayName: _user!.displayName,
                      radius: 20,
                      xp: _user!.xp,
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // STATISTIKA
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1E3A8A),
                        Color(0xFF6B21A8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6B21A8).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$mockHours H",
                            style: GoogleFonts.bebasNeue(
                              color: Colors.white,
                              fontSize: 48,
                              height: 1.0,
                            ),
                          ),
                          const Text(
                            "VALANDŲ",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$mockSessions",
                            style: GoogleFonts.bebasNeue(
                              color: Colors.white,
                              fontSize: 48,
                              height: 1.0,
                            ),
                          ),
                          const Text(
                            "TRENIRUOČIŲ",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currentSport.name.toUpperCase(),
                            style: GoogleFonts.oswald(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "LYGIS ${currentSport.level}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // SPORTO ŠAKOS
                SizedBox(
                  height: 35,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _user!.sportsList.length,
                    itemBuilder: (context, index) {
                      final sport = _user!.sportsList[index];
                      final isSelected = _selectedSportName == sport.name;

                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedSportName = sport.name),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF3B82F6)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : QortColors.border,
                            ),
                          ),
                          child: Text(
                            sport.name.toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : QortColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 35),

                Text(
                  "KĄ TRENIRUOSIME ŠIANDIEN?",
                  style: GoogleFonts.bebasNeue(
                    color: QortColors.textPrimary,
                    fontSize: 22,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 15),

                ...drills.map((drill) => _buildDrillCard(drill)),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrillCard(Map<String, dynamic> drill) {
    bool isOpenMatch = drill['isOpenMatch'] ?? false;

    return GestureDetector(
      onTap: () {
        if (isOpenMatch && _user != null) {
          // ATIDARO SKELBIMŲ LENTĄ
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OpenMatchesScreen(user: _user!),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isOpenMatch
              ? LinearGradient(
                  colors: [Colors.orange.shade700, Colors.deepOrange.shade900],
                )
              : null,
          color: isOpenMatch ? null : QortColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOpenMatch ? Colors.transparent : QortColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isOpenMatch
                    ? Colors.white.withValues(alpha: 0.2)
                    : QortColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                drill['icon'] as IconData,
                color: isOpenMatch ? Colors.white : QortColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drill['title'],
                    style: TextStyle(
                      color: isOpenMatch ? Colors.white : QortColors.textPrimary,
                      fontSize: 15,
                      fontWeight: isOpenMatch
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    drill['time'],
                    style: TextStyle(
                      color: isOpenMatch
                          ? Colors.white70
                          : QortColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (!isOpenMatch)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD946EF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "+${drill['xp']} XP",
                  style: const TextStyle(
                    color: Color(0xFFD946EF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const Icon(LucideIcons.chevronRight, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
