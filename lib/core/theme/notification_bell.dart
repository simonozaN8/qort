import 'package:flutter/material.dart';
import '../../../../../../../../../core/theme/qort_colors.dart';

import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/notifications/notifications_screen.dart';

/// Globalus pranešimų varpelis - rodomas ekrano viršuje
/// Periodiškai atsinaujina ir rodo nepatvirtintų pranešimų skaičių
class NotificationBell extends StatefulWidget {
  /// Spalva (jei null - balta)
  final Color? color;

  /// Dydis
  final double iconSize;

  const NotificationBell({super.key, this.color, this.iconSize = 22});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unreadCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        _isLoading = false;
        return;
      }

      final myId = session.user.id;
      final supabase = Supabase.instance.client;

      // Skaičiuojame visus nepatvirtintus pranešimus
      // 1. Komandos pakvietimai
      final invitations = await supabase
          .from('team_invitations')
          .select('id')
          .eq('invited_user_id', myId)
          .eq('status', 'pending');

      final total = (invitations as List).length;
      // Ateityje pridėsim daugiau šaltinių (mini protokolas, sistemos pranešimai)

      if (mounted) {
        setState(() {
          _unreadCount = total;
        });
      }
    } catch (e) {
      debugPrint("Klaida kraunant pranešimus: $e");
    } finally {
      _isLoading = false;
    }
  }

  void _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    // Po grįžimo - atnaujiname skaičių
    _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.color ?? Colors.white;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(LucideIcons.bell, color: iconColor, size: widget.iconSize),
          onPressed: _open,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: QortColors.background, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _unreadCount > 9 ? "9+" : "$_unreadCount",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
