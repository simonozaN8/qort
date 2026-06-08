import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../core/constants/app_shell_layout.dart';

class TournamentCalendarView extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final void Function(Map<String, dynamic> event) onEventTap;

  const TournamentCalendarView({
    super.key,
    required this.events,
    required this.onEventTap,
  });

  @override
  State<TournamentCalendarView> createState() =>
      _TournamentCalendarViewState();
}

class _TournamentCalendarViewState extends State<TournamentCalendarView> {
  static const Color _accent = Color(0xFFEAB308);

  DateTime _focusedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay;
  late Map<DateTime, List<Map<String, dynamic>>> _eventsPerDay;
  bool _localeReady = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _rebuildEventsCache();
    _initLocale();
  }

  @override
  void didUpdateWidget(covariant TournamentCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _rebuildEventsCache();
    }
  }

  Future<void> _initLocale() async {
    try {
      await initializeDateFormatting('lt_LT');
    } catch (_) {}
    if (mounted) setState(() => _localeReady = true);
  }

  void _rebuildEventsCache() {
    final cache = <DateTime, List<Map<String, dynamic>>>{};
    for (final event in widget.events) {
      final startStr = event['start_date']?.toString();
      final endStr = event['end_date']?.toString();
      if (startStr == null) continue;

      final start = DateTime.tryParse(startStr);
      final end = endStr != null ? DateTime.tryParse(endStr) : start;
      if (start == null) continue;

      var current = DateTime(start.year, start.month, start.day);
      final last = DateTime(
        (end ?? start).year,
        (end ?? start).month,
        (end ?? start).day,
      );

      while (!current.isAfter(last)) {
        cache.putIfAbsent(current, () => []).add(event);
        current = current.add(const Duration(days: 1));
      }
    }
    _eventsPerDay = cache;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _eventsPerDay[key] ?? [];
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInMonth(DateTime day) {
    return day.year == _focusedMonth.year && day.month == _focusedMonth.month;
  }

  String _pluralEvents(int count) {
    if (count == 1) return 'turnyras';
    if (count >= 2 && count <= 9) return 'turnyrai';
    return 'turnyrų';
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  List<DateTime> _generateMonthGrid() {
    final firstOfMonth = _focusedMonth;
    final firstWeekday = firstOfMonth.weekday;
    final startOffset = firstWeekday - 1;

    final gridStart = firstOfMonth.subtract(Duration(days: startOffset));

    return List.generate(42, (i) => gridStart.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_localeReady) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    final monthName = DateFormat('LLLL yyyy', 'lt_LT').format(_focusedMonth);
    final monthNameCapitalized = monthName.isNotEmpty
        ? monthName[0].toUpperCase() + monthName.substring(1)
        : monthName;

    final selectedEvents = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : <Map<String, dynamic>>[];

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: AppShellLayout.bottomNavTotalHeight(context) + 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMonthHeader(monthNameCapitalized),
          _buildWeekdayHeader(),
          _buildDayGrid(),
          _buildSelectedDayHeader(selectedEvents.length),
          _buildEventsList(selectedEvents),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(String monthName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: _prevMonth,
            tooltip: 'Ankstesnis mėnuo',
          ),
          Expanded(
            child: Text(
              monthName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: _nextMonth,
            tooltip: 'Kitas mėnuo',
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    const labels = ['Pr', 'An', 'Tr', 'Kt', 'Pn', 'Št', 'Sk'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: labels.map((label) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _accent.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayGrid() {
    final days = _generateMonthGrid();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 0.7,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: 42,
        itemBuilder: (context, i) => _buildDayCell(days[i]),
      ),
    );
  }

  Widget _buildDayCell(DateTime day) {
    final events = _getEventsForDay(day);
    final isToday = _isSameDay(day, DateTime.now());
    final isSelected = _selectedDay != null && _isSameDay(day, _selectedDay!);
    final inMonth = _isInMonth(day);

    Color? bgColor;
    if (isSelected) {
      bgColor = _accent;
    } else if (isToday) {
      bgColor = _accent.withOpacity(0.15);
    }

    final numberColor = isSelected
        ? Colors.black
        : (inMonth ? Colors.white : Colors.white24);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDay = day;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _accent.withOpacity(0.15),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              day.day.toString(),
              style: TextStyle(
                color: numberColor,
                fontSize: 13,
                fontWeight: (isToday || isSelected)
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            if (events.isNotEmpty && inMonth) ...[
              ...events.take(2).map((event) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black87 : _accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )),
              if (events.length > 2)
                Text(
                  '+${events.length - 2}',
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayHeader(int eventCount) {
    if (_selectedDay == null) return const SizedBox.shrink();

    final formatter = DateFormat('yyyy-MM-dd, EEEE', 'lt_LT');
    final dayStr = formatter.format(_selectedDay!);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.12),
        border: Border(
          top: BorderSide(color: _accent.withOpacity(0.4)),
          bottom: BorderSide(color: _accent.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: _accent, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dayStr,
              style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$eventCount ${_pluralEvents(eventCount)}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<Map<String, dynamic>> events) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.event_busy, color: Colors.white24, size: 32),
            SizedBox(height: 8),
            Text(
              'Šią dieną turnyrų nėra',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: events.map((event) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => widget.onEventTap(event),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
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
                      Icons.chevron_right,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
