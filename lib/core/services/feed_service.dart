import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/query_limits.dart';
import '../models/feed_post.dart';
import 'user_sports_service.dart';

/// Q Feed — skaito iš `feed_posts` + patiktukai.
class FeedService {
  FeedService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<FeedPost>> loadFeed({
    String? sportFilter,
    List<String>? sportsFilter,
    int limit = QueryLimits.feedPosts,
  }) async {
    final myId = _client.auth.currentUser?.id;

    var filter = _client.from('feed_posts').select('''
          *,
          user:profiles!feed_posts_user_id_fkey(nickname, photo_url, xp),
          related_user:profiles!feed_posts_related_user_id_fkey(nickname, photo_url),
          event:events!feed_posts_event_id_fkey(name, image_url, sport, location),
          feed_likes(user_id)
        ''');

    if (sportFilter != null && sportFilter.isNotEmpty) {
      filter = filter.eq('sport', sportFilter);
    }

    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30)).toUtc();

    final data = List<Map<String, dynamic>>.from(
      await filter
          .gte('created_at', thirtyDaysAgo.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit),
    );

    return data
        .map((row) {
          final likes = (row['feed_likes'] as List?) ?? [];
          final likedByMe =
              myId != null && likes.any((l) => l['user_id']?.toString() == myId);
          return FeedPost.fromJson(
            row,
            likesCount: likes.length,
            likedByMe: likedByMe,
          );
        })
        .where((post) {
          if (sportsFilter == null || sportsFilter.isEmpty) return true;
          final sport = post.sport?.trim();
          if (sport == null || sport.isEmpty) return true;
          return sportsFilter.any(
            (s) => s.toLowerCase() == sport.toLowerCase(),
          );
        })
        .toList();
  }

  static Future<void> toggleLike(String postId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    final existing = await _client
        .from('feed_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', myId)
        .maybeSingle();

    if (existing != null) {
      await _client.from('feed_likes').delete().eq('id', existing['id']);
    } else {
      await _client.from('feed_likes').insert({
        'post_id': postId,
        'user_id': myId,
      });
    }
  }

  /// Prisijungti prie atviro skelbimo.
  static Future<String?> joinOpenMatch({
    required String userId,
    required Map<String, dynamic> notice,
  }) async {
    try {
      if (notice['creator_id'] == userId) {
        return 'Negalite prisijungti prie savo paties skelbimo!';
      }

      await _client
          .from('open_matches')
          .update({'status': 'closed'})
          .eq('id', notice['id']);

      await _client.from('matches').insert({
        'player1_id': notice['creator_id'],
        'player2_id': userId,
        'match_date': notice['match_date'],
        'location': notice['location'],
        'status': 'scheduled',
      });

      await UserSportsService.addXp(notice['creator_id'] as String, 15);
      await UserSportsService.addXp(userId, 15);

      return null;
    } catch (e) {
      debugPrint('FeedService.joinOpenMatch: $e');
      return 'Nepavyko prisijungti: $e';
    }
  }
}
