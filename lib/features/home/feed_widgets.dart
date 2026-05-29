import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/app_shell_layout.dart';
import '../../core/utils/sport_icons.dart';
import '../../core/services/feed_service.dart';
import '../../core/theme/qort_design_system.dart';
import '../../core/theme/qort_mode_colors.dart';
import '../../core/widgets/qort_components.dart';
import '../profile/status_avatar.dart';

class FeedCommunityHeader extends StatelessWidget {
  const FeedCommunityHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FEED',
          style: QortDesignSystem.h1.copyWith(
            fontSize: 26,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: QortDesignSystem.space2),
        Text(
          'Kas vyksta tavo sportuose',
          style: QortDesignSystem.body.copyWith(
            color: QortDesignSystem.textSecondary,
          ),
        ),
      ],
    );
  }
}

class FeedSectionLoading extends StatelessWidget {
  const FeedSectionLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: QortDesignSystem.space6),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class FeedEmptyCommunity extends StatelessWidget {
  const FeedEmptyCommunity({super.key});

  @override
  Widget build(BuildContext context) {
    return QortEmptyState(
      icon: LucideIcons.rss,
      title: 'Feed dar tuščias',
      message:
          'Sužaisk mačą, sukurk komandą arba prisijunk prie turnyro — bendruomenė užsipildys.',
      accent: QortDesignSystem.brand,
    );
  }
}

class FeedFriendActivitySection extends StatelessWidget {
  final List<FeedActivityItem> items;
  final bool failed;

  const FeedFriendActivitySection({
    super.key,
    required this.items,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QortSectionHeader(
          title: 'Draugų aktyvumas',
          icon: LucideIcons.users,
          accent: QortDesignSystem.brand,
        ),
        const SizedBox(height: QortDesignSystem.space3),
        if (failed)
          _sectionError('Nepavyko užkrauti draugų aktyvumo')
        else if (items.isEmpty)
          _subtleEmpty(
            'Dar nėra draugų aktyvumo — sužaisk mačą ar prisijunk prie komandos.',
          )
        else
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: QortDesignSystem.space3),
              child: QortCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _activityIcon(e.kind),
                    const SizedBox(width: QortDesignSystem.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.description,
                            style: QortDesignSystem.body.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (e.sport.isNotEmpty)
                            Row(
                              children: [
                                SportIcons.icon(e.sport, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${e.sport} · ${_timeAgo(e.occurredAt)}',
                                    style: QortDesignSystem.caption,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              _timeAgo(e.occurredAt),
                              style: QortDesignSystem.caption,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _activityIcon(FeedActivityKind kind) {
    final icon = switch (kind) {
      FeedActivityKind.matchWin => LucideIcons.trophy,
      FeedActivityKind.friendlyWin => LucideIcons.swords,
      FeedActivityKind.tournamentJoin => LucideIcons.flag,
      FeedActivityKind.teamCreated => LucideIcons.shield,
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: QortDesignSystem.bgElevated,
        borderRadius: BorderRadius.circular(QortDesignSystem.radiusSm),
        border: Border.all(color: QortDesignSystem.borderSubtle),
      ),
      child: Icon(icon, size: 16, color: QortDesignSystem.brand),
    );
  }
}

class FeedOpenMatchesSection extends StatelessWidget {
  final List<dynamic> notices;
  final bool failed;
  final String? joiningId;
  final void Function(Map<String, dynamic> notice) onJoin;

  const FeedOpenMatchesSection({
    super.key,
    required this.notices,
    required this.failed,
    this.joiningId,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QortSectionHeader(
          title: 'Atviri mačai netoli',
          icon: LucideIcons.mapPin,
          accent: QortModeColors.training,
        ),
        const SizedBox(height: QortDesignSystem.space3),
        if (failed)
          _sectionError('Nepavyko užkraoti skelbimų')
        else if (notices.isEmpty)
          _subtleEmpty('Tavo sportuose ir mieste atvirų skelbimų nėra.')
        else
          ...notices.map((raw) {
            final notice = Map<String, dynamic>.from(raw as Map);
            final creator = notice['profiles'] as Map<String, dynamic>?;
            final nick = creator?['nickname']?.toString() ?? 'Žaidėjas';
            final photo = creator?['photo_url']?.toString() ?? '';
            final sport = notice['sport']?.toString() ?? '';
            final location = notice['location']?.toString() ?? '';
            final date = DateTime.tryParse(notice['match_date']?.toString() ?? '');
            final dateStr = date != null
                ? DateFormat('MM-dd, HH:mm').format(date.toLocal())
                : '';
            final id = notice['id']?.toString() ?? '';
            final isJoining = joiningId == id;

            return Padding(
              padding: const EdgeInsets.only(bottom: QortDesignSystem.space3),
              child: QortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusAvatar(
                          imageUrl: photo,
                          displayName: nick,
                          radius: 20,
                        ),
                        const SizedBox(width: QortDesignSystem.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nick,
                                style: QortDesignSystem.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (sport.isNotEmpty)
                                Row(
                                  children: [
                                    SportIcons.icon(sport, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '$sport · $dateStr',
                                        style: QortDesignSystem.caption,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  dateStr,
                                  style: QortDesignSystem.caption,
                                ),
                              if (location.isNotEmpty)
                                Text(
                                  location,
                                  style: QortDesignSystem.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: QortDesignSystem.space3),
                    QortButton(
                      label: isJoining ? 'Jungiama…' : 'Prisijungti',
                      onPressed: isJoining ? null : () => onJoin(notice),
                      accent: QortModeColors.training,
                      expanded: true,
                      size: QortButtonSize.sm,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class FeedNoSportsCta extends StatelessWidget {
  final VoidCallback onOpenProfile;

  const FeedNoSportsCta({super.key, required this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    return QortEmptyState(
      icon: LucideIcons.dumbbell,
      title: 'Pasirink sportus',
      message:
          'Feed rodo turinį pagal tavo sporto šakas. Pridėk sportus profilyje, kad matytum aktyvumą ir skelbimus.',
      actionLabel: 'Pasirink sportus profilyje',
      onAction: onOpenProfile,
      accent: QortDesignSystem.brand,
    );
  }
}

Widget _subtleEmpty(String message) {
  return QortCard(
    backgroundColor: QortDesignSystem.bgElevated,
    child: Row(
      children: [
        Icon(LucideIcons.info, size: 16, color: QortDesignSystem.textMuted),
        const SizedBox(width: QortDesignSystem.space3),
        Expanded(
          child: Text(message, style: QortDesignSystem.caption),
        ),
      ],
    ),
  );
}

Widget _sectionError(String message) {
  return QortCard(
    backgroundColor: QortDesignSystem.bgElevated,
    child: Row(
      children: [
        Icon(LucideIcons.alertTriangle,
            size: 16, color: QortDesignSystem.error),
        const SizedBox(width: QortDesignSystem.space3),
        Expanded(
          child: Text(message, style: QortDesignSystem.caption),
        ),
      ],
    ),
  );
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays > 0) return 'prieš ${diff.inDays} d.';
  if (diff.inHours > 0) return 'prieš ${diff.inHours} val.';
  if (diff.inMinutes > 0) return 'prieš ${diff.inMinutes} min.';
  return 'ką tik';
}

/// Apatinis padding Feed scroll turiniui.
double feedScrollBottomPadding(BuildContext context) =>
    AppShellLayout.scrollBottomPadding(context);
