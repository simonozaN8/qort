import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/config/gemini_config.dart';
import '../../core/services/gemini_visual_service.dart';
import '../../core/theme/qort_mode_colors.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/widgets/qort_section_header.dart';

/// AI vizualų studija — Gemini Flash 2.5 ekranų generavimas.
class GeminiVisualStudioScreen extends StatefulWidget {
  const GeminiVisualStudioScreen({super.key});

  @override
  State<GeminiVisualStudioScreen> createState() =>
      _GeminiVisualStudioScreenState();
}

class _GeminiVisualStudioScreenState extends State<GeminiVisualStudioScreen> {
  final _promptCtrl = TextEditingController(
    text: 'Sukurk treniruočių atvirų mačų sąrašo ekraną su hero, filtrais ir 3 skelbimų kortelėmis.',
  );
  bool _loading = false;
  QortVisualSpec? _spec;
  Uint8List? _heroImage;
  String? _status;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Color _accentFromSpec(QortVisualSpec spec) {
    try {
      final hex = spec.accentHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return QortModeColors.competition;
    }
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _status = null;
      _spec = null;
      _heroImage = null;
    });

    final result = await GeminiVisualService.generateScreenSpec(
      _promptCtrl.text.trim(),
    );

    if (!mounted) return;

    if (!result.ok || result.spec == null) {
      setState(() {
        _loading = false;
        _status = result.message;
      });
      return;
    }

    setState(() {
      _spec = result.spec;
      _status = result.message;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text(
          'AI vizualų studija',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.sparkles,
                  color: GeminiConfig.isConfigured ? p.primary : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    GeminiConfig.isConfigured
                        ? 'Gemini Flash 2.5 — aprašykite ekraną lietuviškai.'
                        : 'Pridėkite GEMINI_API_KEY per --dart-define paleidimui.',
                    style: TextStyle(color: p.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Ekrano aprašymas',
              hintText: 'Pvz.: Blitz reitingų lentelė su hero ir TOP 5 žaidėjais',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading || !GeminiConfig.isConfigured ? null : _generate,
            icon: _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.surface,
                    ),
                  )
                : const Icon(LucideIcons.wand2),
            label: Text(
              'Generuoti vizualą',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _spec != null
                    ? p.primary.withValues(alpha: 0.08)
                    : Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _spec != null
                      ? p.primary.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                _status!,
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (_spec != null) ...[
            const SizedBox(height: 24),
            _PreviewCard(spec: _spec!, heroImage: _heroImage),
          ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final QortVisualSpec spec;
  final Uint8List? heroImage;

  const _PreviewCard({required this.spec, this.heroImage});

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final accent = _parseHex(spec.accentHex);

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 120,
            child: heroImage != null
                ? Image.memory(heroImage!, fit: BoxFit.cover)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          p.background,
                          accent.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spec.mode.toUpperCase(),
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            spec.title.toUpperCase(),
                            style: GoogleFonts.bebasNeue(
                              fontSize: 24,
                              color: p.textPrimary,
                            ),
                          ),
                          Text(
                            spec.subtitle,
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in spec.sections) ...[
                  QortSectionHeader(title: section.label, accent: accent),
                  const SizedBox(height: 8),
                  QortAccentCard(
                    accent: accent,
                    child: Text(
                      section.body,
                      style: TextStyle(color: p.textPrimary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _parseHex(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return QortModeColors.competition;
    }
  }
}
