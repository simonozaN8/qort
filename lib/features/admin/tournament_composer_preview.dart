import 'package:flutter/material.dart';

class TournamentComposerPreview extends StatelessWidget {
  final Widget composer;
  final Widget? sponsorBand;

  const TournamentComposerPreview({
    super.key,
    required this.composer,
    this.sponsorBand,
  });

  static double previewWidthFor(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth > 600 ? 420.0 : (screenWidth - 32).clamp(280, 600);
  }

  static Future<void> showFullScreenPreview(
    BuildContext context,
    Widget composer,
    Widget? sponsorBand,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final width = MediaQuery.of(ctx).size.width;
        final dialogWidth = width > 900 ? 900.0 : width - 24;
        return Dialog(
          backgroundColor: const Color(0xFF0B0B0F),
          insetPadding: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: dialogWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      composer,
                      if (sponsorBand != null) sponsorBand,
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Uždaryti'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = previewWidthFor(context);

    return Column(
      children: [
        Center(
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                composer,
                if (sponsorBand != null) sponsorBand!,
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.fullscreen, size: 18),
            label: const Text('Žiūrėti dideliame ekrane'),
            onPressed: () => showFullScreenPreview(context, composer, sponsorBand),
          ),
        ),
      ],
    );
  }
}

