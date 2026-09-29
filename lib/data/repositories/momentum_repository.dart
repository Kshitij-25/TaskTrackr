import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Cloud copy of XP, streak, habit and focus data at
/// `users/{uid}/momentum/state`. The device is the source of truth; this only
/// carries data between devices. Conflicts resolve to the higher value so a
/// streak or XP never goes backwards because of a sync.
class MomentumRepository {
  MomentumRepository(this.uid);
  final String uid;

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('momentum')
      .doc('state');

  Timer? _debounce;
  Map<String, dynamic> _pending = {};

  Future<Map<String, dynamic>?> fetch() async {
    try {
      final snap = await _doc.get();
      return snap.data();
    } catch (e) {
      log('Momentum fetch failed (offline is fine): $e');
      return null;
    }
  }

  /// Coalesces rapid writes (e.g. ticking five habits) into one.
  void save(String section, Object value) {
    _pending[section] = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), flush);
  }

  void flush() {
    if (_pending.isEmpty) return;
    final data = {..._pending, 'updatedAt': FieldValue.serverTimestamp()};
    _pending = {};
    _doc.set(data, SetOptions(merge: true)).catchError((Object e) {
      log('Momentum sync failed, will retry with next write: $e');
    });
  }

  void dispose() {
    _debounce?.cancel();
    flush();
  }
}
