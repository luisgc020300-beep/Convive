// lib/services/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message.dart';

class ChatService {
  static final _db = FirebaseFirestore.instance;

  static Stream<List<ChatMessage>> streamMessages(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }

  static Future<void> sendMessage(String householdId, String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('households')
        .doc(householdId)
        .collection('messages')
        .add({
      'text': text.trim(),
      'authorUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteMessage(String householdId, String messageId) async {
    await _db
        .collection('households')
        .doc(householdId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  /// Como máximo una reacción por persona y mensaje (igual que WhatsApp/
  /// iMessage) -- tocar el mismo emoji que ya tenías puesto lo quita; tocar
  /// otro te lo cambia. Transacción porque hay que leer qué emoji tenías
  /// antes de decidir qué quitar y qué añadir.
  static Future<void> setReaction(String householdId, String messageId, String emoji) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = _db
        .collection('households')
        .doc(householdId)
        .collection('messages')
        .doc(messageId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final reactions = (snap.data()?['reactions'] as Map<String, dynamic>?) ?? {};
      String? actual;
      for (final entry in reactions.entries) {
        if ((entry.value as List).contains(uid)) {
          actual = entry.key;
          break;
        }
      }
      final updates = <String, dynamic>{};
      if (actual != null) {
        updates['reactions.$actual'] = FieldValue.arrayRemove([uid]);
      }
      if (actual != emoji) {
        updates['reactions.$emoji'] = FieldValue.arrayUnion([uid]);
      }
      tx.set(ref, updates, SetOptions(merge: true));
    });
  }
}
