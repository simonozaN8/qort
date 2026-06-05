import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_mode_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tournament_detail_screen.dart';
import '../../core/widgets/stock_image_attribution.dart';
import '../admin/tournament_composer_widget.dart';
import '../../core/services/event_sponsor_service.dart';
import '../../core/services/pricing_tier_service.dart';
import '../../core/utils/datetime_utils.dart';
import '../admin/tournament_sponsor_band.dart';

/// Varžybų lygio prioritetas sąrašui (žemiausias → aukščiausias).
const _levelOrder = {
  'LIGHT': 1,
  'MIDDLE': 2,
  'HARD': 3,
  'PRO': 4,
  'ELITE': 5,
  'D': 1,
  'D/C': 2,
  'C/B': 3,
  'B/A': 4,
  'A': 5,
  'MĖGĖJAI': 1,
  'PAŽENGĘ': 2,
  'START': 1,
  'PRADEDANTYS': 1,
};

int _getLevelPriority(String name, String eventName) {
  var stripped = name;
  if (eventName.isNotEmpty && stripped.startsWith('$eventName - ')) {
    stripped = stripped.replaceFirst('$eventName - ', '');
  }
  stripped = stripped.toUpperCase().trim();
  return _levelOrder[stripped] ?? 99;
}

void _sortDivisionsByLevel(List<dynamic> divisions, String eventName) {
  divisions.sort((a, b) {
    final aName = a is Map ? a['name']?.toString() ?? '' : '';
    final bName = b is Map ? b['name']?.toString() ?? '' : '';
    return _getLevelPriority(aName, eventName)
        .compareTo(_getLevelPriority(bName, eventName));
  });
}

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final bool previewMode;

  const EventDetailScreen({
    super.key,
    required this.event,
    this.previewMode = false,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoading = true;
  List<dynamic> _divisions = [];
  Map<String, dynamic>? _event;
  List<EventSponsor> _eventSponsors = [];
  List<PricingTier> _pricingTiers = [];

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  double? _getEventEntryPrice() {
    return PricingTierService.currentPrice(_pricingTiers);
  }

  DateTime? _parseEventDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatFullDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null) return '—';
    if (end == null || _isSameDay(start, end)) {
      return _formatFullDate(start);
    }
    return '${_formatFullDate(start)} → ${_formatFullDate(end)}';
  }

  String _formatTierFullLabel(PricingTier tier) {
    final price = tier.price.toStringAsFixed(0);

    if (tier.validUntil == null) {
      return '${tier.name}: $price€';
    }

    final d = tier.validUntil!;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '${tier.name}: $price€ (iki $dateStr)';
  }

  bool _isTierActive(PricingTier tier, PricingTier? effectiveTier) {
    if (effectiveTier == null) return false;
    return tier.id.isNotEmpty
        ? tier.id == effectiveTier.id
        : tier.displayOrder == effectiveTier.displayOrder &&
            tier.name == effectiveTier.name;
  }

  Widget _buildPricingSection() {
    if (_pricingTiers.isEmpty) {
      return _infoRow(
        icon: LucideIcons.banknote,
        text: 'Kaina nenurodyta',
      );
    }

    final now = DateTime.now();
    final visibleTiers = _pricingTiers
        .where((t) => t.validUntil == null || t.validUntil!.isAfter(now))
        .toList();

    if (visibleTiers.isEmpty) {
      return _infoRow(
        icon: LucideIcons.banknote,
        text: 'Registracija uždaryta',
      );
    }

    visibleTiers.sort((a, b) {
      if (a.validUntil == null) return 1;
      if (b.validUntil == null) return -1;
      return a.validUntil!.compareTo(b.validUntil!);
    });

    final effectiveTier = PricingTierService.getEffectiveTier(visibleTiers);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.banknote, color: Color(0xFFEAB308), size: 18),
            SizedBox(width: 10),
            Text(
              'KAINOS:',
              style: TextStyle(
                color: Color(0xFFEAB308),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: visibleTiers.map((tier) {
              final isActive = _isTierActive(tier, effectiveTier);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      isActive
                          ? LucideIcons.flame
                          : (tier.validUntil != null
                              ? LucideIcons.clock
                              : LucideIcons.banknote),
                      color: isActive ? Colors.green : Colors.white54,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatTierFullLabel(tier),
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.white70,
                          fontSize: 14,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  DateTime? _parseDeadline(dynamic deadline) {
    if (deadline == null) return null;
    if (deadline is DateTime) return deadline.toLocal();
    try {
      return DateTimeUtils.fromIso(deadline.toString());
    } catch (_) {
      return DateTime.tryParse(deadline.toString())?.toLocal();
    }
  }

  bool _isDeadlineUrgent(dynamic deadline) {
    final dt = _parseDeadline(deadline);
    if (dt == null) return false;
    final daysLeft = dt.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 7;
  }

  (EventSponsor?, List<EventSponsor>) _sponsorsForPreview() {
    final mainList = _eventSponsors.where((s) => s.isMain).toList();
    final EventSponsor? main = mainList.isNotEmpty ? mainList.first : null;
    final extras = _eventSponsors.where((s) => !s.isMain).toList();
    return (main, extras);
  }

  Future<void> _loadEvent() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final eventId = widget.event['id'];
      final fresh = await client
          .from('events')
          .select(
            '*, tournaments(*, tournament_participants(count)), event_sponsors(*), pricing_tiers(*)',
          )
          .eq('id', eventId)
          .single();

      final tournaments = (fresh['tournaments'] as List?) ?? const [];
      final sponsorsRaw = (fresh['event_sponsors'] as List?) ?? const [];
      final sponsors = sponsorsRaw
          .whereType<Map>()
          .map((j) => EventSponsor.fromJson(Map<String, dynamic>.from(j)))
          .toList();

      if (mounted) {
        final eventMap = Map<String, dynamic>.from(fresh as Map);
        final sortedDivisions = List<dynamic>.from(tournaments);
        _sortDivisionsByLevel(
          sortedDivisions,
          eventMap['name']?.toString() ?? '',
        );
        final tiersFromDb = PricingTierService.parseList(eventMap['pricing_tiers']);
        final tiers = tiersFromDb.isNotEmpty
            ? tiersFromDb
            : PricingTierService.resolveForEvent(eventMap);

        setState(() {
          _event = eventMap;
          _divisions = sortedDivisions;
          _eventSponsors = sponsors;
          _pricingTiers = tiers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw.toString();
    }
  }

  Future<void> _launchUri(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Nepavyko atidaryti: $uri, $e');
    }
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
    Color? textColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: QortModeColors.competition, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRowClickable({
    required IconData icon,
    required String text,
    required double indent,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: QortModeColors.competition, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventInfoCard(Map<String, dynamic> e) {
    final email = e['organizer_email']?.toString().trim();
    final phone = e['organizer_phone']?.toString().trim();
    final organizer = e['organizer']?.toString().trim();
    final sport = e['sport']?.toString().trim();
    final location = e['location']?.toString().trim();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sport != null && sport.isNotEmpty) ...[
            _infoRow(
              icon: LucideIcons.trophy,
              text: 'Sportas: $sport',
            ),
            const SizedBox(height: 12),
          ],
          _infoRow(
            icon: LucideIcons.mapPin,
            text: location != null && location.isNotEmpty
                ? 'Vieta: $location'
                : 'Vieta: Nenurodyta',
          ),
          const SizedBox(height: 12),
          _infoRow(
            icon: LucideIcons.calendar,
            text:
                'Datos: ${_formatDateRange(_parseEventDate(e['start_date']), _parseEventDate(e['end_date']))}',
          ),
          const SizedBox(height: 12),
          _buildPricingSection(),
          if (e['registration_deadline'] != null) ...[
            const SizedBox(height: 12),
            _infoRow(
              icon: LucideIcons.clock,
              text:
                  'Registracija iki: ${_formatDate(e['registration_deadline'])}',
              textColor: _isDeadlineUrgent(e['registration_deadline'])
                  ? Colors.redAccent
                  : null,
            ),
          ],
          const SizedBox(height: 12),
          _infoRow(
            icon: LucideIcons.user,
            text:
                'Organizatorius: ${organizer != null && organizer.isNotEmpty ? organizer : 'Nenurodyta'}',
          ),
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRowClickable(
              icon: LucideIcons.mail,
              text: email,
              indent: 28,
              onTap: () => _launchUri(Uri.parse('mailto:$email')),
            ),
          ],
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRowClickable(
              icon: LucideIcons.phone,
              text: phone,
              indent: 28,
              onTap: () => _launchUri(Uri.parse('tel:$phone')),
            ),
          ],
        ],
      ),
    );
  }

  int _divisionParticipantCount(Map<String, dynamic> tournament) {
    final participants =
        (tournament['tournament_participants'] as List?) ?? [];
    if (participants.isEmpty) return 0;
    final first = participants.first;
    if (first is Map) {
      return (first['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Widget _buildDivisionCard({
    required Map<String, dynamic> div,
    required String divName,
    required int price,
  }) {
    final currentCount = _divisionParticipantCount(div);
    final maxParticipants = (div['max_participants'] as num?)?.toInt() ?? 0;
    final participantsText = maxParticipants > 0
        ? '$currentCount / $maxParticipants dalyvių'
        : '$currentCount dalyvių';

    return GestureDetector(
      onTap: widget.previewMode
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TournamentDetailScreen(
                    tournament: div,
                  ),
                ),
              );
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: QortColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: QortModeColors.competition.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: QortModeColors.competition.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    divName.toUpperCase(),
                    style: GoogleFonts.oswald(
                      color: QortColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${div['gender_category'] ?? 'Atvira'} • ${div['team_format'] ?? '1v1'}",
                    style: const TextStyle(
                      color: QortColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.users,
                        color: Color(0xFFEAB308),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        participantsText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price > 0 ? "$price €" : "NEMOKAMA",
                  style: GoogleFonts.bebasNeue(
                    color: Colors.greenAccent,
                    fontSize: 20,
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  color: QortColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesSection(Map<String, dynamic> e) {
    final rules = e['rules']?.toString() ?? '';
    if (rules.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.fileText, color: Color(0xFFEAB308), size: 18),
              SizedBox(width: 8),
              Text(
                'TURNYRO TAISYKLĖS',
                style: TextStyle(
                  color: Color(0xFFEAB308),
                  fontFamily: 'Anton',
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRulesPreview(rules),
        ],
      ),
    );
  }

  Widget _buildRulesPreview(String rules) {
    final isLong = rules.length > 200;
    final preview = isLong ? '${rules.substring(0, 200)}...' : rules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          preview,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        if (isLong) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showFullRules(rules),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFEAB308).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.maximize2,
                    color: Color(0xFFEAB308),
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Skaityti pilnas taisykles',
                    style: TextStyle(
                      color: Color(0xFFEAB308),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showFullRules(String rules) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.fileText, color: Color(0xFFEAB308)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'TURNYRO TAISYKLĖS',
                      style: TextStyle(
                        color: Color(0xFFEAB308),
                        fontFamily: 'Anton',
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    rules,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _event ?? widget.event;

    return Scaffold(
      backgroundColor: QortColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: QortColors.surface,
            iconTheme: const IconThemeData(color: QortColors.textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              background: ClipRect(
                child: TournamentComposerWidget(
                  headerOnly: true,
                  imageUrl: e['image_url']?.toString(),
                  eventName: e['name']?.toString() ?? '',
                  sport: e['sport']?.toString() ?? '',
                  flipHorizontal: e['image_flip_horizontal'] == true,
                  colorFilterPreset: e['cover_filter_preset']?.toString(),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: TournamentSponsorBand(
              compact: false,
              mainSponsor: _sponsorsForPreview().$1,
              extraSponsors: _sponsorsForPreview().$2,
            ),
          ),

          SliverToBoxAdapter(
            child: StockImageAttribution(data: e),
          ),

          SliverToBoxAdapter(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(50),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: QortModeColors.competition,
                      ),
                    ),
                  )
                : _buildEventInfoCard(e),
          ),

          SliverToBoxAdapter(
            child: _isLoading ? const SizedBox.shrink() : _buildRulesSection(e),
          ),

          SliverToBoxAdapter(
            child: _isLoading
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e['description'] != null &&
                            e['description'].toString().isNotEmpty) ...[
                          Text(
                            "APIE RENGINĮ",
                            style: GoogleFonts.oswald(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            e['description'],
                            style: const TextStyle(
                              color: QortColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 25),
                        ],
                        Text(
                          "PASIRINKITE LYGĮ / KATEGORIJĄ",
                          style: GoogleFonts.bebasNeue(
                            color: QortColors.textPrimary,
                            fontSize: 26,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          "Spauskite ant norimos kategorijos, kad pamatytumėte detales ir registruotumėtės.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        if (widget.previewMode) ...[
                          const SizedBox(height: 8),
                          const Text(
                            "Peržiūros režimas — registracija neaktyvi.",
                            style: TextStyle(
                              color: Color(0xFFEAB308),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_divisions.isEmpty)
                          const Center(
                            child: Text(
                              "Kategorijų dar nėra.",
                              style: TextStyle(color: QortColors.textSecondary),
                            ),
                          ),
                        ..._divisions.map((div) {
                          if (div is! Map) {
                            return const SizedBox.shrink();
                          }
                          final divMap = Map<String, dynamic>.from(div);

                          String divName =
                              divMap['name']?.toString() ?? 'Kategorija';
                          if (e['name'] != null &&
                              divName.startsWith(e['name'])) {
                            divName = divName
                                .replaceFirst('${e['name']} - ', '')
                                .trim();
                          }

                          final tierPrice = _getEventEntryPrice();
                          final price = (tierPrice ??
                                  (divMap['entry_fee'] as num?)?.toDouble() ??
                                  0)
                              .toInt();

                          return _buildDivisionCard(
                            div: divMap,
                            divName: divName,
                            price: price,
                          );
                        }),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
