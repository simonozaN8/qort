import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'match_result_screen.dart'; // BŪTINAS IMPORTAS, kad veiktų pabaiga

// Pagalbinė klasė AI simuliacijai
class PlayerAI {
  String name;
  int skillPoints; // 1000 - 3000 XP
  PlayerAI(this.name, this.skillPoints);
}

class TeamRevealScreen extends StatefulWidget {
  final List<String> players;
  const TeamRevealScreen({super.key, required this.players});

  @override
  State<TeamRevealScreen> createState() => _TeamRevealScreenState();
}

class _TeamRevealScreenState extends State<TeamRevealScreen> {
  // Būsenos: 'analyzing', 'revealed', 'playing'
  String _state = 'analyzing'; 
  List<String> _teamA = [];
  List<String> _teamB = [];
  bool _amITeamA = true; 

  int _scoreA = 0;
  int _scoreB = 0;
  Timer? _gameTimer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _startProcess();
  }

  void _startProcess() {
    // 1. Simuliuojame AI skaičiavimą (3 sek)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _distributeTeamsWithAI(); // Paskirstome komandas
        setState(() => _state = 'revealed');
      }
    });
  }

  // --- AI LOGIKA (SNAKE DRAFT) ---
  void _distributeTeamsWithAI() {
    // 1. Sukuriame "AI Duomenis" žaidėjams
    List<PlayerAI> aiPlayers = widget.players.map((name) {
      // Simuliacija: Hostas yra PRO (2500 XP), kiti atsitiktiniai (1000-2500)
      int skill = name.contains("Host") ? 2500 : Random().nextInt(1500) + 1000; 
      return PlayerAI(name, skill);
    }).toList();

    // 2. Rūšiuojame nuo stipriausio iki silpniausio
    aiPlayers.sort((a, b) => b.skillPoints.compareTo(a.skillPoints));

    // 3. "Snake Draft" algoritmas lygioms komandoms
    List<PlayerAI> teamAList = [];
    List<PlayerAI> teamBList = [];
    
    // Algoritmas: A, B, B, A, A, B...
    for (int i = 0; i < aiPlayers.length; i++) {
      if (i % 4 == 0 || i % 4 == 3) { 
        teamAList.add(aiPlayers[i]);
      } else { 
        teamBList.add(aiPlayers[i]);
      }
    }

    // 4. Išsaugome rezultatus rodymui (Pridedame XP, kad matytųsi AI darbas)
    _teamA = teamAList.map((p) => "${p.name} (${p.skillPoints})").toList();
    _teamB = teamBList.map((p) => "${p.name} (${p.skillPoints})").toList();
    
    // Nustatome, kurioje komandoje esu "Aš"
    _amITeamA = teamAList.any((p) => p.name.contains("Host"));
  }

  void _startGame() {
    setState(() => _state = 'playing');
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  void _finishGame() {
    _gameTimer?.cancel();
    
    // Čia yra RAKTINIS PAKEITIMAS: Nebe uždarome, o einame į Rezultatų ekraną
    // Simuliuojame pergalę (true) ir 150 XP
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(
        builder: (context) => const MatchResultScreen(earnedXP: 150, isWin: true)
      )
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = QortColors.brandNavy;
    
    if (_state == 'analyzing') return _buildAnalyzingView(bgColor);
    if (_state == 'revealed') return _buildRevealView();
    return _buildScoreboardView(bgColor);
  }

  // --- 1. AI ANALYZING ---
  Widget _buildAnalyzingView(Color bg) {
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFD946EF)),
            const SizedBox(height: 20),
            Text("AI BALANSUOJA KOMANDAS...", style: GoogleFonts.oswald(color: Colors.white, fontSize: 18, letterSpacing: 2)),
            const SizedBox(height: 10),
            Text(
              "Analizuojamas XP reitingas ir žaidimo istorija",
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. THE REVEAL ---
  Widget _buildRevealView() {
    final myColor = _amITeamA ? const Color(0xFF3B82F6) : const Color(0xFFEF4444);
    final myTeamName = _amITeamA ? "MĖLYNOJI KOMANDA" : "RAUDONOJI KOMANDA";
    final myTeammates = _amITeamA ? _teamA : _teamB;
    final opponents = _amITeamA ? _teamB : _teamA;

    return Scaffold(
      backgroundColor: myColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.shield, color: Colors.white, size: 60),
              const SizedBox(height: 20),
              Text("TU ŽAIDI UŽ", style: GoogleFonts.oswald(color: Colors.white70, fontSize: 16, letterSpacing: 2)),
              Text(myTeamName, textAlign: TextAlign.center, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 50, height: 1)),
              
              const SizedBox(height: 40),
              
              // Komandos kortelė
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.users, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text("TAVO KOMANDA (XP AVG: 1850)", style: GoogleFonts.oswald(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 10),
                    ...myTeammates.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(p, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    )),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              Text("PRIEŠININKAI: ${opponents.length} žaidėjai", style: TextStyle(color: Colors.white.withOpacity(0.7))),
              
              const Spacer(),
              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: const StadiumBorder()),
                  child: Text("PRADĖTI MAČĄ", style: GoogleFonts.bebasNeue(color: myColor, fontSize: 24)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- 3. SCOREBOARD ---
  Widget _buildScoreboardView(Color bg) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        automaticallyImplyLeading: false,
        title: Text("BLITZ MAČAS", style: GoogleFonts.oswald(color: Colors.grey, fontSize: 14)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(LucideIcons.x, color: Colors.white), onPressed: _finishGame)
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(_formatTime(_secondsElapsed), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 60, letterSpacing: 3)),
          Text("ŽAIDIMO LAIKAS", style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          
          const Spacer(),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _scoreControl("MĖLYNI", const Color(0xFF3B82F6), _scoreA, () => setState(() => _scoreA++)),
              Text("-", style: GoogleFonts.bebasNeue(color: Colors.white30, fontSize: 40)),
              _scoreControl("RAUDONI", const Color(0xFFEF4444), _scoreB, () => setState(() => _scoreB++)),
            ],
          ),
          
          const Spacer(),
          
          Padding(
            padding: const EdgeInsets.all(30),
            child: SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                onPressed: _finishGame,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD946EF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text("BAIGTI IR ĮRAŠYTI", style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _scoreControl(String team, Color color, int score, VoidCallback onAdd) {
    return Column(
      children: [
        Text(team, style: GoogleFonts.oswald(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text("$score", style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 90)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: color)),
            child: Icon(LucideIcons.plus, color: color, size: 30),
          ),
        )
      ],
    );
  }
}