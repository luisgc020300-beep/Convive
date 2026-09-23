// lib/screens/tasks_tab.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/household.dart';
import '../models/note.dart';
import '../models/task.dart';
import '../services/note_service.dart';
import '../services/task_service.dart';

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
              final tasks = snapshot.data ?? [];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tareas', style: Theme.of(context).textTheme.titleLarge),
                      TextButton.icon(
                        onPressed: () => _mostrarNuevaTarea(context, household),
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva'),
                      ),
                    ],
                  ),
                  if (tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Todavía no hay tareas. Añade la primera.'),
                    )
                  else
                    ...tasks.map((t) => _TaskCard(household: household, task: t)),
                  const SizedBox(height: 24),
                  Text('Notas del piso', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _NotesFeed(household: household),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _mostrarNuevaTarea(BuildContext context, Household household) async {
    final tituloCtrl = TextEditingController();
    RecurrenceType tipo = RecurrenceType.weekly;
    final intervalCtrl = TextEditingController(text: '3');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nueva tarea'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(labelText: 'Ej: Fregar la cocina'),
              ),
              const SizedBox(height: 12),
              DropdownButton<RecurrenceType>(
                value: tipo,
                isExpanded: true,
                items: RecurrenceType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) => setState(() => tipo = v ?? tipo),
              ),
              if (tipo == RecurrenceType.everyNDays) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: intervalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cada cuántos días'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final titulo = tituloCtrl.text.trim();
                if (titulo.isEmpty) return;
                await TaskService.createTask(
                  householdId: household.id,
                  title: titulo,
                  recurrenceType: tipo,
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
    final asignado = household.memberProfiles[task.currentAssigneeUid]?.displayName
        ?? 'Sin asignar';
    final esMiTurno =
        task.currentAssigneeUid == FirebaseAuth.instance.currentUser?.uid;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(task.title),
        subtitle: Text('Le toca a $asignado'),
        trailing: FilledButton.tonal(
          onPressed: () => TaskService.completeTask(
            householdId: household.id,
            taskId: task.id,
          ),
          child: Text(esMiTurno ? 'Hecho' : 'Marcar hecho'),
        ),
      ),
    );
  }
}

class _NotesFeed extends StatefulWidget {
  const _NotesFeed({required this.household});

  final Household household;

  @override
  State<_NotesFeed> createState() => _NotesFeedState();
}

class _NotesFeedState extends State<_NotesFeed> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    _noteCtrl.clear();
    await NoteService.postNote(widget.household.id, text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ej: Ha venido el casero...',
                ),
                onSubmitted: (_) => _enviar(),
              ),
            ),
            IconButton(icon: const Icon(Icons.send), onPressed: _enviar),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<ConviveNote>>(
          stream: NoteService.streamNotes(widget.household.id),
          builder: (context, snapshot) {
            final notes = snapshot.data ?? [];
            if (notes.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Sin notas todavía.'),
              );
            }
            return Column(
              children: notes.map((n) {
                final autor = widget.household.memberProfiles[n.authorUid]
                        ?.displayName ??
                    'Alguien';
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.sticky_note_2_outlined),
                  title: Text(n.text),
                  subtitle: Text(autor),
                  trailing: n.authorUid == FirebaseAuth.instance.currentUser?.uid
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () =>
                              NoteService.deleteNote(widget.household.id, n.id),
                        )
                      : null,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
