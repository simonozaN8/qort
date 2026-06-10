import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/app_shell_layout.dart';
import '../../core/theme/qort_design_system.dart';
import '../../core/widgets/qort_components.dart';

class FeedSectionLoading extends StatelessWidget {
  const FeedSectionLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: QortDesignSystem.space6),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class FeedQStreamEmpty extends StatelessWidget {
  const FeedQStreamEmpty({super.key});

  static const _gold = Color(0xFFEAB308);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.users, color: Colors.white24, size: 64),
            const SizedBox(height: 20),
            const Text(
              'TAVO Q SRAUTAS',
              style: TextStyle(
                fontFamily: 'Anton',
                fontSize: 20,
                color: _gold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Čia matysi savo ir kitų sportininkų aktyvumą:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _emptyItem(LucideIcons.trophy, 'Sužaisti mačai'),
            _emptyItem(LucideIcons.users, 'Naujos komandos'),
            _emptyItem(LucideIcons.calendar, 'Turnyrų registracijos'),
            _emptyItem(LucideIcons.megaphone, 'Treniruočių skelbimai'),
            const SizedBox(height: 24),
            const Text(
              'Pradėk sportuoti - srautas užsipildys!',
              style: TextStyle(color: _gold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _emptyItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _gold, size: 16),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class FeedNoSportsCta extends StatelessWidget {
  final VoidCallback onOpenProfile;

  const FeedNoSportsCta({super.key, required this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    return QortEmptyState(
      icon: LucideIcons.dumbbell,
      title: 'Pasirink sportus',
      message:
          'Feed rodo turinį pagal tavo sporto šakas. Pridėk sportus profilyje, kad matytum aktyvumą ir skelbimus.',
      actionLabel: 'Pasirink sportus profilyje',
      onAction: onOpenProfile,
      accent: QortDesignSystem.brand,
    );
  }
}

/// Apatinis padding Feed scroll turiniui.
double feedScrollBottomPadding(BuildContext context) =>
    AppShellLayout.scrollBottomPadding(context);
