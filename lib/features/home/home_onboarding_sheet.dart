import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/services/onboarding_service.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/widgets/qort_logo.dart';

/// Kompaktinis profesionalus intro — ne ištemptas per visą ekraną.
class HomeOnboardingSheet {
  HomeOnboardingSheet._();

  static Future<void> showIfNeeded(BuildContext context) async {
    if (await OnboardingService.isDone()) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _OnboardingDialog(),
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final Color accent;
  final String title;
  final String body;

  const _OnboardingStep({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
  });
}

class _OnboardingDialog extends StatefulWidget {
  const _OnboardingDialog();

  @override
  State<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<_OnboardingDialog> {
  int _page = 0;

  static const _steps = [
    _OnboardingStep(
      icon: LucideIcons.layers,
      accent: Color(0xFF2563EB),
      title: 'Trys režimai',
      body: 'Varžybos, treniruotės ir Blitz — perjunkite viršuje pagal '
          'savo tikslą.',
    ),
    _OnboardingStep(
      icon: LucideIcons.layoutDashboard,
      accent: Color(0xFF2563EB),
      title: 'Pagrindinis skydelis',
      body: 'Artimiausi mačai, veiksmai ir statistika — viskas vienoje vietoje.',
    ),
    _OnboardingStep(
      icon: LucideIcons.calendarDays,
      accent: Color(0xFF2563EB),
      title: 'Rungtynės ir kalendorius',
      body: 'Antras tab apačioje — turnyrai, treniruotės ar Blitz pagal '
          'pasirinktą režimą.',
    ),
    _OnboardingStep(
      icon: LucideIcons.users,
      accent: Color(0xFF16A34A),
      title: 'Treniruotės',
      body: 'Atviri mačai ir sparingai — be turnyro registracijos.',
    ),
    _OnboardingStep(
      icon: LucideIcons.zap,
      accent: Color(0xFF7C3AED),
      title: 'Blitz',
      body: 'Greitas formatas mieste — raskite varžovą ir žaiskite iš karto.',
    ),
    _OnboardingStep(
      icon: LucideIcons.fileText,
      accent: Color(0xFF2563EB),
      title: 'Rezultatai',
      body: 'QORT mačų rezultatus įvedate iš Pagrindinio. Mygtukas + skirtas '
          'išoriniams įrašams.',
    ),
  ];

  Future<void> _finish() async {
    await OnboardingService.markDone();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final step = _steps[_page];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 420),
        child: Material(
          color: p.surfaceElevated,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: p.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (_page == 0) ...[
                      const QortLogo(height: 20),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        _page == 0 ? 'Sveiki atvykę' : '${_page + 1} / ${_steps.length}',
                        style: TextStyle(
                          color: p.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Praleisti',
                        style: TextStyle(color: p.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_page + 1) / _steps.length,
                    minHeight: 3,
                    backgroundColor: p.border,
                    color: step.accent,
                  ),
                ),
                const SizedBox(height: 20),
                Icon(step.icon, size: 32, color: step.accent),
                const SizedBox(height: 12),
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: p.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  step.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_steps.length, (i) {
                    final active = i == _page;
                    return Container(
                      width: active ? 18 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: active ? step.accent : p.border,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    if (_page < _steps.length - 1) {
                      setState(() => _page++);
                    } else {
                      _finish();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: step.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _page < _steps.length - 1 ? 'Toliau' : 'Pradėti',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
