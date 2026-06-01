import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/theme/qort_colors.dart';
import '../../core/constants/match_constants.dart';
import '../../core/services/match_auto_activate_service.dart';
import '../../core/utils/datetime_utils.dart';
import '../../core/widgets/qort_form_help.dart';

class ScheduleTab extends StatefulWidget {
  final List<dynamic> matches;
  final List<dynamic> participants;
  final List<dynamic> stages;
  final String? currentUserId;
  final bool isAdmin;
  final String venueType;
  final String schedulingType;
  final Function(Map<String, dynamic>) onEnterScore;
  final Function(Map<String, dynamic>) onConfirmScore;
  final Function(Map<String, dynamic>) onDisputeScore;
  final VoidCallback? onMatchesActivated;

  const ScheduleTab({
    super.key,
    required this.matches,
    required this.participants,
    required this.stages,
    this.currentUserId,
    this.isAdmin = false,
    this.venueType = "Aikštelė",
    this.schedulingType = "Tik Žaidėjai (Patys tariasi)",
    required this.onEnterScore,
    required this.onConfirmScore,
    required this.onDisputeScore,
    this.onMatchesActivated,
  });

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  bool _isUpdating = false;
  bool _autoActivateChecked = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAutoActivate());
  }

  @override
  void didUpdateWidget(covariant ScheduleTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matches != widget.matches) {
      _autoActivateChecked = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runAutoActivate());
    }
  }

  Future<void> _runAutoActivate() async {
    if (_autoActivateChecked || !mounted) return;
    _autoActivateChecked = true;
    try {
      final activated = await MatchAutoActivateService.processListedMatches(
        widget.matches,
      );
      if (activated && mounted) {
        widget.onMatchesActivated?.call();
      }
    } catch (_) {}
  }

  String _getPlayerName(String? id) {
    if (id == null) return "TBD (Laukiama varžovo)";
    for (var p in widget.participants) {
      if (p['user_id'] == id) return p['team_name'] ?? "Žaidėjas";
    }
    return "Nežinomas";
  }

  Future<void> _updateMatchStatus(
    Map<String, dynamic> match,
    String newStatus,
  ) async {
    setState(() => _isUpdating = true);
    try {
      await Supabase.instance.client
          .from('matches')
          .update({'status': newStatus})
          .eq('id', match['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Būsena atnaujinta!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Klaida: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showScheduleDialog(Map<String, dynamic> match) {
    DateTime? selectedDate = match['scheduled_time'] != null
        ? DateTimeUtils.fromIso(match['scheduled_time'].toString())
        : null;
    TimeOfDay? selectedTime = selectedDate != null
        ? TimeOfDay.fromDateTime(selectedDate)
        : null;
    TextEditingController locationCtrl = TextEditingController(
      text: match['location_name']?.toString() ?? '',
    );
    TextEditingController venueCtrl = TextEditingController(
      text: match['venue_name']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return QortFormDialog.shell(
            title: const Text(
              "Planuoti mačą",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const QortHelpBanner(
                    title: 'Laiko planavimas',
                    bullets: [
                      'Pasirinkite datą ir laiką — dalyviai matys juos mačų kortelėje.',
                      'Arena ir kortas padeda rasti vietą salėje ar aikštyne.',
                    ],
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Data",
                      style: TextStyle(color: QortColors.textSecondary),
                    ),
                    subtitle: Text(
                      selectedDate != null
                          ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                          : "Nepasirinkta",
                      style: const TextStyle(color: QortColors.textPrimary),
                    ),
                    trailing: const Icon(
                      LucideIcons.calendar,
                      color: Colors.blue,
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setModalState(() => selectedDate = d);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Laikas",
                      style: TextStyle(color: QortColors.textSecondary),
                    ),
                    subtitle: Text(
                      selectedTime != null
                          ? selectedTime!.format(context)
                          : "Nepasirinkta",
                      style: const TextStyle(color: QortColors.textPrimary),
                    ),
                    trailing: const Icon(LucideIcons.clock, color: Colors.blue),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (t != null) setModalState(() => selectedTime = t);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationCtrl,
                    style: const TextStyle(color: QortColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: "Arena / Aikštynas",
                      labelStyle: TextStyle(color: QortColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: QortColors.border),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.purpleAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: venueCtrl,
                    style: const TextStyle(color: QortColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: "${widget.venueType} (Nr. ar Pavadinimas)",
                      labelStyle: const TextStyle(color: QortColors.textSecondary),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: QortColors.border),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              QortFormDialog.cancelButton(ctx),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text(
                  "IŠSAUGOTI",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  String? isoTime;
                  if (selectedDate != null && selectedTime != null) {
                    final dt = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );
                    isoTime = DateTimeUtils.toIsoUtc(dt);
                  }

                  setState(() => _isUpdating = true);
                  Navigator.pop(ctx);

                  try {
                    String? lName = locationCtrl.text.trim().isEmpty
                        ? null
                        : locationCtrl.text.trim();
                    String? vName = venueCtrl.text.trim().isEmpty
                        ? null
                        : venueCtrl.text.trim();

                    await Supabase.instance.client
                        .from('matches')
                        .update({
                          'scheduled_time': isoTime,
                          'location_name': lName,
                          'venue_name': vName,
                        })
                        .eq('id', match['id']);

                    setState(() {
                      match['scheduled_time'] = isoTime;
                      match['location_name'] = lName;
                      match['venue_name'] = vName;
                      _isUpdating = false;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Suplanuota sėkmingai!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    setState(() => _isUpdating = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Klaida: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> displayMatches = widget.matches.where((m) {
      if (m['status'] == 'cancelled') return false;

      // IŠMANIOJI PAIEŠKA
      if (_searchQuery.isNotEmpty) {
        final p1Name = _getPlayerName(m['player1_id']).toLowerCase();
        final p2Name = _getPlayerName(m['player2_id']).toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!p1Name.contains(q) && !p2Name.contains(q)) return false;
      }
      return true;
    }).toList();

    displayMatches.sort((a, b) {
      int weightA = (a['status'] == 'completed') ? 1 : 0;
      int weightB = (b['status'] == 'completed') ? 1 : 0;
      return weightA.compareTo(weightB);
    });

    return Stack(
      children: [
        Column(
          children: [
            // PAIEŠKOS LAUKELIS ADMINISTRATORIUI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                color: QortColors.surface,
                border: Border(bottom: BorderSide(color: QortColors.border)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: QortColors.textPrimary),
                decoration: InputDecoration(
                  hintText: "Ieškoti žaidėjo...",
                  hintStyle: const TextStyle(color: QortColors.textSecondary),
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    color: QortColors.primary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            color: QortColors.textSecondary,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: QortColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: QortColors.border),
                  ),
                ),
              ),
            ),

            Expanded(
              child: displayMatches.isEmpty
                  ? Center(
                      child: Text(
                        "Mačų nerasta.",
                        style: GoogleFonts.oswald(
                          color: Colors.grey,
                          fontSize: 18,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: displayMatches.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 15),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return const QortHelpBanner(
                            title: 'Mačų sąrašas',
                            bullets: QortFormHelpTexts.matchesTab,
                          );
                        }
                        return _buildMatchCard(displayMatches[index - 1]);
                      },
                    ),
            ),
          ],
        ),
        if (_isUpdating)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFFD946EF)),
            ),
          ),
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final p1Id = match['player1_id'];
    final p2Id = match['player2_id'];
    final p1Name = _getPlayerName(p1Id);
    final p2Name = _getPlayerName(p2Id);
    final status = match['status'];

    final isMeP1 = widget.currentUserId != null && p1Id == widget.currentUserId;
    final isMeP2 = widget.currentUserId != null && p2Id == widget.currentUserId;
    final isParticipant = isMeP1 || isMeP2;

    String stageId = match['stage']?.toString() ?? '';
    var stageObj = widget.stages.firstWhere(
      (s) => s['id'] == stageId,
      orElse: () => null,
    );

    String stageLabel = "MAČAS";
    Color labelColor = const Color(0xFFD946EF);
    bool isKnockout = false;

    if (stageObj != null) {
      stageLabel = (stageObj['name'] ?? "ETAPAS").toString().toUpperCase();
      String format = stageObj['format']?.toString() ?? '';
      isKnockout =
          format.contains('Atkrintamosios') ||
          format.contains('Elimination') ||
          format.contains('Kvalifikacija') ||
          format.contains('Paguodos');

      if (format.contains('Kvalifikacija') || format.contains('Paguodos')) {
        labelColor = Colors.orangeAccent;
      } else if (format.contains('Grupės') || format.contains('Swiss'))
        labelColor = Colors.blueAccent;
      else if (isKnockout)
        labelColor = Colors.redAccent;
    }

    if (match['group_name'] != null &&
        match['group_name'].toString().isNotEmpty) {
      stageLabel += " - ${match['group_name'].toString().toUpperCase()}";
    }

    // IŠMANUSIS RAUNDŲ PAVADINIMAS
    if (isKnockout && match['round'] != null) {
      int r = int.tryParse(match['round'].toString()) ?? 1;
      if (r == 99) {
        stageLabel += " (DĖL 3 VIETOS)";
      } else if (r > 100)
        stageLabel += " (DĖL ${r - 100} VIETOS)";
      else {
        int matchesInRound = widget.matches
            .where((x) => x['stage'] == stageId && x['round'] == r)
            .length;
        if (matchesInRound == 1) {
          stageLabel += " - FINALAS";
        } else if (matchesInRound == 2)
          stageLabel += " - PUSFINALIS";
        else if (matchesInRound == 4)
          stageLabel += " - KETVIRTFINALIS";
        else if (matchesInRound == 8)
          stageLabel += " - AŠTUNTFINALIS";
        else
          stageLabel += " - $r RAUNDAS";
      }
    }

    final scheduledTime = match['scheduled_time'];
    final venueName = match['venue_name'];
    final locationName = match['location_name'];

    bool isOrganizerDriven =
        widget.schedulingType == "Organizatorius (Veda viską)";

    return Container(
      decoration: BoxDecoration(
        color: QortColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isParticipant
              ? const Color(0xFFD946EF).withOpacity(0.5)
              : QortColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: const BoxDecoration(
              color: QortColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    stageLabel,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                _buildStatusBadge(status),
              ],
            ),
          ),

          if (scheduledTime != null ||
              venueName != null ||
              locationName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: BoxDecoration(
                color: isOrganizerDriven
                    ? Colors.green.withOpacity(0.1)
                    : const Color(0xFF202025),
                border: const Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                children: [
                  if (isOrganizerDriven && scheduledTime != null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.checkCircle2,
                            color: Colors.green,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "OFICIALUS LAIKAS",
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 15,
                    runSpacing: 5,
                    children: [
                      if (scheduledTime != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.calendarClock,
                              color: Colors.blue,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              DateFormat(
                                'MM-dd HH:mm',
                              ).format(DateTimeUtils.fromIso(scheduledTime.toString())),
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      if (locationName != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.building,
                              color: Colors.purpleAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              locationName,
                              style: const TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      if (venueName != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.mapPin,
                              color: Colors.orange,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "${widget.venueType} $venueName",
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        p1Name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.oswald(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      if (isMeP1)
                        const Text(
                          "TAI JŪS",
                          style: TextStyle(
                            color: Color(0xFFD946EF),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: status == 'completed' || status == 'played_waiting'
                      ? Column(
                          children: [
                            Text(
                              "${match['score_p1'] ?? 0} - ${match['score_p2'] ?? 0}",
                              style: GoogleFonts.bebasNeue(
                                color: const Color(0xFFD946EF),
                                fontSize: 26,
                              ),
                            ),
                            if (match['match_details'] != null &&
                                match['match_details']['score_str'] != null &&
                                match['match_details']['score_str']
                                    .toString()
                                    .isNotEmpty)
                              Text(
                                match['match_details']['score_str'],
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        )
                      : Text(
                          "VS",
                          style: GoogleFonts.bebasNeue(
                            color: Colors.grey,
                            fontSize: 20,
                          ),
                        ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        p2Name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.oswald(
                          color: QortColors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      if (isMeP2)
                        const Text(
                          "TAI JŪS",
                          style: TextStyle(
                            color: Color(0xFFD946EF),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (status != 'completed' && !widget.isAdmin)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: _buildActionArea(
                match,
                status,
                isMeP1,
                isMeP2,
                isOrganizerDriven,
                scheduledTime != null,
              ),
            ),

          if (widget.isAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: const Border(
                  top: BorderSide(color: Colors.blue, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        LucideIcons.shieldAlert,
                        color: Colors.blue,
                        size: 14,
                      ),
                      SizedBox(width: 5),
                      Text(
                        "ADMIN KONTROLĖ",
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (status != 'completed')
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          icon: const Icon(
                            LucideIcons.calendarClock,
                            color: Colors.orange,
                            size: 18,
                          ),
                          tooltip: "Planuoti mačą",
                          onPressed: () => _showScheduleDialog(match),
                        ),
                      if (status == 'pending')
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          icon: const Icon(
                            LucideIcons.playCircle,
                            color: Colors.green,
                            size: 20,
                          ),
                          tooltip: "Aktyvuoti mačą",
                          onPressed: () => _updateMatchStatus(match, 'active'),
                        ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          minimumSize: Size.zero,
                          backgroundColor: Colors.blue.withOpacity(0.1),
                        ),
                        onPressed: () => widget.onEnterScore(match),
                        icon: const Icon(
                          LucideIcons.edit3,
                          size: 14,
                          color: Colors.blue,
                        ),
                        label: Text(
                          status == 'completed'
                              ? "Taisyti Rezultatą"
                              : "Įvesti Rezultatą",
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = "LAUKIA / NESUDERINTA";
        break;
      case 'active':
        color = Colors.blue;
        text = "AKTYVUS MAČAS";
        break;
      case 'played_waiting':
        color = Colors.purple;
        text = "PATEIKTAS REZULTATAS";
        break;
      case 'completed':
        color = Colors.green;
        text = "BAIGTAS";
        break;
      default:
        color = Colors.grey;
        text = status.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionArea(
    Map<String, dynamic> match,
    String status,
    bool isMeP1,
    bool isMeP2,
    bool isOrganizerDriven,
    bool hasTime,
  ) {
    if (status == 'pending') {
      if (isMeP2 && match['stage'] == 'ladder') {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: () => _updateMatchStatus(match, 'cancelled'),
                child: const Text("ATMESTI"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => _updateMatchStatus(match, 'active'),
                child: const Text(
                  "PRIIMTI",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      } else if (isMeP1 || isMeP2) {
        if (isOrganizerDriven) {
          return Center(
            child: Text(
              hasTime
                  ? "Oficialus laikas paskirtas. Pasirodykite nurodytu laiku!"
                  : "Laukiama oficialaus laiko ir vietos iš organizatoriaus.",
              style: TextStyle(
                color: hasTime ? Colors.green : Colors.orange,
                fontSize: 12,
              ),
            ),
          );
        } else {
          return const Center(
            child: Text(
              "Suderinkite mačo laiką Tituliniame ekrane",
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          );
        }
      }
    }

    if (status == 'active') {
      if (isMeP1 || isMeP2) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD946EF),
            ),
            icon: const Icon(LucideIcons.edit3, color: Colors.white, size: 16),
            label: const Text(
              "ĮVESTI REZULTATĄ",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => widget.onEnterScore(match),
          ),
        );
      }
    }

    if (status == 'played_waiting') {
      final submitterId = match['submitter_id'];
      final amISubmitter = widget.currentUserId == submitterId;

      if (!amISubmitter && (isMeP1 || isMeP2)) {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: () => widget.onDisputeScore(match),
                child: const Text("Apskųsti"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => widget.onConfirmScore(match),
                child: const Text(
                  "PATVIRTINTI",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      } else if (amISubmitter) {
        return const Center(
          child: Text(
            "Laukiama varžovo patvirtinimo.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        );
      }
    }

    return const Center(
      child: Text(
        "Tik žaidėjai gali valdyti šį mačą.",
        style: TextStyle(color: Colors.white24, fontSize: 12),
      ),
    );
  }
}
