// lib/services/reminder_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/reminder.dart';

class ReminderService {
  static final _db = FirebaseFirestore.instance;

  static Stream<List<PaymentReminder>> streamReminders(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('reminders')
        .snapshots()
        .map((snap) => snap.docs.map(PaymentReminder.fromDoc).toList());
  }

  static Future<void> addReminder({
    required String householdId,
    required String title,
    required bool recurring,
    DateTime? dueDate,
    int? dueDay,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('households')
        .doc(householdId)
        .collection('reminders')
        .add({
      'title': title.trim(),
      'recurring': recurring,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'dueDay': dueDay,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteReminder(String householdId, String reminderId) async {
    await _db
        .collection('households')
        .doc(householdId)
        .collection('reminders')
        .doc(reminderId)
        .delete();
  }
}
