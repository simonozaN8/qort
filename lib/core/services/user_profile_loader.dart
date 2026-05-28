import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/user_model.dart';

/// Profilis + visos sporto šakos iš `user_sports` (ne iš seno `profiles.my_sports`).
class UserProfileLoader {
  UserProfileLoader._();

  static Future<UserProfile?> loadCurrent() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return null;
    return loadById(uid);
  }

  static Future<UserProfile?> loadById(String userId) async {
    try {
      final profileData = await _profileWithSports(userId);
      return UserProfile.fromJson(profileData);
    } catch (e) {
      return null;
    }
  }

  /// Keli profiliai su sporto šakomis (radaras, sąrašai).
  static Future<List<UserProfile>> loadManyByIds(
    List<String> userIds, {
    int? limit,
  }) async {
    if (userIds.isEmpty) return [];
    try {
      final client = Supabase.instance.client;
      final base = client.from('profiles').select().inFilter('id', userIds);
      final dynamic response = limit != null
          ? await base.limit(limit)
          : await base;
      final profiles = List<Map<String, dynamic>>.from(response as List);

      final sports = await client
          .from('user_sports')
          .select()
          .inFilter('user_id', userIds);

      final sportsByUser = <String, List<dynamic>>{};
      for (final row in sports) {
        final uid = row['user_id'] as String;
        sportsByUser.putIfAbsent(uid, () => []).add(row);
      }

      return profiles.map((p) {
        final data = Map<String, dynamic>.from(p);
        data['my_sports'] = sportsByUser[p['id']] ?? [];
        return UserProfile.fromJson(data);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Atsitiktiniai profiliai radui (be savęs).
  static Future<List<UserProfile>> loadDiscoverProfiles({
    required String excludeUserId,
    int limit = 15,
  }) async {
    try {
      final client = Supabase.instance.client;
      final profiles = List<Map<String, dynamic>>.from(
        await client
            .from('profiles')
            .select('id')
            .neq('id', excludeUserId)
            .limit(limit),
      );
      final ids = profiles.map((p) => p['id'] as String).toList();
      return loadManyByIds(ids);
    } catch (e) {
      return [];
    }
  }

  /// Varžovų vardai pagrindiniam ekranui.
  static Future<Map<String, String>> loadDisplayNames(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return {};
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id, nickname, name')
          .inFilter('id', userIds);
      final map = <String, String>{};
      for (final p in rows) {
        map[p['id'] as String] =
            p['nickname'] ?? p['name'] ?? "Žaidėjas";
      }
      return map;
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> _profileWithSports(String userId) async {
    final client = Supabase.instance.client;
    final results = await Future.wait<dynamic>([
      client.from('profiles').select().eq('id', userId).single(),
      client.from('user_sports').select().eq('user_id', userId),
    ]);
    final profileData = Map<String, dynamic>.from(results[0] as Map);
    profileData['my_sports'] = results[1] as List<dynamic>;
    return profileData;
  }
}
