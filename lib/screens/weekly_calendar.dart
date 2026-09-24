// lib/screens/weekly_calendar.dart
//
// Calendario semanal de tareas: una fila de días tocables (lunes a domingo)
// más un panel de detalle del día seleccionado. El detalle usa lo realmente
// completado (`completions`, el mismo dato objetivo que ya usa el resto de
// la app) y, solo para hoy, lo que queda pendiente. No se proyectan
// asignaciones futuras: la rotación solo se conoce con certeza cuando el
// cron o una compleción la hacen avanzar, así que mostrar "quién le tocará
// el jueves" sería inventar un dato -- los días futuros lo dicen así de
// claro en vez de fingir que lo sabemos.
import 'package:flutter/material.dart';

import '../models/household.dart';
import '../models/reminder.dart';
import '../models/task.dart';
import '../services/reminder_service.dart';
import '../services/task_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/corkboard.dart';

const _diasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];
const _memberColors = [
  ConviveColors.amber, ConviveColors.coral, ConviveColors.mint,
  Color(0xFFB08FD8), ConviveColors.rust, Color(0xFF5C9EE8),
];

Color _colorForMember(Household household, String? uid) {
  if (uid == null) return ConviveColors.paperMuted;
  final i = household.members.indexOf(uid);
  if (i < 0) return ConviveColors.paperMuted;
  return _memberColors[i % _memberColors.length];
}

String _nameForMember(Household household, String? uid) =>
    household.memberProfiles[uid]?.displayName ?? 'Alguien';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// Para un recordatorio recurrente, comprueba el día del mes en vez de
// "próxima ocurrencia desde hoy" -- así aparece correctamente sea cual sea
// la semana que se esté navegando, no solo la más próxima.
bool _reminderOcurreEnDia(PaymentReminder r, DateTime day) {
  if (r.recurring) return day.day == (r.dueDay ?? 1).clamp(1, 28);
  return r.dueDate != null && _sameDay(r.dueDate!, day);
}

class WeeklyCalendar extends StatefulWidget {
  const WeeklyCalendar({required this.household, required this.tasks, super.key});

  final Household household;
  final List<ConviveTask> tasks;

  @override
  State<WeeklyCalendar> createState() => _WeeklyCalendarState();
}

class _WeeklyCalendarState extends State<WeeklyCalendar> {
  int _weekOffset = 0;
  late DateTime _selectedDay = _todayMidnight();

  static DateTime _todayMidnight() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayMidnight();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final weekStart = monday.add(Duration(days: 7 * _weekOffset));
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    if (!days.any((d) => _sameDay(d, _selectedDay))) {
      _selectedDay = days.first;
    }

