import 'package:flutter/material.dart';

import '../constants/app_shell_layout.dart';
import '../theme/qort_palette_extension.dart';
import '../theme/qort_theme.dart';

/// Standartinis tab turinys (be dubliuojančio AppBar — viršuje jau MainWrapper).
class QortShellPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;

  const QortShellPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.onRefresh,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: QortTheme.sectionTitle(context.qortPalette),
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: p.background,
      floatingActionButton: floatingActionButton,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: onRefresh != null
              ? RefreshIndicator(
                  color: p.primary,
                  onRefresh: onRefresh!,
                  child: body,
                )
              : body,
        ),
      ),
    );
  }

  static Widget scrollBottomSpacer(BuildContext context) {
    return SizedBox(height: AppShellLayout.scrollBottomPadding(context));
  }
}
