import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../../../../../../core/theme/qort_colors.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _teamNameCtrl = TextEditingController();
  String _selectedSport = "Padelis"; // Dažniausias komandinis
  
  // Komandos nariai (Pradžioje esi tu pats)
  // Kai pajungsime Supabase, čia bus UserID sąrašas
  final List<String> _members = ["Aš (Kapitonas)"];
  final _memberCtrl = TextEditingController();

  final List<String> _teamSports = [
    "Padelis", "Krepšinis (3x3)", "Tinklinis (2v2)", "Futbolas", "Tenisas (Dvejetai)"
  ];

  Future<void> _saveTeam() async {
    if (_teamNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Įveskite komandos pavadinimą!"), backgroundColor: Colors.red));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    
    // 1. Nuskaitome esamas komandas
    String existingJson = prefs.getString('user_teams') ?? "[]";
    List<dynamic> decoded = jsonDecode(existingJson);
    List<Map<String, dynamic>> currentTeams = decoded.map((e) => Map<String, dynamic>.from(e)).toList();

    // 2. Sukuriame naują komandą
    Map<String, dynamic> newTeam = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // Laikinas ID
      'name': _teamNameCtrl.text,
      'sport': _selectedSport,
      'members': _members,
      'wins': 0,
      'losses': 0,
      'created_at': DateTime.now().toIso8601String(),
    };

    // 3. Išsaugome
    currentTeams.insert(0, newTeam); // Naujausia viršuje
    await prefs.setString('user_teams', jsonEncode(currentTeams));

    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Komanda sukurta!"), backgroundColor: Colors.green));
    Navigator.pop(context, true); // Grįžtame su signalu "update"
  }

  void _addMember() {
    if (_memberCtrl.text.isNotEmpty) {
      setState(() {
        _members.add(_memberCtrl.text);
        _memberCtrl.clear();
      });
    }
  }

  void _removeMember(int index) {
    if (index == 0) return; // Negalima ištrinti kapitono
    setState(() {
      _members.removeAt(index);
    });
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
        title: Text("KURTI KOMANDĄ", style: GoogleFonts.bebasNeue(letterSpacing: 1)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _saveTeam, icon: const Icon(LucideIcons.check, color: accentColor))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PAVADINIMAS
            Text("KOMANDOS PAVADINIMAS", style: GoogleFonts.oswald(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _teamNameCtrl,
                style: GoogleFonts.bebasNeue(fontSize: 24, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "PVZ: VILNIAUS TIGRAI",
                  hintStyle: TextStyle(color: Colors.white24),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // SPORTAS
            Text("SPORTO ŠAKA", style: GoogleFonts.oswald(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedSport,
                dropdownColor: cardColor,
                decoration: const InputDecoration(border: InputBorder.none),
                style: const TextStyle(color: Colors.white),
                items: _teamSports.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedSport = v!),
              ),
            ),

            const SizedBox(height: 30),

            // NARIAI
            Text("KOMANDOS NARIAI (${_members.length})", style: GoogleFonts.oswald(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            
            // Pridėjimo laukas
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: _memberCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Įveskite nario vardą...",
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _addMember,
                  style: IconButton.styleFrom(backgroundColor: Colors.blue.withOpacity(0.2)),
                  icon: const Icon(LucideIcons.plus, color: Colors.blue),
                )
              ],
            ),
            
            const SizedBox(height: 15),

            // Narių sąrašas
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _members.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(index == 0 ? LucideIcons.crown : LucideIcons.user, size: 16, color: index == 0 ? Colors.amber : Colors.grey),
                          const SizedBox(width: 10),
                          Text(_members[index], style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      if (index != 0)
                        GestureDetector(
                          onTap: () => _removeMember(index),
                          child: const Icon(LucideIcons.x, size: 16, color: Colors.red),
                        )
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _saveTeam,
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: Text("SUKURTI KOMANDĄ", style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24)),
              ),
            )
          ],
        ),
      ),
    );
  }
}