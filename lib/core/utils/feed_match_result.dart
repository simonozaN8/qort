import 'package:flutter/material.dart';

import '../models/feed_post.dart';

/// Mačo rezultato žyma feed kortelėse (žiūrovo perspektyva).
class FeedMatchResult {
  FeedMatchResult._();

  static const _gold = Color(0xFFEAB308);

  static bool isMatchPost(String postType) {
    return postType == 'tournament_match' ||
        postType == 'training_match' ||
        postType == 'external_record';
  }

  static String labelFor(FeedPost post, String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) return '';

    if (post.postType == 'external_record') {
      if (post.userId == currentUserId) {
        final iWon = post.data['i_won'] as bool? ?? false;
        return iWon ? 'LAIMĖJIMAS' : 'PRALAIMĖJIMAS';
      }
      return 'SUŽAISTAS';
    }

    if (post.postType == 'tournament_match' ||
        post.postType == 'training_match') {
      if (post.data['is_draw'] == true) return 'LYGIOSIOS';

      final p1 = post.data['player1_id']?.toString();
      final p2 = post.data['player2_id']?.toString();
      final winnerId = post.data['winner_id']?.toString();

      if (currentUserId == p1 || currentUserId == p2) {
        if (winnerId == null || winnerId.isEmpty) return 'NEBAIGTA';
        return winnerId == currentUserId ? 'LAIMĖJIMAS' : 'PRALAIMĖJIMAS';
      }

      if (winnerId == null || winnerId.isEmpty) return 'NEBAIGTA';
      return 'SUŽAISTAS';
    }

    return '';
  }

  static Color color(String label) {
    return switch (label) {
      'LAIMĖJIMAS' => Colors.green,
      'PRALAIMĖJIMAS' => Colors.red,
      'LYGIOSIOS' => Colors.amber,
      'SUŽAISTAS' => _gold,
      _ => Colors.white54,
    };
  }

  /// Score vartotojo perspektyvoje — jo skaičius visada pirmas (player1:player2 DB).
  static String scoreFromUserPerspective(
    String score,
    String? currentUserId,
    Map<String, dynamic> data, {
    String? postType,
  }) {
    if (postType == 'external_record') return score;
    if (currentUserId == null || currentUserId.isEmpty || score.isEmpty) {
      return score;
    }

    final p1 = data['player1_id']?.toString();
    final p2 = data['player2_id']?.toString();

    if (currentUserId == p1) return score;
    if (currentUserId == p2) return _flipScore(score);
    return score;
  }

  /// Apverčia "4:6, 3:6" → "6:4, 6:3" (palaiko `:` ir `-`).
  static String _flipScore(String score) {
    final sets = score.split(',').map((s) => s.trim()).toList();
    final flipped = sets.map((set) {
      var separator = ':';
      if (set.contains('-') && !set.contains(':')) {
        separator = '-';
      }
      final parts = set.split(separator);
      if (parts.length == 2) {
        return '${parts[1].trim()}$separator${parts[0].trim()}';
      }
      return set;
    }).toList();
    return flipped.join(', ');
  }

  static Widget? badge(FeedPost post, String? currentUserId) {
    final label = labelFor(post, currentUserId);
    if (label.isEmpty) return null;

    final c = color(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
