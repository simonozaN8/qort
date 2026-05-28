import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/app_shell_layout.dart';
import '../../core/theme/qort_design_system.dart';
import '../../features/profile/user_model.dart';

/// Apatinė navigacija: Pagrindinis · Rungtynės · [+] · Q (Feed) · Profilis.
class QortBottomNav extends StatelessWidget {
  final int currentIndex;
  final AppMode currentMode;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onFabPressed;

  const QortBottomNav({
    super.key,
    required this.currentIndex,
    required this.currentMode,
    required this.onTabSelected,
    required this.onFabPressed,
  });

  static const _items = [
    _NavItem(index: 0, icon: LucideIcons.home, label: 'Pagrindinis'),
    _NavItem(index: 1, icon: LucideIcons.trophy, label: 'Rungtynės'),
    _NavItem(index: 2, icon: LucideIcons.rss, label: 'Feed', useQIcon: true),
    _NavItem(index: 3, icon: LucideIcons.user, label: 'Profilis'),
  ];

  @override
  Widget build(BuildContext context) {
    final fabAccent = QortDesignSystem.modeAccent(currentMode);
    const fabSize = 56.0;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final height = AppShellLayout.bottomNavBarHeight +
        AppShellLayout.fabOverlap +
        bottomPad;

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: QortDesignSystem.bgSurface,
                border: Border(top: BorderSide(color: QortDesignSystem.borderSubtle)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: AppShellLayout.bottomNavBarHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _tab(context, _items[0]),
                            _tab(context, _items[1]),
                          ],
                        ),
                      ),
                      const SizedBox(width: fabSize + 8),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _tab(context, _items[2]),
                            _tab(context, _items[3]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: FloatingActionButton(
              onPressed: onFabPressed,
              backgroundColor: fabAccent,
              elevation: 6,
              highlightElevation: 8,
              shape: const CircleBorder(),
              child: const Icon(LucideIcons.plus, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, _NavItem item) {
    final selected = currentIndex == item.index;
    final iconColor =
        selected ? QortDesignSystem.textPrimary : QortDesignSystem.textSecondary;
    final labelColor =
        selected ? QortDesignSystem.textPrimary : QortDesignSystem.textSecondary;
    final accent = QortDesignSystem.modeAccent(currentMode);

    return InkWell(
      onTap: () => onTabSelected(item.index),
      borderRadius: BorderRadius.circular(QortDesignSystem.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: selected ? QortDesignSystem.bgElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(QortDesignSystem.radiusSm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.useQIcon)
              Text(
                'Q',
                style: TextStyle(
                  color: selected ? accent : iconColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              )
            else
              Icon(item.icon, color: iconColor, size: 22),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final int index;
  final IconData icon;
  final String label;
  final bool useQIcon;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    this.useQIcon = false,
  });
}
