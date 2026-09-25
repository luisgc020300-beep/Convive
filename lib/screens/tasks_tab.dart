// lib/screens/tasks_tab.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/household.dart';
import '../models/note.dart';
import '../models/task.dart';
import '../services/note_service.dart';
import '../services/task_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/convive_sheet.dart';
import '../widgets/corkboard.dart';
import 'weekly_calendar.dart';

class TasksTab extends StatelessWidget {
  const TasksTab({required this.household, super.key});

  final Household household;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ConviveTask>>(
            stream: TaskService.streamTasks(household.id),
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
                  Text('Tareas', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  WeeklyCalendar(
                    household: household,
                    tasks: tasks,
                    onAddTask: (day) => _mostrarNuevaTarea(context, household, day),
                  ),
                  const SizedBox(height: 20),
                  Text('Hoy', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.colors.paperMuted)),
                  const SizedBox(height: 6),
                  if (tareasDeHoy.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Nada tuyo para hoy.'),
                    )
                  else
                    ...tareasDeHoy.map((t) => _TaskCard(household: household, task: t)),
                  const SizedBox(height: 28),
                  Text('Notas del piso', style: Theme.of(context).textTheme.titleLarge),
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

  static const _diasSemanaNombres = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];

  Future<void> _mostrarNuevaTarea(BuildContext context, Household household, DateTime anchorDate) async {
    final tituloCtrl = TextEditingController();
    RecurrenceType tipo = RecurrenceType.weekly;
    final intervalCtrl = TextEditingController(text: '3');
    int diaSemana = anchorDate.weekday;

    await showConviveSheet<void>(
      context: context,
      title: 'Nueva tarea — ${_diasSemanaNombres[anchorDate.weekday - 1]} ${anchorDate.day}',
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: tituloCtrl,
            decoration: const InputDecoration(hintText: 'Ej: Fregar la cocina'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RecurrenceType>(
            initialValue: tipo,
            decoration: const InputDecoration(),
            dropdownColor: context.colors.cork,
            items: RecurrenceType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) => setState(() => tipo = v ?? tipo),
          ),
          if (tipo == RecurrenceType.weekly) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: diaSemana,
              decoration: const InputDecoration(labelText: 'Día de la semana'),
              dropdownColor: context.colors.cork,
              items: List.generate(7, (i) => i + 1)
                  .map((d) => DropdownMenuItem(value: d, child: Text(_diasSemanaNombres[d - 1])))
                  .toList(),
              onChanged: (v) => setState(() => diaSemana = v ?? diaSemana),
            ),
          ],
          if (tipo == RecurrenceType.everyNDays) ...[
            const SizedBox(height: 12),
            TextField(
              controller: intervalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Cada cuántos días'),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              final titulo = tituloCtrl.text.trim();
              if (titulo.isEmpty) return;
              await TaskService.createTask(
                householdId: household.id,
                title: titulo,
                recurrenceType: tipo,
                anchorDate: anchorDate,
                dayOfWeek: tipo == RecurrenceType.weekly ? diaSemana : null,
                intervalDays: tipo == RecurrenceType.everyNDays
                    ? int.tryParse(intervalCtrl.text)
                    : null,
                rotationOrder: household.members,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Crear'),
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
    final asignadoUid = task.asignadoEnDia(DateTime.now());
    final asignado = household.memberProfiles[asignadoUid]?.displayName ?? 'Sin asignar';
    final esMiTurno = asignadoUid == FirebaseAuth.instance.currentUser?.uid;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text('Le toca a $asignado',
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
                : () => TaskService.completeTask(
                      householdId: household.id,
                      taskId: task.id,
                    ),
            child: Text(task.completadaHoy ? 'Hecha hoy' : (esMiTurno ? 'Hecho' : 'Marcar hecho')),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: context.colors.paperMuted),
            onPressed: () => _confirmarBorrado(context, household, task),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarBorrado(BuildContext context, Household household, ConviveTask task) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar esta tarea?'),
        content: Text('Se dejará de repartir "${task.title}". El historial ya registrado no se borra.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.rust),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await TaskService.deleteTask(householdId: household.id, taskId: task.id);
    }
  }
}

class _NotesBoard extends StatelessWidget {
  const _NotesBoard({required this.household});

  final Household household;

  @override
  Widget build(BuildContext context) {
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
                label: Text('Clavar nota', style: TextStyle(color: context.colors.paper)),
              ),
            ),
            StreamBuilder<List<ConviveNote>>(
              stream: NoteService.streamNotes(household.id),
              builder: (context, snapshot) {
                final notes = snapshot.data ?? [];
                if (notes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'El corcho está vacío. Clava la primera nota.',
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
                    final autor = household.memberProfiles[n.authorUid]?.displayName ?? 'Alguien';
                    return PostItNote(
                      text: n.text,
                      author: autor,
                      color: ConviveColors.postIts[entry.key % ConviveColors.postIts.length],
                      seed: n.id.hashCode,
                      onDelete: n.authorUid == myUid
                          ? () => NoteService.deleteNote(household.id, n.id)
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
    await showConviveSheet<void>(
      context: context,
      title: 'Clavar una nota',
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Ej: Ha venido el casero...'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              await NoteService.postNote(household.id, text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Clavar'),
          ),
        ],
      ),
    );
  }
}
