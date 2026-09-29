import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/backend/authenticator.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';
import '../components/momentum_ui.dart';
import '../providers/auth_state_notifer.dart';
import '../providers/momentum_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import 'account_settings_screen.dart';
import 'calendar_screen.dart';
import 'insights_screen.dart';
import 'notification_settings_screen.dart';

/// "You" — level, streaks, weekly XP, achievements, quests and settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.asTab = false});
  static const routeName = '/profile';

  final bool asTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    final user = ref.watch(userProfileProvider).value;
    final s = ref.watch(momentumProvider);
    final gamOn = ref.watch(gamificationProvider) != GamificationMode.off;
    final name =
        (user?.displayName ?? const Authenticator().displayName).trim();
    final now = DateTime.now();

    final week = s.lastWeek;
    final maxXp = week.fold<int>(1, (a, b) => b > a ? b : a);
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final body = ListView(
      padding: EdgeInsets.fromLTRB(
        MomentumTokens.gutter,
        MediaQuery.paddingOf(context).top + (asTab ? 14 : 64),
        MomentumTokens.gutter,
        130,
      ),
      children: [
        Row(
          children: [
            LevelAvatar(name: name, photoUrl: user?.photoURL, size: 60),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'You' : name,
                      style: AppTypography.heading1
                          .copyWith(color: m.ink, fontSize: 24)),
                  const SizedBox(height: 2),
                  Text(
                      gamOn
                          ? 'Level ${s.level} · ${s.levelName}'
                          : '${s.tasksDone} tasks done',
                      style: AppTypography.caption
                          .copyWith(color: m.inkSecondary)),
                ],
              ),
            ),
          ],
        ),
        if (gamOn) ...[
          const SizedBox(height: 16),
          XpBar(progress: s.progress),
          const SizedBox(height: 6),
          Text('${s.xp} / $xpPerLevel XP to next level',
              style: AppTypography.label.copyWith(
                  fontSize: 10, letterSpacing: .4, color: m.inkTertiary)),
        ],
        const SizedBox(height: 18),
        Row(children: [
          _StatCard('${s.streak}', 'DAY STREAK', m.amber),
          const SizedBox(width: 8),
          _StatCard('${s.bestStreak}', 'BEST STREAK', m.violet),
          const SizedBox(width: 8),
          _StatCard('${s.tasksDone}', 'TASKS DONE', m.cyan),
        ]),
        if (gamOn) ...[
          const SizedBox(height: MomentumTokens.sectionGap),
          const SectionLabel('XP this week'),
          const SizedBox(height: 10),
          GlassCard(
            child: SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: (week[i] / maxXp).clamp(.06, 1),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(7),
                                  gradient: i == 6
                                      ? LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [m.amber, m.violet])
                                      : null,
                                  color: i == 6
                                      ? null
                                      : m.ink.withValues(alpha: .14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dayLetters[
                                now.subtract(Duration(days: 6 - i)).weekday -
                                    1],
                            style: AppTypography.label.copyWith(
                                fontSize: 9.5,
                                color: i == 6 ? m.ink : m.inkTertiary),
                          ),
                        ],
                      ),
                    ),
                    if (i < 6) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: MomentumTokens.sectionGap),
          SectionLabel('Achievements',
              trailing: Text('${s.unlocked.length} / ${badges.length}',
                  style: AppTypography.label
                      .copyWith(fontSize: 10, color: m.inkTertiary))),
          const SizedBox(height: 10),
          GridView.count(
            padding: EdgeInsets.zero,
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: .9,
            children: [
              for (final b in badges)
                GestureDetector(
                  onTap: () => showMomentumToast(
                    context,
                    s.unlocked.containsKey(b.id)
                        ? '${b.label} · earned ${_fmtDay(s.unlocked[b.id]!)}'
                        : '${b.label} · ${b.how}',
                  ),
                  child: _Badge(b.label, s.unlocked.containsKey(b.id)),
                ),
            ],
          ),
          const SizedBox(height: MomentumTokens.sectionGap),
          const SectionLabel('Quests'),
          const SizedBox(height: 10),
          _Quest(
            title: questDaily5.title,
            xp: questDaily5.xp,
            claimed: s.isClaimed(questDaily5),
            progress: s.tasksToday / 5,
            detail: s.isClaimed(questDaily5)
                ? 'Claimed today · new one at midnight'
                : '${s.tasksToday.clamp(0, 5)} of 5 · resets at midnight',
            colors: [m.amber, m.violet],
          ),
          const SizedBox(height: 8),
          _Quest(
            title: questStreak40.title,
            xp: questStreak40.xp,
            claimed: s.isClaimed(questStreak40),
            progress: s.streak / 40,
            detail: s.isClaimed(questStreak40)
                ? 'Claimed · one-time quest'
                : '${s.streak} of 40 · ${(40 - s.streak).clamp(0, 40)} days to go',
            colors: [m.violet, m.cyan],
          ),
        ],
        const SizedBox(height: MomentumTokens.sectionGap),
        const SectionLabel('Settings'),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            _ThemeRow(),
            _GamificationRow(),
            _Row(Icons.calendar_month_outlined, 'Calendar',
                () => context.pushNamed(CalendarScreen.routeName)),
            _Row(Icons.insights_outlined, 'Insights',
                () => context.pushNamed(InsightsScreen.routeName)),
            _Row(Icons.person_outline_rounded, 'Account',
                () => context.pushNamed(AccountSettingsScreen.routeName)),
            _Row(Icons.notifications_none_rounded, 'Notifications',
                () => context.pushNamed(NotificationSettingsScreen.routeName)),
          ]),
        ),
        const SizedBox(height: 16),
        MButton(
          label: 'Log out',
          kind: MButtonKind.destructive,
          expand: true,
          onPressed: () =>
              ref.read(authStateNotifierProvider.notifier).logOut(),
        ),
      ],
    );

    if (asTab) return body;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(),
      body: Stack(children: [const AuroraBackground(), body]),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GlassCard(
          radius: MomentumTokens.radiusRow,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Text(value,
                style:
                    AppTypography.display.copyWith(fontSize: 26, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: AppTypography.label
                    .copyWith(fontSize: 8.5, color: context.m.inkTertiary)),
          ]),
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.got);
  final String label;
  final bool got;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 13, 6, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: m.ink.withValues(alpha: got ? .055 : .025),
        border: Border.all(color: m.ink.withValues(alpha: got ? .11 : .06)),
      ),
      child: Column(children: [
        if (got)
          const MomentumCrest(size: 30)
        else
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: m.ink.withValues(alpha: .06),
              border: Border.all(color: m.ink.withValues(alpha: .16)),
            ),
          ),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppTypography.caption.copyWith(
              fontSize: 9.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: got ? m.inkSecondary : m.inkTertiary,
            )),
      ]),
    );
  }
}

