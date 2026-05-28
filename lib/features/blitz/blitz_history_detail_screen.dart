import 'package:flutter/material.dart';
import '../../../../../../../../../core/theme/qort_colors.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BlitzHistoryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> lobby;

  const BlitzHistoryDetailScreen({super.key, required this.lobby});

  @override
  Widget build(BuildContext context) {
    const bgColor = QortColors.background;

    String name = lobby['name'] ?? 'Gatvės Turnyras';
    String sport = lobby['sport'] ?? 'Sportas';
    String format = lobby['format'] ?? 'Formatas';
    String mvpName = lobby['mvp_name'] ?? 'Nenustatyta';

    // Ištraukiame išsaugotus rezultatus
    List<dynamic> resultsData = lobby['results_data'] != null
        ? List<dynamic>.from(lobby['results_data'])
        : [];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "TURNYRO ISTORIJA",
          style: GoogleFonts.bebasNeue(
            letterSpacing: 2,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Bendra informacija ir MVP
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: QortColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Text(
                    name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 32,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "$sport • $format",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.trophy,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "NUGALĖTOJAS (MVP)",
                            style: GoogleFonts.oswald(
                              color: Colors.orangeAccent,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            mvpName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            Text(
              "REZULTATŲ ŠVIESLENTĖ",
              style: GoogleFonts.oswald(
                color: Colors.grey,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),

            // Rezultatų sąrašas
            Expanded(
              child: resultsData.isEmpty
                  ? const Center(
                      child: Text(
                        "Rezultatų duomenų nerasta.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      itemCount: resultsData.length,
                      itemBuilder: (context, index) {
                        final match = resultsData[index];
                        return _buildHistoryMatchCard(match);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryMatchCard(Map<String, dynamic> match) {
    bool isFinal = match['round'] == 'FINALAS';
    bool isBronze = match['round'] == 'DĖL 3 VIETOS';

    Color borderColor = Colors.white10;
    if (isFinal) borderColor = const Color(0xFFEAB308);
    if (isBronze) borderColor = Colors.brown[400]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: (isFinal || isBronze) ? 2 : 1,
        ),
        boxShadow: isFinal
            ? [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 10)]
            : [],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isFinal
                  ? Colors.orange.withOpacity(0.1)
                  : (isBronze ? Colors.brown.withOpacity(0.1) : Colors.black26),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Text(
              match['round'] ?? 'MAČAS',
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(
                color: isFinal
                    ? Colors.orange
                    : (isBronze ? Colors.brown[300] : Colors.grey),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    match['team1']?.split(' (')[0] ?? 'Komanda 1',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    match['scoreDisplay'] ?? 'VS',
                    style: GoogleFonts.bebasNeue(
                      color: Colors.greenAccent,
                      fontSize: 20,
                      letterSpacing: 2,
                    ),
                  ),
                ),

                Expanded(
                  child: Text(
                    match['team2']?.split(' (')[0] ?? 'Komanda 2',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
