import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/qort_colors.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/query_limits.dart';
import '../tournament/tournament_detail_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _isLoading = true;
  String _selectedTab = 'all'; // 'all', 'tournament', 'private'
  String _searchQuery = '';
  List<Map<String, dynamic>> _allChats = [];
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id;
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final client = Supabase.instance.client;

      final myTournaments = await client
          .from('tournament_participants')
          .select('tournament_id, tournaments(name, cover_url)')
          .eq('user_id', _myId!)
          .limit(QueryLimits.inboxTournaments);

      final tournamentIds = (myTournaments as List)
          .map((t) => t['tournament_id'].toString())
          .toList();

      final lastMsgByTournament = <String, Map<String, dynamic>>{};
      if (tournamentIds.isNotEmpty) {
        final recentMsgs = await client
            .from('tournament_chat')
            .select('tournament_id, message, created_at, user_id')
            .inFilter('tournament_id', tournamentIds)
            .order('created_at', ascending: false)
            .limit(QueryLimits.inboxChatPreview);

        final senderIds = (recentMsgs as List)
            .map((m) => m['user_id']?.toString())
            .whereType<String>()
            .toSet()
            .toList();
        final nickById = <String, String>{};
        if (senderIds.isNotEmpty) {
          final profs = await client
              .from('profiles')
              .select('id, nickname')
              .inFilter('id', senderIds);
          for (final p in profs as List) {
            nickById[p['id'].toString()] =
                p['nickname']?.toString() ?? 'Dalyvis';
          }
        }

        for (var msg in recentMsgs) {
          final tid = msg['tournament_id'].toString();
          if (!lastMsgByTournament.containsKey(tid)) {
            final uid = msg['user_id']?.toString();
            lastMsgByTournament[tid] = {
              ...Map<String, dynamic>.from(msg),
              'profiles': uid != null ? {'nickname': nickById[uid]} : null,
            };
          }
        }
      }

      List<Map<String, dynamic>> loadedChats = [];

      for (var t in myTournaments) {
        final tId = t['tournament_id'].toString();
        final tInfo = t['tournaments'];
        final lastMsgRes = lastMsgByTournament[tId];

        final lastMsgText = lastMsgRes != null
            ? lastMsgRes['message']
            : "Pradėkite diskusiją...";
        final lastMsgTime = lastMsgRes?['created_at'];
        final senderName = lastMsgRes != null && lastMsgRes['profiles'] != null
            ? lastMsgRes['profiles']['nickname']
            : "";

        loadedChats.add({
          'type': 'tournament',
          'id': tId,
          'title': tInfo['name'] ?? "Turnyras",
          'image': tInfo['cover_url'],
          'last_message': lastMsgText,
          'sender': senderName,
          'time': lastMsgTime,
          'is_unread': false,
        });
      }

      // Čia vėliau pridėsime "Privatūs" (Matches) logiką
      // ...

      // Rūšiuojame: naujausi viršuje.
      // Jei žinučių nėra, metame į galą.
      loadedChats.sort((a, b) {
        if (a['time'] == null) return 1;
        if (b['time'] == null) return -1;
        return DateTime.parse(b['time']).compareTo(DateTime.parse(a['time']));
      });

      if (mounted) {
        setState(() {
          _allChats = loadedChats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant chat: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Atidaro konkretų chatą
  void _openChat(Map<String, dynamic> chat) async {
    if (chat['type'] == 'tournament') {
      try {
        // Reikia gauti pilną turnyro objektą
        final tData = await Supabase.instance.client
            .from('tournaments')
            .select()
            .eq('id', chat['id'])
            .single();

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              // Svarbu: initialTabIndex: 4 (nurodo atidaryti Chat tabą)
              // Jei tavo DetailScreen neturi šio parametro, reiks pridėti
              builder: (context) =>
                  TournamentDetailScreen(tournament: tData, initialTabIndex: 4),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Klaida: $e")));
      }
    }
  }

  // Filtravimo logika
  List<Map<String, dynamic>> get _filteredChats {
    return _allChats.where((chat) {
      // 1. Tab filtras
      if (_selectedTab == 'tournament' && chat['type'] != 'tournament') {
        return false;
      }
      if (_selectedTab == 'private' && chat['type'] != 'private') return false;

      // 2. Paieškos filtras
      if (_searchQuery.isNotEmpty) {
        final title = chat['title'].toString().toLowerCase();
        return title.contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QortColors.background,
      appBar: AppBar(
        backgroundColor: QortColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "PRANEŠIMAI",
          style: GoogleFonts.bebasNeue(fontSize: 28, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(LucideIcons.settings, color: QortColors.textSecondary),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. PAIEŠKA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: QortColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: QortColors.border),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: "Ieškoti pokalbių...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  icon: Icon(LucideIcons.search, color: Colors.grey, size: 20),
                ),
              ),
            ),
          ),

          // 2. FILTRAI (TABS)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildTab('all', "Visi"),
                const SizedBox(width: 10),
                _buildTab('tournament', "Turnyrai"),
                const SizedBox(width: 10),
                _buildTab('private', "Privatūs"),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Divider(color: QortColors.border, height: 1),

          // 3. SĄRAŠAS
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  )
                : _filteredChats.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _filteredChats.length,
                    itemBuilder: (context, index) {
                      return _buildChatTile(_filteredChats[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String id, String label) {
    final bool isActive = _selectedTab == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : QortColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.white : QortColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final bool isUnread = chat['is_unread'];
    // Laiko formatavimas
    String timeStr = "";
    if (chat['time'] != null) {
      final date = DateTime.parse(chat['time']);
      timeStr = timeago.format(date, locale: 'en_short');
    }

    return InkWell(
      onTap: () => _openChat(chat),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // AVATAR
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: QortColors.background,
                  backgroundImage: chat['image'] != null
                      ? NetworkImage(chat['image'])
                      : null,
                  child: chat['image'] == null
                      ? Icon(
                          chat['type'] == 'tournament'
                              ? LucideIcons.trophy
                              : LucideIcons.user,
                          color: QortColors.textSecondary,
                        )
                      : null,
                ),
                if (isUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD946EF),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: QortColors.background,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 15),

            // TEXT CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat['title'],
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: isUnread
                              ? const Color(0xFFD946EF)
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (chat['sender'] != "")
                        Text(
                          "${chat['sender']}: ",
                          style: const TextStyle(
                            color: QortColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          chat['last_message'],
                          style: TextStyle(
                            color: isUnread ? Colors.white : Colors.grey,
                            fontWeight: isUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.messageSquare, size: 60, color: Colors.grey[800]),
          const SizedBox(height: 15),
          Text(
            "Jokių žinučių",
            style: GoogleFonts.oswald(color: Colors.grey, fontSize: 20),
          ),
          const SizedBox(height: 5),
          const Text(
            "Prisijunkite prie turnyro arba pakvieskite draugą",
            style: TextStyle(color: QortColors.navInactive),
          ),
        ],
      ),
    );
  }
}
