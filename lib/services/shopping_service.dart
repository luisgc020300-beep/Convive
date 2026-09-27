// lib/services/shopping_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/shopping_item.dart';

class ShoppingService {
  static final _db = FirebaseFirestore.instance;

  static Stream<List<ShoppingItem>> streamItems(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('shoppingItems')
        .orderBy('createdAt')
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(ShoppingItem.fromDoc).toList());
  }

  /// [paraUid] es para quién es -- null significa "para todo el piso".
  static Future<void> addItem(String householdId, String text, {String? paraUid}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('households')
        .doc(householdId)
        .collection('shoppingItems')
        .add({
      'text': text.trim(),
      'authorUid': uid,
      'paraUid': paraUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marcar como comprada es lo mismo que borrarla -- es una lista de
  /// pendientes, no un historial (ese papel ya lo hace Pagos). Cualquiera
  /// del piso puede hacerlo, no solo quien la apuntó -- es de todos.
  static Future<void> deleteItem(String householdId, String itemId) async {
    await _db
        .collection('households')
        .doc(householdId)
        .collection('shoppingItems')
        .doc(itemId)
        .delete();
  }
}
