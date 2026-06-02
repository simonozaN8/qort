import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/qort_palette_extension.dart';
import '../../core/widgets/tournament_cover_color_filters.dart';

/// 4 spalvų variantai prieš cover patvirtinimą.
class TournamentCoverFilterPicker extends StatefulWidget {
  final String imageUrl;
  final void Function(String presetId) onConfirm;

  const TournamentCoverFilterPicker({
    super.key,
    required this.imageUrl,
    required this.onConfirm,
  });

  @override
  State<TournamentCoverFilterPicker> createState() =>
      _TournamentCoverFilterPickerState();
}

class _TournamentCoverFilterPickerState
    extends State<TournamentCoverFilterPicker> {
  String _selected = TournamentCoverColorFilters.original;

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SPALVŲ VARIANTAS',
            style: GoogleFonts.bebasNeue(
              fontSize: 22,
              color: p.textPrimary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: TournamentCoverColorFilters.filteredImage(
                imageUrl: widget.imageUrl,
                preset: _selected,
                imageBuilder: (url) => CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TournamentCoverColorFilters.presets.entries.map((e) {
              final selected = _selected == e.key;
              return ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 11)),
                selected: selected,
                onSelected: (_) => setState(() => _selected = e.key),
                selectedColor: p.primary.withValues(alpha: 0.35),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => widget.onConfirm(_selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD946EF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'PATVIRTINTI KAIP COVER',
              style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}
