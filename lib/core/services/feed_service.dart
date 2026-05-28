import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/query_limits.dart';
import 'friends_service.dart';
import 'home_dashboard_service.dart';
import 'user_sports_service.dart';
import '../../features/teams/team_model.dart';

enum FeedActionKind {
  teamInvitation,
  timeProposal,
  ladderChallenge,
  scoreConfirm,
  unscheduledBatch,
}

class FeedActionItem {
  final FeedActionKind kind;
  final String title;
  final String subtitle;
  final dynamic payload;

  const FeedActionItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.payload,
  });
}

enum FeedActivityKind {
  matchWin,
  friendlyWin,
  tournamentJoin,
  teamCreated,
}

class FeedActivityItem {
  final FeedActivityKind kind;
  final DateTime occurredAt;
  final String actorName;
  final String description;
  final String sport;

  const FeedActivityItem({
    required this.kind,
    required this.occurredAt,
    required this.actorName,
    required this.description,
    required this.sport,
  });
}

class FeedSectionResult<T> {
  final T data;
  final bool failed;

  const FeedSectionResult({required this.data, this.failed = false});

  factory FeedSectionResult.ok(T data) => FeedSectionResult(data: data);
  factory FeedSectionResult.fail(T empty) =>
      FeedSectionResult(data: empty, failed: true);
}

class FeedData {
  final List<String> mySports;
  final FeedSectionResult<List<FeedActionItem>> actions;
  final FeedSectionResult<List<FeedActivityItem>> friendActivity;
  final FeedSectionResult<List<dynamic>> openMatches;
  final FeedSectionResult<List<dynamic>> myTournaments;

  const FeedData({
    required this.mySports,
    required this.actions,
    required this.friendActivity,
    required this.openMatches,
    required this.myTournaments,
  });

  factory FeedData.emptySports() => FeedData(
        mySports: const [],
        actions: FeedSectionResult.ok([]),
        friendActivity: FeedSectionResult.ok([]),
        openMatches: FeedSectionResult.ok([]),
        myTournaments: FeedSectionResult.ok([]),
      );
}

/// Feed (Q) duomenų agregatorius — kiekviena sekcija kraunama atskirai.
class FeedService {
  FeedService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<FeedData> load({
    required String userId,
    required List<String> mySports,
    String? userCity,
  }) async {
    if (mySports.isEmpty) return FeedData.emptySports();

    final results = await Future.wait([
      _loadActions(userId, mySports),
      _loadFriendActivity(userId, mySports),
      _loadOpenMatches(userId, mySports, userCity),
      _loadMyTournaments(userId, mySports),
    ]);

    return FeedData(
      mySports: mySports,
      actions: results[0] as FeedSectionResult<List<FeedActionItem>>,
      friendActivity: results[1] as FeedSectionResult<List<FeedActivityItem>>,
      openMatches: results[2],
      myTournaments: results[3],
    );
  }

  /// Prisijungti prie atviro skelbimo (ta pati DB logika kaip open_matches_screen).
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

  static bool _matchInSports(Map<String, dynamic> m, List<String> sports) {
    final sport = m['tournaments']?['sport']?.toString();
    if (sport == null || sport.isEmpty) return true;
    return sports.contains(sport);
  }

