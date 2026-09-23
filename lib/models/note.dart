// lib/models/note.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ConviveNote {
  final String id;
  final String text;
  final String authorUid;
  final DateTime? createdAt;

  const ConviveNote({
    required this.id,
    required this.text,
    required this.authorUid,
    this.createdAt,
  });

  factory ConviveNote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ConviveNote(
      id: doc.id,
      text: d['text'] as String? ?? '',
      authorUid: d['authorUid'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
