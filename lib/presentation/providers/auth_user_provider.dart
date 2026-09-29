import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The signed-in Firebase user, live. Everything user-scoped watches this so
/// switching accounts rebuilds tasks, profile, XP and habits.
final authUserProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.userChanges(),
);

/// Current uid, or null while signed out.
final currentUidProvider = Provider<String?>(
  (ref) =>
      ref.watch(authUserProvider).value?.uid ??
      FirebaseAuth.instance.currentUser?.uid,
);
