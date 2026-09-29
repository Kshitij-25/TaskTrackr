import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_mark.dart';
import '../../theme/momentum_tokens.dart';
import '../components/momentum_ui.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  static const routeName = '/onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  const _Page(this.eyebrow, this.title, this.body, this.cta, this.visual);
  final String eyebrow;
  final String title;
  final String body;
  final String cta;
  final Widget Function(MomentumTokens m) visual;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  late final _pages = <_Page>[
    _Page(
      'CAPTURE',
      'Say it the way\nyou think it.',
      'Type “ship landing page tomorrow 2pm #work !high 45m” — the date, '
          'project, priority and estimate parse themselves.',
      'Continue',
      (m) => const _CaptureVisual(),
    ),
    _Page(
      'MOMENTUM',
      'Every win\nbanks XP.',
      'Tasks, habits and focus sessions level you up. One completion a day '
          'keeps the streak alive — that is the whole game.',
      'Continue',
      (m) => const _HudVisual(),
    ),
    _Page(
      'FOCUS',
      'Protect the\nhours that matter.',
      'A 25-minute timer that survives the lock screen, and a planner that '
          'tells you when today is overbooked — before it is.',
      'Get started',
      (m) => const _RingVisual(),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      if (AppMotion.reduced(context)) {
        _controller.jumpToPage(_page + 1);
      } else {
        _controller.nextPage(duration: AppMotion.sheet, curve: AppMotion.ease);
      }
    } else {
      context.goNamed(LoginScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground(intensity: 1.2)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
                  child: Row(children: [
                    const MomentumLogo(size: 30),
                    const SizedBox(width: 10),
                    Text('TaskTrackr',
                        style: AppTypography.heading2
                            .copyWith(color: m.ink, fontSize: 16)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.goNamed(LoginScreen.routeName),
                      child: Text('Skip',
                          style: AppTypography.caption.copyWith(
                              color: m.inkSecondary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) {
                      final p = _pages[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            Center(child: p.visual(m)),
                            const Spacer(),
                            Text(p.eyebrow,
                                style: AppTypography.label
                                    .copyWith(color: m.amber)),
                            const SizedBox(height: 10),
                            Text(p.title,
                                style: AppTypography.display.copyWith(
                                    color: m.ink, fontSize: 38, height: 1.05)),
                            const SizedBox(height: 14),
                            Text(p.body,
                                style: AppTypography.body
                                    .copyWith(color: m.inkSecondary)),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(children: [
                    for (var i = 0; i < _pages.length; i++)
                      AnimatedContainer(
                        duration: AppMotion.of(context, AppMotion.standard),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _page ? 26 : 8,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: i == _page
                              ? LinearGradient(colors: [m.amber, m.violet])
                              : null,
                          color:
                              i == _page ? null : m.ink.withValues(alpha: .15),
                        ),
                      ),
                    const Spacer(),
                    MButton(label: _pages[_page].cta, onPressed: _next),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureVisual extends StatelessWidget {
  const _CaptureVisual();

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    Widget chip(String t, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: m.ink.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: c.withValues(alpha: .4)),
          ),
          child: Text(t,
              style: AppTypography.caption
                  .copyWith(color: c, fontWeight: FontWeight.w600)),
        );
    return GlassCard(
      child: SizedBox(
        width: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ship landing page tomorrow 2pm #work !high 45m',
                style: AppTypography.bodyStrong.copyWith(color: m.ink)),
            const SizedBox(height: 14),
            Wrap(spacing: 6, runSpacing: 6, children: [
              chip('ship landing page', m.ink),
              chip('#Work', m.violet),
              chip('high priority', m.danger),
              chip('45m', m.cyan),
              chip('tomorrow', m.amber),
              chip('2pm', m.amber),
            ]),
          ],
        ),
      ),
    );
  }
}

class _HudVisual extends StatelessWidget {
  const _HudVisual();

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return GlassCard(
      child: SizedBox(
        width: 300,
        child: Row(children: [
          Column(children: [
            GradientText('34',
                style: AppTypography.display.copyWith(fontSize: 46)),
            Text('DAY STREAK',
                style: AppTypography.label
                    .copyWith(fontSize: 9, color: m.inkTertiary)),
          ]),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Level 12 · Keeper',
                    style: AppTypography.bodyStrong.copyWith(color: m.ink)),
                const SizedBox(height: 10),
                const XpBar(progress: .78),
                const SizedBox(height: 10),
                Text('+40 XP per task',
                    style: AppTypography.label
                        .copyWith(fontSize: 9.5, color: m.amber)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _RingVisual extends StatelessWidget {
  const _RingVisual();

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: .68,
            strokeWidth: 10,
            strokeCap: StrokeCap.round,
            backgroundColor: m.ink.withValues(alpha: .08),
            valueColor: AlwaysStoppedAnimation(m.violet),
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('17:02',
              style:
                  AppTypography.display.copyWith(color: m.ink, fontSize: 44)),
          Text('IN FLOW',
              style:
                  AppTypography.label.copyWith(color: m.amber, fontSize: 10)),
        ]),
      ]),
    );
  }
}
