import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/services/sport_image_service.dart';
import '../../core/services/sports_catalog_service.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_palette_extension.dart';

/// Admin: sporto šakos AI vaizdų pool peržiūra ir generavimas.
class SportImagePoolScreen extends StatefulWidget {
  const SportImagePoolScreen({super.key});

  @override
  State<SportImagePoolScreen> createState() => _SportImagePoolScreenState();
}

class _SportImagePoolScreenState extends State<SportImagePoolScreen> {
  List<String> _sportOptions = ['Tenisas'];
  String _selectedSport = 'Tenisas';
  List<SportImageTemplate> _templates = [];
  ImageGenerationQuota _quota = const ImageGenerationQuota(
    used: 0,
    limit: 3,
    isSuperAdmin: false,
  );
  bool _loadingSports = true;
  bool _loadingList = false;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSports();
  }

  Future<void> _loadSports() async {
    setState(() {
      _loadingSports = true;
      _error = null;
    });
    try {
      final names = await SportsCatalogService.activeSportNames();
      if (!mounted) return;
      setState(() {
        _sportOptions = names.isNotEmpty ? names : ['Tenisas'];
        if (!_sportOptions.contains(_selectedSport)) {
          _selectedSport = _sportOptions.first;
        }
        _loadingSports = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSports = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadPool() async {
    setState(() {
      _loadingList = true;
      _error = null;
    });
    try {
      final result = await SportImageService.listPool(_selectedSport);
      if (!mounted) return;
      setState(() {
        _templates = result.templates;
        _quota = result.quota;
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _generatePool() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final result = await SportImageService.generatePool(_selectedSport);
      if (!mounted) return;
      setState(() {
        _templates = [...result.templates, ..._templates];
        _quota = result.quota;
        _generating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sugeneruota ${result.templates.length} naujų variantų'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  Color _chipColor(String? tag, dynamic palette) {
    switch (tag) {
      case 'trophy_hero':
        return Colors.amber;
      case 'podium_scene':
        return Colors.indigo;
      case 'trophy_minimal':
        return Colors.blueGrey;
      case 'trophy_focus':
        return Colors.amber;
      case 'stadium_atmosphere':
        return Colors.indigo;
      case 'action_photo':
        return Colors.orange;
      case 'minimal_art':
        return Colors.blueGrey;
      case 'cinematic_night':
        return Colors.deepPurple;
      case 'energetic':
        return Colors.orange;
      case 'minimal':
        return Colors.blueGrey;
      case 'dark':
        return Colors.deepPurple;
      default:
        return palette.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final busy = _loadingList || _generating;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        title: Text(
          'AI SPORTO VAIZDAI',
          style: GoogleFonts.bebasNeue(
            color: p.textPrimary,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Generuok ir peržiūrėk 16:9 šablonus sporto šakoms (Gemini). '
              'Naudojama turnyrų viršelėms — kūrimo flow bus vėliau.',
              style: TextStyle(color: p.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (_loadingSports)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedSport),
                initialValue: _selectedSport,
                dropdownColor: p.surface,
                style: TextStyle(color: p.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Sporto šaka',
                  labelStyle: TextStyle(color: p.textSecondary),
                  filled: true,
                  fillColor: p.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: p.border),
                  ),
                ),
                items: _sportOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: busy
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() {
                          _selectedSport = v;
                          _templates = [];
                        });
                      },
              ),
            const SizedBox(height: 8),
            Text(
              _quota.label,
              style: TextStyle(
                color: _quota.canGenerate ? p.textSecondary : Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _loadPool,
                    icon: const Icon(LucideIcons.folderOpen, size: 18),
                    label: const Text('Užkrauti esamus'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.primary,
                      side: BorderSide(color: p.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy || !_quota.canGenerate ? null : _generatePool,
                    icon: _generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.sparkles, size: 18),
                    label: Text(_generating ? 'Generuojama…' : 'Generuoti 3 naujus'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD946EF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_generating) ...[
              const SizedBox(height: 12),
              Text(
                'Gemini generuoja 3 variantus — tai gali užtrukti 20–40 sek.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textSecondary, fontSize: 12),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_loadingList)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_templates.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  children: [
                    Icon(LucideIcons.imageOff, color: p.textSecondary, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Nėra šablonų šiai sporto šakai.\nPaspausk „Generuoti 3 naujus“.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.textSecondary),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: _templates.length,
                itemBuilder: (context, index) {
                  final t = _templates[index];
                  return _TemplateTile(
                    template: t,
                    chipColor: _chipColor(t.styleTag, p),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final SportImageTemplate template;
  final Color chipColor;

  const _TemplateTile({
    required this.template,
    required this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: template.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: QortColors.surface),
            errorWidget: (_, __, ___) => const ColoredBox(
              color: QortColors.surface,
              child: Icon(Icons.broken_image, color: QortColors.textSecondary),
            ),
          ),
          if (template.styleTag != null && template.styleTag!.isNotEmpty)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  template.styleTag!,
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
