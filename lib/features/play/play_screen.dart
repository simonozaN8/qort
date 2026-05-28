import 'package:flutter/material.dart';
import '../../../../../../../../../core/theme/qort_colors.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
// import 'training/sparring_radar_screen.dart'; // Jei turi radarą

class PlayScreen extends StatefulWidget {
  final bool isTrainingMode;
  const PlayScreen({super.key, required this.isTrainingMode});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = QortColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TRENIRUOTĖS",
                      style: GoogleFonts.bebasNeue(
                        fontSize: 32,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      "Tobulink įgūdžius ir rask partnerių",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                // Radaro mygtukas
                GestureDetector(
                  onTap: () {
                    // Navigacija į Radarą
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const SparringRadarScreen()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Atidaromas Sparring Radar..."),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Icon(
                      LucideIcons.radar,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: QortColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: "MANO TRENIRUOTĖS"),
                Tab(text: "IEŠKOTI PARTNERIŲ"),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Turinys
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Mano treniruotės
                ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _card(
                      "Individuali treniruotė",
                      "SEB Arena • Rytoj 10:00",
                      Colors.orange,
                    ),
                    _card(
                      "Grupė (4 žm.)",
                      "Padelio Namai • Penkt. 18:00",
                      Colors.blue,
                    ),
                  ],
                ),
                // 2. Paieška
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.search,
                        size: 50,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Naudokite radarą viršuje",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: QortColors.border),
        color: QortColors.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.oswald(
                        color: QortColors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: QortColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
