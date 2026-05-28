import 'package:flutter/material.dart';
import '../../../../../../../../../core/theme/qort_colors.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/user_profile_loader.dart';
import '../profile/user_model.dart';
import '../profile/status_avatar.dart';

class SparringRadarScreen extends StatefulWidget {
  const SparringRadarScreen({super.key});

  @override
  State<SparringRadarScreen> createState() => _SparringRadarScreenState();
}

class _SparringRadarScreenState extends State<SparringRadarScreen> {
  List<UserProfile> _partners = [];
  bool _isLoading = true;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchPartners();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchPartners() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    try {
      final partners = await UserProfileLoader.loadDiscoverProfiles(
        excludeUserId: currentUserId ?? '',
        limit: 15,
      );

      if (mounted) {
        setState(() {
          _partners = partners;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant radarą: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextProfile(bool liked, String name) {
    if (liked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚡ Kvietimas išsiųstas žaidėjui $name!"),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: QortColors.background,
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    if (_partners.isEmpty) {
      return Scaffold(
        backgroundColor: QortColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.radar, color: Colors.white24, size: 80),
              const SizedBox(height: 20),
              Text(
                "TAVO LYGYJE VARŽOVŲ NĖRA",
                style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24),
              ),
              const Text(
                "Išplėskite paieškos spindulį nustatymuose.",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: QortColors.background,
      // Jei šis langas atidaromas atskirai, pridedame grįžimo mygtuką
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics:
            const NeverScrollableScrollPhysics(), // Išjungiame paprastą slinkimą, naudosime mygtukus
        itemCount: _partners.length,
        itemBuilder: (context, index) {
          final user = _partners[index];

          final sportLevel = user.sportsList.isNotEmpty
              ? user.sportsList.first.level.toString()
              : "1";

          final sportName = user.sportsList.isNotEmpty
              ? user.sportsList.first.name
              : "Sportas";

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. FONO NUOTRAUKA ARBA TAMSUS GRADIENTAS
              Container(
                decoration: BoxDecoration(
                  color: QortColors.surface,
                  image: user.photoUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(user.photoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Container(
                  // Tamsus gradientas apačioje, kad tekstas būtų įskaitomas
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.6),
                        QortColors.background.withOpacity(0.95),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // 2. ŽAIDĖJO INFORMACIJA
              Positioned(
                left: 20,
                bottom: 150, // Pakelta aukščiau, kad tilptų mygtukai
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.orange),
                                ),
                                child: Text(
                                  "${sportName.toUpperCase()} • LYGIS $sportLevel",
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                user.displayName,
                                style: GoogleFonts.bebasNeue(
                                  color: Colors.white,
                                  fontSize: 48,
                                  letterSpacing: 1.5,
                                  height: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.mapPin,
                                    color: Colors.white54,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    user.city.isNotEmpty
                                        ? user.city
                                        : "Lokacija nenurodyta",
                                    style: GoogleFonts.oswald(
                                      color: Colors.white70,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        StatusAvatar(
                          imageUrl: user.photoUrl,
                          displayName: user.displayName,
                          radius: 35,
                          xp: user.xp,
                          winStreak: user.winStreak,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (user.sportsList.isNotEmpty &&
                        user.sportsList.first.sportBio.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              LucideIcons.quote,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                user.sportsList.first.sportBio,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // 3. VEIKSMŲ MYGTUKAI (TINDER STILIUS)
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // PRALEISTI
                    GestureDetector(
                      onTap: () => _nextProfile(false, user.displayName),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: QortColors.surface,
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.2),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.x,
                          color: Colors.redAccent,
                          size: 30,
                        ),
                      ),
                    ),

                    // KVIESTI
                    GestureDetector(
                      onTap: () => _nextProfile(true, user.displayName),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.zap,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