class _Quest extends StatelessWidget {
  const _Quest({
    required this.title,
    required this.xp,
    required this.progress,
    required this.detail,
    required this.colors,
    this.claimed = false,
  });
  final bool claimed;
  final String title;
  final int xp;
  final double progress;
  final String detail;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return GlassCard(
      radius: MomentumTokens.radiusRow,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: AppTypography.bodyStrong
                      .copyWith(color: m.ink, fontSize: 13.5)),
            ),
            TagChip(claimed ? 'CLAIMED' : '+$xp XP',
                color: claimed ? m.success : m.amber),
          ]),
          const SizedBox(height: 10),
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: m.ink.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.02, 1),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(colors: colors),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(detail,
              style: AppTypography.label.copyWith(
                  fontSize: 9.5, letterSpacing: .4, color: m.inkTertiary)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.title, this.onTap);
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon, size: 20, color: m.inkSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: AppTypography.bodyStrong
                    .copyWith(color: m.ink, fontSize: 14)),
          ),
          Icon(Icons.chevron_right_rounded, color: m.inkTertiary),
        ]),
      ),
    );
  }
}

class _ThemeRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
      child: Row(children: [
        Icon(m.isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            size: 20, color: m.inkSecondary),
        const SizedBox(width: 14),
        Expanded(
          child: Text('AMOLED dark',
              style: AppTypography.bodyStrong
                  .copyWith(color: m.ink, fontSize: 14)),
        ),
        Switch.adaptive(
          value: m.isDark,
          activeTrackColor: m.violet,
          onChanged: (v) => ref
              .read(themeProvider.notifier)
              .setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
        ),
      ]),
    );
  }
}

String _fmtDay(String key) {
  final d = DateTime(int.parse(key.substring(0, 4)),
      int.parse(key.substring(4, 6)), int.parse(key.substring(6, 8)));
  return DateFormat('d MMM y').format(d);
}

class _GamificationRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    final mode = ref.watch(gamificationProvider);
    const labels = {
      GamificationMode.full: 'Full',
      GamificationMode.quiet: 'Quiet',
      GamificationMode.off: 'Off',
    };
    return Pressable(
      onTap: () async {
        final picked = await showOptionSheet<GamificationMode>(
          context,
          title: 'Gamification',
          selected: mode,
          options: [
            (
              'Full — XP, bursts and celebrations',
              GamificationMode.full,
              m.amber
            ),
            (
              'Quiet — XP counts, no overlays',
              GamificationMode.quiet,
              m.violet
            ),
            (
              'Off — just tasks and streaks',
              GamificationMode.off,
              m.inkTertiary
            ),
          ],
        );
        if (picked != null) ref.read(gamificationProvider.notifier).set(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(Icons.auto_awesome_outlined, size: 20, color: m.inkSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Gamification',
                style: AppTypography.bodyStrong
                    .copyWith(color: m.ink, fontSize: 14)),
          ),
          Text(labels[mode]!,
              style: AppTypography.caption.copyWith(color: m.inkSecondary)),
          Icon(Icons.chevron_right_rounded, color: m.inkTertiary),
        ]),
      ),
    );
  }
}