  static Future<FeedSectionResult<List<FeedActionItem>>> _loadActions(
    String userId,
    List<String> mySports,
  ) async {
    try {
      final items = <FeedActionItem>[];

      final invitations = await _client
          .from('team_invitations')
          .select('''
            *,
            teams(id, name, sport, level, logo_url),
            inviter:profiles!team_invitations_invited_by_fkey(nickname, name, surname)
          ''')
          .eq('invited_user_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      for (final json in invitations as List) {
        final inv = TeamInvitation.fromJson(Map<String, dynamic>.from(json));
        if (inv.teamSport.isNotEmpty && !mySports.contains(inv.teamSport)) {
          continue;
        }
        items.add(
          FeedActionItem(
            kind: FeedActionKind.teamInvitation,
            title: 'Komandos pakvietimas',
            subtitle:
                '${inv.inviterName.isNotEmpty ? inv.inviterName : 'Kažkas'} kviečia į „${inv.teamName}“',
            payload: inv,
          ),
        );
      }

      final dashboard = await HomeDashboardService.load(userId);

      for (final m in dashboard.incomingProposals) {
        if (!_matchInSports(Map<String, dynamic>.from(m), mySports)) continue;
        final cardType = m['card_type']?.toString();
        if (cardType == 'ladder_challenge') {
          items.add(
            FeedActionItem(
              kind: FeedActionKind.ladderChallenge,
              title: 'Ladder iššūkis',
              subtitle:
                  '${m['opponent_name']} · ${m['tournament_name'] ?? 'Turnyras'}',
              payload: m,
            ),
          );
        } else {
          items.add(
            FeedActionItem(
              kind: FeedActionKind.timeProposal,
              title: 'Laiko pasiūlymas',
              subtitle:
                  '${m['opponent_name']} · ${m['tournament_name'] ?? 'Turnyras'}',
              payload: m,
            ),
          );
        }
      }

      for (final m in dashboard.allMatches) {
        if (m['status'] != 'played_waiting') continue;
        if (!_matchInSports(Map<String, dynamic>.from(m), mySports)) continue;

        final enteredBy = m['match_details']?['entered_by'];
        if (enteredBy == userId) continue;

        items.add(
          FeedActionItem(
            kind: FeedActionKind.scoreConfirm,
            title: 'Patvirtink rezultatą',
            subtitle:
                '${m['opponent_name']} · ${m['tournament_name'] ?? 'Turnyras'}',
            payload: m,
          ),
        );
      }

      final actionableUnscheduled = <dynamic>[];
      for (final m in dashboard.unscheduledMatches) {
        if (!_matchInSports(Map<String, dynamic>.from(m), mySports)) continue;
        if (m['is_proposal_active'] == true && m['proposer_id'] == userId) {
          continue;
        }
        actionableUnscheduled.add(m);
      }

      if (actionableUnscheduled.isNotEmpty) {
        items.add(
          FeedActionItem(
            kind: FeedActionKind.unscheduledBatch,
            title: 'Nesuderinti mačai',
            subtitle:
                '${actionableUnscheduled.length} mačai laukia laiko derinimo',
            payload: actionableUnscheduled,
          ),
        );
      }

      return FeedSectionResult.ok(items);
    } catch (e) {
      debugPrint('FeedService._loadActions: $e');
      return FeedSectionResult.fail([]);
    }
  }

  static Future<FeedSectionResult<List<FeedActivityItem>>> _loadFriendActivity(
    String userId,
    List<String> mySports,
  ) async {
    try {
      final friendIds = await FriendsService.getConnectedUserIds(userId);
      if (friendIds.isEmpty) return FeedSectionResult.ok([]);

      final friendList = friendIds.toList();
      final events = <FeedActivityItem>[];

      await Future.wait([
        _friendMatchWins(friendList, mySports, events),
        _friendFriendlyRecords(friendList, mySports, events),
        _friendTournamentJoins(friendList, mySports, events),
        _friendTeamsCreated(friendList, mySports, events),
      ]);

      events.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      if (events.length > QueryLimits.feedActivity) {
        return FeedSectionResult.ok(events.sublist(0, QueryLimits.feedActivity));
      }
      return FeedSectionResult.ok(events);
    } catch (e) {
      debugPrint('FeedService._loadFriendActivity: $e');
      return FeedSectionResult.fail([]);
    }
  }

