import 'package:flutter/material.dart';

class SmartSplitScreen extends StatefulWidget {
  const SmartSplitScreen({super.key});

  @override
  State<SmartSplitScreen> createState() => _SmartSplitScreenState();
}

class _SmartSplitScreenState extends State<SmartSplitScreen> {
  // Duomenys
  final List<GamePlayer> _players = [];
  final TextEditingController _nameController = TextEditingController();
  int _selectedLevel = 3;
  
  // Rezultatai
  List<GamePlayer> _teamA = [];
  List<GamePlayer> _teamB = [];
  bool _isSplit = false;

  // --- LOGIKA ---

  void _addPlayer() {
    if (_nameController.text.trim().isEmpty) return;
    
    setState(() {
      _players.add(GamePlayer(
        name: _nameController.text.trim(),
        level: _selectedLevel,
      ));
      _nameController.clear();
      _isSplit = false; // Jei pridedam naują, panaikinam seną padalijimą
    });
  }

  void _removePlayer(int index) {
    setState(() {
      _players.removeAt(index);
      _isSplit = false;
    });
  }

  void _calculateTeams() {
    if (_players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reikia bent 2 žaidėjų!")),
      );
      return;
    }

    // 1. Rūšiuojame pagal pajėgumą (nuo stipriausio)
    List<GamePlayer> sorted = List.from(_players);
    sorted.sort((a, b) => b.level.compareTo(a.level));

    List<GamePlayer> team1 = [];
    List<GamePlayer> team2 = [];
    int score1 = 0;
    int score2 = 0;

    // 2. Algoritmas "Gyvatėlė" (balansuoja svorius)
    for (var p in sorted) {
      if (score1 <= score2) {
        team1.add(p);
        score1 += p.level;
      } else {
        team2.add(p);
        score2 += p.level;
      }
    }

    setState(() {
      _teamA = team1;
      _teamB = team2;
      _isSplit = true;
    });
  }

  // --- DIZAINAS ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Komandų Generavimas"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Išvalyti viską",
            onPressed: () {
              setState(() {
                _players.clear();
                _isSplit = false;
              });
            },
          )
        ],
      ),
      body: Column(
        children: [
          // 1. ĮVEDIMO ZONA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: "Žaidėjo vardas",
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Lygio pasirinkimas (Dropdown)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedLevel,
                      items: [1, 2, 3, 4, 5].map((l) => DropdownMenuItem(
                        value: l, 
                        child: Text("Lvl $l", style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedLevel = val!),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.small(
                  onPressed: _addPlayer,
                  backgroundColor: theme.primaryColor,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),

          // 2. SĄRAŠAS ARBA REZULTATAI
          Expanded(
            child: _isSplit 
              ? _buildResultsView(theme) 
              : _buildPlayerListView(theme, cardColor),
          ),

          // 3. PAGRINDINIS MYGTUKAS
          if (!_isSplit && _players.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _calculateTeams,
                  icon: const Icon(Icons.sports_esports),
                  label: const Text("SUSKIRSTYTI KOMANDAS"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerListView(ThemeData theme, Color cardColor) {
    if (_players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add, size: 80, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 10),
            Text("Pridėkite žaidėjus sąraše viršuje", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _players.length,
      itemBuilder: (ctx, i) {
        final p = _players[i];
        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              child: Text("${p.level}", style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor)),
            ),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => _removePlayer(i),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsView(ThemeData theme) {
    int totalA = _teamA.fold(0, (sum, p) => sum + p.level);
    int totalB = _teamB.fold(0, (sum, p) => sum + p.level);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTeamCard("KOMANDA A", _teamA, totalA, Colors.blue, theme)),
              const SizedBox(width: 10),
              Expanded(child: _buildTeamCard("KOMANDA B", _teamB, totalB, Colors.red, theme)),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => setState(() => _isSplit = false),
            child: const Text("Koreguoti sąrašą"),
          )
        ],
      ),
    );
  }

  Widget _buildTeamCard(String title, List<GamePlayer> team, int totalScore, Color color, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: color.withOpacity(0.8),
            child: Text(title, 
              textAlign: TextAlign.center, 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Jėga: $totalScore", style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ),
          ...team.map((p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              children: [
                Icon(Icons.person, size: 16, color: theme.iconTheme.color),
                const SizedBox(width: 5),
                Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
                Text("L${p.level}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          )),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// Pagalbinė klasė duomenims saugoti (šiam failui)
class GamePlayer {
  final String name;
  final int level;
  GamePlayer({required this.name, required this.level});
}