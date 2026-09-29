import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import 'auth_user_provider.dart';

final taskRepositoryProvider = Provider((ref) => TaskRepository());

/// Every task for the signed-in user, archived ones included.
final allTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).getTasks(uid);
});

/// Active (non-archived) tasks — what almost every screen shows.
final taskListProvider = Provider<AsyncValue<List<TaskModel>>>((ref) {
  return ref
      .watch(allTasksProvider)
      .whenData((tasks) => tasks.where((t) => !t.isArchived).toList());
});

final archivedTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasks = ref.watch(allTasksProvider).valueOrNull ?? const [];
  return tasks.where((t) => t.isArchived).toList();
});

final taskActionsProvider = Provider((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return TaskActions(repository, ref.watch(currentUidProvider));
});

class TaskActions {
  TaskActions(this._repository, this._uid);
  final TaskRepository _repository;
  final String? _uid;

  Future<void> addTask(TaskModel task) => _repository.addTask(task);
  Future<void> updateTask(TaskModel task) => _repository.updateTask(task);
  Future<void> deleteTask(String taskId) => _repository.deleteTask(taskId);
  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) =>
      _repository.toggleTaskCompletion(taskId, isCompleted);
  Future<void> setArchived(String taskId, bool archived) =>
      _repository.setArchived(taskId, archived);
  Future<void> moveTask(TaskModel task, DateTime due) =>
      _repository.updateTask(task.copyWith(dueDate: due));
  Future<int> rollOverOverdue() async =>
      _uid == null ? 0 : _repository.rollOverTasks(_uid);
}
