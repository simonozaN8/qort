import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/models/feed_post.dart';
import '../../core/services/feed_service.dart';
import '../../core/theme/qort_design_system.dart';
import '../../core/utils/feed_match_result.dart';
import '../../core/utils/sport_icons.dart';
import '../profile/status_avatar.dart';

class FeedPostCard extends StatefulWidget {
  final FeedPost post;
  final String? currentUserId;
  final VoidCallback? onTap;

  const FeedPostCard({
    super.key,
    required this.post,
    this.currentUserId,
    this.onTap,
  });

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  late FeedPost _post;
  bool _togglingLike = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(covariant FeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.likesCount != widget.post.likesCount ||
        oldWidget.post.likedByMe != widget.post.likedByMe) {
      _post = widget.post;
    }
  }

  Future<void> _toggleLike() async {
    if (_togglingLike) return;
    final wasLiked = _post.likedByMe;
    setState(() {
      _togglingLike = true;
      _post = _post.copyWith(
        likedByMe: !wasLiked,
        likesCount: wasLiked
            ? (_post.likesCount > 0 ? _post.likesCount - 1 : 0)
            : _post.likesCount + 1,
      );
    });

    try {
      await FeedService.toggleLike(_post.id);
    } catch (_) {
      if (mounted) setState(() => _post = widget.post);
    } finally {
      if (mounted) setState(() => _togglingLike = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildContent(),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        children: [
          StatusAvatar(
            imageUrl: _post.user.photoUrl ?? '',
            displayName: _post.user.displayName,
            radius: 18,
            xp: _post.user.xp ?? 0,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _post.user.displayName,
                  style: QortDesignSystem.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_postTypeLabel(_post.postType)} · ${_formatTimestamp(_post.createdAt)}',
                  style: QortDesignSystem.caption,
                ),
              ],
            ),
          ),
          if (_post.sport != null && _post.sport!.isNotEmpty)
            SportIcons.badge(_post.sport!, size: 22),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (_post.postType) {
      'tournament_match' => _buildTournamentMatchContent(),
      'training_match' => _buildTrainingMatchContent(),
      'external_record' => _buildExternalContent(),
      'open_match_created' => _buildOpenMatchContent(),
      'team_created' => _buildTeamContent(),
      'tournament_joined' => _buildTournamentJoinContent(),
      'tournament_finished' => _buildTournamentFinishedContent(),
      _ => _buildGenericContent(),
    };
  }

  Widget _buildPlayersRow() {
    final p1 = _post.user;
    final p2 = _post.relatedUser;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _playerChip(p1.displayName, p1.photoUrl ?? '', p1.xp ?? 0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'vs',
            style: QortDesignSystem.caption.copyWith(
              color: QortDesignSystem.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _playerChip(
          p2?.displayName ?? 'varžovas',
          p2?.photoUrl ?? '',
          p2?.xp ?? 0,
        ),
      ],
    );
  }

  Widget _playerChip(String name, String photo, int xp) {
    return Column(
      children: [
        StatusAvatar(imageUrl: photo, displayName: name, radius: 22, xp: xp),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: QortDesignSystem.caption.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _scoreBadge() {
    final raw = _post.score;
    if (raw == null || raw.isEmpty) return const SizedBox.shrink();
    final score = FeedMatchResult.scoreFromUserPerspective(
      raw,
      widget.currentUserId,
      _post.data,
      postType: _post.postType,
    );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        score,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _matchResultBadge() {
    if (!FeedMatchResult.isMatchPost(_post.postType)) {
      return const SizedBox.shrink();
    }
    final badge = FeedMatchResult.badge(_post, widget.currentUserId);
    if (badge == null) return const SizedBox.shrink();
    return Align(alignment: Alignment.centerLeft, child: badge);
  }

  Widget _buildTournamentMatchContent() {
    final cover = _post.eventCoverUrl;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: QortDesignSystem.bgElevated,
        image: cover != null && cover.isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(cover),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.6),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _matchResultBadge(),
            if (_post.tournamentName != null) ...[
              const SizedBox(height: 8),
              Text(
                _post.tournamentName!,
                textAlign: TextAlign.center,
                style: QortDesignSystem.h3.copyWith(fontSize: 16),
              ),
            ],
            const SizedBox(height: 12),
            _buildPlayersRow(),
            _scoreBadge(),
            if (_post.location != null && _post.location!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.mapPin, size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _post.location!,
                      style: QortDesignSystem.caption.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingMatchContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: QortDesignSystem.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: QortDesignSystem.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _matchResultBadge(),
            const SizedBox(height: 8),
            Text(
              'Treniruotės mačas',
              style: QortDesignSystem.h3.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 12),
            _buildPlayersRow(),
            _scoreBadge(),
            if (_post.location != null && _post.location!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_post.location!, style: QortDesignSystem.caption),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExternalContent() {
    final opponent = _post.opponentName ?? 'varžovas';
    final won = _post.iWon;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: QortDesignSystem.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: won == true
                ? Colors.green.withValues(alpha: 0.4)
                : won == false
                    ? Colors.red.withValues(alpha: 0.4)
                    : QortDesignSystem.borderSubtle,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _matchResultBadge(),
            const SizedBox(height: 8),
            Text('Išorinis rezultatas', style: QortDesignSystem.caption),
            const SizedBox(height: 10),
            Row(
              children: [
                StatusAvatar(
                  imageUrl: _post.user.photoUrl ?? '',
                  displayName: _post.user.displayName,
                  radius: 20,
                  xp: _post.user.xp ?? 0,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _post.user.displayName,
                        style: QortDesignSystem.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text('vs $opponent', style: QortDesignSystem.caption),
                    ],
                  ),
                ),
              ],
            ),
            if (won != null) ...[
              const SizedBox(height: 8),
              Text(
                won ? 'Laimėjimas' : 'Pralaimėjimas',
                style: TextStyle(
                  color: won ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_post.score != null) ...[
              const SizedBox(height: 8),
              Text(
                _post.score!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOpenMatchContent() {
    final dateStr = _post.data['match_date']?.toString();
    String? dateLabel;
    if (dateStr != null && dateStr.isNotEmpty) {
      final parsed = DateTime.tryParse(dateStr);
      dateLabel = parsed != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(parsed)
          : dateStr;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              QortDesignSystem.training.withValues(alpha: 0.25),
              QortDesignSystem.bgElevated,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.search, size: 16, color: QortDesignSystem.training),
                SizedBox(width: 6),
                Text(
                  'Ieškau partnerio',
                  style: TextStyle(
                    color: QortDesignSystem.training,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (_post.sport != null && _post.sport!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  SportIcons.icon(_post.sport!, size: 16),
                  const SizedBox(width: 6),
                  Text(_post.sport!, style: QortDesignSystem.body),
                ],
              ),
            ],
            if (_post.location != null && _post.location!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Expanded(child: Text(_post.location!, style: QortDesignSystem.caption)),
                ],
              ),
            ],
            if (dateLabel != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(dateLabel, style: QortDesignSystem.caption),
                ],
              ),
            ],
            if (_post.matchFormat != null) ...[
              const SizedBox(height: 4),
              Text('Formatas: ${_post.matchFormat}', style: QortDesignSystem.caption),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: QortDesignSystem.bgElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.shield, color: QortDesignSystem.brand, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _post.teamName ?? 'Komanda',
                    style: QortDesignSystem.h3.copyWith(fontSize: 16),
                  ),
                  if (_post.sport != null && _post.sport!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_post.sport!, style: QortDesignSystem.caption),
                  ],
                  if (_post.teamLevel != null) ...[
                    const SizedBox(height: 2),
                    Text('Lygis: ${_post.teamLevel}', style: QortDesignSystem.caption),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverCard({required Widget child}) {
    final cover = _post.eventCoverUrl;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: QortDesignSystem.bgElevated,
        image: cover != null && cover.isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(cover),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.55),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildTournamentJoinContent() {
    return _coverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_post.tournamentName != null)
            Text(
              _post.tournamentName!,
              style: QortDesignSystem.h3.copyWith(fontSize: 16),
            ),
          const SizedBox(height: 6),
          Text(
            '${_post.user.displayName} prisiregistravo',
            style: QortDesignSystem.body.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentFinishedContent() {
    final winner = _post.winnerName ?? _post.user.displayName;
    return _coverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_post.tournamentName != null)
            Text(
              _post.tournamentName!,
              style: QortDesignSystem.h3.copyWith(fontSize: 16),
            ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(LucideIcons.trophy, size: 16, color: Colors.amber),
              SizedBox(width: 6),
              Text('Turnyras baigtas', style: TextStyle(color: Colors.amber)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Nugalėtojas: $winner',
            style: QortDesignSystem.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(_postTypeLabel(_post.postType), style: QortDesignSystem.body),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Row(
        children: [
          InkWell(
            onTap: _toggleLike,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.flame,
                    color: _post.likedByMe ? Colors.orange : Colors.white54,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_post.likesCount}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            _formatTimestamp(_post.createdAt),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _postTypeLabel(String type) {
    return switch (type) {
      'tournament_match' => 'Turnyro mačas',
      'training_match' => 'Treniruotės mačas',
      'external_record' => 'Išorinis įrašas',
      'open_match_created' => 'Atviras mačas',
      'team_created' => 'Nauja komanda',
      'tournament_joined' => 'Turnyro registracija',
      'tournament_finished' => 'Turnyras baigtas',
      _ => 'Įvykis',
    };
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'ką tik';
    if (diff.inHours < 1) return 'prieš ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'prieš ${diff.inHours} val';
    return DateFormat('MM-dd HH:mm').format(dt);
  }
}
