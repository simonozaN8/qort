import 'package:flutter_test/flutter_test.dart';
import 'package:sporto_projektas/core/utils/tournament_bracket_utils.dart';

void main() {
  group('TournamentBracketUtils.selectDefaultStageId', () {
    test('renka etapą, kuriame yra mačų', () {
      final stages = [
        {'id': 'groups', 'format': 'Round Robin (Grupės)', 'name': 'Grupės'},
        {'id': 'playoffs', 'format': 'Single Elimination', 'name': 'Atkrintamosios'},
      ];
      final matches = [
        {'stage': 'groups', 'round': 1},
        {'stage': 'groups', 'round': 1},
      ];

      expect(
        TournamentBracketUtils.selectDefaultStageId(
          stages: stages,
          matches: matches,
        ),
        'groups',
      );
    });

    test('stage id kaip skaičius sutampa su maču', () {
      final stages = [
        {'id': 1, 'format': 'Round Robin', 'name': 'Etapas 1'},
      ];
      final matches = [
        {'stage': '1', 'round': 1},
      ];

      expect(
        TournamentBracketUtils.filterMatchesByStage(matches, '1').length,
        1,
      );
    });
  });

  group('TournamentBracketUtils.filterMatchesByStage', () {
    test('filtruoja pagal stage string', () {
      final matches = [
        {'stage': 'a', 'round': 1},
        {'stage': 'b', 'round': 1},
        {'stage': 'a', 'round': 2},
      ];
      final filtered =
          TournamentBracketUtils.filterMatchesByStage(matches, 'a');
      expect(filtered.length, 2);
    });
  });

  group('TournamentBracketUtils.groupKnockoutRounds', () {
    test('ignoruoja placement round >= 50', () {
      final matches = [
        {'round': 1, 'id': 'm1'},
        {'round': 51, 'id': 'bronze'},
      ];
      final rounds =
          TournamentBracketUtils.groupKnockoutRounds(matches);
      expect(rounds.keys, [1]);
      expect(rounds[1]!.length, 1);
    });
  });

  group('match counts', () {
    test('single elimination 8 dalyvių → 4 pirmo raundo mačai', () {
      expect(
        TournamentBracketUtils.singleEliminationFirstRoundMatches(8),
        4,
      );
    });

    test('single elimination 5 dalyvių → 4 slotai (8 bracket)', () {
      expect(
        TournamentBracketUtils.singleEliminationFirstRoundMatches(5),
        4,
      );
    });

    test('round robin 4 žaidėjai → 6 mačai grupėje', () {
      expect(TournamentBracketUtils.roundRobinMatchesInGroup(4), 6);
    });
  });
}
