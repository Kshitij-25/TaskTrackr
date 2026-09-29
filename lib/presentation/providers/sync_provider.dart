import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'auth_user_provider.dart';
import 'task_provider.dart';

final syncStatusProvider = StreamProvider<bool>((ref) {
  final userId = ref.watch(currentUidProvider);
  if (userId == null) return Stream.value(false);

  final repository = ref.watch(taskRepositoryProvider);
  return repository.getSyncStatus(userId);
});