    return CorkboardSurface(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<List<TaskCompletion>>(
          stream: TaskService.streamHistory(widget.household.id, limit: 300),
          builder: (context, completionsSnapshot) {
            final completions = completionsSnapshot.data ?? [];
            return StreamBuilder<List<PaymentReminder>>(
              stream: ReminderService.streamReminders(widget.household.id),
              builder: (context, remindersSnapshot) {
                final reminders = remindersSnapshot.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: ConviveColors.paper),
                          onPressed: () => setState(() => _weekOffset--),
                        ),
                        Text(
                          _weekOffset == 0
                              ? 'Esta semana'
                              : '${days.first.day} ${_meses[days.first.month - 1]} — ${days.last.day} ${_meses[days.last.month - 1]}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: ConviveColors.paper),
                          onPressed: () => setState(() => _weekOffset++),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (i) {
                        final day = days[i];
                        final delDia = completions
                            .where((c) => c.completedAt != null && _sameDay(c.completedAt!, day))
                            .toList();
                        final hecha = delDia.any((c) => c.status == 'done');
                        final fallada = delDia.any((c) => c.status == 'missed');
                        final tieneRecordatorio = reminders.any((r) => _reminderOcurreEnDia(r, day));
                        return _DayDot(
                          label: _diasSemana[i],
                          number: day.day,
                          esHoy: _sameDay(day, today),
                          seleccionado: _sameDay(day, _selectedDay),
                          estado: hecha
                              ? _DayState.done
                              : fallada
                                  ? _DayState.missed
                                  : _DayState.empty,
                          tieneRecordatorio: tieneRecordatorio,
                          onTap: () => setState(() => _selectedDay = day),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    _DayDetail(
                      household: widget.household,
                      tasks: widget.tasks,
                      day: _selectedDay,
                      today: today,
                      completions: completions
                          .where((c) => c.completedAt != null && _sameDay(c.completedAt!, _selectedDay))
                          .toList(),
                      reminders: reminders.where((r) => _reminderOcurreEnDia(r, _selectedDay)).toList(),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

enum _DayState { done, missed, empty }

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.number,
    required this.esHoy,
    required this.seleccionado,
    required this.estado,
    required this.tieneRecordatorio,
    required this.onTap,
  });

  final String label;
  final int number;
  final bool esHoy;
  final bool seleccionado;
  final _DayState estado;
  final bool tieneRecordatorio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (estado) {
      _DayState.done => ConviveColors.amber,
      _DayState.missed => ConviveColors.rust,
      _DayState.empty => ConviveColors.paperMuted.withValues(alpha: 0.4),
    };
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado ? ConviveColors.amber.withValues(alpha: 0.18) : null,
          borderRadius: BorderRadius.circular(10),
          border: seleccionado ? Border.all(color: ConviveColors.amber, width: 1.4) : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: esHoy ? ConviveColors.amber : ConviveColors.paperMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$number',
              style: TextStyle(
                fontSize: 15,
                color: ConviveColors.paper,
                fontWeight: esHoy ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                if (tieneRecordatorio) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.attach_money, size: 8, color: ConviveColors.mint),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.household,
    required this.tasks,
    required this.day,
    required this.today,
    required this.completions,
    required this.reminders,
  });

  final Household household;
  final List<ConviveTask> tasks;
  final DateTime day;
  final DateTime today;
  final List<TaskCompletion> completions;
  final List<PaymentReminder> reminders;

  @override
  Widget build(BuildContext context) {
    final esHoy = _sameDay(day, today);
    final esFuturo = day.isAfter(today);
    final pendientes = esHoy
        ? tasks.where((t) {
            final start = t.currentPeriodStart;
            final end = t.currentPeriodEnd;
            if (start == null || end == null) return false;
            final cubreHoy = !start.isAfter(DateTime.now()) && end.isAfter(DateTime.now());
            final yaHecha = completions.any((c) => c.taskId == t.id);
            return cubreHoy && !yaHecha;
          }).toList()
        : const <ConviveTask>[];

    if (completions.isEmpty && pendientes.isEmpty && reminders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          esFuturo
              ? 'Todavía no lo sabemos -- se decide cuando llegue el día.'
              : 'Sin registros ese día.',
          style: TextStyle(color: ConviveColors.paperMuted.withValues(alpha: 0.8), fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...reminders.map((r) => _DetailRow(
              texto: r.title,
              persona: r.recurring ? 'cada mes' : 'pago puntual',
              color: ConviveColors.mint,
              icono: Icons.attach_money,
            )),
        ...completions.map((c) => _DetailRow(
              texto: c.taskTitle,
              persona: _nameForMember(household, c.completedBy ?? c.assigneeUid),
              color: _colorForMember(household, c.completedBy ?? c.assigneeUid),
              icono: c.status == 'done' ? Icons.check_circle : Icons.cancel,
            )),
        ...pendientes.map((t) => _DetailRow(
              texto: t.title,
              persona: _nameForMember(household, t.currentAssigneeUid),
              color: _colorForMember(household, t.currentAssigneeUid),
              icono: Icons.schedule,
              pendiente: true,
            )),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.texto,
    required this.persona,
    required this.color,
    required this.icono,
    this.pendiente = false,
  });

  final String texto;
  final String persona;
  final Color color;
  final IconData icono;
  final bool pendiente;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icono, size: 15, color: pendiente ? color.withValues(alpha: 0.7) : color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$texto — $persona',
              style: TextStyle(
                color: ConviveColors.paper,
                fontSize: 13,
                fontStyle: pendiente ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
