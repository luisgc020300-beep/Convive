// lib/screens/payments_tab.dart
//
// Pestaña "Pagos": gastos comunes repartidos estilo Tricount (reparto igual
// entre los miembros incluidos, simplificado a "quién le debe a quién") más
// recordatorios de pago simples (únicos o recurrentes cada mes).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../models/household.dart';
import '../models/reminder.dart';
import '../services/expense_service.dart';
import '../services/reminder_service.dart';

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
            TextButton.icon(
              onPressed: () => _mostrarNuevoGasto(context, household),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
            ),
          ],
        ),
        _ExpensesSection(household: household),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recordatorios de pago', style: Theme.of(context).textTheme.titleLarge),
            TextButton.icon(
              onPressed: () => _mostrarNuevoRecordatorio(context, household),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
            ),
          ],
        ),
        _RemindersSection(household: household),
      ],
    );
  }

  Future<void> _mostrarNuevoGasto(BuildContext context, Household household) async {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String paidByUid = FirebaseAuth.instance.currentUser?.uid ?? household.members.first;
    final incluidos = {...household.members};

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nuevo gasto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Ej: Productos del baño'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Importe total (€)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paidByUid,
                  decoration: const InputDecoration(labelText: '¿Quién pagó?'),
                  items: household.members
                      .map((uid) => DropdownMenuItem(
                            value: uid,
                            child: Text(household.memberProfiles[uid]?.displayName ?? 'Runner'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => paidByUid = v ?? paidByUid),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Repartir entre:', style: Theme.of(ctx).textTheme.labelLarge),
                ),
                ...household.members.map((uid) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
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
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
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

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nuevo recordatorio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Ej: Pagar el agua'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: recurrente,
                title: const Text('Se repite cada mes'),
                onChanged: (v) => setState(() => recurrente = v),
              ),
              if (recurrente)
                DropdownButtonFormField<int>(
                  initialValue: dueDay,
                  decoration: const InputDecoration(labelText: 'Día del mes'),
                  items: List.generate(28, (i) => i + 1)
                      .map((d) => DropdownMenuItem(value: d, child: Text('Día $d')))
                      .toList(),
                  onChanged: (v) => setState(() => dueDay = v ?? dueDay),
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Fecha: ${_formatearFecha(dueDate)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
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
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Todavía no hay gastos comunes registrados.'),
          );
        }
        final balances = calcularBalances(expenses);
        final settlements = simplificarDeudas(balances);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (settlements.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Todo cuadrado, nadie le debe nada a nadie.'),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: settlements.map((s) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${_nombre(s.fromUid)} le debe ${s.amount.toStringAsFixed(2)}€ a ${_nombre(s.toUid)}',
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            ...expenses.map((e) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(e.description),
                    subtitle: Text('Pagó ${_nombre(e.paidByUid)} · ${e.amount.toStringAsFixed(2)}€'),
                    trailing: e.paidByUid == FirebaseAuth.instance.currentUser?.uid
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => ExpenseService.deleteExpense(household.id, e.id),
                          )
                        : null,
                  ),
                )),
          ],
        );
      },
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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Sin recordatorios de pago.'),
          );
        }
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        return Column(
          children: reminders.map((r) {
            final fecha = _formatearFecha(r.nextOccurrence());
            return Card(
              child: ListTile(
                leading: const Icon(Icons.event_repeat_outlined),
                title: Text(r.title),
                subtitle: Text(r.recurring ? '$fecha · cada mes' : fecha),
                trailing: r.createdBy == myUid
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => ReminderService.deleteReminder(household.id, r.id),
                      )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
