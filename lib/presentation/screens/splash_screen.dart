import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_mark.dart';
import '../../theme/momentum_tokens.dart';
import '../components/momentum_ui.dart';
import 'main_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  static const routeName = '/splash';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  // Crest: scale .7 → 1.06 → 1 with fade (mCrest).
  late final _crest =
      CurvedAnimation(parent: _c, curve: const Interval(0, .38));
  late final _word = CurvedAnimation(
      parent: _c, curve: const Interval(.28, .5, curve: AppMotion.ease));
  late final _bar = CurvedAnimation(
      parent: _c, curve: const Interval(.4, 1, curve: Curves.easeInOutCubic));

  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: skip the crest pop and show the settled frame.
    if (AppMotion.reduced(context) && _c.value < 1) _c.value = 1;
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    context
        .go(user != null ? MainScreen.routeName : OnboardingScreen.routeName);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _crestScale(double t) {
    if (t < .45) return .7 + (1.06 - .7) * (t / .45);
    return 1.06 - .06 * ((t - .45) / .55);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground(intensity: 1.3)),
          Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: (_crest.value * 2.2).clamp(0, 1),
                    child: Transform.scale(
                      scale: _crestScale(_crest.value),
                      child: const MomentumLogo(size: 96, tile: true),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Opacity(
                    opacity: _word.value,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - _word.value)),
                      child: Column(children: [
                        Text('TaskTrackr',
                            style: AppTypography.display
                                .copyWith(color: m.ink, fontSize: 36)),
                        const SizedBox(height: 8),
                        Text('A PRODUCTIVITY OS BUILT ON MOMENTUM',
                            style: AppTypography.label
                                .copyWith(fontSize: 10, color: m.inkTertiary)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Opacity(
                    opacity: _word.value,
                    child: SizedBox(
                      width: 140,
                      child: XpBar(progress: _bar.value, height: 4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
