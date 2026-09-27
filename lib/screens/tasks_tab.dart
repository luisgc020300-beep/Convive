// lib/screens/tasks_tab.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/date_names.dart';
import '../l10n/l10n.dart';
import '../models/household.dart';
import '../models/note.dart';
import '../models/shopping_item.dart';
import '../models/task.dart';
import '../services/note_service.dart';
import '../services/shopping_service.dart';
import '../services/task_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_error.dart';
import '../widgets/convive_sheet.dart';
import '../widgets/corkboard.dart';
import 'payments_tab.dart' show mostrarNuevoGasto;
import 'weekly_calendar.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({required this.household, super.key});

  final Household household;

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  // Stream estable -- esta pestaña se reconstruye a menudo por los streams
  // de badges del piso (ver household_home_screen.dart); sin esto, el
  // StreamBuilder de abajo se desuscribía y resuscribía en cada rebuild.
  late Stream<List<ConviveTask>> _tasksStream;

  @override
  void initState() {
    super.initState();
    _tasksStream = TaskService.streamTasks(widget.household.id);
  }

  @override
  void didUpdateWidget(covariant TasksTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.household.id != widget.household.id) {
      _tasksStream = TaskService.streamTasks(widget.household.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = widget.household;
    final l10n = context.l10n;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ConviveTask>>(
            stream: _tasksStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final tasks = snapshot.data ?? [];
              final hoy = DateTime.now();
              final tareasDeHoy = tasks.where((t) => t.ocurreEnDia(hoy)).toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l10n.tasksTitle, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  WeeklyCalendar(
                    household: household,
                    tasks: tasks,
                    onAddTask: (day) => _mostrarNuevaTarea(context, household, day),
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.tasksToday,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.colors.paperMuted)),
                  const SizedBox(height: 6),
                  if (tareasDeHoy.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l10n.tasksNothingToday, style: TextStyle(color: context.colors.paperMuted)),
                    )
                  else
                    ...tareasDeHoy.map((t) => _TaskCard(household: household, task: t)),
                  const SizedBox(height: 28),
                  Text(l10n.shoppingTitle, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _ShoppingList(household: household),
                  const SizedBox(height: 28),
                  Text(l10n.tasksNotesTitle, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _NotesBoard(household: household),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _mostrarNuevaTarea(BuildContext context, Household household, DateTime anchorDate) async {
    final tituloCtrl = TextEditingController();
    RecurrenceType tipo = RecurrenceType.weekly;
    final intervalCtrl = TextEditingController(text: '3');
    int diaSemana = anchorDate.weekday;
    TaskCategory categoria = TaskCategory.other;
    // Fijo por defecto vacío -- si se deja así, se crea en modo rotación
    // (comportamiento de siempre) con todos los miembros del piso.
    var fijar = false;
    final asignadosFijos = <String>{};
    final l10n = context.l10n;
    final nombresDias = diasLargos(context);

    await showConviveSheet<void>(
      context: context,
      title: l10n.tasksNewTaskFor('${nombresDias[anchorDate.weekday - 1]} ${anchorDate.day}'),
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: tituloCtrl,
            decoration: InputDecoration(hintText: l10n.tasksTitleHint),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: TaskCategory.values.map((cat) {
              final seleccionada = cat == categoria;
              return ChoiceChip(
                selected: seleccionada,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, size: 15, color: seleccionada ? context.colors.onAccent : context.colors.paperMuted),
                    const SizedBox(width: 4),
                    Text(cat.label(l10n)),
                  ],
                ),
                selectedColor: context.colors.amber,
                onSelected: (_) => setState(() => categoria = cat),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RecurrenceType>(
            initialValue: tipo,
            decoration: const InputDecoration(),
            dropdownColor: context.colors.cork,
            items: RecurrenceType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label(l10n))))
                .toList(),
            onChanged: (v) => setState(() => tipo = v ?? tipo),
          ),
          if (tipo == RecurrenceType.weekly) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: diaSemana,
              decoration: InputDecoration(labelText: l10n.tasksDayOfWeek),
              dropdownColor: context.colors.cork,
              items: List.generate(7, (i) => i + 1)
                  .map((d) => DropdownMenuItem(value: d, child: Text(nombresDias[d - 1])))
                  .toList(),
              onChanged: (v) => setState(() => diaSemana = v ?? diaSemana),
            ),
          ],
          if (tipo == RecurrenceType.everyNDays) ...[
            const SizedBox(height: 12),
            TextField(
              controller: intervalCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: l10n.tasksIntervalHint),
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: context.colors.amber,
            value: fijar,
            title: Text(fijar ? l10n.tasksAssignModeFixed : l10n.tasksAssignModeRotate),
            subtitle: fijar ? Text(l10n.tasksAssignModeFixedHint) : null,
            onChanged: (v) => setState(() => fijar = v),
          ),
          if (fijar)
            ...household.members.map((uid) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: context.colors.amber,
                  value: asignadosFijos.contains(uid),
                  title: Text(household.memberProfiles[uid]?.displayName ?? l10n.memberUnknown),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      asignadosFijos.add(uid);
                    } else {
                      asignadosFijos.remove(uid);
                    }
                  }),
                )),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              final titulo = tituloCtrl.text.trim();
              if (titulo.isEmpty) return;
              if (fijar && asignadosFijos.isEmpty) return;
              try {
                await TaskService.createTask(
                  householdId: household.id,
                  title: titulo,
                  category: categoria,
                  recurrenceType: tipo,
                  anchorDate: anchorDate,
                  dayOfWeek: tipo == RecurrenceType.weekly ? diaSemana : null,
                  intervalDays: tipo == RecurrenceType.everyNDays
                      ? int.tryParse(intervalCtrl.text)
                      : null,
                  rotationOrder: household.members,
                  assigneeUids: fijar ? asignadosFijos.toList() : const [],
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) AppError.show(ctx, l10n.errorGeneric);
              }
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.household, required this.task});

  final Household household;
  final ConviveTask task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final asignadosUids = task.asignadosEnDia(DateTime.now());
    final asignado = asignadosUids.isEmpty
        ? l10n.memberUnknown
        : joinNames(
            l10n,
            asignadosUids.map((uid) => household.memberProfiles[uid]?.displayName ?? l10n.memberUnknown).toList(),
          );
    final esMiTurno = asignadosUids.contains(FirebaseAuth.instance.currentUser?.uid);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.cork,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: context.colors.amber.withValues(alpha: 0.8), width: 3)),
      ),
      child: Row(
        children: [
          Icon(task.category.icon, size: 18, color: context.colors.paperMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(l10n.tasksAssignedTo(asignado),
                    style: TextStyle(color: context.colors.paperMuted, fontSize: 12)),
              ],
            ),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: task.completadaHoy
                  ? context.colors.mint.withValues(alpha: 0.18)
                  : (esMiTurno ? context.colors.amber.withValues(alpha: 0.22) : context.colors.corkDark),
              foregroundColor: task.completadaHoy
                  ? context.colors.mint
                  : (esMiTurno ? context.colors.amber : context.colors.paperMuted),
              disabledBackgroundColor: context.colors.mint.withValues(alpha: 0.18),
              disabledForegroundColor: context.colors.mint,
            ),
            onPressed: task.completadaHoy
                ? null
                : () async {
                    try {
                      await TaskService.completeTask(
                        householdId: household.id,
                        taskId: task.id,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      // "Ya estaba hecha" es un rechazo esperado (p.ej. un
                      // doble toque, o ya la marcó otra pestaña abierta) --
                      // no es un fallo real, así que no debe sonar a error.
                      final yaHecha = e is FirebaseFunctionsException && e.code == 'failed-precondition';
                      AppError.show(context, yaHecha ? context.l10n.tasksAlreadyDone : context.l10n.errorGeneric);
                    }
                  },
            child: Text(task.completadaHoy ? l10n.tasksDoneToday : (esMiTurno ? l10n.tasksDone : l10n.tasksMarkDone)),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: context.colors.paperMuted),
            tooltip: l10n.delete,
            onPressed: () => _confirmarBorrado(context, household, task),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarBorrado(BuildContext context, Household household, ConviveTask task) async {
    final l10n = context.l10n;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tasksDeleteTitle),
        content: Text(l10n.tasksDeleteBody(task.title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.rust),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      try {
        await TaskService.deleteTask(householdId: household.id, taskId: task.id);
      } catch (e) {
        if (context.mounted) AppError.show(context, l10n.errorGeneric);
      }
    }
  }
}

