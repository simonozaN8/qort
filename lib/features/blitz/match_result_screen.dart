import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MatchResultScreen extends StatefulWidget {
  final int earnedXP;
  final bool isWin;
  const MatchResultScreen({super.key, required this.earnedXP, required this.isWin});

  @override
  State<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends State<MatchResultScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _xpAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _xpAnimation = Tween<double>(begin: 0, end: widget.earnedXP.toDouble()).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = QortColors.background;
    final resultColor = widget.isWin ? const Color(0xFFD946EF) : Colors.grey;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Fonas (Konfeti efektas ateityje)
          Center(
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: resultColor.withOpacity(0.3), blurRadius: 100)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Rezultato ikona
                Icon(widget.isWin ? LucideIcons.trophy : LucideIcons.thumbsUp, color: resultColor, size: 80),
                const SizedBox(height: 20),
                
                Text(
                  widget.isWin ? "QORT VICTORY" : "GOOD GAME",
                  style: GoogleFonts.bebasNeue(
                    color: QortColors.textPrimary,
                    fontSize: 48,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.isWin
                      ? "Tu dominavai aikštelėje!"
                      : "Svarbiausia - tobulėjimas.",
                  style: const TextStyle(color: QortColors.textSecondary),
                ),
                
                const SizedBox(height: 50),
                
                // XP Skaitiklis
                AnimatedBuilder(
                  animation: _xpAnimation,
                  builder: (context, child) {
                    return Column(
                      children: [
                        Text("+${_xpAnimation.value.toInt()} XP", style: GoogleFonts.bebasNeue(color: resultColor, fontSize: 60)),
                        Text(
                          "GAUTA TAŠKŲ",
                          style: GoogleFonts.oswald(
                            color: QortColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // MVP Balsavimas (Statistinis)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: QortColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: QortColors.border),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: QortColors.primaryLight,
                        child: Text(
                          "J",
                          style: TextStyle(color: QortColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Jonas (Host)",
                            style: GoogleFonts.oswald(
                              color: QortColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            "MVP • Daugiausiai taškų",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(LucideIcons.star, color: Colors.orange),
                    ],
                  ),
                ),

                const Spacer(),

                // Mygtukas
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: SizedBox(
                    width: double.infinity, height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                         // Čia grįžtame į pagrindinį ekraną
                         Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      child: Text("TĘSTI", style: GoogleFonts.bebasNeue(color: Colors.black, fontSize: 24)),
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
}