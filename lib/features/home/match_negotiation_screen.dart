import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/query_limits.dart';
import '../../core/services/match_proposal_service.dart';

class MatchNegotiationScreen extends StatefulWidget {
  final Map<String, dynamic> match;
  final String currentUserId;

  const MatchNegotiationScreen({
    super.key,
    required this.match,
    required this.currentUserId,
  });

  @override
  State<MatchNegotiationScreen> createState() => _MatchNegotiationScreenState();
}

class _MatchNegotiationScreenState extends State<MatchNegotiationScreen> {
  final _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  // Pasiūlymo duomenys
  bool _hasActiveProposal = false;
  String? _proposerId;
  DateTime? _proposedDate;
  String? _proposedLocation;

  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToChat();
  }

  Future<void> _loadData() async {
    final client = Supabase.instance.client;

    // 1. Gauname naujausią mačo info (dėl pasiūlymų)
    final matchData = await client
        .from('matches')
        .select()
        .eq('id', widget.match['id'])
        .single();

    // 2. Gauname žinutes (tik paskutines 24 valandas)
    final yesterday = DateTime.now()
        .subtract(const Duration(hours: 24))
        .toIso8601String();
    final msgs = await client
        .from('match_chat')
        .select()
        .eq('match_id', widget.match['id'])
        .gte('created_at', yesterday)
        .order('created_at', ascending: true)
        .limit(QueryLimits.matchNegotiationChat);

    if (mounted) {
      setState(() {
        _hasActiveProposal = matchData['is_proposal_active'] ?? false;
        _proposerId = matchData['proposer_id'];
        if (matchData['proposed_date'] != null) {
          _proposedDate = DateTime.parse(matchData['proposed_date']).toLocal();
        }
        _proposedLocation = matchData['proposed_location'];

        _messages = List<Map<String, dynamic>>.from(msgs);
        _messageCount = _messages.length;
        _isLoading = false;

        // Auto-scroll į apačią
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      });
    }
  }

  void _subscribeToChat() {
    // Čia ateityje galima įdėti Realtime prenumeratą
    // Dabar paprastumo dėlei naudosime periodinį atnaujinimą siunčiant žinutę
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  // --- VEIKSMAI ---

  Future<void> _sendMessage() async {
    if (_msgCtrl.text.isEmpty || _messageCount >= 40) return;

    final content = _msgCtrl.text;
    _msgCtrl.clear();

    try {
      await Supabase.instance.client.from('match_chat').insert({
        'match_id': widget.match['id'],
        'user_id': widget.currentUserId,
        'content': content,
      });
      _loadData(); // Atnaujinam
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Klaida siunčiant")));
      }
    }
  }

  Future<void> _submitProposal(DateTime dt, String loc) async {
    try {
      await MatchProposalService.submitProposal(
        matchId: widget.match['id'] as String,
        proposerId: widget.currentUserId,
        dateTime: dt,
        location: loc,
      );

      _loadData();
      if (mounted) Navigator.pop(context); // Uždaryti modalą
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pasiūlymas išsiųstas!"),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _acceptProposal() async {
    if (_proposedDate == null) return;

    try {
      await MatchProposalService.acceptProposal(
        matchId: widget.match['id'] as String,
        userId: widget.currentUserId,
        proposedDate: _proposedDate!,
        proposedLocation: _proposedLocation,
      );

      if (mounted) {
        Navigator.pop(context, true); // Grįžtam į Home ir sakom "reload"
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mačas suderintas!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Accept error: $e");
    }
  }

  Future<void> _rejectProposal() async {
    try {
      await MatchProposalService.rejectProposal(
        matchId: widget.match['id'] as String,
        userId: widget.currentUserId,
      );

      _loadData();
    } catch (_) {}
  }

  // --- MODALAS LAIKO PASIRINKIMUI ---
  void _showProposalDialog() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 18, minute: 0);
    final locCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: QortColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: QortColors.border),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "SIŪLYTI LAIKĄ",
                style: GoogleFonts.bebasNeue(
                  fontSize: 24,
                  color: QortColors.textPrimary,
                ),
              ),
              const SizedBox(height: 15),
              ListTile(
                title: Text(
                  DateFormat('yyyy-MM-dd').format(selectedDate),
                  style: const TextStyle(color: QortColors.textPrimary),
                ),
                leading: const Icon(LucideIcons.calendar, color: QortColors.primary),
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2026),
                    builder: (context, child) => Theme(
                      data: QortTheme.pickerTheme(context),
                      child: child!,
                    ),
                  );
                  if (p != null) setModalState(() => selectedDate = p);
                },
              ),
              ListTile(
                title: Text(
                  selectedTime.format(context),
                  style: const TextStyle(color: QortColors.textPrimary),
                ),
                leading: const Icon(LucideIcons.clock, color: QortColors.primary),
                onTap: () async {
                  final p = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                    builder: (context, child) => Theme(
                      data: QortTheme.pickerTheme(context),
                      child: child!,
                    ),
                  );
                  if (p != null) setModalState(() => selectedTime = p);
                },
              ),
              TextField(
                controller: locCtrl,
                style: const TextStyle(color: QortColors.textPrimary),
                decoration: InputDecoration(
                  labelText: "Vieta",
                  labelStyle: const TextStyle(color: QortColors.textSecondary),
                  filled: true,
                  fillColor: QortColors.background,
                  prefixIcon: const Icon(
                    LucideIcons.mapPin,
                    color: QortColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: QortColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  final dt = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  _submitProposal(dt, locCtrl.text);
                },
                child: const Text(
                  "SIŪLYTI",
                  style: TextStyle(color: Colors.white),
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
    bool iAmProposer = _proposerId == widget.currentUserId;

    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: QortColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "DERYBOS",
              style: GoogleFonts.bebasNeue(
                fontSize: 20,
                color: QortColors.textPrimary,
              ),
            ),
            Text(
              "$_messageCount/40 žinučių (24h)",
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(
              LucideIcons.refreshCw,
              size: 18,
              color: QortColors.textSecondary,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- 1. PASIŪLYMO STATUSAS ---
          if (_hasActiveProposal)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: iAmProposer
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              child: Column(
                children: [
                  Text(
                    iAmProposer ? "JŪS PASIŪLĖTE:" : "GAVOTE PASIŪLYMĄ:",
                    style: GoogleFonts.oswald(
                      color: iAmProposer ? Colors.blue : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "${DateFormat('MM-dd HH:mm').format(_proposedDate!)} @ ${_proposedLocation ?? 'Vieta?'}",
                    style: const TextStyle(
                      color: QortColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!iAmProposer)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _acceptProposal,
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: const Text("TINKA"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: _rejectProposal,
                          icon: const Icon(
                            LucideIcons.x,
                            size: 16,
                            color: Colors.red,
                          ),
                          label: const Text(
                            "NETINKA",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    )
                  else
                    const Text(
                      "Laukiama varžovo patvirtinimo...",
                      style: TextStyle(
                        color: QortColors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),

          // --- 2. CHAT SRAUTAS ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      bool isMe = msg['user_id'] == widget.currentUserId;
                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? QortColors.primary
                                : QortColors.surface,
                            border: isMe
                                ? null
                                : Border.all(color: QortColors.border),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe
                                  ? const Radius.circular(16)
                                  : Radius.zero,
                              bottomRight: isMe
                                  ? Radius.zero
                                  : const Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['content'],
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.white
                                      : QortColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeago.format(
                                  DateTime.parse(msg['created_at']),
                                  locale: 'en_short',
                                ),
                                style: TextStyle(
                                  color: isMe ? QortColors.textSecondary : Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // --- 3. INPUT ---
          Container(
            padding: const EdgeInsets.all(16),
            color: QortColors.surface,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    onPressed: _hasActiveProposal
                        ? null
                        : _showProposalDialog, // Neleidžiam siūlyti, jei jau yra aktyvus
                    icon: Icon(
                      LucideIcons.calendarClock,
                      color: _hasActiveProposal ? Colors.grey : Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(color: QortColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: "Rašyti žinutę...",
                        hintStyle: const TextStyle(
                          color: QortColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: QortColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF3B82F6),
                    child: IconButton(
                      icon: const Icon(
                        LucideIcons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
