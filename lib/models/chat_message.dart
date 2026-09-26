// lib/models/chat_message.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String text;
  final String authorUid;
  final DateTime? createdAt;
  // Mensajes de sistema (feed de actividad: tarea completada, gasto/nota/
  // recordatorio nuevos) no tienen autor humano -- se identifican por
  // [type] == 'system' y se renderizan distinto (sin burbuja), con el texto
  // localizado en el cliente a partir de [event]/[eventData], nunca en
  // español fijo desde el servidor.
  final String? type;
  final String? event;
  final Map<String, dynamic>? eventData;
  final Map<String, List<String>> reactions;

  bool get esDeSistema => type == 'system';

  const ChatMessage({
    required this.id,
    required this.text,
    required this.authorUid,
    this.createdAt,
    this.type,
    this.event,
    this.eventData,
    this.reactions = const {},
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final reactionsRaw = d['reactions'] as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: doc.id,
      text: d['text'] as String? ?? '',
      authorUid: d['authorUid'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      type: d['type'] as String?,
      event: d['event'] as String?,
      eventData: (d['eventData'] as Map?)?.cast<String, dynamic>(),
      reactions: reactionsRaw.map(
        (k, v) => MapEntry(k, (v as List).cast<String>()),
      ),
    );
  }
}
