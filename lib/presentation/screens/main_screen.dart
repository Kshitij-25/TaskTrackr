import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/backend/notification_service.dart';
import '../../data/models/user_model.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_mark.dart';
import '../../theme/momentum_tokens.dart';
import '../components/add_task_sheet.dart';
import '../components/momentum_ui.dart';
import '../components/sync_indicator.dart';
import '../components/task_detail_sheet.dart';
import '../providers/auth_user_provider.dart';
import '../providers/momentum_provider.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import 'focus_screen.dart';
import 'habits_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'task_list_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});
  static const routeName = '/main';

  /// Tablet and up: the tab bar becomes a rail.
  static const railBreakpoint = 744.0;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  static const _screens = [
    HomeScreen(),
    TaskListScreen(),
    FocusScreen(),
    HabitsScreen(),
    ProfileScreen(asTab: true),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wireNotificationActions();
    NotificationService().ready.then((_) {
      if (mounted) _syncNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final n = NotificationService();
    n.onReschedule = null;
    n.onRollover = null;
    n.onOpenTask = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(focusProvider.notifier).resync();
      // Day may have rolled over while backgrounded: re-derive streaks.
      ref.invalidate(momentumProvider);
    }
  }

  void _wireNotificationActions() {
    final n = NotificationService();
    n.onReschedule = (id) {
      final task = (ref.read(allTasksProvider).valueOrNull ?? const [])
          .where((t) => t.id == id)
          .firstOrNull;
      if (task == null) return;
      final now = DateTime.now();
      final due = DateTime(now.year, now.month, now.day + 1, task.dueDate.hour,
          task.dueDate.minute);
      ref.read(taskActionsProvider).moveTask(task, due).ignore();
      if (mounted) showMomentumToast(context, 'Moved to tomorrow');
    };
    n.onRollover = () async {
      final now = DateTime.now();
      final moved = await ref.read(taskRepositoryProvider).rollOverTasks(
            ref.read(currentUidProvider) ?? '',
            target: DateTime(now.year, now.month, now.day + 1),
          );
      // Also carry today's unfinished tasks forward.
      final open = (ref.read(taskListProvider).valueOrNull ?? const []).where(
          (t) =>
              !t.isCompleted &&
              t.dueDate.year == now.year &&
              t.dueDate.month == now.month &&
              t.dueDate.day == now.day);
      for (final t in open) {
        ref
            .read(taskActionsProvider)
            .moveTask(t, t.dueDate.add(const Duration(days: 1)))
            .ignore();
      }
      if (mounted) {
        showMomentumToast(
            context, 'Rolled ${moved + open.length} tasks to tomorrow');
      }
    };
    n.onOpenTask = (id) {
      if (mounted) showTaskDetail(context, id);
    };
  }

  void _syncNotifications() {
    final tasks = ref.read(allTasksProvider).valueOrNull;
    final user = ref.read(userProfileProvider).valueOrNull;
    if (tasks == null) return;
    final settings = user?.notificationSettings ?? NotificationSettings();
    final s = ref.read(momentumProvider);
    final n = NotificationService();
    n.cacheSettings(settings);
    n.syncSchedules(ScheduleInputs(
      tasks: tasks,
      settings: settings,
      streak: s.streak,
      activeToday: s.activeToday,
    ));
  }

  void _go(int i) {
    if (i == ref.read(mainTabProvider)) return;
    HapticFeedback.selectionClick();
    ref.read(mainTabProvider.notifier).state = i;
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(mainTabProvider);
    final celebration =
        ref.watch(momentumProvider.select((s) => s.celebration));
    final mode = ref.watch(gamificationProvider);
    final reduced = AppMotion.reduced(context);
    final wide = MediaQuery.sizeOf(context).width >= MainScreen.railBreakpoint;

    ref.listen(momentumProvider.select((s) => s.celebration), (_, next) {
      if (next == null) return;
      final notifier = ref.read(momentumProvider.notifier);
      if (mode != GamificationMode.full) {
        // Quiet: a toast, no overlay. Off: nothing at all.
        if (mode == GamificationMode.quiet) {
          showMomentumToast(context, '${next.title} · ${next.subtitle}');
        }
        notifier.clearCelebration();
        return;
      }
      next.kind == CelebrationKind.level
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.lightImpact();
      Future.delayed(
          Duration(
              milliseconds: next.kind == CelebrationKind.level ? 2000 : 1600),
          () {
        if (mounted) notifier.clearCelebration();
      });
    });

    // Badges whose conditions live outside the XP notifier.
    ref.listen(habitsProvider, (_, habits) {
      if (habits.any((h) => h.streak >= 21)) {
        ref.read(momentumProvider.notifier).unlock('habit_keeper');
      }
    });
    ref.listen(focusProvider.select((f) => f.minutesToday), (_, minutes) {
      if (minutes >= 100) {
        ref.read(momentumProvider.notifier).unlock('deep_diver');
      }
    });
    ref.listen(taskListProvider, (prev, next) {
      final before = prev?.valueOrNull;
      final tasks = next.valueOrNull;
      // Only on the transition to "all done", not on a list that loads empty.
      if (before == null || tasks == null || tasks.isEmpty) return;
      final wasOpen = before.any((t) => !t.isCompleted);
      if (wasOpen && tasks.every((t) => t.isCompleted)) {
        ref.read(momentumProvider.notifier).unlock('zero_inbox');
      }
    });

    // Re-plan reminders whenever tasks, settings or the streak change.
    ref.listen(allTasksProvider, (_, __) => _syncNotifications());
    ref.listen(userProfileProvider, (_, __) => _syncNotifications());
    ref.listen(momentumProvider.select((s) => (s.streak, s.activeToday)),
        (_, __) => _syncNotifications());

    final content = AnimatedSwitcher(
      duration: reduced ? AppMotion.micro : AppMotion.standard,
      switchInCurve: AppMotion.ease,
      child: KeyedSubtree(key: ValueKey(index), child: _screens[index]),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          if (wide)
            Padding(
              padding: const EdgeInsets.only(left: 100),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: content,
                ),
              ),
            )
          else
            content,
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            left: 0,
            right: 0,
            child: const Center(child: SyncIndicator()),
          ),
          if (wide)
            Positioned(
              left: 12,
              top: MediaQuery.paddingOf(context).top + 12,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: _Rail(index: index, onTap: _go),
            )
          else
            Positioned(
              left: 14,
              right: 14,
              bottom: MediaQuery.paddingOf(context).bottom + 10,
              child: _TabBar(index: index, onTap: _go),
            ),
          if (celebration != null && mode == GamificationMode.full)
            _CelebrationOverlay(
              key: ValueKey(celebration),
              celebration: celebration,
              level: ref.read(momentumProvider).level,
            ),
        ],
      ),
    );
  }
}

