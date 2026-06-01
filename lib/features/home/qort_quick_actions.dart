import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/event_organizer_policy.dart';
import '../../core/theme/qort_mode_colors.dart';
import '../../core/theme/qort_palette.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../admin/create_tournament_screen.dart';
import '../profile/add_external_record_screen.dart';
import '../profile/user_model.dart';
import '../training/open_matches_screen.dart';

/// Centrinis „+“ meniu — QORT kaip sporto pasas.
class QortQuickActions {
  QortQuickActions._();

  static Future<void> show(
    BuildContext context, {
    required UserProfile user,
    VoidCallback? onRecordsChanged,
  }) {
    final p = context.qortPalette;

    return showModalBottomSheet(
      context: context,
      backgroundColor: p.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'KĄ NORITE UŽFIKSUOTI?',
                textAlign: TextAlign.center,
                style: GoogleFonts.bebasNeue(
                  color: p.textPrimary,
                  fontSize: 26,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Galite registruoti veiklą QORT arba įvesti rezultatą iš kitur — '
                'abu keliai augina jūsų sporto pasą.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _actionTile(
                ctx,
                palette: p,
                icon: LucideIcons.filePlus2,
                color: QortModeColors.competition,
                title: 'Išorinis įrašas',
                subtitle:
                    'Ne QORT mačas: kitoje platformoje žaistas mačas ar turnyro vieta — sporto pasas',
                onTap: () async {
                  Navigator.pop(ctx);
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddExternalRecordScreen(),
                    ),
                  );
                  if (saved == true) onRecordsChanged?.call();
                },
              ),
              const SizedBox(height: 10),
              _actionTile(
                ctx,
                palette: p,
                icon: LucideIcons.megaphone,
                color: QortModeColors.warning,
                title: 'Skelbti atvirą mačą',
                subtitle:
                    'Ieškote partnerio ar varžovo — kiti QORT nariai matys skelbimą',
                onTap: () {
                  Navigator.pop(ctx);
                  if (user.sportsList.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Pirmiausia profilyje pridėkite bent vieną sporto šaką.',
                        ),
                        backgroundColor: QortModeColors.warning,
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OpenMatchesScreen(
                        user: user,
                        openCreateDialog: true,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _actionTile(
                ctx,
                palette: p,
                icon: LucideIcons.trophy,
                color: const Color(0xFFEAB308),
                title: 'Organizuoti renginį',
                badge: 'MOKAMA',
                subtitle:
                    'Turnyras QORT — ${EventOrganizerPolicy.feeLabel()}, patvirtina administratorius',
                onTap: () async {
                  Navigator.pop(ctx);
                  final proceed = await _confirmOrganizerService(context, p);
                  if (proceed != true) return;
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const CreateEventScreen(requiresApproval: true),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _comingSoonRow(p),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool?> _confirmOrganizerService(
    BuildContext context,
    QortPalette p,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'ORGANIZUOTI RENGINĮ',
          style: GoogleFonts.bebasNeue(
            color: Colors.amber,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mokama paslauga: ${EventOrganizerPolicy.feeLabel()}',
              style: TextStyle(
                color: p.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              EventOrganizerPolicy.submissionBannerText,
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text('Atšaukti', style: TextStyle(color: p.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEAB308),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(
              'TĘSTI PARAIŠKĄ',
              style: GoogleFonts.bebasNeue(
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _actionTile(
    BuildContext context, {
    required QortPalette palette,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Text(
                              badge,
                              style: GoogleFonts.bebasNeue(
                                color: Colors.amber,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _comingSoonRow(QortPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.background,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.clock, color: p.textSecondary, size: 14),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Netrukus: greitas Blitz mačas ir treniruotės su treneriu',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
