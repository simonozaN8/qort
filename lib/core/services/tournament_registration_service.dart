import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/tournament_format_utils.dart';
import '../../features/teams/team_model.dart';

/// Registracija į turnyrą (1v1 asmeniškai arba komanda / pora).
class TournamentRegistrationService {
  TournamentRegistrationService._();

  static int countOccupiedSlots(
    List<dynamic> participants,
    Map<String, dynamic> tournament,
  ) {
    if (!TournamentFormatUtils.requiresTeamRegistration(tournament)) {
      return participants.length;
    }
    final teams = <String>{};
    var solo = 0;
    for (final p in participants) {
      final tid = p['team_id']?.toString();
      if (tid != null && tid.isNotEmpty) {
        teams.add(tid);
      } else {
        solo++;
      }
    }
    return teams.length + solo;
  }

  static bool isUserRegistered(
    String userId,
    List<dynamic> participants,
  ) {
    return participants.any((p) => p['user_id']?.toString() == userId);
  }

  static Future<List<Team>> fetchEligibleTeams({
    required String userId,
    required Map<String, dynamic> tournament,
  }) async {
    final client = Supabase.instance.client;
    final minRoster = TournamentFormatUtils.minRosterSize(tournament);

    final rows = await client
        .from('team_members')
        .select('role, teams(*)')
        .eq('user_id', userId);

    final teamIds = <String>[];
    final teams = <Team>[];

    for (final row in rows as List) {
      final teamMap = row['teams'];
      if (teamMap is! Map) continue;
      final team = Team.fromJson(Map<String, dynamic>.from(teamMap));

      if (!TournamentFormatUtils.teamMatchesTournament(
        _TeamAdapter(team),
        tournament,
      )) {
        continue;
      }

      teamIds.add(team.id);
      teams.add(team);
    }

    if (teamIds.isEmpty) return [];

    final memberRows = await client
        .from('team_members')
        .select('team_id')
        .inFilter('team_id', teamIds);
    final counts = <String, int>{};
    for (final row in memberRows as List) {
      final tid = row['team_id'].toString();
      counts[tid] = (counts[tid] ?? 0) + 1;
    }

    return teams
        .map((t) {
          final c = counts[t.id] ?? 0;
          return Team(
            id: t.id,
            name: t.name,
            sport: t.sport,
            creatorId: t.creatorId,
            level: t.level,
            description: t.description,
            logoUrl: t.logoUrl,
            createdAt: t.createdAt,
            format: t.format,
            playersOnCourt: t.playersOnCourt,
            maxTeamSize: t.maxTeamSize,
            city: t.city,
            memberCount: c,
          );
        })
        .where((t) => t.memberCount >= minRoster)
        .toList();
  }

  static Future<String?> registerTeam({
    required String tournamentId,
    required String userId,
    required Team team,
    required List<dynamic> currentParticipants,
    required Map<String, dynamic> tournament,
    String? division,
  }) async {
    final client = Supabase.instance.client;
    final maxP = int.tryParse(tournament['max_participants']?.toString() ?? '') ?? 16;
    final occupied = countOccupiedSlots(currentParticipants, tournament);
    if (occupied >= maxP) return 'Turnyras pilnas!';

    if (currentParticipants.any((p) => p['team_id']?.toString() == team.id)) {
      return 'Ši komanda jau užregistruota.';
    }

    final minRoster = TournamentFormatUtils.minRosterSize(tournament);
    if (team.memberCount < minRoster) {
      return 'Komandoje turi būti bent $minRoster nariai.';
    }

    final membership = await client
        .from('team_members')
        .select('role')
        .eq('team_id', team.id)
        .eq('user_id', userId)
        .maybeSingle();
    if (membership == null) {
      return 'Nesi šios komandos narys.';
    }

    await client.from('tournament_participants').insert({
      'tournament_id': tournamentId,
      'user_id': userId,
      'team_id': team.id,
      'team_name': team.name,
      'division': division,
      'status': 'active',
    });
    return null;
  }

  static Future<String?> registerIndividual({
    required String tournamentId,
    required String userId,
    required String displayName,
    required List<dynamic> currentParticipants,
    required Map<String, dynamic> tournament,
    String? division,
  }) async {
    final client = Supabase.instance.client;
    final maxP = int.tryParse(tournament['max_participants']?.toString() ?? '') ?? 16;
    if (countOccupiedSlots(currentParticipants, tournament) >= maxP) {
      return 'Turnyras pilnas!';
    }
    if (isUserRegistered(userId, currentParticipants)) {
      return 'Jau užsiregistravote.';
    }

    await client.from('tournament_participants').insert({
      'tournament_id': tournamentId,
      'user_id': userId,
      'team_name': displayName,
      'division': division,
      'status': 'active',
    });
    return null;
  }
}

class _TeamAdapter implements TeamLike {
  final Team _t;
  _TeamAdapter(this._t);
  @override
  String get id => _t.id;
  @override
  String get name => _t.name;
  @override
  String get sport => _t.sport;
  @override
  String? get format => _t.format;
  @override
  int get memberCount => _t.memberCount;
  @override
  String get creatorId => _t.creatorId;
}
