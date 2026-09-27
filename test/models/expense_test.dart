// test/models/expense_test.dart
//
// Reparto de gastos y simplificación de deudas -- dinero real entre
// compañeros de piso, así que cualquier error de redondeo o de balance
// aquí es justo el tipo de bug que la investigación de reseñas de la
// competencia señala como el que más rencor genera (Tricount, Splitwise).
import 'package:flutter_test/flutter_test.dart';
import 'package:convive/models/expense.dart';

Expense _gasto({
  required double amount,
  required String paidByUid,
  required Map<String, double> splits,
  ExpenseCategory category = ExpenseCategory.otros,
  DateTime? createdAt,
  bool isSettlement = false,
}) {
  return Expense(
    id: 'e1',
    description: 'Test',
    amount: amount,
    paidByUid: paidByUid,
    splits: splits,
    category: category,
    createdAt: createdAt,
    isSettlement: isSettlement,
  );
}

void main() {
  group('ExpenseCategory wire round trip', () {
    test('cada valor sobrevive ida y vuelta', () {
      for (final cat in ExpenseCategory.values) {
        expect(ExpenseCategoryX.fromWire(cat.wireValue), cat);
      }
    });

    test('un valor desconocido cae en otros, no revienta', () {
      expect(ExpenseCategoryX.fromWire('inventado'), ExpenseCategory.otros);
      expect(ExpenseCategoryX.fromWire(null), ExpenseCategory.otros);
    });
  });

  group('splitEqually', () {
    test('reparto exacto entre 2 personas', () {
      final r = splitEqually(20.0, ['a', 'b']);
      expect(r['a'], 10.0);
      expect(r['b'], 10.0);
    });

    test('el resto de céntimos de redondeo cuadra con el total exacto', () {
      // 10€ entre 3 personas = 3.33, 3.33, 3.34 -- nunca se puede perder ni
      // un céntimo del total real.
      final r = splitEqually(10.0, ['a', 'b', 'c']);
      final suma = r.values.fold<double>(0, (acc, v) => acc + v);
      expect((suma * 100).round(), 1000);
      expect(r.values.where((v) => v == 3.34).length, 1); // uno se lleva el céntimo de más
      expect(r.values.where((v) => v == 3.33).length, 2);
    });

    test('lista vacía no revienta', () {
      expect(splitEqually(50.0, []), isEmpty);
    });
  });

  group('calcularBalances', () {
    test('quien paga se abona el total, cada uid en splits se resta lo suyo', () {
      final gastos = [
        _gasto(amount: 30.0, paidByUid: 'a', splits: {'a': 15.0, 'b': 15.0}),
      ];
      final balances = calcularBalances(gastos);
      // "a" pagó 30, le tocaban 15 -> +15 (le deben 15)
      expect(balances['a'], 15.0);
      // "b" no pagó nada, le tocaban 15 -> -15 (debe 15)
      expect(balances['b'], -15.0);
    });

    test('un settlement cancela la deuda entre quien debía y quien cobró', () {
      // a debía 20 a b; a "paga" 20 que se reparten enteros a b -- misma
      // aritmética que un gasto normal, pero deja a los dos en 0.
      final gastos = [
        _gasto(amount: 30.0, paidByUid: 'b', splits: {'a': 20.0, 'b': 10.0}),
        _gasto(amount: 20.0, paidByUid: 'a', splits: {'b': 20.0}, isSettlement: true),
      ];
      final balances = calcularBalances(gastos);
      expect(balances['a'], 0.0);
      expect(balances['b'], 0.0);
    });

    test('varios gastos se acumulan', () {
      final gastos = [
        _gasto(amount: 20.0, paidByUid: 'a', splits: {'a': 10.0, 'b': 10.0}),
        _gasto(amount: 10.0, paidByUid: 'b', splits: {'a': 5.0, 'b': 5.0}),
      ];
      final balances = calcularBalances(gastos);
      // a: +20 (pagó) -10 (gasto 1) -5 (gasto 2) = +5
      expect(balances['a'], 5.0);
      // b: +10 (pagó) -10 (gasto 1) -5 (gasto 2) = -5
      expect(balances['b'], -5.0);
    });
  });

  group('simplificarDeudas', () {
    test('un deudor y un acreedor -> un único pago', () {
      final settlements = simplificarDeudas({'a': -20.0, 'b': 20.0});
      expect(settlements.length, 1);
      expect(settlements.first.fromUid, 'a');
      expect(settlements.first.toUid, 'b');
      expect(settlements.first.amount, 20.0);
    });

    test('saldo en paz no genera ningún pago', () {
      expect(simplificarDeudas({'a': 0.0, 'b': 0.0}), isEmpty);
      expect(simplificarDeudas({'a': 0.001, 'b': -0.001}), isEmpty); // ruido de redondeo
    });

    test('reduce al mínimo número de pagos posible (voraz)', () {
      // a debe 10, b debe 5, c le deben 15 -- en vez de dos pagos sueltos
      // sin optimizar, empareja al mayor deudor con el único acreedor.
      final settlements = simplificarDeudas({'a': -10.0, 'b': -5.0, 'c': 15.0});
      expect(settlements.length, 2);
      final total = settlements.fold<double>(0, (acc, s) => acc + s.amount);
      expect(total, 15.0);
      expect(settlements.every((s) => s.toUid == 'c'), isTrue);
    });
  });

  group('gastosPorCategoria', () {
    test('solo suma gastos del mes de referencia', () {
      final gastos = [
        _gasto(amount: 10.0, paidByUid: 'a', splits: {}, category: ExpenseCategory.comida, createdAt: DateTime(2026, 3, 15)),
        _gasto(amount: 5.0, paidByUid: 'a', splits: {}, category: ExpenseCategory.comida, createdAt: DateTime(2026, 2, 15)),
      ];
      final totales = gastosPorCategoria(gastos, mes: DateTime(2026, 3, 1));
      expect(totales[ExpenseCategory.comida], 10.0);
    });

    test('sin createdAt no cuenta para ningún mes', () {
      final gastos = [_gasto(amount: 10.0, paidByUid: 'a', splits: {})];
      final totales = gastosPorCategoria(gastos, mes: DateTime(2026, 3, 1));
      expect(totales, isEmpty);
    });

    test('un settlement no cuenta como gasto real aunque sea del mes', () {
      final gastos = [
        _gasto(
          amount: 20.0,
          paidByUid: 'a',
          splits: {'b': 20.0},
          category: ExpenseCategory.otros,
          createdAt: DateTime(2026, 3, 10),
          isSettlement: true,
        ),
      ];
      final totales = gastosPorCategoria(gastos, mes: DateTime(2026, 3, 1));
      expect(totales, isEmpty);
    });
  });
}
