import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/qort_colors.dart';

/// Rodo ginčo dialogą. Grąžina pateiktą tekstą arba null jei atšaukta.
Future<String?> showMatchDisputeDialog(
  BuildContext context, {
  String? opponentName,
}) {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final text = controller.text.trim();
          final canSubmit = text.length >= 10;

          return AlertDialog(
            backgroundColor: QortColors.surface,
            title: Row(
              children: [
                const Icon(LucideIcons.shieldAlert, color: Colors.red, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Apskųsti rezultatą',
                    style: GoogleFonts.inter(
                      color: QortColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (opponentName != null && opponentName.isNotEmpty) ...[
                    Text(
                      'Mačas prieš: $opponentName',
                      style: const TextStyle(
                        color: QortColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Organizatorius peržiūrės skundą ir priims sprendimą.',
                    style: TextStyle(
                      color: QortColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    maxLength: 500,
                    onChanged: (_) => setDialogState(() {}),
                    style: const TextStyle(color: QortColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Aprašyk kodėl rezultatas neteisingas',
                      hintStyle: const TextStyle(color: QortColors.textSecondary),
                      filled: true,
                      fillColor: QortColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: QortColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: QortColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Atšaukti',
                  style: TextStyle(color: QortColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit ? Colors.red : Colors.grey,
                ),
                onPressed: canSubmit
                    ? () => Navigator.pop(ctx, controller.text.trim())
                    : null,
                child: const Text(
                  'Pateikti skundą',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
