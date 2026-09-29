import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task_model.dart';

class TaskRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'tasks';

  Stream<List<TaskModel>> getTasks(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(TaskModel.fromFirestore).toList();
    });
  }

  Stream<bool> getSyncStatus(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.metadata.hasPendingWrites);
  }

  // Writes are not awaited by callers that must work offline: Firestore
  // applies them to the local cache immediately and syncs when it can.

  Future<void> addTask(TaskModel task) {
    return _firestore.collection(_collection).add(task.toFirestore());
  }

  Future<void> updateTask(TaskModel task) {
    return _firestore
        .collection(_collection)
        .doc(task.id)
        .update(task.toFirestore());
  }

  Future<void> deleteTask(String taskId) {
    return _firestore.collection(_collection).doc(taskId).delete();
  }

  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) {
    return _firestore.collection(_collection).doc(taskId).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? Timestamp.now() : null,
    });
  }

  Future<void> setArchived(String taskId, bool archived) {
    return _firestore
        .collection(_collection)
        .doc(taskId)
        .update({'isArchived': archived});
  }

  /// Moves every open task due before today onto [target] (default: today),
  /// keeping its time of day. Returns how many moved.
  ///
  /// Filters client-side so it needs no composite index and works from the
  /// offline cache.
  Future<int> rollOverTasks(String userId, {DateTime? target}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = target ?? today;
    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    var moved = 0;
    for (final doc in snapshot.docs) {
      final task = TaskModel.fromFirestore(doc);
      if (task.isCompleted || task.isArchived) continue;
      if (!task.dueDate.isBefore(today)) continue;
      batch.update(doc.reference, {
        'dueDate': Timestamp.fromDate(DateTime(day.year, day.month, day.day,
            task.dueDate.hour, task.dueDate.minute)),
      });
      moved++;
    }
    if (moved > 0) batch.commit().ignore();
    return moved;
  }
}
