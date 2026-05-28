import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Mačo statusai
enum MatchStatus { unscheduled, pending, played_waiting, disputed, completed }

class MatchItemCard extends StatelessWidget {
  final String opponentName;
  final String deadline;
  final MatchStatus status;
  final String? result;
  final VoidCallback onTap; // Visos kortelės paspaudimas
  final VoidCallback?
  onPrimaryAction; // Pagrindinis mygtukas (pvz., suvesti/patvirtinti)
  final VoidCallback? onSecondaryAction; // Antrinis mygtukas (pvz., skųsti)

  const MatchItemCard({
    super.key,
    required this.opponentName,
    required this.deadline,
    required this.status,
    this.result,
    required this.onTap,
    this.onPrimaryAction,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case MatchStatus.unscheduled:
        statusColor = Colors.grey;
        statusText = "NESUPLANUOTA";
        statusIcon = LucideIcons.calendarClock;
        break;
      case MatchStatus.pending:
        statusColor = const Color(0xFF3B82F6);
        statusText = "LAUKIAMA MAČO";
        statusIcon = LucideIcons.swords;
        break;
      case MatchStatus.played_waiting:
        statusColor = Colors.orange;
        statusText = "LAUKIAMA PATVIRTINIMO (2H)";
        statusIcon = LucideIcons.hourglass;
        break;
      case MatchStatus.disputed:
        statusColor = Colors.red;
        statusText = "GINČIJAMA";
        statusIcon = LucideIcons.alertTriangle;
        break;
      case MatchStatus.completed:
        statusColor = const Color(0xFF22C55E);
        statusText = "UŽBAIGTA";
        statusIcon = LucideIcons.checkCircle;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 4, color: statusColor),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: QortColors.surface,
                  child: Column(
          children: [
            // Header: Statusas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: GoogleFonts.oswald(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  deadline,
                  style: const TextStyle(color: QortColors.textSecondary, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Varžovai
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _player(opponentName, true), // Opponent
                Text(
                  "VS",
                  style: GoogleFonts.bebasNeue(
                    fontSize: 24,
                    color: QortColors.navInactive,
                  ),
                ),
                _player("Jūs", false),
              ],
            ),

            // Veiksmo mygtukai
            if (status == MatchStatus.unscheduled)
              _actionButton(
                "SIŪLYTI LAIKĄ IR VIETĄ",
                Colors.white,
                onTap: onPrimaryAction,
              ),
            if (status == MatchStatus.pending)
              _actionButton(
                "SUVESTI REZULTATĄ",
                const Color(0xFF3B82F6),
                onTap: onPrimaryAction,
              ),
            if (status == MatchStatus.played_waiting)
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      "PATVIRTINTI",
                      const Color(0xFF22C55E),
                      onTap: onPrimaryAction,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      "SKŲSTI",
                      Colors.red,
                      isOutlined: true,
                      onTap: onSecondaryAction,
                    ),
                  ),
                ],
              ),
            if (status == MatchStatus.completed)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  "REZULTATAS: ${result ?? '-'}",
                  style: GoogleFonts.bebasNeue(color: QortColors.textPrimary, ),
                ),
              ),
          ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _player(String name, bool isOpponent) {
    return Row(
      children: [
        if (!isOpponent) ...[
          Text(
            name,
            style: GoogleFonts.oswald(fontSize: 16, color: QortColors.textPrimary),
          ),
          const SizedBox(width: 10),
        ],
        CircleAvatar(
          radius: 18,
          backgroundColor: isOpponent
              ? Colors.red.withOpacity(0.2)
              : Colors.blue.withOpacity(0.2),
          child: Text(
            name.isNotEmpty ? name[0] : "?",
            style: TextStyle(color: isOpponent ? Colors.red : Colors.blue),
          ),
        ),
        if (isOpponent) ...[
          const SizedBox(width: 10),
          Text(
            name,
            style: GoogleFonts.oswald(fontSize: 16, color: QortColors.textPrimary),
          ),
        ],
      ],
    );
  }

  Widget _actionButton(
    String text,
    Color color, {
    bool isOutlined = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 15),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: GoogleFonts.oswald(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
