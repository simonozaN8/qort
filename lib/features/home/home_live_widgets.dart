import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/app_shell_layout.dart';
import '../../core/theme/qort_palette.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/widgets/qort_ambient_background.dart';
import '../../core/widgets/qort_hero_banner.dart';
import '../profile/user_model.dart';

/// Hero juosta pagal režimą — nuotrauka + gradientas + CTA jausmas.
class HomeLiveHero extends StatelessWidget {
  final AppMode mode;
  final String userName;
  final int upcomingMatches;
  final int actionItems;
  final bool isNewUser;

  const HomeLiveHero({
    super.key,
    required this.mode,
    required this.userName,
    this.upcomingMatches = 0,
    this.actionItems = 0,
    this.isNewUser = false,
  });


  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final accent = _modeAccent(mode);
    final copy = _copyForMode(mode, upcomingMatches, actionItems, isNewUser);

    return QortHeroBanner(
      accent: accent,
      height: 140,
      child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userName.isNotEmpty)
                  Text(
                    'Sveiki, $userName',
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                if (userName.isNotEmpty) const SizedBox(height: 4),
                Text(
                  copy.tag,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  copy.headline,
                  style: GoogleFonts.inter(
                    color: p.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(_modeIcon(mode), color: accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        copy.subline,
                        style: TextStyle(
                          color: p.textSecondary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }
}

/// 3 spalvotos kortelės — greitas režimo perjungimas.
class HomeModeQuickCards extends StatelessWidget {
  final AppMode current;
  final ValueChanged<AppMode>? onSelect;

  const HomeModeQuickCards({
    super.key,
    required this.current,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    return Row(
      children: [
        Expanded(
          child: _card(
            p: p,
            mode: AppMode.competition,
            icon: LucideIcons.trophy,
            label: 'Varžybos',
            color: const Color(0xFF3B82F6),
            selected: current == AppMode.competition,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _card(
            p: p,
            mode: AppMode.training,
            icon: LucideIcons.target,
            label: 'Treniruotės',
            color: const Color(0xFF16C56E),
            selected: current == AppMode.training,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _card(
            p: p,
            mode: AppMode.blitz,
            icon: LucideIcons.zap,
            label: 'Blitz',
            color: const Color(0xFFD946EF),
            selected: current == AppMode.blitz,
          ),
        ),
      ],
    );
  }

  Widget _card({
    required QortPalette p,
    required AppMode mode,
    required IconData icon,
    required String label,
    required Color color,
    required bool selected,
  }) {
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : p.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onSelect == null ? null : () => onSelect!(mode),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : p.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : p.textSecondary, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? p.textPrimary : p.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bendras „gyvas“ home karkasas: fonas + hero + režimai + turinys.
class HomeLiveScaffold extends StatelessWidget {
  final AppMode mode;
  final String userName;
  final int upcomingMatches;
  final int actionItems;
  final bool isNewUser;
  final Color refreshAccent;
  final Future<void> Function() onRefresh;
  final ValueChanged<AppMode>? onModeSelected;
  final List<Widget> children;

  const HomeLiveScaffold({
    super.key,
    required this.mode,
    required this.userName,
    required this.onRefresh,
    required this.children,
    this.upcomingMatches = 0,
    this.actionItems = 0,
    this.isNewUser = false,
    this.refreshAccent = const Color(0xFF16C56E),
    this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          QortAmbientBackground(palette: p),
          RefreshIndicator(
            onRefresh: onRefresh,
            color: refreshAccent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HomeLiveHero(
                          mode: mode,
                          userName: userName,
                          upcomingMatches: upcomingMatches,
                          actionItems: actionItems,
                          isNewUser: isNewUser,
                        ),
                        const SizedBox(height: 20),
                        ...children,
                        SizedBox(
                          height: AppShellLayout.scrollBottomPadding(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy {
  final String tag;
  final String headline;
  final String subline;

  const _HeroCopy(this.tag, this.headline, this.subline);
}

_HeroCopy _copyForMode(
  AppMode mode,
  int matches,
  int actions,
  bool isNewUser,
) {
  switch (mode) {
    case AppMode.training:
      return _HeroCopy(
        'TRENIRUOTĖS',
        isNewUser ? 'Pradėk nuo\natviro mačo' : 'Rask varžovą\nsavo lygiu',
        matches > 0
            ? '$matches suderinti mačai • atviri skelbimai'
            : 'Skelbk arba priimk atvirą mačą',
      );
    case AppMode.blitz:
      return const _HeroCopy(
        'BLITZ',
        'Greitas formatas',
        'Atidarykite Blitz skirtuką ir pradėkite',
      );
    case AppMode.competition:
      return _HeroCopy(
        'VARŽYBOS',
        actions > 0
            ? 'Reikia tavo\nveiksmo'
            : (isNewUser ? 'Pradėk nuo\nturnyro' : 'Tavo sezonas\ntęsiasi'),
        matches > 0
            ? '$matches artimiausi mačai${actions > 0 ? ' • $actions laukia' : ''}'
            : (actions > 0
                ? '$actions veiksmai laukia tavo sprendimo'
                : 'Suderinti mačai ir turnyrai — žemiau'),
      );
  }
}

Color _modeAccent(AppMode mode) {
  switch (mode) {
    case AppMode.training:
      return const Color(0xFF16C56E);
    case AppMode.blitz:
      return const Color(0xFFD946EF);
    case AppMode.competition:
    default:
      return const Color(0xFF3B82F6);
  }
}

IconData _modeIcon(AppMode mode) {
  switch (mode) {
    case AppMode.training:
      return LucideIcons.target;
    case AppMode.blitz:
      return LucideIcons.zap;
    case AppMode.competition:
    default:
      return LucideIcons.trophy;
  }
}
