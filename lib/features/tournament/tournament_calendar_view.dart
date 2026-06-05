import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme/qort_design_system.dart';
import '../admin/tournament_composer_widget.dart';

enum _BarStyle { capsule, tag, bookend }

class TournamentCalendarView extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final void Function(Map<String, dynamic> event) onEventTap;

  const TournamentCalendarView({
    super.key,
    required this.events,
    required this.onEventTap,
  });

  @override
  State<TournamentCalendarView> createState() => _TournamentCalendarViewState();
}

class _TournamentCalendarViewState extends State<TournamentCalendarView> {
  static const _accent = QortDesignSystem.competition;

  late CalendarFormat _calendarFormat;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Map<DateTime, List<Map<String, dynamic>>> _eventsPerDay;
  bool _localeReady = false;
  _BarStyle _barStyle = _BarStyle.capsule;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _selectedDay = _dateOnly(DateTime.now());
    _rebuildEventsCache();
    _ensureLocale();
  }

  Future<void> _ensureLocale() async {
    try {
      await initializeDateFormatting('lt_LT', null);
    } catch (_) {
      // Fallback to default locale if lt_LT fails on this platform.
    }
    if (mounted) setState(() => _localeReady = true);
  }

  @override
  void didUpdateWidget(covariant TournamentCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _rebuildEventsCache();
    }
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _rebuildEventsCache() {
    final cache = <DateTime, List<Map<String, dynamic>>>{};

    for (final event in widget.events) {
      final startStr = event['start_date']?.toString();
      if (startStr == null || startStr.isEmpty) continue;

      final start = DateTime.tryParse(startStr);
      if (start == null) continue;

      final endStr = event['end_date']?.toString();
      final endParsed =
          endStr != null && endStr.isNotEmpty ? DateTime.tryParse(endStr) : null;
      final end = endParsed ?? start;

      var current = _dateOnly(start);
      final last = _dateOnly(end);

      while (!current.isAfter(last)) {
        cache.putIfAbsent(current, () => []).add(event);
        current = current.add(const Duration(days: 1));
      }
    }

    _eventsPerDay = cache;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _eventsPerDay[_dateOnly(day)] ?? [];
  }

  String _getEventType(Map<String, dynamic> event) {
    final start = DateTime.tryParse(event['start_date']?.toString() ?? '');
    final endRaw = event['end_date']?.toString();
    final end = endRaw != null && endRaw.isNotEmpty
        ? DateTime.tryParse(endRaw)
        : start;
    if (start == null) return 'single';
    if (end == null) return 'single';

    final days = _dateOnly(end).difference(_dateOnly(start)).inDays + 1;
    if (days <= 1) return 'single';
    if (days <= 7) return 'weekend';
    return 'continuous';
  }

  int get _visibleWeekRows {
    return switch (_calendarFormat) {
      CalendarFormat.month => 6,
      CalendarFormat.twoWeeks => 2,
      CalendarFormat.week => 1,
    };
  }

  /// Kalendoriaus blokui skirta dalis (likusi – dienos sąrašui).
  double _calendarAreaHeight(double totalHeight) =>
      totalHeight * 0.56;

  /// Dinaminis eilutės aukštis pagal tikrą kalendoriaus zonos aukštį.
  double _rowHeightForArea(double calendarAreaHeight) {
    const headerAndDow = 118.0;
    final rows = _visibleWeekRows;
    final forRows = calendarAreaHeight - headerAndDow;
    if (forRows <= 0) return 28;
    return (forRows / rows).clamp(26.0, 48.0);
  }

  double _barSlotHeight({required bool compact}) {
    return switch (_barStyle) {
      _BarStyle.capsule => compact ? 6.0 : 8.0,
      _BarStyle.tag => compact ? 11.0 : 14.0,
      _BarStyle.bookend => compact ? 7.0 : 10.0,
    };
  }

  String _shortEventName(Map<String, dynamic> event) {
    final name = event['name']?.toString() ?? '';
    final evName = event['parent_event_name']?.toString() ?? '';
    var short = name;
    if (evName.isNotEmpty) {
      short = TournamentLevelInfo.stripEventPrefix(
        tournamentName: name,
        eventName: evName,
      );
    } else {
      short = name.replaceFirst(RegExp(r'^[^-]+ - '), '').trim();
      if (short.isEmpty) short = name;
    }
    short = short.toUpperCase();
    if (short.length > 10) return short.substring(0, 10);
    return short;
  }

  Widget _buildBarStylePrototypeRow() {
    if (!kDebugMode) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'Stilius:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Capsule', style: TextStyle(fontSize: 11)),
              selected: _barStyle == _BarStyle.capsule,
              selectedColor: _accent,
              labelStyle: TextStyle(
                color: _barStyle == _BarStyle.capsule
                    ? Colors.black
                    : Colors.white70,
              ),
              onSelected: (_) => setState(() => _barStyle = _BarStyle.capsule),
            ),
            const SizedBox(width: 4),
            ChoiceChip(
              label: const Text('Tag', style: TextStyle(fontSize: 11)),
              selected: _barStyle == _BarStyle.tag,
              selectedColor: _accent,
              labelStyle: TextStyle(
                color:
                    _barStyle == _BarStyle.tag ? Colors.black : Colors.white70,
              ),
              onSelected: (_) => setState(() => _barStyle = _BarStyle.tag),
            ),
            const SizedBox(width: 4),
            ChoiceChip(
              label: const Text('Bookend', style: TextStyle(fontSize: 11)),
              selected: _barStyle == _BarStyle.bookend,
              selectedColor: _accent,
              labelStyle: TextStyle(
                color: _barStyle == _BarStyle.bookend
                    ? Colors.black
                    : Colors.white70,
              ),
              onSelected: (_) => setState(() => _barStyle = _BarStyle.bookend),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_localeReady) {
      return const Center(
        child: CircularProgressIndicator(color: _accent),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final calendarH = _calendarAreaHeight(constraints.maxHeight);
        final rowHeight = _rowHeightForArea(calendarH);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBarStylePrototypeRow(),
            SizedBox(
              height: calendarH,
              child: TableCalendar<Map<String, dynamic>>(
                firstDay: DateTime(2025, 1, 1),
                lastDay: DateTime(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) =>
                    _selectedDay != null && isSameDay(day, _selectedDay),
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Mėnuo',
                  CalendarFormat.twoWeeks: '2 sav.',
                  CalendarFormat.week: 'Savaitė',
                },
                locale: 'lt_LT',
                eventLoader: _getEventsForDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
                rowHeight: rowHeight,
                calendarStyle: const CalendarStyle(
                  outsideDaysVisible: false,
                  markersMaxCount: 0,
                  cellMargin: EdgeInsets.all(1),
                  defaultTextStyle: TextStyle(color: Colors.white, fontSize: 11),
                  weekendTextStyle:
                      TextStyle(color: Colors.white70, fontSize: 11),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonDecoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  formatButtonTextStyle: const TextStyle(color: Colors.black),
                  titleTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  leftChevronIcon: const Icon(
                    LucideIcons.chevronLeft,
                    color: Colors.white,
                    size: 20,
                  ),
                  rightChevronIcon: const Icon(
                    LucideIcons.chevronRight,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: _accent, fontSize: 10),
                  weekendStyle: TextStyle(color: _accent, fontSize: 10),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final isSelected =
                        _selectedDay != null && isSameDay(day, _selectedDay);
                    final isToday = isSameDay(day, DateTime.now());
                    return _buildDayCell(
                      day,
                      isToday: isToday,
                      isSelected: isSelected,
                    );
                  },
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() => _calendarFormat = format);
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
            ),
            Expanded(child: _buildDayEventsList()),
          ],
        );
      },
    );
  }

  Widget _buildDayCell(
    DateTime day, {
    required bool isToday,
    required bool isSelected,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final events = _getEventsForDay(day);
        final eventCount = events.length;
        final cellH = constraints.maxHeight;
        final cellW = constraints.maxWidth;
        final compact = cellH < 40;

        const dayLabelH = 14.0;
        final slotH = _barSlotHeight(compact: compact);
        final barSlots = cellH > dayLabelH + 6
            ? math.max(0, ((cellH - dayLabelH - 8) / slotH).floor())
            : 0;
        final visibleCount = math.min(barSlots, math.min(3, eventCount));
        final hiddenCount = eventCount - visibleCount;

        Color dayColor;
        FontWeight dayWeight;
        if (isSelected) {
          dayColor = Colors.black;
          dayWeight = FontWeight.bold;
        } else if (isToday) {
          dayColor = _accent;
          dayWeight = FontWeight.bold;
        } else {
          dayColor = Colors.white;
          dayWeight = FontWeight.normal;
        }

        return ClipRect(
          child: SizedBox(
            width: cellW,
            height: cellH,
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: isSelected
                    ? _accent
                    : isToday
                        ? _accent.withValues(alpha: 0.15)
                        : null,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? _accent
                      : _accent.withValues(alpha: 0.2),
                  width: isSelected ? 2 : 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    day.day.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dayColor,
                      fontSize: compact ? 10 : 11,
                      fontWeight: dayWeight,
                      height: 1.1,
                    ),
                  ),
                  if (visibleCount > 0)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, barConstraints) {
                          final barAreaH = barConstraints.maxHeight;
                          final plusH = hiddenCount > 0 ? (compact ? 8.0 : 10.0) : 0.0;
                          final perBarH = visibleCount > 0
                              ? ((barAreaH - plusH) / visibleCount)
                                  .clamp(4.0, slotH)
                              : slotH;

                          return ClipRect(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ...List.generate(visibleCount, (i) {
                                  return SizedBox(
                                    height: perBarH,
                                    child: _buildEventBar(
                                      events[i],
                                      _getEventType(events[i]),
                                      day,
                                      cellCompact: compact,
                                      maxBarHeight: perBarH,
                                    ),
                                  );
                                }),
                                if (hiddenCount > 0)
                                  SizedBox(
                                    height: plusH,
                                    child: Center(
                                      child: Text(
                                        '+$hiddenCount',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: compact ? 7 : 8,
                                          fontWeight: FontWeight.w600,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  else if (eventCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventBar(
    Map<String, dynamic> event,
    String type,
    DateTime day, {
    bool? cellCompact,
    double? maxBarHeight,
  }) {
    final start = DateTime.tryParse(event['start_date']?.toString() ?? '');
    final end = DateTime.tryParse(event['end_date']?.toString() ?? '');

    final isStart =
        start != null && isSameDay(_dateOnly(start), _dateOnly(day));
    final isEnd = end != null && isSameDay(_dateOnly(end), _dateOnly(day));

    Widget bar;
    final compact = cellCompact ?? (maxBarHeight != null && maxBarHeight < 10);

    switch (_barStyle) {
      case _BarStyle.capsule:
        bar = _buildBarCapsule(
          isStart: isStart,
          isEnd: isEnd,
          compact: compact,
          maxHeight: maxBarHeight,
        );
      case _BarStyle.tag:
        bar = _buildBarTag(
          event,
          isStart: isStart,
          isEnd: isEnd,
          compact: compact,
          maxHeight: maxBarHeight,
        );
      case _BarStyle.bookend:
        bar = _buildBarBookend(
          isStart: isStart,
          isEnd: isEnd,
          compact: compact,
          maxHeight: maxBarHeight,
        );
    }

    if (maxBarHeight == null) return bar;
    return SizedBox(
      height: maxBarHeight,
      width: double.infinity,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: bar,
      ),
    );
  }

  Widget _buildBarCapsule({
    required bool isStart,
    required bool isEnd,
    required bool compact,
    double? maxHeight,
  }) {
    final h = math.min(maxHeight ?? 6.0, compact ? 5.0 : 6.0);
    final dot = math.min(h, compact ? 5.0 : 7.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: h,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isStart)
              Container(
                width: dot,
                height: dot,
                decoration: const BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Container(
                height: 2,
                color: _accent.withValues(
                  alpha: isStart || isEnd ? 1.0 : 0.6,
                ),
              ),
            ),
            if (isEnd)
              Container(
                width: dot,
                height: dot,
                decoration: const BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarTag(
    Map<String, dynamic> event, {
    required bool isStart,
    required bool isEnd,
    required bool compact,
    double? maxHeight,
  }) {
    final shortName = _shortEventName(event);
    final barH = math.min(maxHeight ?? 12.0, compact ? 9.0 : 11.0);
    final fontSize = compact ? 6.0 : 7.0;
    final iconSize = compact ? 7.0 : 8.0;

    if (isStart) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Container(
          height: barH,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(2),
              right: Radius.zero,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.play_arrow, size: iconSize, color: Colors.black),
              const SizedBox(width: 1),
              Expanded(
                child: Text(
                  shortName,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isEnd) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Container(
          height: barH,
          decoration: const BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.horizontal(
              left: Radius.zero,
              right: Radius.circular(2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.stop, size: iconSize, color: Colors.black),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Align(
        alignment: Alignment.center,
        child: Container(
          height: math.min(maxHeight ?? 2.0, compact ? 1.5 : 2),
          color: _accent.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildBarBookend({
    required bool isStart,
    required bool isEnd,
    required bool compact,
    double? maxHeight,
  }) {
    final h = math.min(maxHeight ?? 8.0, compact ? 5.0 : 7.0);
    final iconSize = compact ? 5.0 : 6.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.horizontal(
            left: isStart ? const Radius.circular(4) : Radius.zero,
            right: isEnd ? const Radius.circular(4) : Radius.zero,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isStart)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(Icons.flag, size: iconSize, color: Colors.black),
              )
            else
              const SizedBox(width: 2),
            if (isEnd)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  Icons.emoji_events,
                  size: iconSize,
                  color: Colors.black,
                ),
              )
            else
              const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildDayEventsList() {
    final events = _getEventsForDay(_selectedDay ?? DateTime.now());

    if (events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Šią dieną turnyrų nėra',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      physics: const ClampingScrollPhysics(),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _buildEventListItem(events[i]),
    );
  }

  Widget _buildEventListItem(Map<String, dynamic> event) {
    final type = _getEventType(event);
    final typeIcon =
        type == 'continuous' ? '⟶' : type == 'weekend' ? '◐' : '●';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onEventTap(event),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeIcon,
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['name']?.toString() ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${event['sport'] ?? ''} · ${event['location'] ?? ''}',
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: Colors.white54,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
