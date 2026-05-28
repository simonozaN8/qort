import 'package:flutter/material.dart';
import '../../../../../../../../../core/theme/qort_colors.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AddMatchScreen extends StatefulWidget {
  final List<String> availableSports;
  final String initialMatchType;

  const AddMatchScreen({
    super.key, 
    required this.availableSports,
    this.initialMatchType = "Varžybos",
  });

  @override
  State<AddMatchScreen> createState() => _AddMatchScreenState();
}

class _AddMatchScreenState extends State<AddMatchScreen> {
  // Duomenys
  String _selectedSport = "Tenisas";
  String _matchType = "Varžybos"; // Varžybos arba Treniruotė
  
  // Kontroleriai rezultatams (JŪS vs VARŽOVAS)
  final TextEditingController _s1p1 = TextEditingController();
  final TextEditingController _s1p2 = TextEditingController();
  
  final TextEditingController _s2p1 = TextEditingController();
  final TextEditingController _s2p2 = TextEditingController();
  
  final TextEditingController _s3p1 = TextEditingController();
  final TextEditingController _s3p2 = TextEditingController();

  final TextEditingController _opponentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.availableSports.isNotEmpty) {
      _selectedSport = widget.availableSports.first;
    }
    _matchType = widget.initialMatchType;
  }

  // Funkcija rezultatui suformuoti ir grąžinti
  void _submitMatch() {
    // 1. Validacija (Paprasta)
    if (_opponentController.text.isEmpty) {
      _showError("Įveskite varžovo vardą");
      return;
    }
    if (_s1p1.text.isEmpty || _s1p2.text.isEmpty) {
      _showError("Įveskite bent pirmo seto rezultatą");
      return;
    }

    // 2. Formuojame rezultatų eilutę (pvz., "6-4, 6-3")
    String score = "${_s1p1.text}-${_s1p2.text}";
    if (_s2p1.text.isNotEmpty && _s2p2.text.isNotEmpty) {
      score += ", ${_s2p1.text}-${_s2p2.text}";
    }
    if (_s3p1.text.isNotEmpty && _s3p2.text.isNotEmpty) {
      score += ", ${_s3p1.text}-${_s3p2.text}";
    }

    // 3. Nustatome laimėtoją (Supaprastinta logika pagal pirmą setą demo tikslams, 
    // bet realybėje reiktų skaičiuoti visus setus)
    int mySets = 0;
    int opSets = 0;
    
    // Helper funkcija seto laimėtojui
    void checkSet(String p1, String p2) {
      if (p1.isEmpty || p2.isEmpty) return;
      int s1 = int.tryParse(p1) ?? 0;
      int s2 = int.tryParse(p2) ?? 0;
      if (s1 > s2) {
        mySets++;
      } else if (s2 > s1) opSets++;
    }

    checkSet(_s1p1.text, _s1p2.text);
    checkSet(_s2p1.text, _s2p2.text);
    checkSet(_s3p1.text, _s3p2.text);

    String result = "D"; // Draw
    if (mySets > opSets) result = "W"; // Win
    if (opSets > mySets) result = "L"; // Loss

    // 4. Grąžiname duomenis į MainWrapper
    Navigator.pop(context, {
      'sport': _selectedSport,
      'type': _matchType,
      'opponent': _opponentController.text,
      'location': _locationController.text.isEmpty ? "Aikštelė" : _locationController.text,
      'score': score,
      'result': result,
      'date': DateTime.now().toString().split(' ')[0],
      'time': "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = QortColors.background;
    const cardColor = QortColors.surface;
    const accentColor = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text("NAUJAS MAČAS", style: GoogleFonts.bebasNeue(letterSpacing: 1)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _submitMatch, icon: const Icon(LucideIcons.check, color: accentColor))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. SPORTO IR TIPO PASIRINKIMAS ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _buildDropdown("Sporto šaka", _selectedSport, ["Tenisas", "Padelis", "Krepšinis"], (val) => setState(() => _selectedSport = val!)),
                  const SizedBox(height: 15),
                  _buildDropdown("Mačo tipas", _matchType, ["Varžybos", "Treniruotė", "Draugiškas"], (val) => setState(() => _matchType = val!)),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // --- 2. VARŽOVAS IR VIETA ---
            Text("DETALĖS", style: GoogleFonts.oswald(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _buildTextInput("Varžovas", _opponentController, LucideIcons.user),
                  const SizedBox(height: 15),
                  _buildTextInput("Vieta / Klubas", _locationController, LucideIcons.mapPin),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 3. REZULTATAS (SCOREBOARD) ---
            Text("REZULTATAS", style: GoogleFonts.oswald(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(""), // Spacer
                      Text("SET 1", style: GoogleFonts.bebasNeue(color: Colors.grey)),
                      Text("SET 2", style: GoogleFonts.bebasNeue(color: Colors.grey)),
                      Text("SET 3", style: GoogleFonts.bebasNeue(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Eilutė: AŠ
                  Row(
                    children: [
                      SizedBox(width: 60, child: Text("AŠ", style: GoogleFonts.bebasNeue(color: accentColor, fontSize: 20))),
                      Expanded(child: _scoreInput(_s1p1)),
                      const SizedBox(width: 10),
                      Expanded(child: _scoreInput(_s2p1)),
                      const SizedBox(width: 10),
                      Expanded(child: _scoreInput(_s3p1)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Eilutė: VARŽOVAS
                  Row(
                    children: [
                      SizedBox(width: 60, child: Text("OPP", style: GoogleFonts.bebasNeue(color: Colors.red, fontSize: 20))),
                      Expanded(child: _scoreInput(_s1p2)),
                      const SizedBox(width: 10),
                      Expanded(child: _scoreInput(_s2p2)),
                      const SizedBox(width: 10),
                      Expanded(child: _scoreInput(_s3p2)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _submitMatch,
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: Text("PATVIRTINTI REZULTATĄ", style: GoogleFonts.bebasNeue(fontSize: 24, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- UI KOMPONENTAI ---
  
  Widget _scoreInput(TextEditingController controller) {
    return Container(
      height: 50,
      decoration: BoxDecoration(color: QortColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: GoogleFonts.bebasNeue(fontSize: 24, color: Colors.white),
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    );
  }

  Widget _buildTextInput(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: QortColors.surface,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      style: const TextStyle(color: Colors.white),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}