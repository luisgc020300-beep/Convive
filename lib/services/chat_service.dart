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
}
