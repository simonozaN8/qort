import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/app_shell_layout.dart';
import '../../core/theme/qort_design_system.dart';
import '../../features/profile/user_model.dart';

/// Apatinė navigacija: Pagrindinis · Rungtynės · [Q] · Sukurti · Profilis.
class QortBottomNav extends StatelessWidget {
  final int currentIndex;
  final AppMode currentMode;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCreatePressed;

  const QortBottomNav({
    super.key,
    required this.currentIndex,
    required this.currentMode,
    required this.onTabSelected,
    required this.onCreatePressed,
  });

  static const _feedIndex = 2;
  static const _createIndex = 3;

  static const _leftItems = [
    _NavItem(index: 0, icon: LucideIcons.home, label: 'Pagrindinis'),
    _NavItem(index: 1, icon: LucideIcons.trophy, label: 'Rungtynės'),
  ];

  static const _rightItems = [
    _NavItem(index: _createIndex, icon: LucideIcons.plus, label: 'Sukurti'),
    _NavItem(index: 4, icon: LucideIcons.user, label: 'Profilis'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = QortDesignSystem.modeAccent(currentMode);
    const fabSize = 56.0;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final height = AppShellLayout.bottomNavBarHeight +
        AppShellLayout.fabOverlap +
        bottomPad;
    final feedSelected = currentIndex == _feedIndex;

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
                            _tab(context, _leftItems[0], accent),
                            _tab(context, _leftItems[1], accent),
                          ],
                        ),
                      ),
                      const SizedBox(width: fabSize + 8),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _tab(context, _rightItems[0], accent, onTap: onCreatePressed),
                            _tab(context, _rightItems[1], accent),
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
              onPressed: () => onTabSelected(_feedIndex),
              backgroundColor: accent,
              elevation: feedSelected ? 10 : 6,
              highlightElevation: feedSelected ? 12 : 8,
              shape: CircleBorder(
                side: feedSelected
                    ? BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 2)
                    : BorderSide.none,
              ),
              child: const Text(
                'Q',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    _NavItem item,
    Color accent, {
    VoidCallback? onTap,
  }) {
    final selected = currentIndex == item.index;
    final activeColor = selected ? accent : QortDesignSystem.textSecondary;

    return InkWell(
      onTap: onTap ?? () => onTabSelected(item.index),
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
            Icon(item.icon, color: activeColor, size: 22),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: activeColor,
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

  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
  });
}
