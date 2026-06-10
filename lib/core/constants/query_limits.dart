/// Užklausų limitai – apsauga nuo per didelių duomenų srautų klientui ir DB.
library;

class QueryLimits {

  static const int homeMatches = 100;

  static const int autoCompleteMatches = 15;

  /// Reitingų lentelė – pakanka TOP, mažesnė apkrova klientui.

  static const int leaderboardRows = 500;

  static const int chatMessages = 100;

  static const int tournamentList = 80;

  /// Home „Atrask“ peržiūra — tik kelios kortelės.
  static const int homeDiscoverPreview = 5;

  static const int myRecords = 150;

  static const int profileSearch = 30;

  static const int insightsRecords = 300;

  static const int openMatchesFeed = 80;

  static const int feedActivity = 20;

  static const int feedOpenMatches = 10;

  static const int feedPosts = 50;

  static const int adminTournaments = 100;

  static const int myTournaments = 50;

  static const int inboxTournaments = 50;

  static const int inboxChatPreview = 80;

  /// Vieno turnyro dalyviai / mačai (didžiausias bracket ~512).

  static const int tournamentParticipants = 512;

  static const int tournamentMatches = 512;

  static const int myTeams = 30;

  static const int teamMembers = 32;

  static const int matchNegotiationChat = 50;

  static const int announcementReads = 200;

}


