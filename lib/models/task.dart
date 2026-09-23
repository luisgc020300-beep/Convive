// lib/models/task.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurrenceType { daily, weekly, everyNDays }

extension RecurrenceTypeX on RecurrenceType {
  String get wireValue => switch (this) {
        RecurrenceType.daily => 'daily',
        RecurrenceType.weekly => 'weekly',
        RecurrenceType.everyNDays => 'every_n_days',
      };

  String get label => switch (this) {
        RecurrenceType.daily => 'Cada día',
        RecurrenceType.weekly => 'Cada semana',
        RecurrenceType.everyNDays => 'Cada X días',
      };

  static RecurrenceType fromWire(String? v) => switch (v) {
        'weekly' => RecurrenceType.weekly,
        'every_n_days' => RecurrenceType.everyNDays,
        _ => RecurrenceType.daily,
      };

  Duration periodDuration({int? intervalDays}) => switch (this) {
        RecurrenceType.daily => const Duration(days: 1),
        RecurrenceType.weekly => const Duration(days: 7),
        RecurrenceType.everyNDays =>
          Duration(days: (intervalDays ?? 1).clamp(1, 365)),
      };
}

class ConviveTask {
  final String id;
  final String title;
  final RecurrenceType recurrenceType;
  final int? intervalDays;
  final List<String> rotationOrder;
  final int rotationIndex;
  final String? currentAssigneeUid;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final bool active;

  const ConviveTask({
    required this.id,
    required this.title,
    required this.recurrenceType,
    this.intervalDays,
    required this.rotationOrder,
    required this.rotationIndex,
    this.currentAssigneeUid,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    required this.active,
  });

  factory ConviveTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final recurrence = (d['recurrence'] as Map<String, dynamic>?) ?? {};
    return ConviveTask(
      id: doc.id,
      title: d['title'] as String? ?? '',
      recurrenceType: RecurrenceTypeX.fromWire(recurrence['type'] as String?),
      intervalDays: (recurrence['intervalDays'] as num?)?.toInt(),
      rotationOrder: (d['rotationOrder'] as List?)?.cast<String>() ?? [],
      rotationIndex: (d['rotationIndex'] as num?)?.toInt() ?? 0,
      currentAssigneeUid: d['currentAssigneeUid'] as String?,
      currentPeriodStart: (d['currentPeriodStart'] as Timestamp?)?.toDate(),
      currentPeriodEnd: (d['currentPeriodEnd'] as Timestamp?)?.toDate(),
      active: d['active'] as bool? ?? true,
    );
  }
}

class TaskCompletion {
  final String id;
  final String taskId;
  final String taskTitle;
  final String? assigneeUid;
  final String status; // done | missed | skipped
  final DateTime? completedAt;
  final String? completedBy;

  const TaskCompletion({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    this.assigneeUid,
    required this.status,
    this.completedAt,
    this.completedBy,
  });

  factory TaskCompletion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TaskCompletion(
      id: doc.id,
      taskId: d['taskId'] as String? ?? '',
      taskTitle: d['taskTitle'] as String? ?? '',
      assigneeUid: d['assigneeUid'] as String?,
      status: d['status'] as String? ?? 'done',
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
      completedBy: d['completedBy'] as String?,
    );
  }
}
