import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/models/login_state.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_mark.dart';
import '../../theme/momentum_tokens.dart';
import '../components/momentum_ui.dart';
import '../providers/auth_state_notifer.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});
  static const routeName = '/login';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = context.m;
    final loginState = ref.watch(authStateNotifierProvider);
    final loading = loginState == LoginState.loading;

    ref.listen(authStateNotifierProvider, (previous, next) {
      if (next == LoginState.error) {
        showMomentumToast(context,
            'Sign-in didn’t go through. Check your connection and try again.');
      }
    });

    final reduced = AppMotion.reduced(context);
    // Staggered rise; reduced motion gets a plain 120ms fade, no movement.
    Widget rise(double delay, Widget child) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduced
              ? AppMotion.micro
              : Duration(milliseconds: 360 + (delay * 1000).round()),
          curve: reduced
              ? Curves.linear
              : Interval(delay / (delay + .36), 1, curve: AppMotion.ease),
          builder: (_, t, c) => Opacity(
            opacity: t,
            child: reduced
                ? c
                : Transform.translate(
                    offset: Offset(0, 10 * (1 - t)), child: c),
          ),
          child: child,
        );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground(intensity: 1.2)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 3),
                  rise(0, const MomentumLogo(size: 64, tile: true)),
                  const SizedBox(height: 28),
                  rise(
                      .06,
                      Text('TASKTRACKR',
                          style: AppTypography.label
                              .copyWith(color: m.inkTertiary))),
                  const SizedBox(height: 10),
                  rise(
                      .1,
                      Text('Keep the\nstreak alive.',
                          style: AppTypography.display.copyWith(
                              color: m.ink, fontSize: 42, height: 1.02))),
                  const SizedBox(height: 14),
                  rise(
                      .14,
                      Text(
                        'Tasks, habits and focus sessions that bank XP. '
                        'Sign in to sync your momentum across devices.',
                        style:
                            AppTypography.body.copyWith(color: m.inkSecondary),
                      )),
                  const SizedBox(height: 26),
                  rise(.18, const _Teaser()),
                  const Spacer(flex: 4),
                  rise(
                      .22,
                      GlassBlur(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            MButton(
                              label: loading
                                  ? 'Signing in…'
                                  : 'Continue with Google',
                              expand: true,
                              loading: loading,
                              icon: Image.network(
                                'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                                width: 18,
                                height: 18,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.login_rounded),
                              ),
                              onPressed: () => ref
                                  .read(authStateNotifierProvider.notifier)
                                  .loginWithGoogle(),
                            ),
                            const SizedBox(height: 12),
                            Text('SECURE ONE-TAP SIGN-IN · WORKS OFFLINE',
                                style: AppTypography.label.copyWith(
                                    fontSize: 9, color: m.inkTertiary)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'By continuing you agree to the Terms of Service\nand Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption
                          .copyWith(fontSize: 11, color: m.inkTertiary),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A glimpse of the HUD: streak, level and focus as chips.
class _Teaser extends StatelessWidget {
  const _Teaser();

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    Widget pill(String value, String label, Color c) => Expanded(
          child: GlassCard(
            radius: MomentumTokens.radiusRow,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: AppTypography.heading2
                        .copyWith(color: c, fontSize: 20)),
                const SizedBox(height: 2),
                Text(label,
                    style: AppTypography.label
                        .copyWith(fontSize: 8.5, color: m.inkTertiary)),
              ],
            ),
          ),
        );
    return Row(children: [
      pill('+40', 'XP PER TASK', m.amber),
      const SizedBox(width: 8),
      pill('25:00', 'FOCUS', m.violet),
      const SizedBox(width: 8),
      pill('∞', 'STREAK', m.cyan),
    ]);
  }
}