/// 76pt glass rail for tablet widths. Same destinations as the tab bar.
class _Rail extends StatelessWidget {
  const _Rail({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return GlassBlur(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            const MomentumLogo(size: 38, tile: true),
            const SizedBox(height: 18),
            for (var i = 0; i < 5; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration:
                      AppMotion.of(context, const Duration(milliseconds: 300)),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    color: i == index
                        ? m.ink.withValues(alpha: m.isDark ? .11 : .07)
                        : Colors.transparent,
                  ),
                  child: Column(children: [
                    CustomPaint(
                      size: const Size(19, 19),
                      painter: _Glyph(
                          i, i == index ? m.ink : m.ink.withValues(alpha: .42)),
                    ),
                    const SizedBox(height: 6),
                    Text(_TabBar._labels[i],
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color:
                              i == index ? m.ink : m.ink.withValues(alpha: .42),
                        )),
                  ]),
                ),
              ),
            const Spacer(),
            Pressable(
              onTap: () => showAddTaskSheet(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(colors: [m.amber, m.violet]),
                ),
                child: const Icon(Icons.add_rounded, color: Color(0xFF0B0B12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _labels = ['Today', 'Tasks', 'Focus', 'Habits', 'You'];

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return GlassBlur(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          for (var i = 0; i < 5; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration:
                      AppMotion.of(context, const Duration(milliseconds: 300)),
                  curve: AppMotion.ease,
                  padding: const EdgeInsets.fromLTRB(0, 9, 0, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    color: i == index
                        ? m.ink.withValues(alpha: m.isDark ? .11 : .07)
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        size: const Size(17, 17),
                        painter: _Glyph(i,
                            i == index ? m.ink : m.ink.withValues(alpha: .42)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _labels[i],
                        style: AppTypography.caption.copyWith(
                          fontSize: 10.5,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color:
                              i == index ? m.ink : m.ink.withValues(alpha: .42),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Geometric primitives only: circle, rounded square, bar, arc. 2px stroke.
class _Glyph extends CustomPainter {
  _Glyph(this.kind, this.color);
  final int kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final c = s.center(Offset.zero);
    final fill = Paint()..color = color;
    switch (kind) {
      case 0: // Today: sun-ish circle with core
        canvas.drawCircle(c, s.width * .42, p);
        canvas.drawCircle(c, 2.4, fill);
      case 1: // Tasks: three bars
        for (var i = 0; i < 3; i++) {
          final y = s.height * (.2 + i * .3);
          canvas.drawLine(Offset(s.width * .1, y),
              Offset(s.width * (i == 2 ? .6 : .9), y), p);
        }
      case 2: // Focus: open arc + dot
        canvas.drawArc(Rect.fromCircle(center: c, radius: s.width * .42),
            -math.pi / 2, math.pi * 1.6, false, p);
        canvas.drawCircle(c, 2.2, fill);
      case 3: // Habits: rounded square with check-bar
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(1, 1, s.width - 2, s.height - 2),
                const Radius.circular(5)),
            p);
        canvas.drawLine(Offset(s.width * .3, s.height * .5),
            Offset(s.width * .7, s.height * .5), p);
      case 4: // You: head + shoulders arc
        canvas.drawCircle(Offset(c.dx, s.height * .32), s.width * .2, p);
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(c.dx, s.height * 1.02),
                width: s.width * .9,
                height: s.height * .8),
            math.pi * 1.08,
            math.pi * .84,
            false,
            p);
    }
  }

  @override
  bool shouldRepaint(_Glyph old) => old.kind != kind || old.color != color;
}

/// Level-up crest (big) or badge / quest banner (lighter). Under reduce
/// motion it is a 120ms crossfade with no scale.
class _CelebrationOverlay extends StatelessWidget {
  const _CelebrationOverlay({
    super.key,
    required this.celebration,
    required this.level,
  });
  final Celebration celebration;
  final int level;

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final reduced = AppMotion.reduced(context);
    final isLevel = celebration.kind == CelebrationKind.level;

    final Widget crest = isLevel
        ? Stack(alignment: Alignment.center, children: [
            const MomentumCrest(size: 110),
            Text('$level',
                style: AppTypography.display
                    .copyWith(fontSize: 40, color: const Color(0xFF0B0B12))),
          ])
        : const MomentumCrest(size: 76);

    final eyebrow = switch (celebration.kind) {
      CelebrationKind.level => 'LEVEL UP',
      CelebrationKind.badge => 'BADGE EARNED',
      CelebrationKind.quest => 'QUEST COMPLETE',
    };

    final card = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        crest,
        const SizedBox(height: 20),
        Text(eyebrow, style: AppTypography.label.copyWith(color: m.amber)),
        const SizedBox(height: 6),
        Text(
          isLevel ? celebration.subtitle : celebration.title,
          textAlign: TextAlign.center,
          style: AppTypography.heading1.copyWith(color: m.ink),
        ),
        if (!isLevel) ...[
          const SizedBox(height: 4),
          Text(
            celebration.subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: m.inkSecondary),
          ),
        ],
      ],
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduced ? AppMotion.micro : AppMotion.celebrate,
          curve: reduced ? Curves.linear : AppMotion.easeCelebrate,
          builder: (_, t, child) => Opacity(
            opacity: t.clamp(0, 1),
            child: ColoredBox(
              color: isLevel ? m.scrim : m.scrim.withValues(alpha: .35),
              child: Center(
                child: reduced
                    ? child
                    : Transform.scale(scale: .7 + .3 * t, child: child),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: card,
          ),
        ),
      ),
    );
  }
}