class _ShoppingList extends StatefulWidget {
  const _ShoppingList({required this.household});

  final Household household;

  @override
  State<_ShoppingList> createState() => _ShoppingListState();
}

class _ShoppingListState extends State<_ShoppingList> {
  final _textCtrl = TextEditingController();
  // "Para quién" del próximo ítem a añadir -- por defecto, tú mismo (lo más
  // común), null significa "para todo el piso". Se mantiene entre un
  // añadido y el siguiente a propósito: si vas apuntando varias cosas
  // tuyas seguidas, no hace falta reelegir cada vez.
  late String? _paraUidSeleccionado = FirebaseAuth.instance.currentUser?.uid;
  late Stream<List<ShoppingItem>> _itemsStream;

  @override
  void initState() {
    super.initState();
    _itemsStream = ShoppingService.streamItems(widget.household.id);
  }

  @override
  void didUpdateWidget(covariant _ShoppingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.household.id != widget.household.id) {
      _itemsStream = ShoppingService.streamItems(widget.household.id);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _anadir() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ShoppingService.addItem(widget.household.id, text, paraUid: _paraUidSeleccionado);
      _textCtrl.clear();
    } catch (e) {
      if (mounted) AppError.show(context, context.l10n.errorGeneric);
    }
  }

  Future<void> _marcarComprada(ShoppingItem item) async {
    final l10n = context.l10n;
    try {
      await ShoppingService.deleteItem(widget.household.id, item.id);
    } catch (e) {
      if (mounted) AppError.show(context, l10n.errorGeneric);
      return;
    }
    if (!mounted) return;
    // Justo el gesto que evita tener que acordarse de apuntarlo luego por
    // separado: comprar y registrar el gasto en un solo paso.
    final esGasto = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.shoppingAddExpenseQuestion),
        content: Text(item.text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.shoppingAddExpenseNo)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.mint, foregroundColor: const Color(0xFF0B2116)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.shoppingAddExpenseYes),
          ),
        ],
      ),
    );
    if (esGasto == true && mounted) {
      final miUid = FirebaseAuth.instance.currentUser?.uid;
      // Si el ítem era para todo el piso, el reparto por defecto es todo
      // el piso; si era para una persona concreta, solo entre quien compra
      // y quien lo pidió -- se puede ampliar a mano en el formulario si al
      // final sí era para todos.
      final incluidosIniciales = item.paraUid == null
          ? {...widget.household.members}
          : <String>{?miUid, item.paraUid!};
      await mostrarNuevoGasto(
        context,
        widget.household,
        descripcionInicial: item.text,
        incluidosIniciales: incluidosIniciales,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(color: colors.cork, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  decoration: InputDecoration(hintText: l10n.shoppingHint, isDense: true),
                  onSubmitted: (_) => _anadir(),
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.add_circle, color: colors.mint),
                tooltip: l10n.shoppingAdd,
                onPressed: _anadir,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...widget.household.members.map((uid) {
                  final seleccionado = uid == _paraUidSeleccionado;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: seleccionado,
                      onSelected: (_) => setState(() => _paraUidSeleccionado = uid),
                      label: Text(widget.household.memberProfiles[uid]?.displayName ?? l10n.memberUnknown),
                      labelStyle: TextStyle(
                          fontSize: 12, color: seleccionado ? const Color(0xFF0B2116) : colors.paper),
                      selectedColor: colors.mint,
                      backgroundColor: colors.corkDark,
                      side: BorderSide.none,
                    ),
                  );
                }),
                ChoiceChip(
                  selected: _paraUidSeleccionado == null,
                  onSelected: (_) => setState(() => _paraUidSeleccionado = null),
                  label: Text(l10n.shoppingForEveryone),
                  labelStyle: TextStyle(
                      fontSize: 12, color: _paraUidSeleccionado == null ? const Color(0xFF0B2116) : colors.paper),
                  selectedColor: colors.mint,
                  backgroundColor: colors.corkDark,
                  side: BorderSide.none,
                ),
              ],
            ),
          ),
          StreamBuilder<List<ShoppingItem>>(
            stream: _itemsStream,
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    l10n.shoppingEmpty,
                    style: TextStyle(color: colors.paperMuted, fontSize: 13),
                  ),
                );
              }
              return Column(
                children: items.map((item) {
                  final para = item.paraUid == null
                      ? l10n.shoppingForEveryone
                      : (widget.household.memberProfiles[item.paraUid]?.displayName ?? l10n.memberUnknown);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: IconButton(
                      icon: Icon(Icons.radio_button_unchecked, color: colors.paperMuted, size: 22),
                      tooltip: l10n.shoppingMarkBought,
                      onPressed: () => _marcarComprada(item),
                    ),
                    title: Text(item.text, style: TextStyle(color: colors.paper)),
                    subtitle: Text(para, style: TextStyle(color: colors.paperMuted, fontSize: 11.5)),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NotesBoard extends StatefulWidget {
  const _NotesBoard({required this.household});

  final Household household;

  @override
  State<_NotesBoard> createState() => _NotesBoardState();
}

class _NotesBoardState extends State<_NotesBoard> {
  late Stream<List<ConviveNote>> _notesStream;

  @override
  void initState() {
    super.initState();
    _notesStream = NoteService.streamNotes(widget.household.id);
  }

  @override
  void didUpdateWidget(covariant _NotesBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.household.id != widget.household.id) {
      _notesStream = NoteService.streamNotes(widget.household.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = widget.household;
    final l10n = context.l10n;
    return CorkboardSurface(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _mostrarNuevaNota(context, household),
                icon: Icon(Icons.push_pin_outlined, color: context.colors.paper, size: 16),
                label: Text(l10n.tasksPinNote, style: TextStyle(color: context.colors.paper)),
              ),
            ),
            StreamBuilder<List<ConviveNote>>(
              stream: _notesStream,
              builder: (context, snapshot) {
                final notes = snapshot.data ?? [];
                if (notes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        l10n.tasksBoardEmpty,
                        style: ConviveText.handwritten(fontSize: 16, color: context.colors.paperMuted),
                      ),
                    ),
                  );
                }
                final myUid = FirebaseAuth.instance.currentUser?.uid;
                return Wrap(
                  spacing: 14,
                  runSpacing: 18,
                  children: notes.asMap().entries.map((entry) {
                    final n = entry.value;
                    final autor = household.memberProfiles[n.authorUid]?.displayName ?? l10n.memberUnknown;
                    return PostItNote(
                      text: n.text,
                      author: autor,
                      color: ConviveColors.postIts[entry.key % ConviveColors.postIts.length],
                      seed: n.id.hashCode,
                      onDelete: n.authorUid == myUid
                          ? () async {
                              try {
                                await NoteService.deleteNote(household.id, n.id);
                              } catch (e) {
                                if (context.mounted) AppError.show(context, context.l10n.errorGeneric);
                              }
                            }
                          : null,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarNuevaNota(BuildContext context, Household household) async {
    final ctrl = TextEditingController();
    final l10n = context.l10n;
    await showConviveSheet<void>(
      context: context,
      title: l10n.tasksNewNoteTitle,
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(hintText: l10n.tasksNoteHint),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              try {
                await NoteService.postNote(household.id, text);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) AppError.show(ctx, l10n.errorGeneric);
              }
            },
            child: Text(l10n.tasksPin),
          ),
        ],
      ),
    );
  }
}
