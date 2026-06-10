import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/event_archive_service.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_design_system.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../../core/theme/qort_theme.dart';
import '../../core/utils/sport_icons.dart';
import '../tournament/event_detail_screen.dart';

class EventArchiveScreen extends StatefulWidget {
  const EventArchiveScreen({super.key});

  @override
  State<EventArchiveScreen> createState() => _EventArchiveScreenState();
}

class _EventArchiveScreenState extends State<EventArchiveScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _events = [];
  List<String> _availableSports = [];
  List<String> _availableCities = [];
  List<int> _availableYears = [];
  String _sport = 'VISI';
  int? _year;
  String? _city;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    _loadArchive();
  }

  void _deriveFilterOptions(List<Map<String, dynamic>> allEvents) {
    final sports = <String>{};
    final cities = <String>{};
    final years = <int>{};

    for (final event in allEvents) {
      final sport = event['sport']?.toString().trim() ?? '';
      if (sport.isNotEmpty) sports.add(sport);

      final location = event['location']?.toString().trim() ?? '';
      if (location.isNotEmpty) cities.add(location);

      final startStr = event['start_date']?.toString();
      if (startStr != null) {
        final dt = DateTime.tryParse(startStr);
        if (dt != null) years.add(dt.year);
      }
    }

    _availableSports = sports.toList()..sort();
    _availableCities = cities.toList()..sort();
    _availableYears = years.toList()..sort((a, b) => b.compareTo(a));

    if (_sport != 'VISI' && !_availableSports.contains(_sport)) {
      _sport = 'VISI';
    }
    if (_city != null && !_availableCities.contains(_city)) {
      _city = null;
    }
    if (_year != null && !_availableYears.contains(_year)) {
      _year = null;
    }
  }

  void _applyFilters() {
    _events = _allEvents.where((event) {
      if (_sport != 'VISI') {
        final eventSport = event['sport']?.toString().trim() ?? '';
        if (eventSport.toLowerCase() != _sport.toLowerCase()) return false;
      }
      if (_year != null) {
        final startStr = event['start_date']?.toString();
        final dt = startStr != null ? DateTime.tryParse(startStr) : null;
        if (dt == null || dt.year != _year) return false;
      }
      if (_city != null) {
        final location = event['location']?.toString().trim().toLowerCase() ?? '';
        if (location != _city!.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _loadArchive() async {
    setState(() => _isLoading = true);
    try {
      final data = await EventArchiveService.loadUserHistory(
        userId: _userId,
      );
      if (!mounted) return;
      setState(() {
        _allEvents = data;
        _deriveFilterOptions(data);
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Klaida kraunant archyvą: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openFilters() async {
    if (_availableSports.isEmpty &&
        _availableCities.isEmpty &&
        _availableYears.isEmpty) {
      return;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: QortColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ArchiveFilterSheet(
        sports: _availableSports,
        cities: _availableCities,
        years: _availableYears,
        initialSport: _sport,
        initialYear: _year,
        initialCity: _city,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _sport = result['sport'] as String? ?? 'VISI';
      _year = result['year'] as int?;
      _city = result['city'] as String?;
      _applyFilters();
    });
  }

  Map<String, dynamic>? _userParticipation(Map<String, dynamic> event) {
    if (_userId == null) return null;
    final tournaments = event['tournaments'] as List? ?? [];
    for (final t in tournaments) {
      if (t is! Map) continue;
      final participants = t['tournament_participants'] as List? ?? [];
      for (final p in participants) {
        if (p is Map && p['user_id']?.toString() == _userId) {
          return {
            'tournament': t,
            'participant': p,
          };
        }
      }
    }
    return null;
  }

  String _resultLabel(Map<String, dynamic>? participation) {
    if (participation == null) return '';
    final p = participation['participant'] as Map<String, dynamic>;
    final place = p['final_place'];
    final rp = p['earned_rp'];
    final xp = p['earned_xp'];
    final parts = <String>[];
    if (place != null) parts.add('$place. vieta');
    if (rp != null && (rp as num) > 0) parts.add('+$rp RP');
    if (xp != null && (xp as num) > 0) parts.add('+$xp XP');
    return parts.isEmpty ? 'Dalyvavo' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final hasFilters = _availableSports.isNotEmpty ||
        _availableCities.isNotEmpty ||
        _availableYears.isNotEmpty;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: p.textPrimary),
        title: Text(
          'Mano istorija',
          style: GoogleFonts.oswald(
            color: p.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (hasFilters)
            IconButton(
              icon: const Icon(LucideIcons.slidersHorizontal),
              color: p.textSecondary,
              onPressed: _openFilters,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allEvents.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.archive,
                          size: 48,
                          color: p.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nėra pasibaigusių turnyrų',
                          style: TextStyle(color: p.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _events.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.filterX,
                              size: 48,
                              color: p.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Pagal pasirinktus filtrus turnyrų nerasta',
                              style: TextStyle(color: p.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _sport = 'VISI';
                                  _year = null;
                                  _city = null;
                                  _applyFilters();
                                });
                              },
                              child: const Text('Išvalyti filtrus'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        final participation = _userParticipation(event);
                        final startDate = event['start_date']?.toString();
                        final dateLabel = startDate != null
                            ? DateFormat('yyyy-MM-dd')
                                .format(DateTime.parse(startDate))
                            : '—';
                        final sport =
                            event['sport']?.toString().toUpperCase() ??
                                'SPORTAS';
                        final status = event['status']?.toString() ?? '';
                        final statusLabel = status == 'cancelled'
                            ? 'Atšauktas'
                            : 'Pasibaigęs';

                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventDetailScreen(event: event),
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: QortColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    SportIcons.badge(sport, size: 24),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        event['name']?.toString() ?? 'Renginys',
                                        style: const TextStyle(
                                          color: QortColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: status == 'cancelled'
                                            ? Colors.red
                                                .withValues(alpha: 0.15)
                                            : Colors.grey
                                                .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: status == 'cancelled'
                                              ? Colors.redAccent
                                              : p.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      LucideIcons.calendar,
                                      size: 14,
                                      color: p.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dateLabel,
                                      style: TextStyle(
                                        color: p.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      LucideIcons.mapPin,
                                      size: 14,
                                      color: p.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        event['location']?.toString() ??
                                            'Vieta nenustatyta',
                                        style: TextStyle(
                                          color: p.textSecondary,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (participation != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _resultLabel(participation),
                                    style: const TextStyle(
                                      color: Color(0xFFEAB308),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _ArchiveFilterSheet extends StatefulWidget {
  final List<String> sports;
  final List<String> cities;
  final List<int> years;
  final String initialSport;
  final int? initialYear;
  final String? initialCity;

  const _ArchiveFilterSheet({
    required this.sports,
    required this.cities,
    required this.years,
    required this.initialSport,
    this.initialYear,
    this.initialCity,
  });

  @override
  State<_ArchiveFilterSheet> createState() => _ArchiveFilterSheetState();
}

class _ArchiveFilterSheetState extends State<_ArchiveFilterSheet> {
  late String _sport;
  int? _year;
  String? _city;

  @override
  void initState() {
    super.initState();
    _sport = widget.initialSport;
    _year = widget.initialYear;
    _city = widget.initialCity;
  }

  @override
  Widget build(BuildContext context) {
    final sportOptions = ['VISI', ...widget.sports];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FILTRAI', style: QortTheme.sectionTitle(context.qortPalette)),
            if (widget.sports.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'SPORTAS',
                style: QortTheme.sectionTitle(context.qortPalette),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sportOptions.map((s) {
                  final selected = _sport == s;
                  return FilterChip(
                    label: Text(s == 'VISI' ? 'Visi sportai' : s),
                    selected: selected,
                    onSelected: (_) => setState(() => _sport = s),
                  );
                }).toList(),
              ),
            ],
            if (widget.years.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('METAI', style: QortTheme.sectionTitle(context.qortPalette)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Visi metai'),
                    selected: _year == null,
                    onSelected: (_) => setState(() => _year = null),
                  ),
                  ...widget.years.map(
                    (y) => FilterChip(
                      label: Text('$y'),
                      selected: _year == y,
                      onSelected: (_) => setState(() => _year = y),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.cities.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'MIESTAS',
                style: QortTheme.sectionTitle(context.qortPalette),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Visi miestai'),
                    selected: _city == null,
                    onSelected: (_) => setState(() => _city = null),
                  ),
                  ...widget.cities.map(
                    (c) => FilterChip(
                      label: Text(c),
                      selected: _city == c,
                      onSelected: (_) => setState(() => _city = c),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: QortDesignSystem.competition,
                ),
                onPressed: () {
                  Navigator.pop(context, {
                    'sport': _sport,
                    'year': _year,
                    'city': _city,
                  });
                },
                child: const Text('Taikyti'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
