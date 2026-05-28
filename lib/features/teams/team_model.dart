/// Komandos modelis
class Team {
  final String id;
  final String name;
  final String sport;
  final String creatorId;
  final int level;
  final String? description;
  final String? logoUrl;
  final DateTime createdAt;

  // Formato laukai
  final String? format; // pvz. "3x3", "5x5", "4x4"
  final int playersOnCourt; // kiek aikštelėje vienu metu
  final int maxTeamSize; // max narių komandoje
  final String? city; // miestas

  // Užkrauti atskirai
  final List<TeamMember> members;
  final int memberCount;

  Team({
    required this.id,
    required this.name,
    required this.sport,
    required this.creatorId,
    required this.level,
    this.description,
    this.logoUrl,
    required this.createdAt,
    this.format,
    this.playersOnCourt = 3,
    this.maxTeamSize = 7,
    this.city,
    this.members = const [],
    this.memberCount = 0,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'] ?? '',
      sport: json['sport'] ?? '',
      creatorId: json['creator_id'],
      level: json['level'] ?? 1,
      description: json['description'],
      logoUrl: json['logo_url'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      format: json['format'],
      playersOnCourt: json['players_on_court'] ?? 3,
      maxTeamSize: json['max_team_size'] ?? 7,
      city: json['city'],
      members:
          (json['members'] as List?)
              ?.map((m) => TeamMember.fromJson(m))
              .toList() ??
          [],
      memberCount: json['member_count'] ?? 0,
    );
  }

  /// Apskaičiuoja komandos lygį pagal narius
  /// Aukščiausias narys lemia komandos lygį
  static int calculateLevel(List<TeamMember> members) {
    if (members.isEmpty) return 1;
    int max = 1;
    for (var m in members) {
      if (m.level > max) max = m.level;
    }
    return max;
  }
}

/// Komandos nario modelis
class TeamMember {
  final String id;
  final String teamId;
  final String userId;
  final String role; // 'creator' | 'member'
  final DateTime joinedAt;

  // Iš profiles join
  final String nickname;
  final String name;
  final String surname;
  final String? photoUrl;

  // Iš user_sports join (lygis šiame sporte)
  final int level;

  TeamMember({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.nickname = '',
    this.name = '',
    this.surname = '',
    this.photoUrl,
    this.level = 1,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return TeamMember(
      id: json['id'],
      teamId: json['team_id'],
      userId: json['user_id'],
      role: json['role'] ?? 'member',
      joinedAt: DateTime.tryParse(json['joined_at'] ?? '') ?? DateTime.now(),
      nickname: profile?['nickname'] ?? '',
      name: profile?['name'] ?? '',
      surname: profile?['surname'] ?? '',
      photoUrl: profile?['photo_url'],
      level: json['level'] ?? 1,
    );
  }

  bool get isCreator => role == 'creator';

  /// Display vardas - slapyvardis arba vardas+pavardė
  String get displayName {
    if (nickname.isNotEmpty) return nickname;
    return "$name $surname".trim();
  }
}

/// Kvietimo modelis
class TeamInvitation {
  final String id;
  final String teamId;
  final String invitedUserId;
  final String invitedBy;
  final String status; // 'pending' | 'accepted' | 'declined'
  final DateTime createdAt;
  final DateTime? respondedAt;

  // Iš teams join
  final String teamName;
  final String teamSport;

  // Iš profiles join (kas kvietė)
  final String inviterName;

  TeamInvitation({
    required this.id,
    required this.teamId,
    required this.invitedUserId,
    required this.invitedBy,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.teamName = '',
    this.teamSport = '',
    this.inviterName = '',
  });

  factory TeamInvitation.fromJson(Map<String, dynamic> json) {
    final team = json['teams'] as Map<String, dynamic>?;
    final inviter = json['inviter'] as Map<String, dynamic>?;
    return TeamInvitation(
      id: json['id'],
      teamId: json['team_id'],
      invitedUserId: json['invited_user_id'],
      invitedBy: json['invited_by'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'])
          : null,
      teamName: team?['name'] ?? '',
      teamSport: team?['sport'] ?? '',
      inviterName: (inviter?['nickname'] as String?)?.isNotEmpty == true
          ? inviter!['nickname']
          : "${inviter?['name'] ?? ''} ${inviter?['surname'] ?? ''}".trim(),
    );
  }

  bool get isPending => status == 'pending';
}
