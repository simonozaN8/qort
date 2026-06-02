/// Viešos turnyro nuorodos — keisti domain vienoje vietoje.
class TournamentLinks {
  TournamentLinks._();

  static const String baseUrl = 'https://qort.app';

  static String tournamentUrl(String tournamentId) =>
      '$baseUrl/tournament/$tournamentId';

  static String eventUrl(String eventId) => '$baseUrl/event/$eventId';
}
