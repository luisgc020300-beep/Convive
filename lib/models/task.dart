// lib/models/task.dart
//
// Tareas con fecha ancla: en vez de una ventana que se reinicia cada vez
// que alguien completa (el modelo viejo, que hacía imposible saber qué
// tocaría un día futuro), cada tarea tiene una fecha fija de referencia y
// una regla de recurrencia. A partir de ahí, para CUALQUIER día -- pasado,
// hoy o futuro -- se puede calcular por aritmética si esa tarea toca ese
// día y a quién le toca, sin inventar nada: es una cuenta, no una
// suposición. Esto es lo que permite que el calendario proyecte de verdad
// hacia el futuro para tareas semanales y "cada X días".
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

enum RecurrenceType { daily, weekly, everyNDays }

extension RecurrenceTypeX on RecurrenceType {
  String get wireValue => switch (this) {
        RecurrenceType.daily => 'daily',
        RecurrenceType.weekly => 'weekly',
        RecurrenceType.everyNDays => 'every_n_days',
      };

  String label(AppLocalizations l10n) => switch (this) {
        RecurrenceType.daily => l10n.recurrenceDaily,
        RecurrenceType.weekly => l10n.recurrenceWeekly,
        RecurrenceType.everyNDays => l10n.recurrenceEveryNDays,
      };

  static RecurrenceType fromWire(String? v) => switch (v) {
        'weekly' => RecurrenceType.weekly,
        'every_n_days' => RecurrenceType.everyNDays,
        _ => RecurrenceType.daily,
      };
}

/// Categoría de la tarea -- puramente informativa (icono + filtro visual),
/// no cambia ninguna lógica de asignación ni de recurrencia.
enum TaskCategory { kitchen, bathroom, livingRoom, bedroom, other }

extension TaskCategoryX on TaskCategory {
  String get wireValue => switch (this) {
        TaskCategory.kitchen => 'kitchen',
        TaskCategory.bathroom => 'bathroom',
        TaskCategory.livingRoom => 'living_room',
        TaskCategory.bedroom => 'bedroom',
        TaskCategory.other => 'other',
      };

  IconData get icon => switch (this) {
        TaskCategory.kitchen => Icons.kitchen_outlined,
        TaskCategory.bathroom => Icons.bathtub_outlined,
        TaskCategory.livingRoom => Icons.weekend_outlined,
        TaskCategory.bedroom => Icons.bed_outlined,
        TaskCategory.other => Icons.checklist_outlined,
      };

  String label(AppLocalizations l10n) => switch (this) {
        TaskCategory.kitchen => l10n.taskCategoryKitchen,
        TaskCategory.bathroom => l10n.taskCategoryBathroom,
        TaskCategory.livingRoom => l10n.taskCategoryLivingRoom,
        TaskCategory.bedroom => l10n.taskCategoryBedroom,
        TaskCategory.other => l10n.taskCategoryOther,
      };

  static TaskCategory fromWire(String? v) => switch (v) {
        'kitchen' => TaskCategory.kitchen,
        'bathroom' => TaskCategory.bathroom,
        'living_room' => TaskCategory.livingRoom,
        'bedroom' => TaskCategory.bedroom,
        _ => TaskCategory.other,
      };
}

DateTime _medianoche(DateTime d) => DateTime(d.year, d.month, d.day);

class ConviveTask {
  final String id;
  final String title;
  final TaskCategory category;
  final RecurrenceType recurrenceType;
  final int? intervalDays; // solo everyNDays
  final int? dayOfWeek; // solo weekly -- 1=lunes .. 7=domingo (DateTime.weekday)
  final DateTime anchorDate; // fecha fija de referencia para toda la aritmética
  final List<String> rotationOrder;
  // Si no está vacío, la tarea NO rota -- son SIEMPRE estas personas (una
  // para "fija", dos o más para "compartida"), todos los días que toque.
  // Vacío = comportamiento de siempre (rotationOrder cíclico).
  final List<String> assigneeUids;
  final bool active;
  final String? lastCompletionDay;

  const ConviveTask({
    required this.id,
    required this.title,
    this.category = TaskCategory.other,
    required this.recurrenceType,
    this.intervalDays,
    this.dayOfWeek,
    required this.anchorDate,
    required this.rotationOrder,
    this.assigneeUids = const [],
    required this.active,
    this.lastCompletionDay,
  });

  // Mismo criterio de "qué día es hoy" (UTC) que usa la Cloud Function
  // completeTask, para que el botón se desactive con la misma regla que
  // aplica el servidor -- ver claveDia() en functions/index.js.
  bool get completadaHoy {
    final hoy = DateTime.now().toUtc();
    return lastCompletionDay == '${hoy.year}-${hoy.month}-${hoy.day}';
  }

