import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_shell_layout.dart';
import '../../core/constants/query_limits.dart';
import '../../core/theme/qort_design_system.dart';
import '../../core/widgets/qort_components.dart';
import '../../core/widgets/qort_ambient_background.dart';
import '../../core/widgets/qort_live_scaffold.dart';
import '../../core/services/open_events_service.dart';
import '../../core/services/sports_catalog_service.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/theme/qort_theme.dart';
import '../../core/utils/sport_icons.dart';
import '../../core/utils/sport_visual_icon.dart';
import '../profile/user_model.dart';
import '../admin/tournament_composer_widget.dart';
import '../../core/services/event_sponsor_service.dart';
import '../admin/tournament_sponsor_band.dart';

import 'event_detail_screen.dart';
import 'tournament_detail_screen.dart'; // Būtina, kad atidarytų pavienius turnyrus

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  String _selectedFilter = "VISI";
  List<String> _filters = ["VISI"];
  List<dynamic> _events = [];
  bool _isLoading = true;
  OpenEventsSortMode _sortMode = OpenEventsSortMode.newest;

  @override
  void initState() {
    super.initState();
    _initFiltersAndEvents();
  }

  Future<void> _initFiltersAndEvents() async {
    try {
      final names = await SportsCatalogService.activeSportNames();
      if (mounted) {
        setState(() => _filters = ["VISI", ...names]);
      }
    } catch (e) {
      debugPrint("Klaida kraunant sportų filtrus: $e");
    }
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final combinedList = await OpenEventsService.loadOpenEvents(
        limit: QueryLimits.tournamentList,
        sortMode: _sortMode,
      );

      if (mounted) {
        setState(() {
          _events = combinedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant kalendorių: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSortModeChanged(OpenEventsSortMode mode) {
    if (_sortMode == mode) return;
    setState(() => _sortMode = mode);
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> displayedEvents = _selectedFilter == "VISI"
        ? _events
        : _events
              .where(
                (e) =>
                    e['sport']?.toString().toLowerCase() ==
                    _selectedFilter.toLowerCase(),
              )
              .toList();

    final p = context.qortPalette;

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          QortAmbientBackground(palette: p),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                      child: QortCompactHero(
                        mode: AppMode.competition,
                        title: 'Turnyrai · Kalendorius',
                        subtitle: '${displayedEvents.length} renginiai',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                      child: Text(
                        'RIKIAVIMAS',
                        style: QortTheme.sectionTitle(p),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          QortPill(
                            label: 'Naujausi',
                            icon: LucideIcons.sparkles,
                            selected: _sortMode == OpenEventsSortMode.newest,
                            color: QortDesignSystem.competition,
                            onTap: () =>
                                _onSortModeChanged(OpenEventsSortMode.newest),
                          ),
                          const SizedBox(width: 8),
                          QortPill(
                            label: 'Artimiausi',
                            icon: LucideIcons.calendarClock,
                            selected: _sortMode == OpenEventsSortMode.soonest,
                            color: QortDesignSystem.competition,
                            onTap: () =>
                                _onSortModeChanged(OpenEventsSortMode.soonest),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'FILTRAI',
                              style: QortTheme.sectionTitle(p),
                            ),
                          ),
                          IconButton(
                            icon: Icon(LucideIcons.search, color: p.textSecondary),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;
                    return QortPill(
                      label: filter,
                      icon: filter != 'VISI'
                          ? null
                          : LucideIcons.layoutGrid,
                      selected: isSelected,
                      color: QortDesignSystem.competition,
                      onTap: () => setState(() => _selectedFilter = filter),
                    );
                  },
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: QortColors.primary),
                      )
                    : displayedEvents.isEmpty
                        ? const Center(
                            child: Text(
                              'Šiuo metu renginių nėra.',
                              style: TextStyle(color: QortColors.textSecondary),
                            ),
                          )
                        : RefreshIndicator(
                            color: QortColors.primary,
                            onRefresh: _loadEvents,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                              itemCount: displayedEvents.length + 1,
                              itemBuilder: (context, index) {
                                if (index == displayedEvents.length) {
                                  return SizedBox(
                                    height: AppShellLayout.scrollBottomPadding(context),
                                  );
                                }
                                return _buildEventCard(displayedEvents[index]);
                              },
                            ),
                          ),
              ),
            ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final p = context.qortPalette;
    bool isParentEvent = event['is_parent_event'] == true;
    final sponsorsRaw = (event['event_sponsors'] as List?) ?? const [];
    final sponsors = sponsorsRaw
        .whereType<Map>()
        .map((j) => EventSponsor.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    final mainList = sponsors.where((s) => s.isMain).toList();
    final EventSponsor? mainSponsor = mainList.isNotEmpty ? mainList.first : null;
    final extraSponsors = sponsors.where((s) => !s.isMain).toList();

    String startDate = event['start_date'] != null
        ? DateFormat('MM-dd').format(DateTime.parse(event['start_date']))
        : '';
    String endDate = event['end_date'] != null
        ? DateFormat('MM-dd').format(DateTime.parse(event['end_date']))
        : '';
    String dateString = startDate.isNotEmpty
        ? "$startDate - $endDate"
        : "Nenustatyta";
    String sport = event['sport']?.toString().toUpperCase() ?? "SPORTAS";

    return GestureDetector(
      onTap: () {
        // NUKREIPIAME PRIKLAUSOMAI NUO TO, AR TAI RENGINYS, AR PAVIENIS TURNYRAS
        if (isParentEvent) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(event: event),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TournamentDetailScreen(tournament: event),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: QortDesignSystem.space5),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(QortDesignSystem.radiusLg),
          border: Border.all(color: QortDesignSystem.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(QortDesignSystem.radiusLg),
              ),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: isParentEvent
                    ? _EventComposerCover(event: event)
                    : _EventCoverImage(url: event['image_url']?.toString()),
              ),
            ),
            if (isParentEvent)
              TournamentSponsorBand(
                compact: true,
                mainSponsor: mainSponsor,
                extraSponsors: extraSponsors,
              ),
            if (!isParentEvent)
              Padding(
                padding: const EdgeInsets.all(QortDesignSystem.space5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SportIcons.badge(sport, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              sport,
                              style: QortDesignSystem.micro.copyWith(
                                color: SportVisualIcon.specFor(sport).primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.calendar,
                              color: p.textSecondary,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              dateString,
                              style: QortDesignSystem.caption.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: QortDesignSystem.space3),
                    Text(
                      event['name'] ?? "Renginys",
                      style: QortDesignSystem.h3,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          color: Colors.blueAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            event['location'] ?? "Vieta nenustatyta",
                            style: QortDesignSystem.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _EventCoverImage extends StatelessWidget {
  final String? url;

  const _EventCoverImage({this.url});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (url != null && url!.trim().isNotEmpty)
        ? url!
        : QortDesignSystem.eventPlaceholderImage;

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholder(showLoader: true);
      },
    );
  }

  Widget _placeholder({bool showLoader = false}) {
    return Container(
      color: QortDesignSystem.bgElevated,
      alignment: Alignment.center,
      child: showLoader
          ? const CircularProgressIndicator(strokeWidth: 2)
          : const Icon(
              LucideIcons.image,
              color: QortDesignSystem.textMuted,
              size: 40,
            ),
    );
  }
}

class _EventComposerCover extends StatelessWidget {
  final Map<String, dynamic> event;

  const _EventComposerCover({required this.event});

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  List<TournamentLevelInfo> _levels() {
    final evName = event['name']?.toString() ?? '';
    final list = (event['tournaments'] as List?) ?? const [];
    return list.whereType<Map>().map((t) {
      final tName = t['name']?.toString() ?? '';
      final level = TournamentLevelInfo.stripEventPrefix(
        tournamentName: tName,
        eventName: evName,
      );
      return TournamentLevelInfo(
        levelName: level,
        formatCode: t['format_code']?.toString() ?? '1v1',
        gender: t['gender']?.toString(),
        minRp: (t['min_rp'] as num?)?.toInt() ?? 0,
        maxRp: (t['max_rp'] as num?)?.toInt() ?? 3000,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    double? price;
    final tList = (event['tournaments'] as List?) ?? const [];
    if (tList.isNotEmpty) {
      final first = tList.first;
      if (first is Map && first['entry_fee'] != null) {
        price = (first['entry_fee'] as num).toDouble();
      }
    }
    return TournamentComposerWidget(
      compact: true,
      imageUrl: event['image_url']?.toString(),
      flipHorizontal: event['image_flip_horizontal'] == true,
      colorFilterPreset: event['cover_filter_preset']?.toString(),
      eventName: event['name']?.toString() ?? 'Renginys',
      sport: event['sport']?.toString() ?? '',
      location: event['location']?.toString(),
      startDate: _parseDate(event['start_date']),
      endDate: _parseDate(event['end_date']),
      price: price,
      levels: _levels(),
    );
  }
}
