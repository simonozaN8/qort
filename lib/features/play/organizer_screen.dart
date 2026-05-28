import 'package:flutter/material.dart';
import '../../../../../../../../../core/theme/qort_colors.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class OrganizerScreen extends StatelessWidget {
  const OrganizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const bgColor = QortColors.background;
    const cardColor = QortColors.surface;
    const goldColor = Color(0xFFFFD700);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text("ORGANIZATORIAUS PULTAS", style: GoogleFonts.bebasNeue(color: Colors.white)),
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // PREMIUM BANERIS
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [goldColor.withOpacity(0.2), cardColor]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: goldColor.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.crown, color: goldColor, size: 40),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("TAPK ORGANIZATORIUMI", style: GoogleFonts.oswald(color: Colors.white, fontSize: 16)),
                        const Text("Kurk lygas, generuok lenteles ir rink mokesčius per QORT.", style: TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // KŪRIMO FORMA
            Text("NAUJAS TURNYRAS", style: GoogleFonts.oswald(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 15),
            
            _inputField("Turnyro Pavadinimas", "pvz. Vilniaus Pavasario Taurė"),
            const SizedBox(height: 10),
            _inputField("Vieta", "pvz. SEB Arena"),
            const SizedBox(height: 10),
            
            // Formatas
            Row(
              children: [
                Expanded(child: _dropdownField("Formatas", ["Vieno minuso", "Dvigubo minuso", "Ratų sistema (Round Robin)"])),
                const SizedBox(width: 10),
                Expanded(child: _dropdownField("Sportas", ["Tenisas", "Padelis", "Krepšinis", "Futbolas"])),
              ],
            ),
            
            const SizedBox(height: 10),
            _inputField("Maksimalus dalyvių skaičius", "pvz. 16"),
            
            const Spacer(),
            
            // KAINA UŽ ORGANIZAVIMĄ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Paslaugos mokestis:", style: TextStyle(color: Colors.grey)),
                Text("€ 9.99 / turnyrui", style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20)),
              ],
            ),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                onPressed: () {
                  // Čia būtų mokėjimo integracija
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Turnyras sukurtas! Nuoroda išsiųsta dalyviams.")));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text("SUKURTI IR PALEISTI", style: GoogleFonts.bebasNeue(color: Colors.black, fontSize: 24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(color: QortColors.surface, borderRadius: BorderRadius.circular(12)),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey[700]), border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          decoration: BoxDecoration(color: QortColors.surface, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.first,
              dropdownColor: QortColors.surface,
              style: const TextStyle(color: Colors.white),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {},
            ),
          ),
        ),
      ],
    );
  }
}