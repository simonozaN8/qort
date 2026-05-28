enum AppMode { competition, training, blitz }

class SportDetails {
  final String id;
  final String name;
  final int level; // Dabar 1-5
  final String description;
  final String sportBio;
  final int rp; // Konkrečios sporto šakos reitingas
  final int matchesPlayed;
  final int tournamentsWon;
  final double winRate;
  final List<Map<String, dynamic>> rpHistory;

  SportDetails({
    required this.id,
    required this.name,
    required this.level,
    this.description = "",
    this.sportBio = "",
    this.rp = 1000,
    this.matchesPlayed = 0,
    this.tournamentsWon = 0,
    this.winRate = 0.0,
    this.rpHistory = const [],
  });

  factory SportDetails.fromJson(Map<String, dynamic> json) {
    return SportDetails(
      id: json['id'] ?? '',
      name: json['sport'] ?? '',
      level: json['level'] is int
          ? json['level']
          : int.tryParse(json['level'].toString()) ?? 1,
      description: json['description'] ?? '',
      sportBio: json['sport_bio'] ?? '',
      rp: json['official_rp'] ?? 1000,
      matchesPlayed: json['matches_played'] ?? 0,
      tournamentsWon: json['tournaments_won'] ?? 0,
      winRate: (json['win_rate'] ?? 0.0).toDouble(),
      rpHistory: List<Map<String, dynamic>>.from(json['rp_history'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sport': name,
      'level': level,
      'description': description,
      'sport_bio': sportBio,
      'official_rp': rp,
      'matches_played': matchesPlayed,
      'tournaments_won': tournamentsWon,
      'win_rate': winRate,
      'rp_history': rpHistory,
    };
  }
}

class UserProfile {
  final String id;
  final String email;
  final String nickname;
  final String name;
  final String surname;
  final String photoUrl;
  final String city;
  final String district;
  final String county;
  final String phone;

  final int xp;
  final int blitzPoints;
  final double qCoins;
  final int winStreak;

  final List<SportDetails> sportsList;

  final String gender;
  final String birthDate;
  final String height;
  final String dominantSide;
  final String locationPreference;
  final bool isInjured;
  final bool isOnVacation;

  UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    required this.name,
    required this.surname,
    required this.photoUrl,
    required this.city,
    required this.district,
    required this.county,
    required this.phone,
    required this.xp,
    required this.blitzPoints,
    required this.qCoins,
    required this.winStreak,
    required this.sportsList,
    required this.gender,
    required this.birthDate,
    required this.height,
    required this.dominantSide,
    required this.locationPreference,
    required this.isInjured,
    required this.isOnVacation,
  });

  String get displayName =>
      nickname.isNotEmpty ? nickname : (name.isNotEmpty ? name : "Žaidėjas");

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final parsedSports = _parseSportsList(json['my_sports']);

    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      nickname: json['nickname'] ?? '',
      name: json['name'] ?? '',
      surname: json['surname'] ?? '',
      photoUrl: json['photo_url'] ?? '',
      city: json['city'] ?? '',
      district: json['district'] ?? '',
      county: json['county'] ?? '',
      phone: json['phone'] ?? '',
      xp: json['xp'] ?? 0,
      blitzPoints: json['blitz_points'] ?? 0,
      qCoins: (json['q_coins'] ?? 0.0).toDouble(),
      winStreak: json['win_streak'] ?? 0,
      sportsList: parsedSports,
      gender: json['gender'] ?? 'Vyras',
      birthDate: json['birth_date'] ?? '',
      height: json['height'] ?? '',
      dominantSide: json['dominant_side'] ?? 'Dešinė',
      locationPreference: json['location_preference'] ?? 'Mano mieste',
      isInjured: json['is_injured'] ?? false,
      isOnVacation: json['is_on_vacation'] ?? false,
    );
  }

  /// Tik `user_sports` eilutės (laukas `sport`). Senas `profiles.my_sports` JSON ignoruojamas.
  static List<SportDetails> _parseSportsList(dynamic raw) {
    if (raw is! List || raw.isEmpty) return [];
    final first = raw.first;
    if (first is! Map) return [];
    if (!first.containsKey('sport')) return [];
    return raw
        .map((s) => SportDetails.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? nickname,
    String? name,
    String? surname,
    String? photoUrl,
    String? city,
    String? district,
    String? county,
    String? phone,
    int? xp,
    int? blitzPoints,
    double? qCoins,
    int? winStreak,
    List<SportDetails>? sportsList,
    String? gender,
    String? birthDate,
    String? height,
    String? dominantSide,
    String? locationPreference,
    bool? isInjured,
    bool? isOnVacation,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      photoUrl: photoUrl ?? this.photoUrl,
      city: city ?? this.city,
      district: district ?? this.district,
      county: county ?? this.county,
      phone: phone ?? this.phone,
      xp: xp ?? this.xp,
      blitzPoints: blitzPoints ?? this.blitzPoints,
      qCoins: qCoins ?? this.qCoins,
      winStreak: winStreak ?? this.winStreak,
      sportsList: sportsList ?? this.sportsList,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      height: height ?? this.height,
      dominantSide: dominantSide ?? this.dominantSide,
      locationPreference: locationPreference ?? this.locationPreference,
      isInjured: isInjured ?? this.isInjured,
      isOnVacation: isOnVacation ?? this.isOnVacation,
    );
  }
}
