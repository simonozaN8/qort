import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/qort_mode_colors.dart';
import 'core/theme/qort_palette_extension.dart';
import 'core/widgets/qort_logo.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/user_model.dart';
import 'features/home/home_onboarding_sheet.dart';
import 'features/home/home_screen.dart';
import 'features/home/qort_bottom_nav.dart';
import 'features/home/qort_quick_actions.dart';
import 'features/tournament/tournament_list_screen.dart';
import 'features/blitz/blitz_screen.dart';
import 'features/training/open_matches_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/home/inbox_screen.dart';
import 'core/services/user_profile_loader.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;
  AppMode _currentMode = AppMode.competition;
  int _notificationBadge = 0;

  UserProfile _user = UserProfile(
    id: '',
    email: '',
    nickname: 'Žaidėjas',
    name: '',
    surname: '',
    photoUrl: '',
    city: '',
    district: '',
    county: '',
    phone: '',
    xp: 0,
    blitzPoints: 0,
    qCoins: 0.0,
    winStreak: 0,
    sportsList: [],
    gender: 'Vyras',
    birthDate: '',
    height: '',
    dominantSide: 'Dešinė',
    locationPreference: 'Mano mieste',
    isInjured: false,
    isOnVacation: false,
  );

  bool _isLoading = true;
  final List<Widget?> _tabCache = List.filled(4, null);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNotificationBadge();
  }

  Future<void> _loadUserData() async {
    try {
      final profile = await UserProfileLoader.loadCurrent();
      if (mounted) {
        setState(() {
          if (profile != null) _user = profile;
          _isLoading = false;
          _tabCache[0] = null;
          _tabCache[3] = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) HomeOnboardingSheet.showIfNeeded(context);
        });
      }
    } catch (e) {
      debugPrint('Klaida užkraunant profilį: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNotificationBadge() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final res = await Supabase.instance.client
          .from('team_invitations')
          .select('id')
          .eq('invitee_id', uid)
          .eq('status', 'pending');
      if (mounted) {
        setState(() => _notificationBadge = (res as List).length);
      }
    } catch (_) {}
  }

  void _changeMode(AppMode mode) {
    setState(() {
      _currentMode = mode;
      _currentIndex = 0;
      _tabCache[0] = null;
      _tabCache[1] = null;
    });
  }

  Widget _buildPlayTab() {
    if (_currentMode == AppMode.training) {
      return OpenMatchesScreen(user: _user);
    }
    if (_currentMode == AppMode.blitz) {
      return const BlitzScreen();
    }
    return const TournamentListScreen();
  }

  Widget _screenAt(int index) {
    return _tabCache[index] ??= switch (index) {
      0 => HomeScreen(
          currentMode: _currentMode,
          userName: _user.nickname.isNotEmpty ? _user.nickname : 'Žaidėjas',
          onModeSelected: _changeMode,
          onOpenPlayTab: () => setState(() => _currentIndex = 1),
          onOpenQuickActions: () => QortQuickActions.show(
            context,
            user: _user,
            onRecordsChanged: () {
              _loadUserData();
              _loadNotificationBadge();
            },
          ),
        ),
      1 => _buildPlayTab(),
      2 => NotificationsScreen(currentMode: _currentMode),
      3 => ProfileScreen(
          user: _user,
          currentMode: _currentMode,
          onUserUpdate: (updatedUser) => setState(() {
            _user = updatedUser;
            _tabCache[3] = null;
          }),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Color _accentForMode(AppMode mode) {
    switch (mode) {
      case AppMode.training:
        return QortModeColors.training;
      case AppMode.blitz:
        return QortModeColors.blitz;
      case AppMode.competition:
        return QortModeColors.competition;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final p = context.qortPalette;
      return Scaffold(
        backgroundColor: p.background,
        body: Center(
          child: CircularProgressIndicator(color: p.primary),
        ),
      );
    }

    final p = context.qortPalette;

    return Scaffold(
      backgroundColor: p.background,
      extendBody: true,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(bottom: BorderSide(color: p.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: p.isDark ? 0.25 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
                child: Row(
                  children: [
                    const QortLogo(height: 30),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _modeBtn(context, AppMode.competition, LucideIcons.trophy, 'Varžybos'),
                          const SizedBox(width: 6),
                          _modeBtn(context, AppMode.training, LucideIcons.target, 'Treniruotės'),
                          const SizedBox(width: 6),
                          _modeBtn(context, AppMode.blitz, LucideIcons.zap, 'Blitz'),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Žinutės',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InboxScreen()),
                      ),
                      icon: Icon(
                        LucideIcons.messageSquare,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: List.generate(4, (i) {
                if (_tabCache[i] == null && i != _currentIndex) {
                  return const SizedBox.shrink();
                }
                return _screenAt(i);
              }),
            ),
          ),
        ],
      ),
      bottomNavigationBar: QortBottomNav(
        currentIndex: _currentIndex,
        currentMode: _currentMode,
        notificationBadge: _notificationBadge,
        onTabSelected: (i) {
          setState(() => _currentIndex = i);
          if (i == 2) _loadNotificationBadge();
        },
        onFabPressed: () => QortQuickActions.show(
          context,
          user: _user,
          onRecordsChanged: () {
            _loadUserData();
            _loadNotificationBadge();
          },
        ),
      ),
    );
  }

  Widget _modeBtn(BuildContext context, AppMode mode, IconData icon, String label) {
    final isSelected = _currentMode == mode;
    final accent = _accentForMode(mode);
    final p = context.qortPalette;

    return GestureDetector(
      onTap: () => _changeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? accent : p.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accent : p.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : p.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
