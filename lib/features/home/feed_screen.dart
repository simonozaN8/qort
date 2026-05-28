import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/feed_service.dart';
import '../../core/services/user_profile_loader.dart';
import '../../core/theme/qort_design_system.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../profile/user_model.dart';
import 'feed_widgets.dart';

class FeedScreen extends StatefulWidget {
  final UserProfile user;
  final VoidCallback onOpenProfileTab;
  final VoidCallback? onUserRefresh;

  const FeedScreen({
    super.key,
    required this.user,
    required this.onOpenProfileTab,
    this.onUserRefresh,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
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

  FeedData? _feed;
  bool _isLoading = true;
  String? _joiningNoticeId;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  List<String> get _mySports =>
      _user.sportsList.map((s) => s.name).where((n) => n.isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.sportsList.length != widget.user.sportsList.length) {
      _user = widget.user;
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    final uid = _userId;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profile = await UserProfileLoader.loadById(uid);
      if (profile != null && mounted) {
        setState(() => _user = profile);
      }
    } catch (_) {}

    final sports = _mySports;
    FeedData? feed;

    if (sports.isEmpty) {
      feed = FeedData.emptySports();
    } else {
      feed = await FeedService.load(
        userId: uid,
        mySports: sports,
        userCity: _user.city,
      );
    }

    if (mounted) {
      setState(() {
        _feed = feed;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    widget.onUserRefresh?.call();
    await _loadAll();
  }

  Future<void> _joinNotice(Map<String, dynamic> notice) async {
    final uid = _userId;
    if (uid == null) return;

    setState(() => _joiningNoticeId = notice['id']?.toString());

    final error = await FeedService.joinOpenMatch(userId: uid, notice: notice);

    if (!mounted) return;
    setState(() => _joiningNoticeId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              'Sėkmingai prisijungėte! Mačas suderintas. Gavote +15 XP.',
        ),
        backgroundColor: error != null ? Colors.red : Colors.green,
      ),
    );

    if (error == null) await _loadAll();
  }

  bool _isFeedFullyEmpty(FeedData feed) {
    final friendEmpty =
        !feed.friendActivity.failed && feed.friendActivity.data.isEmpty;
    final openEmpty =
        !feed.openMatches.failed && feed.openMatches.data.isEmpty;
    return friendEmpty && openEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final feed = _feed;
    final hasSports = _mySports.isNotEmpty;

    return Scaffold(
      backgroundColor: p.background,
      body: RefreshIndicator(
        color: QortDesignSystem.brand,
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  QortDesignSystem.space4,
                  QortDesignSystem.space4,
                  QortDesignSystem.space4,
                  QortDesignSystem.space2,
                ),
                child: FeedCommunityHeader(),
              ),
            ),
            if (_isLoading && feed == null)
              const SliverToBoxAdapter(child: FeedSectionLoading())
            else if (!hasSports)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(QortDesignSystem.space4),
                  child: FeedNoSportsCta(onOpenProfile: widget.onOpenProfileTab),
                ),
              )
            else if (feed != null && _isFeedFullyEmpty(feed))
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(QortDesignSystem.space4),
                  child: FeedEmptyCommunity(),
                ),
              )
            else if (feed != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: QortDesignSystem.space4,
                  ),
                  child: FeedFriendActivitySection(
                    items: feed.friendActivity.data,
                    failed: feed.friendActivity.failed,
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: QortDesignSystem.space6),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: QortDesignSystem.space4,
                  ),
                  child: FeedOpenMatchesSection(
                    notices: feed.openMatches.data,
                    failed: feed.openMatches.failed,
                    joiningId: _joiningNoticeId,
                    onJoin: _joinNotice,
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(height: feedScrollBottomPadding(context)),
            ),
          ],
        ),
      ),
    );
  }
}
