import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../theme/app_motion.dart';
import '../../theme/momentum_tokens.dart';
import '../providers/sync_provider.dart';
import 'momentum_ui.dart';

/// "OFFLINE · PENDING" chip, shown only while Firestore has unsynced writes.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(syncStatusProvider).value ?? false;
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.standard),
      child: isSyncing
          ? TagChip('SYNCING · PENDING WRITES',
              color: context.m.amber, dot: true)
          : const SizedBox.shrink(),
    );
  }
}
