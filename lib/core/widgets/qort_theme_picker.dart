import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/qort_palette.dart';
import '../theme/qort_palette_extension.dart';
import '../theme/qort_theme_notifier.dart';

/// Kompaktus temų pasirinkimas nustatymuose.
class QortThemePicker extends StatefulWidget {
  const QortThemePicker({super.key});

  @override
  State<QortThemePicker> createState() => _QortThemePickerState();
}

class _QortThemePickerState extends State<QortThemePicker> {
  static const _variants = [
    QortPalette.premiumLight,
    QortPalette.proDark,
    QortPalette.sportContrast,
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final currentId = QortThemeNotifier.instance.palette.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IŠVAIZDA',
          style: GoogleFonts.oswald(
            color: p.textSecondary,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        ..._variants.map((variant) {
          final selected = variant.id == currentId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => QortThemeNotifier.instance.apply(variant),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? variant.primary : p.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      _ThemeSwatch(palette: variant),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              variant.title,
                              style: TextStyle(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              variant.subtitle,
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                        color: selected ? variant.primary : p.navInactive,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final QortPalette palette;

  const _ThemeSwatch({required this.palette});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Expanded(child: ColoredBox(color: palette.background)),
                    Expanded(child: ColoredBox(color: palette.primary)),
                  ],
                ),
              ),
              Expanded(
                child: ColoredBox(color: palette.surface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
