// lib/models/reminder.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentReminder {
  final String id;
  final String title;
  final bool recurring;
  final DateTime? dueDate; // usado si !recurring
  final int? dueDay; // día del mes (1-31), usado si recurring
  final String createdBy;

  const PaymentReminder({
    required this.id,
    required this.title,
    required this.recurring,
    this.dueDate,
    this.dueDay,
    required this.createdBy,
  });

  factory PaymentReminder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PaymentReminder(
      id: doc.id,
      title: d['title'] as String? ?? '',
      recurring: d['recurring'] as bool? ?? false,
      dueDate: (d['dueDate'] as Timestamp?)?.toDate(),
      dueDay: (d['dueDay'] as num?)?.toInt(),
      createdBy: d['createdBy'] as String? ?? '',
    );
  }

  /// Próxima fecha de vencimiento: la fecha fija si es un recordatorio
  /// puntual, o el próximo día [dueDay] del mes (este mes si no ha pasado
  /// todavía, si no el que viene) si es recurrente.
  DateTime nextOccurrence() {
    if (!recurring) return dueDate ?? DateTime.now();
    final now = DateTime.now();
    final dia = (dueDay ?? 1).clamp(1, 28);
    final esteMovil = DateTime(now.year, now.month, dia);
    if (!esteMovil.isBefore(DateTime(now.year, now.month, now.day))) {
      return esteMovil;
    }
    final siguienteMes = DateTime(now.year, now.month + 1, dia);
    return siguienteMes;
  }
}