  /// ¿Le toca a esta tarea el día [day]?
  bool ocurreEnDia(DateTime day) {
    final ancla = _medianoche(anchorDate);
    final d = _medianoche(day);
    if (d.isBefore(ancla)) return false;
    switch (recurrenceType) {
      case RecurrenceType.daily:
        return true;
      case RecurrenceType.weekly:
        return d.weekday == (dayOfWeek ?? ancla.weekday);
      case RecurrenceType.everyNDays:
        final n = (intervalDays ?? 1).clamp(1, 365);
        return d.difference(ancla).inDays % n == 0;
    }
  }

  /// A quién le toca esta tarea el día [day] -- lista vacía si ese día no
  /// le toca a la tarea. Si [assigneeUids] tiene gente fija, esa gente SIEMPRE
  /// es la respuesta (sin rotar); si no, rota por [rotationOrder] como
  /// siempre (un solo nombre).
  List<String> asignadosEnDia(DateTime day) {
    if (!ocurreEnDia(day)) return const [];
    if (assigneeUids.isNotEmpty) return assigneeUids;
    final unico = asignadoEnDia(day);
    return unico == null ? const [] : [unico];
  }

  /// Versión de un solo nombre (rotación clásica) -- se mantiene para no
  /// tocar el cálculo de rotación en sí, [asignadosEnDia] es la que debe
  /// usar la UI de aquí en adelante.
  String? asignadoEnDia(DateTime day) {
    if (rotationOrder.isEmpty || !ocurreEnDia(day)) return null;
    final ancla = _medianoche(anchorDate);
    final d = _medianoche(day);
    final dias = d.difference(ancla).inDays;
    final int ocurrencia;
    switch (recurrenceType) {
      case RecurrenceType.daily:
        ocurrencia = dias;
      case RecurrenceType.weekly:
        ocurrencia = (dias / 7).round();
      case RecurrenceType.everyNDays:
        final n = (intervalDays ?? 1).clamp(1, 365);
        ocurrencia = dias ~/ n;
    }
    return rotationOrder[ocurrencia % rotationOrder.length];
  }

  factory ConviveTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final recurrence = (d['recurrence'] as Map<String, dynamic>?) ?? {};
    // Fallback para tareas creadas antes del sistema de ancla -- no debería
    // hacer falta para tareas nuevas, pero evita que una tarea antigua sin
    // anchorDate reviente al leerla.
    final anchor = (d['anchorDate'] as Timestamp?)?.toDate() ??
        (d['currentPeriodStart'] as Timestamp?)?.toDate() ??
        (d['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    return ConviveTask(
      id: doc.id,
      title: d['title'] as String? ?? '',
      category: TaskCategoryX.fromWire(d['category'] as String?),
      recurrenceType: RecurrenceTypeX.fromWire(recurrence['type'] as String?),
      intervalDays: (recurrence['intervalDays'] as num?)?.toInt(),
      dayOfWeek: (recurrence['dayOfWeek'] as num?)?.toInt(),
      anchorDate: anchor,
      rotationOrder: (d['rotationOrder'] as List?)?.cast<String>() ?? [],
      assigneeUids: (d['assigneeUids'] as List?)?.cast<String>() ?? const [],
      active: d['active'] as bool? ?? true,
      lastCompletionDay: d['lastCompletionDay'] as String?,
    );
  }
}

class TaskCompletion {
  final String id;
  final String taskId;
  final String taskTitle;
  final List<String> assigneeUids;
  final String status; // done | missed
  final DateTime? occurrenceDate; // qué día tocaba, no cuándo se pulsó el botón
  final DateTime? completedAt; // cuándo se pulsó "Hecho" -- null si fue "missed"
  final String? completedBy;

  const TaskCompletion({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    this.assigneeUids = const [],
    required this.status,
    this.occurrenceDate,
    this.completedAt,
    this.completedBy,
  });

  factory TaskCompletion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    // Compatibilidad con historial viejo, que guardaba un solo
    // "assigneeUid" en vez de la lista.
    final lista = (d['assigneeUids'] as List?)?.cast<String>();
    final antiguo = d['assigneeUid'] as String?;
    return TaskCompletion(
      id: doc.id,
      taskId: d['taskId'] as String? ?? '',
      taskTitle: d['taskTitle'] as String? ?? '',
      assigneeUids: lista ?? (antiguo != null ? [antiguo] : const []),
      status: d['status'] as String? ?? 'done',
      occurrenceDate: (d['occurrenceDate'] as Timestamp?)?.toDate(),
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
      completedBy: d['completedBy'] as String?,
    );
  }
}
