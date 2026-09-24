// lib/screens/payments_tab.dart
//
// Pestaña "Pagos" como un libro de cuentas: balance propio destacado,
// movimientos como líneas de recibo (divisor punteado, importes en mono)
// más recordatorios de pago simples (únicos o recurrentes cada mes).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../models/household.dart';
import '../models/reminder.dart';
import '../services/expense_service.dart';
import '../services/reminder_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/convive_sheet.dart';
import '../widgets/dashed_divider.dart';
import 'expenses_summary_screen.dart';

const _mesesPagos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _formatearFecha(DateTime d) => '${d.day} ${_mesesPagos[d.month - 1]}';

class PaymentsTab extends StatelessWidget {
  const PaymentsTab({required this.household, super.key});

  final Household household;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gastos comunes', style: Theme.of(context).textTheme.titleLarge),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.bar_chart_rounded, color: ConviveColors.mint, size: 20),
                  tooltip: 'Resumen de gastos',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ExpensesSummaryScreen(household: household)),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _mostrarNuevoGasto(context, household),
                  icon: const Icon(Icons.add, color: ConviveColors.mint),
                  label: const Text('Nuevo', style: TextStyle(color: ConviveColors.mint)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ExpensesSection(household: household),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recordatorios de pago', style: Theme.of(context).textTheme.titleLarge),
            TextButton.icon(
              onPressed: () => _mostrarNuevoRecordatorio(context, household),
              icon: const Icon(Icons.add, color: ConviveColors.mint),
              label: const Text('Nuevo', style: TextStyle(color: ConviveColors.mint)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _RemindersSection(household: household),
      ],
    );
  }

  Future<void> _mostrarNuevoGasto(BuildContext context, Household household) async {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String paidByUid = FirebaseAuth.instance.currentUser?.uid ?? household.members.first;
    final incluidos = {...household.members};
    ExpenseCategory categoria = ExpenseCategory.otros;

    await showConviveSheet<void>(
      context: context,
      title: 'Nuevo gasto',
      builder: (ctx, setState) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(hintText: 'Ej: Productos del baño'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ExpenseCategory.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final cat = ExpenseCategory.values[i];
                  final seleccionada = cat == categoria;
                  return ChoiceChip(
                    selected: seleccionada,
                    onSelected: (_) => setState(() => categoria = cat),
                    avatar: Icon(cat.icon, size: 15,
                        color: seleccionada ? const Color(0xFF0B2116) : ConviveColors.paperMuted),
                    label: Text(cat.label),
                    labelStyle: TextStyle(
                        fontSize: 12.5, color: seleccionada ? const Color(0xFF0B2116) : ConviveColors.paper),
                    selectedColor: ConviveColors.mint,
                    backgroundColor: ConviveColors.corkDark,
                    side: BorderSide.none,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'Importe total (€)'),
              style: ConviveText.amount(fontSize: 16, color: ConviveColors.paper),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: paidByUid,
              decoration: const InputDecoration(labelText: '¿Quién pagó?'),
              dropdownColor: ConviveColors.cork,
              items: household.members
                  .map((uid) => DropdownMenuItem(
                        value: uid,
                        child: Text(household.memberProfiles[uid]?.displayName ?? 'Runner'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => paidByUid = v ?? paidByUid),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Repartir entre:', style: TextStyle(color: ConviveColors.paperMuted, fontSize: 13)),
            ),
            ...household.members.map((uid) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: ConviveColors.mint,
                  value: incluidos.contains(uid),
                  title: Text(household.memberProfiles[uid]?.displayName ?? 'Runner'),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      incluidos.add(uid);
                    } else {
                      incluidos.remove(uid);
                    }
                  }),
                )),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ConviveColors.mint, foregroundColor: const Color(0xFF0B2116)),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                if (descCtrl.text.trim().isEmpty || amount == null || amount <= 0 || incluidos.isEmpty) {
                  return;
                }
                final splits = splitEqually(amount, incluidos.toList());
                await ExpenseService.addExpense(
                  householdId: household.id,
                  description: descCtrl.text.trim(),
                  amount: amount,
                  paidByUid: paidByUid,
                  splits: splits,
                  category: categoria,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarNuevoRecordatorio(BuildContext context, Household household) async {
    final titleCtrl = TextEditingController();
    bool recurrente = true;
    int dueDay = 1;
    DateTime dueDate = DateTime.now().add(const Duration(days: 1));

    await showConviveSheet<void>(
      context: context,
      title: 'Nuevo recordatorio',
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(hintText: 'Ej: Pagar el agua'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: ConviveColors.mint,
            value: recurrente,
            title: const Text('Se repite cada mes'),
            onChanged: (v) => setState(() => recurrente = v),
          ),
          if (recurrente)
            DropdownButtonFormField<int>(
              initialValue: dueDay,
              decoration: const InputDecoration(labelText: 'Día del mes'),
              dropdownColor: ConviveColors.cork,
              items: List.generate(28, (i) => i + 1)
                  .map((d) => DropdownMenuItem(value: d, child: Text('Día $d')))
                  .toList(),
              onChanged: (v) => setState(() => dueDay = v ?? dueDay),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Fecha: ${_formatearFecha(dueDate)}'),
              trailing: const Icon(Icons.calendar_today, size: 18, color: ConviveColors.mint),
              onTap: () async {
                final elegida = await showDatePicker(
                  context: ctx,
                  initialDate: dueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (elegida != null) setState(() => dueDate = elegida);
              },
            ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ConviveColors.mint, foregroundColor: const Color(0xFF0B2116)),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              await ReminderService.addReminder(
                householdId: household.id,
                title: titleCtrl.text.trim(),
                recurring: recurrente,
                dueDate: recurrente ? null : dueDate,
                dueDay: recurrente ? dueDay : null,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }
}

class _ExpensesSection extends StatelessWidget {
  const _ExpensesSection({required this.household});

  final Household household;

  String _nombre(String uid) => household.memberProfiles[uid]?.displayName ?? 'Alguien';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Expense>>(
      stream: ExpenseService.streamExpenses(household.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final expenses = snapshot.data ?? [];
        if (expenses.isEmpty) {
          return Text(
            'Todavía no hay gastos comunes registrados.',
            style: TextStyle(color: ConviveColors.paperMuted),
          );
        }
        final balances = calcularBalances(expenses);
        final settlements = simplificarDeudas(balances);
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        final miBalance = balances[myUid] ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BalanceCard(balance: miBalance),
            if (settlements.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ConviveColors.cork,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < settlements.length; i++) ...[
                      if (i > 0) const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: DashedDivider(),
                      ),
                      Text(
                        '${_nombre(settlements[i].fromUid)} le debe a ${_nombre(settlements[i].toUid)}',
                        style: const TextStyle(fontSize: 13, color: ConviveColors.paper),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('${settlements[i].amount.toStringAsFixed(2)}€', style: ConviveText.amount(fontSize: 15, color: ConviveColors.mint)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: ConviveColors.cork,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < expenses.length; i++) ...[
                    if (i > 0) const DashedDivider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(expenses[i].category.icon, size: 17, color: ConviveColors.paperMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(expenses[i].description, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('pagó ${_nombre(expenses[i].paidByUid)}',
                                    style: TextStyle(fontSize: 11.5, color: ConviveColors.paperMuted)),
                              ],
                            ),
                          ),
                          Text('${expenses[i].amount.toStringAsFixed(2)}€', style: ConviveText.amount(fontSize: 15)),
                          if (expenses[i].paidByUid == myUid)
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: ConviveColors.paperMuted),
                              onPressed: () => ExpenseService.deleteExpense(household.id, expenses[i].id),
                            )
                          else
                            const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    final cuadrado = balance.abs() < 0.005;
    final positivo = balance > 0;
    final color = cuadrado ? ConviveColors.paperMuted : (positivo ? ConviveColors.mint : ConviveColors.rust);
    final etiqueta = cuadrado ? 'Estás en paz' : (positivo ? 'te deben' : 'debes');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text('TU BALANCE', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: ConviveColors.paperMuted)),
          const SizedBox(height: 4),
          Text(
            cuadrado ? '0.00€' : '${positivo ? '+' : ''}${balance.toStringAsFixed(2)}€',
            style: ConviveText.amount(fontSize: 30, weight: FontWeight.w700, color: color),
          ),
          Text(etiqueta, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _RemindersSection extends StatelessWidget {
  const _RemindersSection({required this.household});

  final Household household;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentReminder>>(
      stream: ReminderService.streamReminders(household.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final reminders = [...(snapshot.data ?? [])]
          ..sort((a, b) => a.nextOccurrence().compareTo(b.nextOccurrence()));
        if (reminders.isEmpty) {
          return Text('Sin recordatorios de pago.', style: TextStyle(color: ConviveColors.paperMuted));
        }
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: ConviveColors.cork,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (var i = 0; i < reminders.length; i++) ...[
                if (i > 0) const DashedDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: ConviveColors.mint.withValues(alpha: 0.18), shape: BoxShape.circle),
                        child: const Icon(Icons.event_repeat_outlined, size: 17, color: ConviveColors.mint),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reminders[i].title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              reminders[i].recurring
                                  ? '${_formatearFecha(reminders[i].nextOccurrence())} · cada mes'
                                  : _formatearFecha(reminders[i].nextOccurrence()),
                              style: TextStyle(fontSize: 12, color: ConviveColors.paperMuted),
                            ),
                          ],
                        ),
                      ),
                      if (reminders[i].createdBy == myUid)
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: ConviveColors.paperMuted),
                          onPressed: () => ReminderService.deleteReminder(household.id, reminders[i].id),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
