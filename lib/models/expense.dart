// lib/models/expense.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory { comida, luz, agua, gas, internet, limpieza, casa, ocio, otros }

extension ExpenseCategoryX on ExpenseCategory {
  String get wireValue => switch (this) {
        ExpenseCategory.comida => 'comida',
        ExpenseCategory.luz => 'luz',
        ExpenseCategory.agua => 'agua',
        ExpenseCategory.gas => 'gas',
        ExpenseCategory.internet => 'internet',
        ExpenseCategory.limpieza => 'limpieza',
        ExpenseCategory.casa => 'casa',
        ExpenseCategory.ocio => 'ocio',
        ExpenseCategory.otros => 'otros',
      };

  String get label => switch (this) {
        ExpenseCategory.comida => 'Comida',
        ExpenseCategory.luz => 'Luz',
        ExpenseCategory.agua => 'Agua',
        ExpenseCategory.gas => 'Gas',
        ExpenseCategory.internet => 'Internet',
        ExpenseCategory.limpieza => 'Limpieza',
        ExpenseCategory.casa => 'Casa',
        ExpenseCategory.ocio => 'Ocio',
        ExpenseCategory.otros => 'Otros',
      };

  IconData get icon => switch (this) {
        ExpenseCategory.comida => Icons.local_grocery_store_outlined,
        ExpenseCategory.luz => Icons.lightbulb_outline,
        ExpenseCategory.agua => Icons.water_drop_outlined,
        ExpenseCategory.gas => Icons.local_fire_department_outlined,
        ExpenseCategory.internet => Icons.wifi,
        ExpenseCategory.limpieza => Icons.cleaning_services_outlined,
        ExpenseCategory.casa => Icons.shopping_bag_outlined,
        ExpenseCategory.ocio => Icons.celebration_outlined,
        ExpenseCategory.otros => Icons.more_horiz,
      };

  // Fallback a "otros" si algún día se quita/renombra una categoría y queda
  // un gasto antiguo con una clave que ya no existe -- nunca debe reventar.
  static ExpenseCategory fromWire(String? v) => switch (v) {
        'comida' => ExpenseCategory.comida,
        'luz' => ExpenseCategory.luz,
        'agua' => ExpenseCategory.agua,
        'gas' => ExpenseCategory.gas,
        'internet' => ExpenseCategory.internet,
        'limpieza' => ExpenseCategory.limpieza,
        'casa' => ExpenseCategory.casa,
        'ocio' => ExpenseCategory.ocio,
        _ => ExpenseCategory.otros,
      };
}

class Expense {
  final String id;
  final String description;
  final double amount;
  final String paidByUid;
  final Map<String, double> splits; // uid -> cuánto le toca pagar de este gasto
  final ExpenseCategory category;
  final DateTime? createdAt;

  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidByUid,
    required this.splits,
    required this.category,
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
      category: ExpenseCategoryX.fromWire(d['category'] as String?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Total gastado por categoría en un mes concreto (por defecto, el mes
/// actual) -- puro cálculo sobre lo que ya se sincroniza al cliente, sin
/// query nueva. Listo para cuando se quiera mostrar un resumen mensual.
Map<ExpenseCategory, double> gastosPorCategoria(List<Expense> expenses, {DateTime? mes}) {
  final ref = mes ?? DateTime.now();
  final totales = <ExpenseCategory, double>{};
  for (final e in expenses) {
    final fecha = e.createdAt;
    if (fecha == null || fecha.year != ref.year || fecha.month != ref.month) continue;
    totales[e.category] = (totales[e.category] ?? 0) + e.amount;
  }
  return totales;
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
