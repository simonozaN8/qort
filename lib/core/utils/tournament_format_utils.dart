/// Turnyro formato kodas ir reikalingas narių skaičius.
class TournamentFormatUtils {
  TournamentFormatUtils._();

  static String? formatCode(Map<String, dynamic> tournament) {
    final code = tournament['format_code']?.toString().trim();
    if (code != null && code.isNotEmpty) return code;
    final label = tournament['team_format']?.toString() ?? '';
    final m = RegExp(
      r'\b(\d+v\d+|\d+x\d+)\b',
      caseSensitive: false,
    ).firstMatch(label);
    return m?.group(1)?.toLowerCase();
  }

  static int minRosterSize(Map<String, dynamic> tournament) {
    final explicit =
        int.tryParse(tournament['min_roster_size']?.toString() ?? '');
    if (explicit != null && explicit > 0) return explicit;

    final code = formatCode(tournament);
    if (code == null || code == '1v1') return 1;
    final m = RegExp(r'^(\d+)[vx]', caseSensitive: false).firstMatch(code);
    if (m != null) return int.parse(m.group(1)!);
    return 1;
  }

  static bool requiresTeamRegistration(Map<String, dynamic> tournament) {
    return minRosterSize(tournament) > 1;
  }

  static bool teamMatchesTournament(TeamLike team, Map<String, dynamic> tournament) {
    if (team.sport != tournament['sport']?.toString()) return false;
    final tCode = formatCode(tournament);
    final teamCode = team.format?.trim().toLowerCase();
    if (tCode == null || teamCode == null) return false;
    return tCode.toLowerCase() == teamCode;
  }
}

/// Minimalus komandos interfeisas registracijai.
abstract class TeamLike {
  String get id;
  String get name;
  String get sport;
  String? get format;
  int get memberCount;
  String get creatorId;
}
