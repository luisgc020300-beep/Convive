// lib/services/note_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/note.dart';

class NoteService {
  static final _db = FirebaseFirestore.instance;

  static Stream<List<ConviveNote>> streamNotes(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(ConviveNote.fromDoc).toList());
  }

  static Future<void> postNote(String householdId, String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('households')
        .doc(householdId)
        .collection('notes')
        .add({
      'text': text.trim(),
      'authorUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteNote(String householdId, String noteId) async {
    await _db
        .collection('households')
        .doc(householdId)
        .collection('notes')
        .doc(noteId)
        .delete();
  }
}
