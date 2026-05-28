import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/qort_palette_extension.dart';

/// Grupės rezultatų matrica (žaidėjas × žaidėjas) — švarus, profesionalus stilius.
class TournamentGroupMatrix extends StatelessWidget {
  final String groupName;
  final List<Map<String, dynamic>> matches;
  final String Function(String playerId) resolveName;
  final String? currentUserId;

  const TournamentGroupMatrix({
    super.key,
    required this.groupName,
    required this.matches,
    required this.resolveName,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.qortPalette;
    final lossColor = Theme.of(context).colorScheme.error;
    final playerIds = <String>{};
    for (final m in matches) {
      if (m['player1_id'] != null) playerIds.add(m['player1_id'].toString());
      if (m['player2_id'] != null) playerIds.add(m['player2_id'].toString());
    }
    final players = playerIds.toList();
    final matchMap = <String, dynamic>{};
    for (final m in matches) {
      final p1 = m['player1_id'].toString();
      final p2 = m['player2_id'].toString();
      matchMap['${p1}_$p2'] = m;
      matchMap['${p2}_$p1'] = m;
    }

    var displayName = groupName.toUpperCase();
    if (!displayName.contains('GRUPĖ')) displayName = 'GRUPĖ $displayName';

    return Container(
      margin: const EdgeInsets.all(10),
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.18 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: p.surfaceElevated,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: GoogleFonts.inter(
                      color: p.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Icon(LucideIcons.grid, color: p.primary, size: 18),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Table(
                    defaultColumnWidth: const FixedColumnWidth(68),
                    columnWidths: const {0: FixedColumnWidth(96)},
                    border: TableBorder.all(color: p.border, width: 1),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: p.surfaceElevated),
                        children: [
                          _headerCell('', p),
                          ...players.map((id) => _headerCell(
                                _shortName(resolveName(id)),
                                p,
                              )),
                          _headerCell('TŠK', p, accent: true),
                        ],
                      ),
                      ...players.map((rowId) {
                        var points = 0;
                        return TableRow(
                          children: [
                            _nameCell(rowId, p),
                            ...players.map((colId) {
                              if (rowId == colId) {
                                return _diagonalCell(p);
                              }
                              final match = matchMap['${rowId}_$colId'];
                              if (match == null) return _emptyCell(p);
                              final isPlayed = match['status'] == 'completed';
                              if (!isPlayed) return _pendingCell(p);

                              final s1 =
                                  int.tryParse(match['score_p1'].toString()) ??
                                      0;
                              final s2 =
                                  int.tryParse(match['score_p2'].toString()) ??
                                      0;
                              final won =
                                  (match['player1_id'].toString() == rowId &&
                                      s1 > s2) ||
                                  (match['player2_id'].toString() == rowId &&
                                      s2 > s1);
                              if (won) points++;

                              final scoreText = match['player1_id'].toString() ==
                                      rowId
                                  ? '$s1:$s2'
                                  : '$s2:$s1';
                              return _scoreCell(scoreText, won, p, lossColor);
                            }),
                            _pointsCell('$points', p),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortName(String name) {
    if (name.length <= 8) return name;
    return '${name.substring(0, 7)}…';
  }

  Widget _headerCell(String text, dynamic p, {bool accent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: accent ? p.primary : p.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _nameCell(String rowId, dynamic p) {
    final isMe = rowId == currentUserId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: isMe ? p.primary.withValues(alpha: 0.08) : null,
      alignment: Alignment.centerLeft,
      child: Text(
        resolveName(rowId),
        style: GoogleFonts.inter(
          color: isMe ? p.primary : p.textPrimary,
          fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _diagonalCell(dynamic p) {
    return Container(
      height: 46,
      color: p.listRowAlt,
    );
  }

  Widget _emptyCell(dynamic p) {
    return SizedBox(height: 46, child: ColoredBox(color: p.surface));
  }

  Widget _pendingCell(dynamic p) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      color: p.surface,
      child: Text(
        '–',
        style: TextStyle(color: p.textSecondary.withValues(alpha: 0.6)),
      ),
    );
  }

  Widget _scoreCell(String score, bool won, dynamic p, Color lossColor) {
    final bg = won
        ? p.success.withValues(alpha: 0.12)
        : lossColor.withValues(alpha: 0.1);
    final fg = won ? p.success : lossColor;
    return Container(
      height: 46,
      alignment: Alignment.center,
      color: bg,
      child: Text(
        score,
        style: GoogleFonts.inter(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _pointsCell(String points, dynamic p) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      color: p.primary.withValues(alpha: 0.06),
      child: Text(
        points,
        style: GoogleFonts.inter(
          color: p.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}
