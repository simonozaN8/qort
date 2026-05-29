import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'core/theme/notification_bell.dart';
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
import 'features/home/feed_screen.dart';
import 'features/home/inbox_screen.dart';
import 'core/services/user_profile_loader.dart';

enum _HeaderModeLabelStyle { iconOnly, short, full }

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;
  AppMode _currentMode = AppMode.competition;

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
  int _lastStackIndex = 0;

  static const int _createTabIndex = 3;
  static const int _profileTabIndex = 4;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final profile = await UserProfileLoader.loadCurrent();
      if (mounted) {
        setState(() {
          if (profile != null) _user = profile;
          _isLoading = false;
          _tabCache[0] = null;
          _tabCache[2] = null;
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
            onRecordsChanged: _loadUserData,
          ),
        ),
      1 => _buildPlayTab(),
      2 => FeedScreen(
          user: _user,
          onOpenProfileTab: () => setState(() => _currentIndex = _profileTabIndex),
          onUserRefresh: _loadUserData,
        ),
      3 => ProfileScreen(
          user: _user,
          currentMode: _currentMode,
          onUserUpdate: (updatedUser) => setState(() {
            _user = updatedUser;
            _tabCache[2] = null;
            _tabCache[3] = null;
          }),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  int get _stackIndex {
    if (_currentIndex == _createTabIndex) return _lastStackIndex;
    if (_currentIndex == _profileTabIndex) return 3;
    return _currentIndex;
  }

  void _onTabSelected(int index) {
    if (index == _createTabIndex) {
      setState(() => _currentIndex = _createTabIndex);
      QortQuickActions.show(
        context,
        user: _user,
        onRecordsChanged: _loadUserData,
      ).whenComplete(() {
        if (mounted) {
          setState(() => _currentIndex = _tabIndexForStack(_lastStackIndex));
        }
      });
      return;
    }

    setState(() {
      _currentIndex = index;
      _lastStackIndex = index == _profileTabIndex ? 3 : index;
    });
  }

  int _tabIndexForStack(int stackIndex) =>
      stackIndex == 3 ? _profileTabIndex : stackIndex;

  void _onCreatePressed() => _onTabSelected(_createTabIndex);

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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final labelStyle = _labelStyleForWidth(screenWidth);
    final isCompactHeader = screenWidth < 600;
    final headerPadding = isCompactHeader
        ? const EdgeInsets.fromLTRB(12, 8, 4, 10)
        : const EdgeInsets.fromLTRB(16, 8, 8, 10);
    final pillGap = isCompactHeader ? 4.0 : 6.0;

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
                padding: headerPadding,
                child: Row(
                  children: [
                    const QortLogo(height: 30),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _modeBtn(
                            context,
                            AppMode.competition,
                            LucideIcons.trophy,
                            labelStyle,
                          ),
                          SizedBox(width: pillGap),
                          _modeBtn(
                            context,
                            AppMode.training,
                            LucideIcons.target,
                            labelStyle,
                          ),
                          SizedBox(width: pillGap),
                          _modeBtn(
                            context,
                            AppMode.blitz,
                            LucideIcons.zap,
                            labelStyle,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NotificationBell(
                          color: p.textSecondary,
                          iconSize: isCompactHeader ? 20 : 22,
                        ),
                        IconButton(
                          tooltip: 'Žinutės',
                          visualDensity: isCompactHeader
                              ? VisualDensity.compact
                              : VisualDensity.standard,
                          constraints: isCompactHeader
                              ? const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                )
                              : null,
                          padding: isCompactHeader ? EdgeInsets.zero : null,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InboxScreen(),
                            ),
                          ),
                          icon: Icon(
                            LucideIcons.messageSquare,
                            color: p.textSecondary,
                            size: isCompactHeader ? 20 : 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _stackIndex,
              children: List.generate(4, (i) {
                if (_tabCache[i] == null && i != _stackIndex) {
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
        onTabSelected: _onTabSelected,
        onCreatePressed: _onCreatePressed,
      ),
    );
  }

  _HeaderModeLabelStyle _labelStyleForWidth(double width) {
    if (width < 400) return _HeaderModeLabelStyle.iconOnly;
    if (width < 440) return _HeaderModeLabelStyle.short;
    return _HeaderModeLabelStyle.full;
  }

  String? _modeLabel(AppMode mode, _HeaderModeLabelStyle style) {
    if (style == _HeaderModeLabelStyle.iconOnly) return null;
    switch (mode) {
      case AppMode.competition:
        return style == _HeaderModeLabelStyle.short ? 'Varž.' : 'Varžybos';
      case AppMode.training:
        return style == _HeaderModeLabelStyle.short ? 'Trenir.' : 'Treniruotės';
      case AppMode.blitz:
        return 'Blitz';
    }
  }

  Widget _modeBtn(
    BuildContext context,
    AppMode mode,
    IconData icon,
    _HeaderModeLabelStyle labelStyle,
  ) {
    final isSelected = _currentMode == mode;
    final accent = _accentForMode(mode);
    final p = context.qortPalette;
    final label = _modeLabel(mode, labelStyle);
    final iconOnly = labelStyle == _HeaderModeLabelStyle.iconOnly;

    return GestureDetector(
      onTap: () => _changeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: iconOnly ? 8 : 10,
          vertical: 7,
        ),
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
              size: iconOnly ? 14 : 13,
              color: isSelected ? Colors.white : p.textSecondary,
            ),
            if (label != null) ...[
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
          ],
        ),
      ),
    );
  }
}
