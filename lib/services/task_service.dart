// lib/services/task_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/task.dart';

class TaskService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  static Stream<List<ConviveTask>> streamTasks(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('tasks')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(ConviveTask.fromDoc).toList());
  }

  static Stream<List<TaskCompletion>> streamHistory(
    String householdId, {
    int limit = 50,
  }) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('completions')
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(TaskCompletion.fromDoc).toList());
  }

  /// Crea una tarea recurrente. La rotación empieza por el primer miembro
  /// de [rotationOrder] — normalmente los miembros actuales del piso.
  static Future<void> createTask({
    required String householdId,
    required String title,
    required RecurrenceType recurrenceType,
    int? intervalDays,
    required List<String> rotationOrder,
  }) async {
    if (rotationOrder.isEmpty) {
      throw ArgumentError('Un piso sin miembros no puede tener tareas.');
    }
    final ahora = DateTime.now();
    final duracion = recurrenceType.periodDuration(intervalDays: intervalDays);
    await _db
        .collection('households')
        .doc(householdId)
        .collection('tasks')
        .add({
      'title': title,
      'recurrence': {
        'type': recurrenceType.wireValue,
        'intervalDays': ?intervalDays,
      },
      'rotationOrder': rotationOrder,
      'rotationIndex': 0,
      'currentAssigneeUid': rotationOrder.first,
      'currentPeriodStart': Timestamp.fromDate(ahora),
      'currentPeriodEnd': Timestamp.fromDate(ahora.add(duracion)),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> completeTask({
    required String householdId,
    required String taskId,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region)
        .httpsCallable('completeTask');
    await callable.call<Map<String, dynamic>>({
      'householdId': householdId,
      'taskId': taskId,
    });
  }
}
