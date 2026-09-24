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
    // Se ordena por occurrenceDate (qué día tocaba), no por completedAt --
    // ese campo es null en los registros "missed", así que ordenar por él
    // los empujaría siempre al final o los dejaría fuera del limit.
    return _db
        .collection('households')
        .doc(householdId)
        .collection('completions')
        .orderBy('occurrenceDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(TaskCompletion.fromDoc).toList());
  }

  /// Crea una tarea recurrente anclada a [anchorDate] -- normalmente el día
  /// que el usuario tenía seleccionado en el calendario. La rotación
  /// empieza por el primer miembro de [rotationOrder].
  static Future<void> createTask({
    required String householdId,
    required String title,
    required RecurrenceType recurrenceType,
    required DateTime anchorDate,
    int? intervalDays,
    int? dayOfWeek,
    required List<String> rotationOrder,
  }) async {
    if (rotationOrder.isEmpty) {
      throw ArgumentError('Un piso sin miembros no puede tener tareas.');
    }
    await _db
        .collection('households')
        .doc(householdId)
        .collection('tasks')
        .add({
      'title': title,
      'recurrence': {
        'type': recurrenceType.wireValue,
        'intervalDays': ?intervalDays,
        'dayOfWeek': ?dayOfWeek,
      },
      'anchorDate': Timestamp.fromDate(anchorDate),
      'rotationOrder': rotationOrder,
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

  static Future<void> deleteTask({
    required String householdId,
    required String taskId,
  }) async {
    await _db
        .collection('households')
        .doc(householdId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }
}
