// lib/screens/weekly_calendar.dart
//
// Vista semanal de tareas: una columna por día (lunes a domingo) con lo
// realmente completado (a partir de `completions`, el mismo dato objetivo
// que usa el mediador) y, para hoy, lo que queda pendiente. No se proyectan
// asignaciones futuras: la rotación solo se conoce con certeza cuando el
// cron o una compleción la hacen avanzar, así que mostrar "quién le tocará
// el jueves" sería inventar un dato.
import 'package:flutter/material.dart';

import '../models/household.dart';
import '../models/task.dart';
import '../services/task_service.dart';

const _diasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];
const _memberColors = [
  Color(0xFF4C6EF5), Color(0xFFE8590C), Color(0xFF2F9E44),
  Color(0xFFAE3EC9), Color(0xFFE03131), Color(0xFF0C8599),
];

Color _colorForMember(Household household, String? uid) {
  if (uid == null) return Colors.grey;
  final i = household.members.indexOf(uid);
  if (i < 0) return Colors.grey;
  return _memberColors[i % _memberColors.length];
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class WeeklyCalendar extends StatefulWidget {
  const WeeklyCalendar({required this.household, required this.tasks, super.key});

  final Household household;
  final List<ConviveTask> tasks;

  @override
  State<WeeklyCalendar> createState() => _WeeklyCalendarState();
}

class _WeeklyCalendarState extends State<WeeklyCalendar> {
  int _weekOffset = 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final weekStart = monday.add(Duration(days: 7 * _weekOffset));
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _weekOffset--),
            ),
            Text(
              _weekOffset == 0
                  ? 'Esta semana'
                  : 'Semana del ${days.first.day} ${_meses[days.first.month - 1]}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _weekOffset++),
            ),
          ],
        ),
        SizedBox(
          height: 220,
          child: StreamBuilder<List<TaskCompletion>>(
            stream: TaskService.streamHistory(widget.household.id, limit: 300),
            builder: (context, snapshot) {
              final completions = snapshot.data ?? [];
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (context, i) {
                  final day = days[i];
                  final esHoy = _sameDay(day, today);
                  final delDia = completions
                      .where((c) => c.completedAt != null && _sameDay(c.completedAt!, day))
                      .toList();
                  final pendientesHoy = esHoy
                      ? widget.tasks.where((t) {
                          final start = t.currentPeriodStart;
                          final end = t.currentPeriodEnd;
                          if (start == null || end == null) return false;
                          final cubreHoy = !start.isAfter(now) && end.isAfter(now);
                          final yaHecha = delDia.any((c) => c.taskId == t.id);
                          return cubreHoy && !yaHecha;
                        }).toList()
                      : const <ConviveTask>[];

                  return Container(
                    width: 108,
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: esHoy
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        width: esHoy ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_diasSemana[i]} ${day.day}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: esHoy ? FontWeight.w700 : FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...delDia.map((c) => _Chip(
                                      texto: c.taskTitle,
                                      color: _colorForMember(widget.household, c.completedBy),
                                      icono: c.status == 'done'
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                    )),
                                ...pendientesHoy.map((t) => _Chip(
                                      texto: t.title,
                                      color: _colorForMember(widget.household, t.currentAssigneeUid),
                                      icono: Icons.schedule,
                                      outline: true,
                                    )),
                                if (delDia.isEmpty && pendientesHoy.isEmpty)
                                  Text(
                                    '—',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).disabledColor,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.color, required this.icono, this.outline = false});

  final String texto;
  final Color color;
  final IconData icono;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : color.withValues(alpha: 0.15),
        border: outline ? Border.all(color: color.withValues(alpha: 0.6)) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 10, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9.5),
            ),
          ),
        ],
      ),
    );
  }
}
