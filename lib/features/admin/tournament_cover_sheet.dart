import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/sport_image_service.dart';
import '../../core/services/stock_image_service.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/widgets/stock_image_attribution.dart';
import '../../core/widgets/tournament_cover_color_filters.dart';
import 'tournament_cover_filter_picker.dart';

/// Bottom sheet: stock, AI šablonai, generavimas arba įkelti savo nuotrauką.
class TournamentCoverSheet extends StatefulWidget {
  /// Null = renginio kūrimas (be UPDATE tournaments); nurodytas = admin pultas.
  final String? tournamentId;
  final String sportCode;

  const TournamentCoverSheet({
    super.key,
    this.tournamentId,
    required this.sportCode,
  });

  @override
  State<TournamentCoverSheet> createState() => _TournamentCoverSheetState();
}

class _TournamentCoverSheetState extends State<TournamentCoverSheet> {
  final _stockQueryCtrl = TextEditingController();

  List<SportImageTemplate> _templates = [];
  List<StockImage> _stockImages = [];
  ImageGenerationQuota _quota = const ImageGenerationQuota(
    used: 0,
    limit: 3,
    isSuperAdmin: false,
  );
  bool _loadingList = false;
  bool _generating = false;
  bool _uploading = false;
  bool _stockSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPool();
  }

  @override
  void dispose() {
    _stockQueryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPool() async {
    setState(() {
      _loadingList = true;
      _error = null;
    });
    try {
      final result = await SportImageService.listPool(widget.sportCode);
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

  Future<void> _searchStock() async {
    setState(() {
      _stockSearching = true;
      _error = null;
    });
    try {
      final images = await StockImageService.search(
        sportCode: widget.sportCode,
        customQuery: _stockQueryCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _stockImages = images;
        _stockSearching = false;
      });
      if (images.isEmpty) {
        setState(() => _error = 'Nieko nerasta — pabandyk kitą paiešką.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stockSearching = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _generatePool() async {
    if (!_quota.canGenerate) {
      setState(() => _error = 'Pasiektas dienos limitas (${_quota.limit} generavimai).');
      return;
    }

    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final result = await SportImageService.generatePool(widget.sportCode);
      if (!mounted) return;
      setState(() {
        _templates = [...result.templates, ..._templates];
        _quota = result.quota;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _showFilterPickerAndApply({
    required String imageUrl,
    String? templateId,
    required String coverSource,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final p = ctx.qortPalette;
        return Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: TournamentCoverFilterPicker(
            imageUrl: imageUrl,
            onConfirm: (preset) async {
              Navigator.pop(ctx);
              await _saveCover(
                imageUrl: imageUrl,
                coverSource: coverSource,
                templateId: templateId,
                filterPreset: preset,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmStockImage(StockImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Patvirtinti vaizdą?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(image.imageUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Photo by ${image.photographer} · ${StockImageAttribution.capitalizeSource(image.source)}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Atšaukti'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Naudoti', style: TextStyle(color: Color(0xFFD946EF))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _saveCover(
      imageUrl: image.imageUrl,
      coverSource: 'stock_library',
      filterPreset: TournamentCoverColorFilters.original,
      imagePhotographer: image.photographer,
      imageSource: image.source,
      imageSourceUrl: image.sourceUrl,
    );
  }

  Future<void> _saveCover({
    required String imageUrl,
    required String coverSource,
    String? templateId,
    required String filterPreset,
    String? imagePhotographer,
    String? imageSource,
    String? imageSourceUrl,
  }) async {
    try {
      final payload = <String, dynamic>{
        'cover_source': coverSource,
        'image_url': imageUrl,
        'cover_filter_preset': filterPreset == TournamentCoverColorFilters.original
            ? null
            : filterPreset,
      };

      if (coverSource == 'ai_cache' && templateId != null) {
        payload['cover_template_id'] = templateId;
      } else {
        payload['cover_template_id'] = null;
      }

      if (coverSource == 'stock_library') {
        payload['image_photographer'] = imagePhotographer;
        payload['image_source'] = imageSource;
        payload['image_source_url'] = imageSourceUrl;
      } else {
        payload['image_photographer'] = null;
        payload['image_source'] = null;
        payload['image_source_url'] = null;
      }

      final tournamentId = widget.tournamentId;
      if (tournamentId != null && tournamentId.isNotEmpty) {
        await Supabase.instance.client
            .from('tournaments')
            .update(payload)
            .eq('id', tournamentId);
      }

      if (!mounted) return;
      Navigator.pop(context, {
        ...payload,
        'cover_filter_preset': payload['cover_filter_preset'],
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _onTemplateTap(SportImageTemplate template) {
    _showFilterPickerAndApply(
      imageUrl: template.imageUrl,
      templateId: template.id,
      coverSource: 'ai_cache',
    );
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
      final userId =
          Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final basePath = widget.tournamentId ?? 'draft/$userId';
      final path =
          '$basePath/organizer_${DateTime.now().millisecondsSinceEpoch}.$safeExt';

      await Supabase.instance.client.storage
          .from('tournament-images')
          .uploadBinary(path, bytes);

      final url = Supabase.instance.client.storage
          .from('tournament-images')
          .getPublicUrl(path);

      if (!mounted) return;
      setState(() => _uploading = false);

      await _showFilterPickerAndApply(
        imageUrl: url,
        coverSource: 'organizer_upload',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e.toString();
      });
    }
  }

  Widget _sectionTitle(String text) {
    final p = context.qortPalette;
    return Text(
      text,
      style: GoogleFonts.oswald(
        color: p.primary,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStockSection(bool busy) {
    final p = context.qortPalette;
  final crossCount = MediaQuery.sizeOf(context).width > 600 ? 3 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(LucideIcons.camera, color: p.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              'IEŠKOTI INTERNETE',
              style: GoogleFonts.oswald(
                color: p.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _stockQueryCtrl,
                enabled: !busy,
                style: TextStyle(color: p.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Pvz: trofėjus, stadione, raudonas fonas',
                  hintStyle: TextStyle(color: p.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: p.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: p.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onSubmitted: busy ? null : (_) => _searchStock(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: busy || _stockSearching ? null : _searchStock,
              style: ElevatedButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              child: _stockSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('IEŠKOTI'),
            ),
          ],
        ),
        if (_stockImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 16 / 11,
            ),
            itemCount: _stockImages.length,
            itemBuilder: (context, i) {
              final img = _stockImages[i];
              return InkWell(
                onTap: busy ? null : () => _confirmStockImage(img),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: img.thumbUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Photo by ${img.photographer} · ${StockImageAttribution.capitalizeSource(img.source)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.textSecondary, fontSize: 8),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final busy = _loadingList || _generating || _uploading || _stockSearching;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'TURNYRO VAIZDAS',
                style: GoogleFonts.bebasNeue(
                  fontSize: 24,
                  color: p.textPrimary,
                  letterSpacing: 1,
                ),
              ),
              Text(
                widget.sportCode,
                style: TextStyle(color: p.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                _quota.label,
                style: TextStyle(
                  color: _quota.canGenerate ? p.textSecondary : Colors.orangeAccent,
                  fontSize: 11,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 20),
              Text(
                'STOCK BIBLIOTEKOS',
                style: GoogleFonts.oswald(
                  color: p.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildStockSection(busy),
              _sectionTitle('PASIRINK IŠ ESAMŲ'),
              const SizedBox(height: 10),
              if (_loadingList)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_templates.isEmpty)
                Text(
                  'Pool tuščias — sugeneruok naujus žemiau.',
                  style: TextStyle(color: p.textSecondary, fontSize: 12),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: _templates.length,
                  itemBuilder: (context, i) {
                    final t = _templates[i];
                    return InkWell(
                      onTap: busy ? null : () => _onTemplateTap(t),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: t.imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (t.styleTag != null)
                            Positioned(
                              left: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                color: Colors.black54,
                                child: Text(
                                  t.styleTag!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              _sectionTitle('GENERUOTI NAUJUS'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
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
                  label: Text(
                    _generating
                        ? 'Generuojama (20–40 s)…'
                        : 'Generuoti 3 naujus į pool',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD946EF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('ĮKELTI SAVO NUOTRAUKĄ'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _pickAndUpload,
                  icon: _uploading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.primary,
                          ),
                        )
                      : const Icon(LucideIcons.upload, size: 18),
                  label: const Text('Pasirinkti iš galerijos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.primary,
                    side: BorderSide(color: p.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
