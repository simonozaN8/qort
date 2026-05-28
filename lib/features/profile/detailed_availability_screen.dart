import 'package:flutter/material.dart';
import '../../../../../../../../../core/theme/qort_colors.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class DetailedAvailabilityScreen extends StatefulWidget {
  const DetailedAvailabilityScreen({super.key});

  @override
  State<DetailedAvailabilityScreen> createState() => _DetailedAvailabilityScreenState();
}

class _DetailedAvailabilityScreenState extends State<DetailedAvailabilityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = ["PR", "AN", "TR", "KE", "PE", "ŠE", "SE"];
  
  // Saugome pasirinktas valandas kiekvienai dienai
  // Pvz: 0 (Pirmadienis) -> [18, 19, 20]
  final Map<int, List<int>> _selections = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = QortColors.background;
    const accentColor = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("DETALUS LAIKAS", style: GoogleFonts.bebasNeue(letterSpacing: 2, color: Colors.white)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: accentColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.oswald(fontWeight: FontWeight.bold),
          tabs: _days.map((d) => Tab(text: d)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(7, (dayIndex) => _buildDayGrid(dayIndex, accentColor)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Čia išsaugotume ir grąžintume duomenis
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Grafikas atnaujintas!")));
        },
        backgroundColor: accentColor,
        label: Text("IŠSAUGOTI", style: GoogleFonts.oswald(fontWeight: FontWeight.bold)),
        icon: const Icon(LucideIcons.check),
      ),
    );
  }

  Widget _buildDayGrid(int dayIndex, Color accentColor) {
    // Generuojame valandas nuo 06:00 iki 23:00
    final hours = List.generate(18, (i) => i + 6); 

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: hours.length,
        itemBuilder: (context, index) {
          final hour = hours[index];
          final isSelected = _selections[dayIndex]?.contains(hour) ?? false;

          return GestureDetector(
            onTap: () {
              setState(() {
                if (_selections[dayIndex] == null) _selections[dayIndex] = [];
                
                if (isSelected) {
                  _selections[dayIndex]!.remove(hour);
                } else {
                  _selections[dayIndex]!.add(hour);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : QortColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? accentColor : Colors.white10),
                boxShadow: isSelected ? [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 8)] : [],
              ),
              alignment: Alignment.center,
              child: Text(
                "${hour.toString().padLeft(2, '0')}:00",
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}