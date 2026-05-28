import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../../../../../core/theme/qort_colors.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'team_reveal_screen.dart'; // Būtina navigacijai į žaidimą

class LobbyScreen extends StatefulWidget {
  final bool isHost; // Ar aš kuriu (Host), ar jungiuosi (Guest)?
  const LobbyScreen({super.key, required this.isHost});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with SingleTickerProviderStateMixin {
  // Simuliuojame žaidėjų prisijungimą (Host režime)
  final List<String> _joinedPlayers = ["Aš (Host)"];
  Timer? _demoTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Animacija QR kodo pulsavimui
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

    if (widget.isHost) {
      // Simuliacija: Kas 3 sekundes prisijungia naujas žaidėjas
      _demoTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        // Leidžiame prisijungti iki 12 žaidėjų simuliacijai
        if (_joinedPlayers.length < 12) {
          setState(() {
            _joinedPlayers.add("Svečias ${timer.tick}");
          });
        } else {
          timer.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // --- LOGIKA: LIMITŲ TIKRINIMAS IR STARTAS ---
  void _checkLimitsAndStart() {
    int playerCount = _joinedPlayers.length;
    int freeLimit = 4; // Nemokamas limitas
    bool isPremium = false; // Čia ateityje tikrinsime vartotojo prenumeratą

    if (playerCount > freeLimit && !isPremium) {
      _showPaywallDialog(playerCount);
    } else {
      // Viskas gerai -> Eikime į Reveal
      Navigator.push(context, MaterialPageRoute(builder: (context) => TeamRevealScreen(players: _joinedPlayers)));
    }
  }

  void _showPaywallDialog(int count) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: QortColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.orange, width: 2)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.crown, color: Colors.orange, size: 50),
              const SizedBox(height: 10),
              Text(
                "VIRŠYTAS LIMITAS ($count)",
                style: GoogleFonts.bebasNeue(
                  color: QortColors.textPrimary,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Nemokama versija leidžia tik iki 4 žaidėjų/komandų. Norėdami organizuoti didesnius Blitz turnyrus, pasirinkite planą:",
                textAlign: TextAlign.center,
                style: TextStyle(color: QortColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _payOption("STANDARD", "€10 / mėn", "Iki 8 žaidėjų"),
              const SizedBox(height: 10),
              _payOption("UNLIMITED", "€20 / mėn", "Neribotas skaičius", isBest: true),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Vėliau", style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = QortColors.background;
    const blitzColor = Color(0xFFD946EF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.x,
            color: widget.isHost ? QortColors.textPrimary : Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isHost ? "LOBBY #8821" : "SKANUOTI KODĄ",
          style: GoogleFonts.bebasNeue(
            letterSpacing: 2,
            fontSize: 24,
            color: widget.isHost ? QortColors.textPrimary : Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: widget.isHost ? _buildHostView(blitzColor) : _buildGuestView(blitzColor),
    );
  }

  // --- 1. ORGANIZATORIAUS VAIZDAS (HOST) ---
  Widget _buildHostView(Color accentColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Text(
          "NUSKANUOKITE, KAD PRISIJUNGTI",
          style: GoogleFonts.oswald(
            color: QortColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 30),
        
        // Pulsuojantis QR Kodas (Simuliacija)
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 280, height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withOpacity(0.1 + (_pulseController.value * 0.2)), // Pulse efektas
                      boxShadow: [BoxShadow(color: accentColor.withOpacity(0.5), blurRadius: 40 * _pulseController.value)],
                    ),
                  );
                },
              ),
              Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Icon(LucideIcons.qrCode, size: 150, color: Colors.black), // Čia bus tikras QR
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Žaidėjų Baseinas
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: QortColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: accentColor.withOpacity(0.3))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "PRISIJUNGĘ ŽAIDĖJAI (${_joinedPlayers.length})",
                    style: GoogleFonts.oswald(
                      color: QortColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_joinedPlayers.length > 1)
                    Text("PASIRUOŠĘ", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 20),
              
              // Avatarų tinklelis
              if (_joinedPlayers.isEmpty)
                const Center(child: Text("Laukiama žaidėjų...", style: TextStyle(color: Colors.grey)))
              else
                Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  children: _joinedPlayers.map((player) {
                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: QortColors.primaryLight,
                          child: Text(
                            player[0],
                            style: const TextStyle(
                              color: QortColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          player,
                          style: GoogleFonts.oswald(
                            color: QortColors.textSecondary,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              
              const SizedBox(height: 30),
              
              // GENERATE MYGTUKAS SU LOGIKA
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _joinedPlayers.length > 1 ? () => _checkLimitsAndStart() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    disabledBackgroundColor: Colors.grey[800],
                  ),
                  child: Text("GENERUOTI KOMANDAS", style: GoogleFonts.bebasNeue(fontSize: 24, color: _joinedPlayers.length > 1 ? Colors.white : Colors.grey)),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  // --- 2. DALYVIO VAIZDAS (GUEST/CAMERA) ---
  Widget _buildGuestView(Color accentColor) {
    return Stack(
      children: [
        // Kameros Placeholder (Čia būtų realus vaizdas)
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black,
                accentColor.withValues(alpha: 0.25),
                Colors.black87,
              ],
            ),
          ),
        ),
        
        // Skenerio rėmelis
        Center(
          child: Container(
            width: 250, height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: accentColor, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Kampai
                Positioned(top: 0, left: 0, child: _corner(accentColor)),
                Positioned(top: 0, right: 0, child: RotatedBox(quarterTurns: 1, child: _corner(accentColor))),
                Positioned(bottom: 0, right: 0, child: RotatedBox(quarterTurns: 2, child: _corner(accentColor))),
                Positioned(bottom: 0, left: 0, child: RotatedBox(quarterTurns: 3, child: _corner(accentColor))),
                
                // Skenavimo linija (Animuota)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Align(
                      alignment: Alignment(0, -1 + (2 * _pulseController.value)),
                      child: Container(height: 2, color: accentColor, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 20)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Apatinė dalis (Rankinis įvedimas)
        Positioned(
          bottom: 50, left: 20, right: 20,
          child: Column(
            children: [
              Text("Nukreipkite kamerą į QR kodą", style: GoogleFonts.oswald(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text("ARBA", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ),
                  const Expanded(child: Divider(color: Colors.white24)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
                child: const TextField(
                  style: TextStyle(color: Colors.white, letterSpacing: 5, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "ĮVESTI ID (Pvz. 8821)",
                    hintStyle: TextStyle(color: Colors.grey, letterSpacing: 1, fontWeight: FontWeight.normal),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text("PRISIJUNGTI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  // Pagalbinis metodas skenerio kampams
  Widget _corner(Color color) {
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: color, width: 4),
          left: BorderSide(color: color, width: 4),
        ),
      ),
    );
  }

  // Mokėjimo variantų kortelė
  Widget _payOption(String title, String price, String sub, {bool isBest = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isBest ? Colors.orange : QortColors.background,
        borderRadius: BorderRadius.circular(12),
        border: isBest ? null : Border.all(color: QortColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.oswald(
                  color: isBest ? Colors.black : QortColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  color: isBest ? Colors.black87 : QortColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          Text(
            price,
            style: GoogleFonts.bebasNeue(
              color: isBest ? Colors.black : QortColors.textPrimary,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}