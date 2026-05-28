import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../constants/app_shell_layout.dart';
import '../theme/qort_mode_colors.dart';
import '../theme/qort_palette_extension.dart';
import '../theme/qort_theme.dart';
import '../widgets/qort_ambient_background.dart';
import '../widgets/qort_hero_banner.dart';
import '../../features/profile/user_model.dart';

/// Vieningas ekrano karkasas — home stilistika visiems moduliams.
class QortLiveScaffold extends StatelessWidget {
  final AppMode mode;
  final String title;
  final String? subtitle;
  final String? heroHeadline;
  final List<Widget>? actions;
  final Widget child;
  final Future<void> Function()? onRefresh;
  final bool showHero;
  final bool scrollable;

  const QortLiveScaffold({
    super.key,
    required this.mode,
    required this.title,
    required this.child,
    this.subtitle,
    this.heroHeadline,
    this.actions,
    this.onRefresh,
    this.showHero = true,
    this.scrollable = true,
  });

  Color get _accent => switch (mode) {
        AppMode.training => QortModeColors.training,
        AppMode.blitz => QortModeColors.blitz,
        AppMode.competition => QortModeColors.competition,
      };

  IconData get _modeIcon => switch (mode) {
        AppMode.training => LucideIcons.target,
        AppMode.blitz => LucideIcons.zap,
        AppMode.competition => LucideIcons.trophy,
      };

  String get _modeTag => switch (mode) {
        AppMode.training => 'TRENIRUOTĖS',
        AppMode.blitz => 'BLITZ',
        AppMode.competition => 'VARŽYBOS',
      };

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHero) ...[
            _CompactHero(
              accent: _accent,
              modeIcon: _modeIcon,
              modeTag: _modeTag,
              title: heroHeadline ?? title,
              subtitle: subtitle,
            ),
            const SizedBox(height: 16),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: QortTheme.sectionTitle(p),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
          if (scrollable) child else Expanded(child: child),
          if (scrollable)
            SizedBox(height: AppShellLayout.scrollBottomPadding(context)),
        ],
      ),
    );

    Widget body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: scrollable ? content : Column(children: [Expanded(child: content)]),
      ),
    );

    if (onRefresh != null) {
      body = RefreshIndicator(
        onRefresh: onRefresh!,
        color: _accent,
        child: scrollable
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: body,
              )
            : body,
      );
    } else if (scrollable) {
      body = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          QortAmbientBackground(palette: p),
          SafeArea(child: body),
        ],
      ),
    );
  }
}

/// Kompaktiškas hero juostos variantas tab-1 ekranams.
class QortCompactHero extends StatelessWidget {
  final AppMode mode;
  final String title;
  final String? subtitle;

  const QortCompactHero({
    super.key,
    required this.mode,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => _CompactHero(
        accent: switch (mode) {
          AppMode.training => QortModeColors.training,
          AppMode.blitz => QortModeColors.blitz,
          AppMode.competition => QortModeColors.competition,
        },
        modeIcon: switch (mode) {
          AppMode.training => LucideIcons.target,
          AppMode.blitz => LucideIcons.zap,
          AppMode.competition => LucideIcons.trophy,
        },
        modeTag: switch (mode) {
          AppMode.training => 'TRENIRUOTĖS',
          AppMode.blitz => 'BLITZ',
          AppMode.competition => 'VARŽYBOS',
        },
        title: title,
        subtitle: subtitle,
      );
}

class _CompactHero extends StatelessWidget {
  final Color accent;
  final IconData modeIcon;
  final String modeTag;
  final String title;
  final String? subtitle;

  const _CompactHero({
    required this.accent,
    required this.modeIcon,
    required this.modeTag,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    return QortHeroBanner(
      accent: accent,
      height: 120,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              modeTag,
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: p.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const Spacer(),
            if (subtitle != null)
              Row(
                children: [
                  Icon(modeIcon, color: accent, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 11,
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
