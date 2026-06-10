class FeedPostUser {
  final String? nickname;
  final String? photoUrl;
  final int? xp;

  const FeedPostUser({this.nickname, this.photoUrl, this.xp});

  factory FeedPostUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FeedPostUser();
    return FeedPostUser(
      nickname: json['nickname']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      xp: (json['total_xp'] as num?)?.toInt() ??
          (json['xp'] as num?)?.toInt(),
    );
  }

  String get displayName {
    final n = nickname?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Žaidėjas';
  }
}

class FeedPost {
  final String id;
  final String postType;
  final String userId;
  final String? relatedUserId;
  final String? sport;
  final String? location;
  final String? eventId;
  final String? tournamentId;
  final String? sourceTable;
  final String? sourceId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final FeedPostUser user;
  final FeedPostUser? relatedUser;
  final String? eventName;
  final String? eventCoverUrl;
  final int likesCount;
  final bool likedByMe;

  const FeedPost({
    required this.id,
    required this.postType,
    required this.userId,
    this.relatedUserId,
    this.sport,
    this.location,
    this.eventId,
    this.tournamentId,
    this.sourceTable,
    this.sourceId,
    required this.data,
    required this.createdAt,
    required this.user,
    this.relatedUser,
    this.eventName,
    this.eventCoverUrl,
    this.likesCount = 0,
    this.likedByMe = false,
  });

  factory FeedPost.fromJson(
    Map<String, dynamic> json, {
    int likesCount = 0,
    bool likedByMe = false,
  }) {
    final createdStr = json['created_at']?.toString();
    final eventJson = json['event'] is Map
        ? Map<String, dynamic>.from(json['event'] as Map)
        : null;

    return FeedPost(
      id: json['id']?.toString() ?? '',
      postType: json['post_type']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      relatedUserId: json['related_user_id']?.toString(),
      sport: json['sport']?.toString() ?? eventJson?['sport']?.toString(),
      location: json['location']?.toString() ?? eventJson?['location']?.toString(),
      eventId: json['event_id']?.toString(),
      tournamentId: json['tournament_id']?.toString(),
      sourceTable: json['source_table']?.toString(),
      sourceId: json['source_id']?.toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : {},
      createdAt: createdStr != null
          ? DateTime.tryParse(createdStr) ?? DateTime.now()
          : DateTime.now(),
      user: FeedPostUser.fromJson(
        json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : null,
      ),
      relatedUser: FeedPostUser.fromJson(
        json['related_user'] is Map
            ? Map<String, dynamic>.from(json['related_user'] as Map)
            : null,
      ),
      eventName: eventJson?['name']?.toString(),
      eventCoverUrl: eventJson?['image_url']?.toString(),
      likesCount: likesCount,
      likedByMe: likedByMe,
    );
  }

  FeedPost copyWith({int? likesCount, bool? likedByMe}) {
    return FeedPost(
      id: id,
      postType: postType,
      userId: userId,
      relatedUserId: relatedUserId,
      sport: sport,
      location: location,
      eventId: eventId,
      tournamentId: tournamentId,
      sourceTable: sourceTable,
      sourceId: sourceId,
      data: data,
      createdAt: createdAt,
      user: user,
      relatedUser: relatedUser,
      eventName: eventName,
      eventCoverUrl: eventCoverUrl,
      likesCount: likesCount ?? this.likesCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }

  String? get score {
    final s = data['score']?.toString();
    if (s != null && s.isNotEmpty) return s;
    return null;
  }

  String? get opponentName => data['opponent_name']?.toString();
  bool? get iWon => data['i_won'] as bool?;
  String? get tournamentName =>
      data['tournament_name']?.toString() ?? eventName;
  String? get teamName => data['team_name']?.toString();
  String? get teamLevel => data['level']?.toString();
  String? get matchFormat => data['format']?.toString();
  String? get winnerName => data['winner_name']?.toString();
}
