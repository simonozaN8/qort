/// Medžio (bracket) filtravimas ir etapų pasirinkimas — be UI, testuojama atskirai.
class TournamentBracketUtils {
  TournamentBracketUtils._();

  static String stageKey(dynamic id) => id?.toString().trim() ?? '';

  static List<Map<String, dynamic>> filterMatchesByStage(
    List<dynamic> matches,
    String stageId,
  ) {
    final key = stageKey(stageId);
    if (key.isEmpty) return [];
    return matches
        .where((m) => stageKey(m['stage']) == key)
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
  }

  /// Pirmas etapas, kuriame yra mačų; kitaip — atkrintamosios arba pirmas etapas.
  static String selectDefaultStageId({
    required List<dynamic> stages,
    required List<dynamic> matches,
  }) {
    final stageList = stages
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    if (stageList.isEmpty) return 'playoffs';

    for (final stage in stageList) {
      final id = stageKey(stage['id']);
      if (id.isEmpty) continue;
      final hasMatches =
          matches.any((m) => stageKey(m['stage']) == id);
      if (hasMatches) return id;
    }

    for (final stage in stageList) {
      final format = stage['format']?.toString() ?? '';
      if (format.contains('Atkrintamosios') ||
          format.contains('Elimination')) {
        return stageKey(stage['id']);
      }
    }

    return stageKey(stageList.first['id']);
  }

  static Map<int, List<Map<String, dynamic>>> groupKnockoutRounds(
    List<Map<String, dynamic>> stageMatches,
  ) {
    final rounds = <int, List<Map<String, dynamic>>>{};
    for (final m in stageMatches) {
      final r = int.tryParse(m['round'].toString()) ?? 1;
      if (r >= 50) continue;
      rounds.putIfAbsent(r, () => []).add(m);
    }
    return rounds;
  }

  /// Pirmojo atkrintamųjų raundo mačų skaičius (2^n dalyviai).
  static int singleEliminationFirstRoundMatches(int participants) {
    if (participants < 2) return 0;
    var pow2 = 2;
    while (pow2 < participants) {
      pow2 *= 2;
    }
    return pow2 ~/ 2;
  }

  /// Round Robin: mačų skaičius vienoje grupėje.
  static int roundRobinMatchesInGroup(int playersInGroup) {
    if (playersInGroup < 2) return 0;
    return playersInGroup * (playersInGroup - 1) ~/ 2;
  }
}
