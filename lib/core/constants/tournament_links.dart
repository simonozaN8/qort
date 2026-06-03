/// Viešos turnyro nuorodos — keisti domain vienoje vietoje.
class TournamentLinks {
  TournamentLinks._();

  static const String baseUrl = 'https://app.qort.lt';

  static String tournamentUrl(String tournamentId) =>
      '$baseUrl/tournament/$tournamentId';

  /// PASTABA: Iki PWA deployment'o nuoroda nukreipia į neegzistuojantį
  /// subdomain. Po deployment'o į serveriai.lt — veiks.
  static String eventUrl(String eventId) => '$baseUrl/event/$eventId';
}