  static Future<void> _friendMatchWins(
    List<String> friendIds,
    List<String> mySports,
    List<FeedActivityItem> events,
  ) async {
    try {
      final rows = await _client
          .from('matches')
          .select('*, tournaments!inner(name, sport)')
          .eq('status', 'completed')
          .inFilter('winner_id', friendIds)
          .order('updated_at', ascending: false)
          .limit(40);

      final profileIds = <String>{};
      for (final m in rows as List) {
        final sport = m['tournaments']?['sport']?.toString() ?? '';
        if (sport.isNotEmpty && !mySports.contains(sport)) continue;
        profileIds.add(m['winner_id'] as String);
        final loser = m['player1_id'] == m['winner_id']
            ? m['player2_id']
            : m['player1_id'];
        if (loser != null) profileIds.add(loser as String);
      }

      final names = await _loadDisplayNames(profileIds.toList());

      for (final m in rows as List) {
        final winnerId = m['winner_id'] as String?;
        if (winnerId == null || !friendIds.contains(winnerId)) continue;

        final sport = m['tournaments']?['sport']?.toString() ?? '';
        if (sport.isNotEmpty && !mySports.contains(sport)) continue;

        final loserId = m['player1_id'] == winnerId
            ? m['player2_id']
            : m['player1_id'];
        final winnerName = names[winnerId] ?? 'Žaidėjas';
        final loserName =
            loserId != null ? (names[loserId] ?? 'varžovą') : 'varžovą';
        final score = m['match_details']?['score_str']?.toString() ?? '';
        final ts = DateTime.tryParse(m['updated_at']?.toString() ?? '') ??
            DateTime.tryParse(m['created_at']?.toString() ?? '') ??
            DateTime.now();

        events.add(
          FeedActivityItem(
            kind: FeedActivityKind.matchWin,
            occurredAt: ts,
            actorName: winnerName,
            description: score.isNotEmpty
                ? '$winnerName laimėjo prieš $loserName $score'
                : '$winnerName laimėjo prieš $loserName',
            sport: sport,
          ),
        );
      }
    } catch (e) {
      debugPrint('FeedService._friendMatchWins: $e');
    }
  }

  static Future<void> _friendFriendlyRecords(
    List<String> friendIds,
    List<String> mySports,
    List<FeedActivityItem> events,
  ) async {
    try {
      final rows = await _client
          .from('external_records')
          .select()
          .inFilter('user_id', friendIds)
          .inFilter('sport', mySports)
          .eq('record_type', 'friendly')
          .eq('i_won', true)
          .order('date_played', ascending: false)
          .limit(20);

      final profileIds = friendIds.toSet();
      for (final r in rows as List) {
        final oppId = r['opponent_user_id'] as String?;
        if (oppId != null) profileIds.add(oppId);
      }
      final names = await _loadDisplayNames(profileIds.toList());

      for (final r in rows as List) {
        final uid = r['user_id'] as String?;
        if (uid == null) continue;
        final actor = names[uid] ?? 'Žaidėjas';
        final oppName = r['opponent_name']?.toString().isNotEmpty == true
            ? r['opponent_name']
            : (r['opponent_user_id'] != null
                ? names[r['opponent_user_id']] ?? 'varžovą'
                : 'varžovą');
        final sport = r['sport']?.toString() ?? '';
        final ts = DateTime.tryParse(r['date_played']?.toString() ?? '') ??
            DateTime.now();

        events.add(
          FeedActivityItem(
            kind: FeedActivityKind.friendlyWin,
            occurredAt: ts,
            actorName: actor,
            description: '$actor laimėjo prieš $oppName',
            sport: sport,
          ),
        );
      }
    } catch (e) {
      debugPrint('FeedService._friendFriendlyRecords: $e');
    }
  }

