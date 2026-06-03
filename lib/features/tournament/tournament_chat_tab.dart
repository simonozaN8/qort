import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import '../../core/theme/qort_mode_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/query_limits.dart';

class TournamentChatTab extends StatefulWidget {
  final String tournamentId;
  final bool isAdmin;

  const TournamentChatTab({
    super.key,
    required this.tournamentId,
    required this.isAdmin,
  });

  @override
  State<TournamentChatTab> createState() => _TournamentChatTabState();
}

class _TournamentChatTabState extends State<TournamentChatTab> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // Auto-scroll

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _pinnedAnnouncements = [];

  bool _isLoading = true;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id;
    _loadAllData();
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    Supabase.instance.client
        .from('tournament_chat')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', widget.tournamentId)
        .order('created_at')
        .listen((List<Map<String, dynamic>> data) async {
          if (mounted) {
            _processData(await _attachProfiles(data));
          }
        });
  }

  Future<void> _loadAllData() async {
    try {
      final client = Supabase.instance.client;

      // 1. Gauname žinutes (rankinis užkrovimas pradžiai)
      final chatRes = await client
          .from('tournament_chat')
          .select('*')
          .eq('tournament_id', widget.tournamentId)
          .order('created_at', ascending: false)
          .limit(QueryLimits.chatMessages);
      final ordered = List<Map<String, dynamic>>.from(chatRes).reversed.toList();

      _processData(await _attachProfiles(ordered));
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _attachProfiles(
    List<Map<String, dynamic>> msgs,
  ) async {
    final ids = msgs
        .map((m) => m['user_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    if (ids.isEmpty) return msgs;

    final profs = await Supabase.instance.client
        .from('profiles')
        .select('id, nickname, photo_url')
        .inFilter('id', ids);
    final byId = <String, Map<String, dynamic>>{};
    for (final p in profs as List) {
      byId[p['id'].toString()] = Map<String, dynamic>.from(p);
    }

    return msgs.map((m) {
      final copy = Map<String, dynamic>.from(m);
      final uid = m['user_id']?.toString();
      if (uid != null && byId.containsKey(uid)) {
        copy['profiles'] = byId[uid];
      }
      return copy;
    }).toList();
  }

  // Bendra funkcija duomenų apdorojimui (kad kodas nesikartotų)
  Future<void> _processData(List<Map<String, dynamic>> allMsgs) async {
    final client = Supabase.instance.client;

    // Gauname, ką aš jau perskaičiau (skelbimus)
    final readRes = await client
        .from('announcement_reads')
        .select('chat_id')
        .eq('user_id', _myId!)
        .limit(QueryLimits.announcementReads);

    Set<String> readIds = (readRes as List)
        .map((r) => r['chat_id'].toString())
        .toSet();
    List<Map<String, dynamic>> pinned = [];

    for (var msg in allMsgs) {
      if (msg['is_announcement'] == true && !readIds.contains(msg['id'])) {
        pinned.add(msg);
      }
    }

    if (mounted) {
      setState(() {
        _messages = allMsgs;
        _pinnedAnnouncements = pinned.reversed.toList();
        _isLoading = false;
      });

      // Nusukame į apačią, jei atsirado nauja žinutė
      if (_messages.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    }
  }

  Future<void> _sendMessage({bool isAnnouncement = false}) async {
    if (_msgCtrl.text.trim().isEmpty) return;
    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();

    try {
      // SVARBU: Siunčiame ID kaip tekstą (UUID), jokio int.parse!
      await Supabase.instance.client.from('tournament_chat').insert({
        'tournament_id': widget.tournamentId,
        'user_id': _myId,
        'message': text,
        'is_announcement': isAnnouncement,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Klaida: $e")));
      }
    }
  }

  Future<void> _markAsRead(String chatId) async {
    // Vietinis UI atnaujinimas (greičiui)
    setState(() {
      _pinnedAnnouncements.removeWhere((m) => m['id'] == chatId);
    });
    // DB atnaujinimas
    try {
      await Supabase.instance.client.from('announcement_reads').insert({
        'user_id': _myId,
        'chat_id': chatId,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // SKELBIMŲ KARUSELĖ VIRŠUJE
        if (_pinnedAnnouncements.isNotEmpty) _buildPinnedSection(),

        // ŽINUČIŲ SĄRAŠAS
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: QortModeColors.competition),
                )
              : _messages.isEmpty
              ? Center(
                  child: Text(
                    "Čia kol kas tuščia...",
                    style: GoogleFonts.oswald(color: QortColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg['user_id'] == _myId;
                    final isAnnouncement = msg['is_announcement'] == true;
                    return _buildMessageBubble(msg, isMe, isAnnouncement);
                  },
                ),
        ),

        // RAŠYMO LAUKAS
        _buildInputArea(),
      ],
    );
  }

  Widget _buildPinnedSection() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 120),
      decoration: const BoxDecoration(
        color: QortColors.surface,
        border: Border(bottom: BorderSide(color: QortColors.border)),
      ),
      child: PageView.builder(
        itemCount: _pinnedAnnouncements.length,
        controller: PageController(viewportFraction: 0.95),
        itemBuilder: (context, index) {
          final ann = _pinnedAnnouncements[index];
          final timeStr = ann['created_at'] != null
              ? timeago.format(
                  DateTime.parse(ann['created_at']),
                  locale: 'en_short',
                )
              : "";

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.megaphone,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "SVARBUS PRANEŠIMAS",
                            style: GoogleFonts.oswald(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              color: QortColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ann['message'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _markAsRead(ann['id']),
                  icon: const Icon(
                    LucideIcons.checkCircle,
                    color: Colors.orange,
                  ),
                  tooltip: "Pažymėti kaip perskaitytą",
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        color: QortColors.surface,
        border: Border(top: BorderSide(color: QortColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (widget.isAdmin)
              IconButton(
                icon: const Icon(LucideIcons.megaphone, color: Colors.orange),
                onPressed: () => _sendMessage(isAnnouncement: true),
                tooltip: "Skelbti visiems",
              ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _msgCtrl,
                  style: const TextStyle(color: QortColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: widget.isAdmin
                        ? "Rašyti pranešimą..."
                        : "Rašyti žinutę...",
                    hintStyle: const TextStyle(color: QortColors.textSecondary),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(isAnnouncement: false),
                ),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              backgroundColor: QortModeColors.competition,
              child: IconButton(
                icon: const Icon(
                  LucideIcons.send,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => _sendMessage(isAnnouncement: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isMe,
    bool isAnnouncement,
  ) {
    // Jei nėra profilio info (nes Realtime grąžina tik žinutę, be join), naudojame placeholder
    // Geriausiam rezultatui reiktų papildomo fetch vartotojams, bet čia supaprastinta
    final profile = msg['profiles'] ?? {};
    final name = profile['nickname'] ?? "Dalyvis";
    final timeStr = msg['created_at'] != null
        ? timeago.format(DateTime.parse(msg['created_at']), locale: 'en_short')
        : "";

    if (isAnnouncement) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                "📢 ORGANIZATORIUS: ${msg['message']}",
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                timeStr,
                style: const TextStyle(color: Colors.orange, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? QortModeColors.competition : QortColors.background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(
                name,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(msg['message'], style: const TextStyle(color: QortColors.textPrimary)),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeStr,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
