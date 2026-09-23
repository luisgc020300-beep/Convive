// lib/models/expense.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String description;
  final double amount;
  final String paidByUid;
  final Map<String, double> splits; // uid -> cuánto le toca pagar de este gasto
  final DateTime? createdAt;

  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidByUid,
    required this.splits,
    this.createdAt,
  });

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final rawSplits = (d['splits'] as Map<String, dynamic>?) ?? {};
    return Expense(
      id: doc.id,
      description: d['description'] as String? ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      paidByUid: d['paidByUid'] as String? ?? '',
      splits: rawSplits.map((uid, v) => MapEntry(uid, (v as num).toDouble())),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Reparte [amount] a partes iguales entre [uids], repartiendo el resto de
/// céntimos de redondeo en los primeros de la lista para que la suma cuadre
/// exactamente con el total del gasto.
Map<String, double> splitEqually(double amount, List<String> uids) {
  if (uids.isEmpty) return {};
  final centavos = (amount * 100).round();
  final base = centavos ~/ uids.length;
  final resto = centavos % uids.length;
  final result = <String, double>{};
  for (var i = 0; i < uids.length; i++) {
    final extra = i < resto ? 1 : 0;
    result[uids[i]] = (base + extra) / 100;
  }
  return result;
}

/// Balance neto por persona a partir de una lista de gastos: positivo si le
/// deben dinero, negativo si debe. paidByUid se abona el total; cada uid en
/// splits se le resta lo que le tocaba de ese gasto (incluido quien pagó, si
/// también estaba en el reparto).
Map<String, double> calcularBalances(List<Expense> expenses) {
  final balances = <String, double>{};
  for (final e in expenses) {
    balances[e.paidByUid] = (balances[e.paidByUid] ?? 0) + e.amount;
    for (final entry in e.splits.entries) {
      balances[entry.key] = (balances[entry.key] ?? 0) - entry.value;
    }
  }
  return balances;
}

class Settlement {
  final String fromUid;
  final String toUid;
  final double amount;
  const Settlement({required this.fromUid, required this.toUid, required this.amount});
}

/// Simplifica los balances netos en el menor número de pagos posible
/// (algoritmo voraz: siempre empareja al mayor deudor con el mayor acreedor).
List<Settlement> simplificarDeudas(Map<String, double> balances) {
  final deudores = <MapEntry<String, double>>[];
  final acreedores = <MapEntry<String, double>>[];
  balances.forEach((uid, saldo) {
    final redondeado = (saldo * 100).round() / 100;
    if (redondeado < -0.005) deudores.add(MapEntry(uid, -redondeado));
    if (redondeado > 0.005) acreedores.add(MapEntry(uid, redondeado));
  });
  deudores.sort((a, b) => b.value.compareTo(a.value));
  acreedores.sort((a, b) => b.value.compareTo(a.value));

  final settlements = <Settlement>[];
  var i = 0, j = 0;
  while (i < deudores.length && j < acreedores.length) {
    final deuda = deudores[i];
    final credito = acreedores[j];
    final pago = deuda.value < credito.value ? deuda.value : credito.value;
    settlements.add(Settlement(fromUid: deuda.key, toUid: credito.key, amount: pago));
    deudores[i] = MapEntry(deuda.key, deuda.value - pago);
    acreedores[j] = MapEntry(credito.key, credito.value - pago);
    if (deudores[i].value < 0.005) i++;
    if (acreedores[j].value < 0.005) j++;
  }
  return settlements;
}
