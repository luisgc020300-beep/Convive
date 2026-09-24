// lib/screens/expenses_summary_screen.dart
//
// Resumen de gastos por categoría, mes a mes. Pantalla propia (no dentro
// del scroll de Pagos) para no sobrecargar esa pestaña -- se entra a
// propósito, no se pasa por encima sin querer.
import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../models/household.dart';
import '../services/expense_service.dart';
import '../theme/design_tokens.dart';

const _mesesNombres = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

class ExpensesSummaryScreen extends StatefulWidget {
  const ExpensesSummaryScreen({required this.household, super.key});

  final Household household;

  @override
  State<ExpensesSummaryScreen> createState() => _ExpensesSummaryScreenState();
}

class _ExpensesSummaryScreenState extends State<ExpensesSummaryScreen> {
  late DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen de gastos')),
      body: StreamBuilder<List<Expense>>(
        stream: ExpenseService.streamExpensesForMonth(widget.household.id, _mes),
        builder: (context, snapshot) {
          final gastos = snapshot.data ?? [];
          final totales = gastosPorCategoria(gastos, mes: _mes);
          final total = totales.values.fold<double>(0, (a, b) => a + b);
          final categoriasOrdenadas = totales.keys.toList()
            ..sort((a, b) => totales[b]!.compareTo(totales[a]!));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _mes = DateTime(_mes.year, _mes.month - 1)),
                  ),
                  Text(
                    '${_mesesNombres[_mes.month - 1]} ${_mes.year}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => _mes = DateTime(_mes.year, _mes.month + 1)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (gastos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Sin gastos ese mes.', style: TextStyle(color: ConviveColors.paperMuted)),
                )
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: ConviveColors.mint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ConviveColors.mint.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      const Text('TOTAL DEL PISO',
                          style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: ConviveColors.paperMuted)),
                      const SizedBox(height: 4),
                      Text('${total.toStringAsFixed(2)}€',
                          style: ConviveText.amount(fontSize: 30, weight: FontWeight.w700, color: ConviveColors.mint)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...categoriasOrdenadas.map((cat) {
                  final importe = totales[cat]!;
                  final proporcion = total > 0 ? importe / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(cat.icon, size: 16, color: ConviveColors.paperMuted),
                            const SizedBox(width: 8),
                            Expanded(child: Text(cat.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                            Text('${(proporcion * 100).round()}%',
                                style: TextStyle(fontSize: 12, color: ConviveColors.paperMuted)),
                            const SizedBox(width: 8),
                            Text('${importe.toStringAsFixed(2)}€', style: ConviveText.amount(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: proporcion,
                            minHeight: 5,
                            backgroundColor: ConviveColors.corkDark,
                            valueColor: const AlwaysStoppedAnimation(ConviveColors.mint),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}
