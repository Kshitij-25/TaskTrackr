import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/backend/authenticator.dart';
import '../../data/models/user_model.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';
import '../components/momentum_ui.dart';
import '../providers/user_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});
  static const routeName = '/notification-settings';

  Future<void> _update(
    BuildContext context,
    UserModel user,
    NotificationSettings Function(Map<String, dynamic>) change,
  ) async {
    try {
      await const Authenticator().updateNotificationSettings(
          change(user.notificationSettings.toMap()).toMap());
    } catch (e) {
      if (context.mounted) showMomentumToast(context, 'Could not save: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    final userAsync = ref.watch(userProfileProvider);

    Widget row(UserModel user, String key, String title, String sub, String tag,
        Color tagColor) {
      final value = user.notificationSettings.toMap()[key] as bool;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(title,
                        style: AppTypography.bodyStrong
                            .copyWith(color: m.ink, fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  TagChip(tag, color: tagColor),
                ]),
                const SizedBox(height: 3),
                Text(sub,
                    style: AppTypography.caption
                        .copyWith(color: m.inkTertiary, fontSize: 12)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: m.violet,
            onChanged: (v) => _update(
              context,
              user,
              (map) => NotificationSettings.fromMap({...map, key: v}),
            ),
          ),
        ]),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Notifications')),
      body: Stack(children: [
        const Positioned.fill(child: AuroraBackground()),
        userAsync.when(
          data: (user) {
            if (user == null) {
              return const Center(child: Text('No user profile found'));
            }
            return ListView(
              padding: EdgeInsets.fromLTRB(
                MomentumTokens.gutter,
                MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                MomentumTokens.gutter,
                40,
              ),
              children: [
                Text(
                  'Max three a day, nothing between 22:00 and 08:00 except '
                  'overdue alerts and the streak saver.',
                  style: AppTypography.caption.copyWith(color: m.inkSecondary),
                ),
                const SizedBox(height: 18),
                const SectionLabel('Task-triggered'),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    row(
                        user,
                        'dueSoon',
                        'Due soon',
                        '30 minutes before a task is due',
                        'CRITICAL',
                        m.danger),
                    row(
                        user,
                        'overdue',
                        'Overdue alert',
                        '15 minutes after — with “move to tomorrow”',
                        'CRITICAL',
                        m.danger),
                    row(
                        user,
                        'morningBriefing',
                        'Morning briefing',
                        'Today’s count and overdue at 08:00',
                        'NORMAL',
                        m.amber),
                    row(
                        user,
                        'eveningWrapUp',
                        'Evening wrap-up',
                        'Score at 20:00, roll the rest to tomorrow',
                        'LOW',
                        m.cyan),
                  ]),
                ),
                const SizedBox(height: MomentumTokens.sectionGap),
                const SectionLabel('Streaks & motivation'),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    row(user, 'streakAtRisk', 'Streak at risk',
                        '21:00 if nothing is logged today', 'NORMAL', m.amber),
                    row(user, 'streakMilestone', 'Streak milestones',
                        'At 7, 14, 30, 60 and 100 days', 'LOW', m.cyan),
                    row(
                        user,
                        'weeklyReview',
                        'Weekly review',
                        'Sunday 19:00 with your week in numbers',
                        'LOW',
                        m.cyan),
                  ]),
                ),
              ],
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ]),
    );
  }
}
