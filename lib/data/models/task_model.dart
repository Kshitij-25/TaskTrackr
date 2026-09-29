import 'package:cloud_firestore/cloud_firestore.dart';

class Subtask {
  const Subtask({required this.title, this.done = false});

  factory Subtask.fromMap(Map<String, dynamic> map) => Subtask(
        title: map['title'] as String? ?? '',
        done: map['done'] as bool? ?? false,
      );

  final String title;
  final bool done;

  Map<String, dynamic> toMap() => {'title': title, 'done': done};

  Subtask copyWith({String? title, bool? done}) =>
      Subtask(title: title ?? this.title, done: done ?? this.done);
}

class TaskModel {
  TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.dueDate,
    required this.priority,
    required this.category,
    this.isCompleted = false,
    required this.userId,
    this.isPending = false,
    this.estimateMinutes,
    this.subtasks = const [],
    this.isArchived = false,
    this.completedAt,
  });

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      priority: data['priority'] ?? 'Low',
      category: data['category'] ?? 'General',
      isCompleted: data['isCompleted'] ?? false,
      userId: data['userId'] ?? '',
      isPending: doc.metadata.hasPendingWrites,
      estimateMinutes: (data['estimateMinutes'] as num?)?.toInt(),
      subtasks: ((data['subtasks'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Subtask.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      isArchived: data['isArchived'] ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }
  final bool isArchived;

  /// When the task was last completed; null for open or legacy tasks.
  final DateTime? completedAt;
  final String id;
  final String title;
  final String? description;
  final DateTime dueDate;
  final String priority;
  final String category;
  final bool isCompleted;
  final String userId;
  final bool isPending;
  final int? estimateMinutes;
  final List<Subtask> subtasks;

  String get estimateLabel {
    final m = estimateMinutes;
    if (m == null) return '';
    if (m < 60) return '${m}m';
    return m % 60 == 0 ? '${m ~/ 60}h' : '${m ~/ 60}h ${m % 60}m';
  }

  String get subtaskLabel =>
      '${subtasks.where((s) => s.done).length}/${subtasks.length}';

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'priority': priority,
      'category': category,
      'isCompleted': isCompleted,
      'userId': userId,
      'estimateMinutes': estimateMinutes,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      'isArchived': isArchived,
      'completedAt':
          completedAt == null ? null : Timestamp.fromDate(completedAt!),
    };
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
    String? category,
    bool? isCompleted,
    String? userId,
    bool? isPending,
    int? estimateMinutes,
    List<Subtask>? subtasks,
    bool? isArchived,
    DateTime? completedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      userId: userId ?? this.userId,
      isPending: isPending ?? this.isPending,
      estimateMinutes: estimateMinutes ?? this.estimateMinutes,
      subtasks: subtasks ?? this.subtasks,
      isArchived: isArchived ?? this.isArchived,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
