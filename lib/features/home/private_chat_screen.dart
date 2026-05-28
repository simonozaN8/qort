import 'package:flutter/material.dart';
import '../../core/theme/qort_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/query_limits.dart';

class PrivateChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;

  const PrivateChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String? _myId;
  String? _chatRoomId;
  bool _isLoadingRoom = true;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id;
    _initChatRoom();
  }

  // Patikrina ar kambarys egzistuoja, jei ne - sukuria
  Future<void> _initChatRoom() async {
    if (_myId == null) return;

    try {
      final client = Supabase.instance.client;

      // Ieškome esamo kambario
      final existingRooms = await client
          .from('direct_chats')
          .select('id')
          .or(
            'and(user1_id.eq.$_myId,user2_id.eq.${widget.otherUserId}),and(user1_id.eq.${widget.otherUserId},user2_id.eq.$_myId)',
          )
          .limit(1);

      if (existingRooms.isNotEmpty) {
        setState(() {
          _chatRoomId = existingRooms[0]['id'];
          _isLoadingRoom = false;
        });
      } else {
        // Sukuriame naują kambarį
        final newRoom = await client
            .from('direct_chats')
            .insert({'user1_id': _myId, 'user2_id': widget.otherUserId})
            .select('id')
            .single();

        setState(() {
          _chatRoomId = newRoom['id'];
          _isLoadingRoom = false;
        });
      }
    } catch (e) {
      debugPrint("Klaida inicializuojant pokalbį: $e");
      if (mounted) setState(() => _isLoadingRoom = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty || _chatRoomId == null || _myId == null) {
      return;
    }

    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();

    try {
      await Supabase.instance.client.from('direct_messages').insert({
        'chat_id': _chatRoomId,
        'sender_id': _myId,
        'content': text,
      });

      // Atnaujiname kambario updated_at, kad Inbox'e pakiltų į viršų
      await Supabase.instance.client
          .from('direct_chats')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', _chatRoomId!);
    } catch (e) {
      debugPrint("Klaida siunčiant žinutę: $e");
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: QortColors.background,
              backgroundImage: widget.otherUserAvatar.isNotEmpty
                  ? NetworkImage(widget.otherUserAvatar)
                  : null,
              child: widget.otherUserAvatar.isEmpty
                  ? const Icon(
                      LucideIcons.user,
                      color: QortColors.textSecondary,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherUserName,
              style: GoogleFonts.oswald(fontSize: 18, color: Colors.white),
            ),
          ],
        ),
      ),
      body: _isLoadingRoom
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client
                        .from('direct_messages')
                        .stream(primaryKey: ['id'])
                        .eq('chat_id', _chatRoomId!)
                        .order('created_at', ascending: false)
                        .limit(QueryLimits.chatMessages),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.blue),
                        );
                      }

                      final messages = snapshot.data!;
                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            "Pradėkite pokalbį su ${widget.otherUserName}!",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollCtrl,
                        reverse: true, // Svarbu: rodo naujausias apačioje
                        padding: const EdgeInsets.all(15),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg['sender_id'] == _myId;
                          final date = DateTime.parse(
                            msg['created_at'],
                          ).toLocal();
                          final timeStr = DateFormat('HH:mm').format(date);

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
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.blue
                                    : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['content'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      color: isMe
                                          ? QortColors.textSecondary
                                          : Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: const BoxDecoration(
        color: QortColors.surface,
        border: Border(top: BorderSide(color: QortColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Rašyti žinutę...",
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: QortColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
