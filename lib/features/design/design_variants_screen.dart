import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/qort_palette.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/theme/qort_theme.dart';
import '../../core/theme/qort_theme_notifier.dart';
import '../../core/widgets/qort_logo.dart';

/// Gyva 3 dizaino variantų peržiūra su QORT logotipu ir admin mockup.
class DesignVariantsScreen extends StatefulWidget {
  const DesignVariantsScreen({super.key});

  @override
  State<DesignVariantsScreen> createState() => _DesignVariantsScreenState();
}

class _DesignVariantsScreenState extends State<DesignVariantsScreen> {
  late String _selectedId;
  final _variants = const [
    QortPalette.premiumLight,
    QortPalette.proDark,
    QortPalette.sportContrast,
  ];

  @override
  void initState() {
    super.initState();
    _selectedId = QortThemeNotifier.instance.palette.id;
  }

  Future<void> _apply() async {
    final p = QortPalette.fromId(_selectedId);
    await QortThemeNotifier.instance.apply(p);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Taikytas variantas: ${p.title}'),
        backgroundColor: p.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = QortThemeNotifier.instance.palette;

    return Theme(
      data: QortTheme.fromPalette(current),
      child: Scaffold(
        backgroundColor: current.background,
        appBar: AppBar(
          title: Text(
            'DIZAINO VARIANTAI',
            style: GoogleFonts.bebasNeue(letterSpacing: 1.2, fontSize: 22),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            const QortLogo(height: 36, showWordmark: true),
            const SizedBox(height: 12),
            Text(
              'Pasirinkite variantą — žemiau pilnas „Valdymo pulto“ maketas su logotipu. '
              'Paspauskite „Taikyti“, kad visoje programoje matytumėte gyvai.',
              style: TextStyle(
                color: current.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            ..._variants.map((p) => _VariantCard(
                  palette: p,
                  selected: _selectedId == p.id,
                  onSelect: () => setState(() => _selectedId = p.id),
                )),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(LucideIcons.check),
              label: Text(
                'TAIKYTI: ${QortPalette.fromId(_selectedId).title}'.toUpperCase(),
                style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 1),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  final QortPalette palette;
  final bool selected;
  final VoidCallback onSelect;

  const _VariantCard({
    required this.palette,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onSelect,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(
                  selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  color: selected ? palette.primary : palette.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        palette.title,
                        style: GoogleFonts.bebasNeue(
                          fontSize: 20,
                          letterSpacing: 1,
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        palette.subtitle,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Theme(
            data: QortTheme.fromPalette(palette),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? palette.primary : palette.border,
                  width: selected ? 2.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: const _AdminPanelMock(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pilnas valdymo pulto maketas vienam variantui.
class _AdminPanelMock extends StatelessWidget {
  const _AdminPanelMock();

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    return ColoredBox(
      color: p.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: p.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(LucideIcons.arrowLeft, color: p.textPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'VALDYMO PULTAS',
                    style: GoogleFonts.bebasNeue(
                      color: p.textPrimary,
                      fontSize: 20,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const QortLogo(height: 22, showWordmark: true),
              ],
            ),
          ),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _chip(p, 'BENDRA INFO', false),
                const SizedBox(width: 8),
                _chip(p, 'MIDDLE', true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _participantsCard(p),
                const SizedBox(height: 12),
                _stageSnippet(p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(QortPalette p, String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? p.chipSelected : p.chipUnselectedBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? p.chipSelected : p.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : p.chipUnselectedText,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _participantsCard(QortPalette p) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DALYVIAI (18)',
                        style: GoogleFonts.bebasNeue(
                          color: p.success,
                          fontSize: 18,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'Atvykimas, traumos ir mokėjimai',
                        style: TextStyle(color: p.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronUp, color: p.textSecondary, size: 18),
              ],
            ),
          ),
          ...List.generate(4, (i) {
            final alt = i.isOdd;
            return Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              decoration: BoxDecoration(
                color: alt ? p.listRowAlt : p.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.border.withValues(alpha: 0.6)),
              ),
              child: ListTile(
                dense: true,
                title: Text(
                  'Test Botas ${i + 1}',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'Atvyko: ${i == 0 ? 'TAIP' : 'NE'} • Apmokėjimas: LAUKIA',
                  style: TextStyle(color: p.textSecondary, fontSize: 10),
                ),
                trailing: Icon(
                  LucideIcons.moreVertical,
                  color: p.textSecondary,
                  size: 16,
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _stageSnippet(QortPalette p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1 ETAPAS',
            style: GoogleFonts.bebasNeue(
              color: p.primary,
              fontSize: 16,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Etapo Formatas',
            style: TextStyle(color: p.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: p.listRowAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.border),
            ),
            child: Text(
              'Round Robin (Grupės)',
              style: TextStyle(color: p.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
