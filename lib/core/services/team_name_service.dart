import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/team_naming_rules.dart';

/// Atnaujina komandos pavadinimą pagal narius (tenisas, padelis…).
class TeamNameService {
  static Future<void> syncTeamDisplayName(String teamId) async {
    final client = Supabase.instance.client;

    final team = await client
        .from('teams')
        .select('sport, format')
        .eq('id', teamId)
        .single();

    final sport = team['sport']?.toString() ?? '';
    final format = team['format']?.toString();

    if (!TeamNamingRules.usesParticipantNames(sport, format)) return;

    final members = await client
        .from('team_members')
        .select('profiles(nickname, name, surname)')
        .eq('team_id', teamId)
        .order('joined_at');

    final profiles = <Map<String, dynamic>>[];
    for (final row in members as List) {
      final p = row['profiles'];
      if (p is Map) profiles.add(Map<String, dynamic>.from(p));
    }

    if (profiles.isEmpty) return;

    final newName = TeamNamingRules.buildFromProfiles(profiles);
    await client.from('teams').update({'name': newName}).eq('id', teamId);
  }
}
