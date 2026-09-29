import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/momentum_provider.dart';
import 'momentum_ui.dart';

/// Banks a win and gives feedback that matches the gamification mode:
/// full → haptic + particle burst + "+XP" toast; quiet → haptic + toast;
/// off → haptic + plain toast, no XP wording.
void rewardWin(
  BuildContext context,
  WidgetRef ref,
  XpSource source, {
  required String message,
  Offset? burstAt,
}) {
  final mode = ref.read(gamificationProvider);
  final granted = ref.read(momentumProvider.notifier).award(source);
  HapticFeedback.lightImpact();
  if (mode == GamificationMode.full && burstAt != null) {
    showXpBurst(context, burstAt);
  }
  showMomentumToast(
    context,
    granted > 0 ? '$message · +$granted XP' : message,
  );
}

/// "+40 XP" style label, or [fallback] when gamification is off.
String xpLabel(WidgetRef ref, XpSource source, {String fallback = ''}) =>
    ref.watch(gamificationProvider) == GamificationMode.off
        ? fallback
        : '+${source.xp} XP';
