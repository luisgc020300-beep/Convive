// lib/services/expense_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/expense.dart';

class ExpenseService {
  static final _db = FirebaseFirestore.instance;

  static Stream<List<Expense>> streamExpenses(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map(Expense.fromDoc).toList());
  }

  /// Gastos de un mes concreto, pedidos directos a Firestore (no de la caché
  /// de los 200 más recientes) -- para un piso con mucho historial, un mes
  /// antiguo podría quedar fuera de esos 200 y salir un total incorrecto.
  static Stream<List<Expense>> streamExpensesForMonth(String householdId, DateTime mes) {
    final inicio = DateTime(mes.year, mes.month);
    final fin = DateTime(mes.year, mes.month + 1);
    return _db
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('createdAt', isLessThan: Timestamp.fromDate(fin))
        .snapshots()
        .map((snap) => snap.docs.map(Expense.fromDoc).toList());
  }

  static Future<void> addExpense({
    required String householdId,
    required String description,
    required double amount,
    required String paidByUid,
    required Map<String, double> splits,
    ExpenseCategory category = ExpenseCategory.otros,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .add({
      'description': description.trim(),
      'amount': amount,
      'paidByUid': paidByUid,
      'splits': splits,
      'category': category.wireValue,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteExpense(String householdId, String expenseId) async {
    await _db
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }
}
