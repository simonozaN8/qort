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
import 'tournament_detail_screen.dart';

class _FilterState {
  final OpenEventsSortMode sort;
  final String sport;
  final String? city;

  const _FilterState({
    this.sort = OpenEventsSortMode.newest,
    this.sport = 'VISI',
    this.city,
  });

  bool get isDefault =>
      sort == OpenEventsSortMode.newest && sport == 'VISI' && city == null;

  _FilterState copyWith({
    OpenEventsSortMode? sort,
    String? sport,
    String? city,
    bool clearCity = false,
  }) {
    return _FilterState(
      sort: sort ?? this.sort,
      sport: sport ?? this.sport,
      city: clearCity ? null : (city ?? this.city),
    );
  }
}

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  _FilterState _filterState = const _FilterState();
  List<String> _availableSports = [];
  List<String> _availableCities = [];
  List<dynamic> _events = [];
  bool _isLoading = true;

  bool get _hasActiveFilters => !_filterState.isDefault;

  @override
  void initState() {
    super.initState();
    _initFiltersAndEvents();
  }

  Future<void> _initFiltersAndEvents() async {
    try {
      final names = await SportsCatalogService.activeSportNames();
      if (mounted) {
        setState(() => _availableSports = names);
      }
    } catch (e) {
      debugPrint('Klaida kraunant sportų filtrus: $e');
    }
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final combinedList = await OpenEventsService.loadOpenEvents(
        limit: QueryLimits.tournamentList,
        sortMode: _filterState.sort,
      );

      if (mounted) {
        setState(() {
          _events = combinedList;
          _isLoading = false;
        });
        _loadAvailableCities();
      }
    } catch (e) {
      debugPrint('Klaida kraunant kalendorių: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadAvailableCities() {
    final normalized = <String, String>{};

    for (final event in _events) {
      final raw = event['location']?.toString().trim() ?? '';
      if (raw.isEmpty) continue;

      final key = raw.toLowerCase();
      if (!normalized.containsKey(key)) {
        final display =
            raw[0].toUpperCase() + raw.substring(1).toLowerCase();
        normalized[key] = display;
      }
    }

    final cities = normalized.values.toList()..sort();

    setState(() => _availableCities = cities);
  }

  List<dynamic> _displayedEvents() {
    var events = List<dynamic>.from(_events);

    if (_filterState.sport != 'VISI') {
      final sport = _filterState.sport.toLowerCase();
      events = events
          .where(
            (e) => e['sport']?.toString().toLowerCase() == sport,
          )
          .toList();
    }

    if (_filterState.city != null) {
      final filterCity = _filterState.city!.toLowerCase().trim();
      events = events.where((e) {
        final eventCity =
            e['location']?.toString().toLowerCase().trim() ?? '';
        return eventCity == filterCity;
      }).toList();
    }

    return events;
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterState>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterSheet(
        initial: _filterState,
        availableCities: _availableCities,
        availableSports: _availableSports,
      ),
    );

    if (result != null && mounted) {
      final sortChanged = result.sort != _filterState.sort;
      setState(() => _filterState = result);
      if (sortChanged) {
        await _loadEvents();
      }
    }
  }

  String _sortLabel(OpenEventsSortMode mode) {
    return switch (mode) {
      OpenEventsSortMode.newest => 'Naujausi',
      OpenEventsSortMode.soonest => 'Artimiausi',
      OpenEventsSortMode.mostPopular => 'Populiariausi',
    };
  }

  Widget _buildActiveFiltersBar() {
    final chips = <Widget>[];

    if (_filterState.sort != OpenEventsSortMode.newest) {
      chips.add(
        _FilterTag(
          label: _sortLabel(_filterState.sort),
          onRemove: () {
            setState(
              () => _filterState = _filterState.copyWith(
                sort: OpenEventsSortMode.newest,
              ),
            );
            _loadEvents();
          },
        ),
      );
    }
    if (_filterState.sport != 'VISI') {
      chips.add(
        _FilterTag(
          label: _filterState.sport,
          onRemove: () {
            setState(
              () => _filterState = _filterState.copyWith(sport: 'VISI'),
            );
          },
        ),
      );
    }
    if (_filterState.city != null) {
      chips.add(
        _FilterTag(
          label: _filterState.city!,
          onRemove: () {
            setState(
              () => _filterState = _filterState.copyWith(clearCity: true),
            );
          },
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: chips,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedEvents = _displayedEvents();
    final p = context.qortPalette;
    const accent = QortDesignSystem.competition;

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          QortAmbientBackground(palette: p),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: RefreshIndicator(
                  color: QortColors.primary,
                  onRefresh: _loadEvents,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 130,
                        floating: true,
                        snap: true,
                        pinned: false,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        automaticallyImplyLeading: false,
                        actions: [
                          IconButton(
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  LucideIcons.slidersHorizontal,
                                  color: p.textSecondary,
                                ),
                                if (_hasActiveFilters)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onPressed: _openFilterSheet,
                          ),
                          const SizedBox(width: 4),
                        ],
                        flexibleSpace: FlexibleSpaceBar(
                          background: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: QortCompactHero(
                                mode: AppMode.competition,
                                title: 'Turnyrai · Kalendorius',
                                subtitle: '${displayedEvents.length} renginiai',
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_hasActiveFilters)
                        SliverToBoxAdapter(child: _buildActiveFiltersBar()),
                      if (_isLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: QortColors.primary,
                            ),
                          ),
                        )
                      else if (displayedEvents.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'Šiuo metu renginių nėra.',
                              style: TextStyle(color: p.textSecondary),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildEventCard(
                                displayedEvents[index] as Map<String, dynamic>,
                              ),
                              childCount: displayedEvents.length,
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: AppShellLayout.scrollBottomPadding(context),
                        ),
                      ),
                    ],
                  ),
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
    final isParentEvent = event['is_parent_event'] == true;
    final sponsorsRaw = (event['event_sponsors'] as List?) ?? const [];
    final sponsors = sponsorsRaw
        .whereType<Map>()
        .map((j) => EventSponsor.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    final mainList = sponsors.where((s) => s.isMain).toList();
    final EventSponsor? mainSponsor =
        mainList.isNotEmpty ? mainList.first : null;
    final extraSponsors = sponsors.where((s) => !s.isMain).toList();

    final startDate = event['start_date'] != null
        ? DateFormat('MM-dd').format(DateTime.parse(event['start_date']))
        : '';
    final endDate = event['end_date'] != null
        ? DateFormat('MM-dd').format(DateTime.parse(event['end_date']))
        : '';
    final dateString =
        startDate.isNotEmpty ? '$startDate - $endDate' : 'Nenustatyta';
    final sport = event['sport']?.toString().toUpperCase() ?? 'SPORTAS';

    return GestureDetector(
      onTap: () {
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
                              style: QortDesignSystem.caption.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: QortDesignSystem.space3),
                    Text(
                      event['name'] ?? 'Renginys',
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
                            event['location'] ?? 'Vieta nenustatyta',
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

class _FilterTag extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterTag({
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    const accent = QortDesignSystem.competition;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              LucideIcons.x,
              size: 14,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final _FilterState initial;
  final List<String> availableCities;
  final List<String> availableSports;

  const _FilterSheet({
    required this.initial,
    required this.availableCities,
    required this.availableSports,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const _accent = QortDesignSystem.competition;

  late OpenEventsSortMode _sort;
  late String _sport;
  late String? _city;

  @override
  void initState() {
    super.initState();
    _sort = widget.initial.sort;
    _sport = widget.initial.sport;
    _city = widget.initial.city;
  }

  bool get _hasAnyChange =>
      _sort != OpenEventsSortMode.newest ||
      _sport != 'VISI' ||
      _city != null;

  void _reset() {
    setState(() {
      _sort = OpenEventsSortMode.newest;
      _sport = 'VISI';
      _city = null;
    });
  }

  TextStyle _labelStyle(BuildContext context) {
    return QortTheme.sectionTitle(context.qortPalette);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('FILTRAI', style: _labelStyle(context)),
                const Spacer(),
                if (_hasAnyChange)
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Išvalyti'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('RIKIAVIMAS', style: _labelStyle(context)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                QortPill(
                  label: 'Naujausi',
                  icon: LucideIcons.sparkles,
                  selected: _sort == OpenEventsSortMode.newest,
                  color: _accent,
                  onTap: () =>
                      setState(() => _sort = OpenEventsSortMode.newest),
                ),
                QortPill(
                  label: 'Artimiausi',
                  icon: LucideIcons.calendarClock,
                  selected: _sort == OpenEventsSortMode.soonest,
                  color: _accent,
                  onTap: () =>
                      setState(() => _sort = OpenEventsSortMode.soonest),
                ),
                QortPill(
                  label: 'Populiariausi',
                  icon: LucideIcons.users,
                  selected: _sort == OpenEventsSortMode.mostPopular,
                  color: _accent,
                  onTap: () =>
                      setState(() => _sort = OpenEventsSortMode.mostPopular),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('SPORTO ŠAKA', style: _labelStyle(context)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                QortPill(
                  label: 'VISI',
                  icon: LucideIcons.layoutGrid,
                  selected: _sport == 'VISI',
                  color: _accent,
                  onTap: () => setState(() => _sport = 'VISI'),
                ),
                ...widget.availableSports.map(
                  (s) => QortPill(
                    label: s,
                    selected: _sport == s,
                    color: _accent,
                    onTap: () => setState(() => _sport = s),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('MIESTAS', style: _labelStyle(context)),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _city,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF2A2A2A),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Visi miestai'),
                    ),
                    ...widget.availableCities.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c,
                        child: Text(c),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _city = val),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  _FilterState(sort: _sort, sport: _sport, city: _city),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'TAIKYTI FILTRUS',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
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
