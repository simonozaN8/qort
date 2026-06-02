import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/tournament_links.dart';
import '../../core/services/event_sponsor_service.dart';
import 'tournament_composer_widget.dart';
import 'tournament_sponsor_band.dart';

/// Dalinimasis: PNG eksportas (16:9 + QR) ir nuoroda.
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

  String get _eventId => _event?['id']?.toString() ?? '';
  String get _shareUrl =>
      _eventId.isEmpty ? '' : TournamentLinks.eventUrl(_eventId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadEvent();
      await _capturePng();
    });
  }

  TournamentComposerWidget get _composerWithQr {
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

    double? price;
    if (_tournaments.isNotEmpty) {
      final first = _tournaments.first;
      if (first is Map && first['entry_fee'] != null) {
        price = (first['entry_fee'] as num).toDouble();
      }
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
      price: price ?? widget.composer.price,
      description: eventDesc ?? widget.composer.description,
      organizerName: eventOrg ?? widget.composer.organizerName,
      levels: levels.isNotEmpty ? levels : widget.composer.levels,
      mainSponsor: mainSponsor ?? widget.composer.mainSponsor,
      extraSponsors: _eventSponsors.isNotEmpty ? extraSponsors : widget.composer.extraSponsors,
      qrUrl: _shareUrl,
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
          .select('*, tournaments(*), event_sponsors(*)')
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
    if (_loadingEvent) return;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _error = e.toString();
      });
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
    if (_pngBytes == null) return;
    final file = await _writePngToTemp();
    if (file == null || !mounted) return;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: 'QORT turnyro plakatas',
    );
  }

  Future<void> _copyLink() async {
    if (_shareUrl.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _shareUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nuoroda nukopijuota')),
    );
  }

  Future<void> _sharePng() async {
    if (_pngBytes == null) return;
    final file = await _writePngToTemp();
    if (file == null) return;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text:
          'QORT: ${_event?['name']?.toString() ?? widget.composer.eventName}\n$_shareUrl',
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  _composerWithQr,
                  TournamentSponsorBand(
                    compact: false,
                    mainSponsor: (() {
                      final main = _eventSponsors.where((s) => s.isMain).toList();
                      return main.isNotEmpty ? main.first : null;
                    })(),
                    extraSponsors: _eventSponsors.where((s) => !s.isMain).toList(),
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
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
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
            ElevatedButton.icon(
              onPressed: _pngBytes == null ? null : _downloadPng,
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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pngBytes == null ? null : _sharePng,
              icon: const Icon(LucideIcons.share2, size: 18),
              label: const Text('Bendrinti'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
