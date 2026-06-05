import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../../core/constants/tournament_links.dart';
import '../../core/services/event_sponsor_service.dart';
import '../../core/services/pricing_tier_service.dart';
import 'tournament_composer_widget.dart';
import 'tournament_sponsor_band.dart';

/// Dalinimasis: PNG eksportas ir nuoroda (be QR).
Future<void> showTournamentComposerShareSheet({
  required BuildContext context,
  required String tournamentId,
  required TournamentComposerWidget composer,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TournamentComposerShareSheet(
      tournamentId: tournamentId,
      composer: composer,
    ),
  );
}

class _TournamentComposerShareSheet extends StatefulWidget {
  final String tournamentId;
  final TournamentComposerWidget composer;

  const _TournamentComposerShareSheet({
    required this.tournamentId,
    required this.composer,
  });

  @override
  State<_TournamentComposerShareSheet> createState() =>
      _TournamentComposerShareSheetState();
}

class _TournamentComposerShareSheetState
    extends State<_TournamentComposerShareSheet> {
  final GlobalKey _exportKey = GlobalKey();
  Uint8List? _pngBytes;
  bool _exporting = false;
  String? _error;
  Map<String, dynamic>? _event;
  List<dynamic> _tournaments = [];
  List<EventSponsor> _eventSponsors = [];
  bool _loadingEvent = true;
  String? _feedbackMessage;
  bool _feedbackIsError = false;

  String get _eventId => _event?['id']?.toString() ?? '';
  String get _shareUrl =>
      _eventId.isEmpty ? '' : TournamentLinks.eventUrl(_eventId);

  bool get _isIOSPWA {
    if (!kIsWeb) return false;
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      final isIOS = ua.contains('iphone') || ua.contains('ipad');
      final isStandalone =
          html.window.matchMedia('(display-mode: standalone)').matches;
      return isIOS && isStandalone;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadEvent();
      await _capturePng();
    });
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _feedbackMessage = message;
      _feedbackIsError = isError;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _feedbackMessage = null);
      }
    });
  }

  Widget? _buildFeedbackBanner() {
    if (_feedbackMessage == null) return null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _feedbackIsError ? Colors.red.shade900 : Colors.green.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _feedbackIsError ? Icons.error : Icons.check_circle,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _feedbackMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  TournamentComposerWidget get _composerForShare {
    final eventName = _event?['name']?.toString();
    final eventSport = _event?['sport']?.toString();
    final eventLocation = _event?['location']?.toString();
    final eventDesc = _event?['description']?.toString();
    final eventOrg = _event?['organizer']?.toString();
    final startDate = _event?['start_date'] != null
        ? DateTime.tryParse(_event!['start_date'].toString())
        : null;
    final endDate = _event?['end_date'] != null
        ? DateTime.tryParse(_event!['end_date'].toString())
        : null;

    final levels = _tournaments.whereType<Map>().map((t) {
      final tName = t['name']?.toString() ?? '';
      final level = TournamentLevelInfo.stripEventPrefix(
        tournamentName: tName,
        eventName: eventName ?? '',
      );
      return TournamentLevelInfo(
        levelName: level,
        formatCode: t['format_code']?.toString() ?? '1v1',
        gender: t['gender']?.toString(),
        minRp: (t['min_rp'] as num?)?.toInt() ?? 0,
        maxRp: (t['max_rp'] as num?)?.toInt() ?? 3000,
      );
    }).toList();

    List<PricingTier>? tiers;
    if (_event != null) {
      final resolved = PricingTierService.resolveForEvent(
        Map<String, dynamic>.from(_event!),
      );
      if (resolved.isNotEmpty) tiers = resolved;
    }

    final mainList = _eventSponsors.where((s) => s.isMain).toList();
    final EventSponsor? mainSponsor = mainList.isNotEmpty ? mainList.first : null;
    final extraSponsors = _eventSponsors.where((s) => !s.isMain).toList();

    return TournamentComposerWidget(
      imageUrl: widget.composer.imageUrl,
      imageFile: widget.composer.imageFile,
      imageBytes: widget.composer.imageBytes,
      eventName: eventName ?? widget.composer.eventName,
      sport: eventSport ?? widget.composer.sport,
      location: eventLocation ?? widget.composer.location,
      startDate: startDate ?? widget.composer.startDate,
      endDate: endDate ?? widget.composer.endDate,
      pricingTiers: tiers ?? widget.composer.pricingTiers,
      price: tiers == null ? widget.composer.price : null,
      description: eventDesc ?? widget.composer.description,
      organizerName: eventOrg ?? widget.composer.organizerName,
      levels: levels.isNotEmpty ? levels : widget.composer.levels,
      mainSponsor: mainSponsor ?? widget.composer.mainSponsor,
      extraSponsors:
          _eventSponsors.isNotEmpty ? extraSponsors : widget.composer.extraSponsors,
      flipHorizontal: widget.composer.flipHorizontal,
      colorFilterPreset: widget.composer.colorFilterPreset,
    );
  }

  Future<void> _loadEvent() async {
    setState(() {
      _loadingEvent = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final t = await client
          .from('tournaments')
          .select('id, event_id')
          .eq('id', widget.tournamentId)
          .single();
      final eventId = t['event_id']?.toString();
      if (eventId == null || eventId.isEmpty) {
        throw Exception('Turnyras neturi event_id');
      }
      final e = await client
          .from('events')
          .select('*, tournaments(*), event_sponsors(*), pricing_tiers(*)')
          .eq('id', eventId)
          .single();
      final tournaments = (e['tournaments'] as List?) ?? const [];
      final sponsorsRaw = (e['event_sponsors'] as List?) ?? const [];
      final sponsors = sponsorsRaw
          .whereType<Map>()
          .map((j) => EventSponsor.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      if (!mounted) return;
      setState(() {
        _event = Map<String, dynamic>.from(e as Map);
        _tournaments = tournaments;
        _eventSponsors = sponsors;
        _loadingEvent = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEvent = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _capturePng() async {
    if (_loadingEvent) {
      await _loadEvent();
    }
    if (!mounted) return;

    setState(() {
      _exporting = true;
      _error = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 400));
      final boundary =
          _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Nepavyko paruošti peržiūros eksportui');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('PNG konvertavimas nepavyko');

      if (!mounted) return;
      setState(() {
        _pngBytes = byteData.buffer.asUint8List();
        _exporting = false;
      });
    } catch (e, st) {
      debugPrint('Capture klaida: $e\n$st');
      if (mounted) {
        setState(() {
          _exporting = false;
          _error = 'Klaida: $e';
        });
        _showFeedback('Nepavyko paruošti PNG: $e', isError: true);
      }
    }
  }

  Future<File?> _writePngToTemp() async {
    if (_pngBytes == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/qort_tournament_${widget.tournamentId}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(_pngBytes!);
    return file;
  }

  Future<void> _downloadPng() async {
    try {
      if (_pngBytes == null) {
        await _capturePng();
      }
      if (_pngBytes == null) {
        _showFeedback('Nepavyko paruošti vaizdo', isError: true);
        return;
      }

      if (kIsWeb) {
        final blob = html.Blob([_pngBytes!], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'qort_${_eventId.isNotEmpty ? _eventId : widget.tournamentId}.png',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
        _showFeedback('PNG atsisiųstas');
      } else {
        final file = await _writePngToTemp();
        if (file == null) {
          _showFeedback('Nepavyko sukurti failo', isError: true);
          return;
        }
        final shareText = _shareUrl.isEmpty
            ? 'QORT turnyro plakatas'
            : 'Pažiūrėk šį turnyrą: $_shareUrl';
        final result = await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/png')],
          text: shareText,
        );
        if (result.status == ShareResultStatus.success) {
          _showFeedback('Pasidalinta');
        }
      }
    } catch (e, st) {
      debugPrint('Download klaida: $e\n$st');
      _showFeedback('Klaida atsisiunčiant: $e', isError: true);
    }
  }

  void _showCopyDialog(String text) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Nukopijuok nuorodą rankiniu būdu',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isIOSPWA
                  ? 'iOS programėlėje kopijavimas ribotas. Pažymėk tekstą žemiau:'
                  : 'Pažymėk nuorodą žemiau ir nukopijuok:',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Uždaryti'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyLink() async {
    if (_shareUrl.isEmpty) {
      _showFeedback('Renginys dar kraunamas, palauk...');
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: _shareUrl));
      _showFeedback('Nuoroda nukopijuota');
      return;
    } catch (e) {
      debugPrint('Flutter Clipboard fail: $e');
    }

    if (kIsWeb) {
      try {
        final textarea = html.TextAreaElement()
          ..value = _shareUrl
          ..style.position = 'fixed'
          ..style.left = '-9999px';
        html.document.body?.append(textarea);
        textarea.select();
        final success = html.document.execCommand('copy');
        textarea.remove();

        if (success) {
          _showFeedback('Nuoroda nukopijuota');
          return;
        }
      } catch (e) {
        debugPrint('execCommand fail: $e');
      }
    }

    try {
      final result = await Share.share(
        _shareUrl,
        subject: 'QORT turnyras',
      );
      debugPrint('Share result: ${result.status}, ${result.raw}');
      if (result.status == ShareResultStatus.success) {
        _showFeedback('Pasidalinta');
      }
      return;
    } catch (e) {
      debugPrint('share_plus fail: $e');
    }

    _showCopyDialog(_shareUrl);
  }

  Future<void> _sharePng() async {
    try {
      if (_pngBytes == null) {
        await _capturePng();
      }
      if (_pngBytes == null) {
        _showFeedback('Nepavyko paruošti vaizdo', isError: true);
        return;
      }

      final shareText = _shareUrl.isEmpty
          ? 'QORT turnyro plakatas'
          : 'Pažiūrėk šį turnyrą: $_shareUrl';

      try {
        if (kIsWeb) {
          final result = await Share.share(
            shareText,
            subject: 'QORT turnyras',
          );

          debugPrint('Share result: ${result.status}, ${result.raw}');

          if (result.status == ShareResultStatus.success) {
            _showFeedback('Pasidalinta');
          } else if (result.status == ShareResultStatus.dismissed) {
            // Vartotojas atšaukė — tylėti
          } else {
            _showFeedback('Share nepalaikomas — naudok dialogą žemiau');
            _showCopyDialog(shareText);
          }
          return;
        } else {
          final file = await _writePngToTemp();
          if (file == null) {
            _showFeedback('Nepavyko sukurti failo', isError: true);
            return;
          }

          final result = await Share.shareXFiles(
            [XFile(file.path, mimeType: 'image/png')],
            text: shareText,
            subject: 'QORT turnyras',
          );

          if (result.status == ShareResultStatus.success) {
            _showFeedback('Pasidalinta');
          }
          return;
        }
      } catch (e) {
        debugPrint('share_plus klaida: $e');
      }

      _showCopyDialog(shareText);
    } catch (e, st) {
      debugPrint('Share klaida: $e\n$st');
      _showFeedback('Klaida: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedbackBanner = _buildFeedbackBanner();

    return Container(
      margin: const EdgeInsets.only(top: 40),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DALINTIS SOC TINKLUOSE',
              style: GoogleFonts.bebasNeue(
                color: Colors.white,
                fontSize: 22,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            RepaintBoundary(
              key: _exportKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _composerForShare,
                  TournamentSponsorBand(
                    compact: false,
                    mainSponsor: (() {
                      final main =
                          _eventSponsors.where((s) => s.isMain).toList();
                      return main.isNotEmpty ? main.first : null;
                    })(),
                    extraSponsors:
                        _eventSponsors.where((s) => !s.isMain).toList(),
                  ),
                ],
              ),
            ),
            if (_loadingEvent)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_exporting)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (_pngBytes != null && !_exporting) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_pngBytes!, fit: BoxFit.contain),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _shareUrl.isEmpty ? '...' : _shareUrl,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 16),
            if (feedbackBanner != null) feedbackBanner,
            ElevatedButton.icon(
              onPressed: _downloadPng,
              icon: const Icon(LucideIcons.download, size: 18),
              label: const Text('Atsisiųsti PNG'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD946EF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _copyLink,
              icon: const Icon(LucideIcons.link, size: 18),
              label: const Text('Kopijuoti nuorodą'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD946EF),
                side: const BorderSide(color: Color(0xFFD946EF)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (!_isIOSPWA) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _sharePng,
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Bendrinti'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
            if (_isIOSPWA)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 12,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFEAB308),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'iOS programėlėje: atsisiųsk PNG ir nukopijuok '
                          'nuorodą, tada įkelk į Instagram, Facebook ar '
                          'kitą tinklą rankomis.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
