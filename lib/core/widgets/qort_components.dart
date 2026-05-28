import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/qort_design_system.dart';

enum QortButtonVariant { primary, secondary, ghost }

enum QortButtonSize { sm, md, lg }

// ---------------------------------------------------------------------------
// QortCard
// ---------------------------------------------------------------------------

class QortCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const QortCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(QortDesignSystem.space4),
      decoration: BoxDecoration(
        color: backgroundColor ?? QortDesignSystem.bgSurface,
        borderRadius: BorderRadius.circular(QortDesignSystem.radiusMd),
        border: Border.all(color: QortDesignSystem.borderSubtle),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QortDesignSystem.radiusMd),
        child: card,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QortButton
// ---------------------------------------------------------------------------

class QortButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final QortButtonVariant variant;
  final QortButtonSize size;
  final Color? accent;
  final IconData? icon;
  final bool expanded;

  const QortButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = QortButtonVariant.primary,
    this.size = QortButtonSize.md,
    this.accent,
    this.icon,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? QortDesignSystem.brand;
    final hPad = switch (size) {
      QortButtonSize.sm => QortDesignSystem.space3,
      QortButtonSize.md => QortDesignSystem.space4,
      QortButtonSize.lg => QortDesignSystem.space5,
    };
    final vPad = switch (size) {
      QortButtonSize.sm => 8.0,
      QortButtonSize.md => 12.0,
      QortButtonSize.lg => 14.0,
    };
    final fontSize = switch (size) {
      QortButtonSize.sm => 12.0,
      QortButtonSize.md => 14.0,
      QortButtonSize.lg => 15.0,
    };

    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment:
          expanded ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: fontSize + 2, color: _foreground(color)),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: _foreground(color),
          ),
        ),
      ],
    );

    final button = switch (variant) {
      QortButtonVariant.primary => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: QortDesignSystem.bgInteractive,
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(QortDesignSystem.radiusSm),
            ),
          ),
          child: child,
        ),
      QortButtonVariant.secondary => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: QortDesignSystem.textPrimary,
            side: BorderSide(color: QortDesignSystem.borderDefault),
            backgroundColor: QortDesignSystem.bgElevated,
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(QortDesignSystem.radiusSm),
            ),
          ),
          child: child,
        ),
      QortButtonVariant.ghost => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: color,
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(QortDesignSystem.radiusSm),
            ),
          ),
          child: child,
        ),
    };

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Color _foreground(Color accent) {
    if (variant == QortButtonVariant.primary) return Colors.white;
    if (variant == QortButtonVariant.ghost) return accent;
    return QortDesignSystem.textPrimary;
  }
}

// ---------------------------------------------------------------------------
// QortPill
// ---------------------------------------------------------------------------

class QortPill extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const QortPill({
    super.key,
    required this.label,
    this.color,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? QortDesignSystem.brand;
    final bg = selected ? accent : QortDesignSystem.bgElevated;
    final fg = selected ? Colors.white : QortDesignSystem.textPrimary;
    final border = selected ? accent : QortDesignSystem.borderDefault;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QortDesignSystem.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(QortDesignSystem.radiusFull),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: selected ? Colors.white : accent),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: QortDesignSystem.micro.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QortInput
// ---------------------------------------------------------------------------

class QortInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final Widget? suffix;

  const QortInput({
    super.key,
    this.controller,
    this.hint,
    this.onSubmitted,
    this.onChanged,
    this.prefixIcon,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: QortDesignSystem.body.copyWith(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: QortDesignSystem.caption,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: QortDesignSystem.textMuted, size: 18)
            : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: QortDesignSystem.bgSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: QortDesignSystem.space4,
          vertical: QortDesignSystem.space3,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(QortDesignSystem.radiusSm),
          borderSide: BorderSide(color: QortDesignSystem.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(QortDesignSystem.radiusSm),
          borderSide: const BorderSide(color: QortDesignSystem.brand, width: 1.5),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QortStatCard
// ---------------------------------------------------------------------------

class QortStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final String? subtitle;

  const QortStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return QortCard(
      padding: const EdgeInsets.all(QortDesignSystem.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: QortDesignSystem.display.copyWith(
              fontSize: 36,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: QortDesignSystem.micro.copyWith(
              letterSpacing: 0.8,
              color: QortDesignSystem.textSecondary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: QortDesignSystem.caption.copyWith(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QortSectionHeader
// ---------------------------------------------------------------------------

class QortSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Color? accent;
  final IconData? icon;
  final List<Widget>? actions;

  const QortSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.accent,
    this.icon,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? QortDesignSystem.brand;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: QortDesignSystem.h2,
          ),
        ),
        if (count != null && count! > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(QortDesignSystem.radiusFull),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              '$count',
              style: QortDesignSystem.micro.copyWith(color: color),
            ),
          ),
        if (actions != null) ...actions!,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// QortEmptyState
// ---------------------------------------------------------------------------

class QortEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accent;

  const QortEmptyState({
    super.key,
    this.icon = LucideIcons.inbox,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? QortDesignSystem.textMuted;

    return Padding(
      padding: const EdgeInsets.all(QortDesignSystem.space8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: QortDesignSystem.bgElevated,
              borderRadius: BorderRadius.circular(QortDesignSystem.radiusLg),
              border: Border.all(color: QortDesignSystem.borderSubtle),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: QortDesignSystem.space5),
          Text(title.toUpperCase(), style: QortDesignSystem.h1.copyWith(fontSize: 22)),
          const SizedBox(height: QortDesignSystem.space2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: QortDesignSystem.caption.copyWith(height: 1.45),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: QortDesignSystem.space5),
            QortButton(
              label: actionLabel!,
              onPressed: onAction,
              accent: accent ?? QortDesignSystem.brand,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QortAccentCard (palikta suderinamumui su home ekranais)
// ---------------------------------------------------------------------------

class QortAccentCard extends StatelessWidget {
  final Color accent;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const QortAccentCard({
    super.key,
    required this.accent,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 14, 14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: QortDesignSystem.bgSurface,
        borderRadius: BorderRadius.circular(QortDesignSystem.radiusMd),
        border: Border.all(color: QortDesignSystem.borderSubtle),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(QortDesignSystem.radiusMd),
                ),
              ),
            ),
            Expanded(child: Padding(padding: padding, child: child)),
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QortDesignSystem.radiusMd),
        child: card,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QortStatChip
// ---------------------------------------------------------------------------

class QortStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const QortStatChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(QortDesignSystem.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: QortDesignSystem.display.copyWith(fontSize: 22, height: 1),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: QortDesignSystem.micro.copyWith(
                letterSpacing: 0.5,
                color: QortDesignSystem.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