  static Future<void> _friendTournamentJoins(
    List<String> friendIds,
    List<String> mySports,
    List<FeedActivityItem> events,
  ) async {
    try {
      final rows = await _client
          .from('tournament_participants')
          .select('*, tournaments!inner(name, sport), profiles(nickname, name, surname)')
          .inFilter('user_id', friendIds)
          .order('created_at', ascending: false)
          .limit(30);

      for (final row in rows as List) {
        final sport = row['tournaments']?['sport']?.toString() ?? '';
        if (sport.isNotEmpty && !mySports.contains(sport)) continue;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final actor = _nameFromProfile(profile);
        final tName = row['tournaments']?['name']?.toString() ?? 'turnyro';
        final ts = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now();

        events.add(
          FeedActivityItem(
            kind: FeedActivityKind.tournamentJoin,
            occurredAt: ts,
            actorName: actor,
            description: '$actor prisijungė prie turnyro „$tName“',
            sport: sport,
          ),
        );
      }
    } catch (e) {
      debugPrint('FeedService._friendTournamentJoins: $e');
    }
  }

  static Future<void> _friendTeamsCreated(
    List<String> friendIds,
    List<String> mySports,
    List<FeedActivityItem> events,
  ) async {
    try {
      final rows = await _client
          .from('teams')
          .select('*, profiles!creator_id(nickname, name, surname)')
          .inFilter('creator_id', friendIds)
          .inFilter('sport', mySports)
          .order('created_at', ascending: false)
          .limit(20);

      for (final row in rows as List) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final actor = _nameFromProfile(profile);
        final teamName = row['name']?.toString() ?? 'komandą';
        final sport = row['sport']?.toString() ?? '';
        final ts = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now();

        events.add(
          FeedActivityItem(
            kind: FeedActivityKind.teamCreated,
            occurredAt: ts,
            actorName: actor,
            description: '$actor sukūrė komandą „$teamName“',
            sport: sport,
          ),
        );
      }
    } catch (e) {
      debugPrint('FeedService._friendTeamsCreated: $e');
    }
  }

  static Future<FeedSectionResult<List<dynamic>>> _loadOpenMatches(
    String userId,
    List<String> mySports,
    String? userCity,
  ) async {
    try {
      var query = _client
          .from('open_matches')
          .select('*, profiles(nickname, photo_url, xp)')
          .inFilter('sport', mySports)
          .eq('status', 'open')
          .neq('creator_id', userId);

      if (userCity != null && userCity.trim().isNotEmpty) {
        query = query.ilike('location', '%${userCity.trim()}%');
      }

      final response = await query
          .order('match_date', ascending: true)
          .limit(QueryLimits.feedOpenMatches);

      return FeedSectionResult.ok(List<dynamic>.from(response));
    } catch (e) {
      debugPrint('FeedService._loadOpenMatches: $e');
      return FeedSectionResult.fail([]);
    }
  }

  static Future<FeedSectionResult<List<dynamic>>> _loadMyTournaments(
    String userId,
    List<String> mySports,
  ) async {
    try {
      final dashboard = await HomeDashboardService.load(userId);
      HomeDashboardData.enrichTournamentProgress(
        myTournaments: dashboard.myTournaments,
        allMatches: dashboard.allMatches,
      );

      final filtered = dashboard.myTournaments.where((t) {
        final sport = t['tournaments']?['sport']?.toString();
        if (sport == null || sport.isEmpty) return true;
        return mySports.contains(sport);
      }).toList();

      return FeedSectionResult.ok(filtered);
    } catch (e) {
      debugPrint('FeedService._loadMyTournaments: $e');
      return FeedSectionResult.fail([]);
    }
  }

  static Future<Map<String, String>> _loadDisplayNames(List<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id, nickname, name, surname')
          .inFilter('id', ids);

      final map = <String, String>{};
      for (final p in rows as List) {
        map[p['id'] as String] = _nameFromProfile(
          Map<String, dynamic>.from(p),
        );
      }
      return map;
    } catch (e) {
      debugPrint('FeedService._loadDisplayNames: $e');
      return {};
    }
  }

  static String _nameFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return 'Žaidėjas';
    final nick = profile['nickname']?.toString() ?? '';
    if (nick.isNotEmpty) return nick;
    final name = profile['name']?.toString() ?? '';
    final surname = profile['surname']?.toString() ?? '';
    final full = '$name $surname'.trim();
    return full.isNotEmpty ? full : 'Žaidėjas';
  }
}
