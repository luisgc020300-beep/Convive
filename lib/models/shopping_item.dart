// lib/models/shopping_item.dart
//
// Lista de la compra compartida -- de todos, no de quien la apunta. Sin
// asignación ni rotación (a diferencia de las tareas): cualquiera añade,
// cualquiera la compra y la quita. Marcar como comprada la borra --
// no hace falta un historial de "comprado", es una lista de pendientes,
// no un registro (ese papel ya lo hace Pagos).
import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingItem {
  final String id;
  final String text;
  final String authorUid;
  // Para quién es -- normalmente quien lo apunta (por defecto, ver
  // ShoppingService.addItem), pero puede ser otra persona (p.ej. "cómprame
  // esto") o null si es un ítem de todo el piso, no de una persona
  // concreta. Determina el reparto por defecto al pasarlo a Pagos.
  final String? paraUid;
  final DateTime? createdAt;

  const ShoppingItem({
    required this.id,
    required this.text,
    required this.authorUid,
    this.paraUid,
    this.createdAt,
  });

  factory ShoppingItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ShoppingItem(
      id: doc.id,
      text: d['text'] as String? ?? '',
      authorUid: d['authorUid'] as String? ?? '',
      paraUid: d['paraUid'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
