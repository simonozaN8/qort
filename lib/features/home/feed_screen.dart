import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/feed_post.dart';
import '../../core/services/feed_service.dart';
import '../../core/services/user_profile_loader.dart';
import '../../core/theme/qort_design_system.dart';
import '../../core/theme/qort_palette_extension.dart';
import '../profile/my_results_screen.dart';
import '../profile/user_model.dart';
import '../teams/team_profile_screen.dart';
import '../tournament/event_detail_screen.dart';
import '../training/open_matches_screen.dart';
import 'feed_post_card.dart';
import 'feed_widgets.dart';
import 'match_negotiation_screen.dart';

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

  List<FeedPost> _posts = [];
  bool _isLoading = true;
  bool _loadFailed = false;

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
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final profile = await UserProfileLoader.loadById(uid);
        if (profile != null && mounted) {
          _user = profile;
        }
      }

      final sports = _mySports;
      if (sports.isEmpty) {
        if (mounted) {
          setState(() {
            _posts = [];
            _isLoading = false;
          });
        }
        return;
      }

      final posts = await FeedService.loadFeed(sportsFilter: sports);

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Feed load error: $e');
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    widget.onUserRefresh?.call();
    await _loadAll();
  }

  Future<void> _handlePostTap(FeedPost post) async {
    switch (post.postType) {
      case 'tournament_match':
      case 'tournament_joined':
      case 'tournament_finished':
        if (post.eventId != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailScreen(event: {'id': post.eventId}),
            ),
          );
        }
        break;

      case 'training_match':
        if (post.sourceTable == 'matches' && post.sourceId != null) {
          await _openMatchDetail(post.sourceId!);
        }
        break;

      case 'open_match_created':
        if (post.sourceId != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OpenMatchesScreen(
                user: _user,
                highlightId: post.sourceId,
              ),
            ),
          );
        }
        break;

      case 'team_created':
        if (post.sourceId != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeamProfileScreen(teamId: post.sourceId!),
            ),
          );
        }
        break;

      case 'external_record':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MyResultsScreen(initialTab: 2),
          ),
        );
        break;
    }
  }

  Future<void> _openMatchDetail(String matchId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final row = await Supabase.instance.client
          .from('matches')
          .select()
          .eq('id', matchId)
          .maybeSingle();

      if (!mounted || row == null) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchNegotiationScreen(
            match: Map<String, dynamic>.from(row),
            currentUserId: uid,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Feed open match error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final hasSports = _mySports.isNotEmpty;

    return Scaffold(
      backgroundColor: p.background,
      body: RefreshIndicator(
        color: QortDesignSystem.brand,
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_isLoading)
              const SliverToBoxAdapter(child: FeedSectionLoading())
            else if (!hasSports)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(QortDesignSystem.space4),
                  child: FeedNoSportsCta(onOpenProfile: widget.onOpenProfileTab),
                ),
              )
            else if (_loadFailed)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(QortDesignSystem.space4),
                  child: Column(
                    children: [
                      const FeedQStreamEmpty(),
                      TextButton(
                        onPressed: _loadAll,
                        child: const Text('Bandyti dar kartą'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_posts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: FeedQStreamEmpty(),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => FeedPostCard(
                    post: _posts[index],
                    currentUserId: _user.id.isNotEmpty
                        ? _user.id
                        : Supabase.instance.client.auth.currentUser?.id,
                    onTap: () => _handlePostTap(_posts[index]),
                  ),
                  childCount: _posts.length,
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: feedScrollBottomPadding(context)),
            ),
          ],
        ),
      ),
    );
  }
}
