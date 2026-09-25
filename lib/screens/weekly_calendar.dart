// lib/screens/weekly_calendar.dart
//
// Calendario de tareas: por defecto una fila de días tocables (semana
// actual) que se puede desplegar a mes completo con el botón de abajo, y
// un panel de detalle del día seleccionado desde el que también se añaden
// tareas nuevas ancladas a ese día. Gracias al sistema de ancla de
// ConviveTask (ver lib/models/task.dart), el detalle de un día -- pasado,
// hoy o futuro -- se calcula por aritmética, no por suposición: para
// tareas semanales y "cada X días" sí podemos decir honestamente "esto
// toca el jueves que viene y le tocaría a Ana", porque ya no depende de
// cuándo se pulsó "Hecho" la última vez.
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
const _mesesLargos = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
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
// la semana/mes que se esté navegando, no solo la más próxima.
bool _reminderOcurreEnDia(PaymentReminder r, DateTime day) {
  if (r.recurring) return day.day == (r.dueDay ?? 1).clamp(1, 28);
  return r.dueDate != null && _sameDay(r.dueDate!, day);
}

enum _DayState { done, missed, scheduled, empty }

_DayState _estadoParaDia(DateTime day, List<ConviveTask> tasks, List<TaskCompletion> completions) {
  final resueltas = completions.where((c) => c.occurrenceDate != null && _sameDay(c.occurrenceDate!, day));
  if (resueltas.any((c) => c.status == 'done')) return _DayState.done;
  if (resueltas.any((c) => c.status == 'missed')) return _DayState.missed;
  final resueltasIds = resueltas.map((c) => c.taskId).toSet();
  if (tasks.any((t) => t.ocurreEnDia(day) && !resueltasIds.contains(t.id))) return _DayState.scheduled;
  return _DayState.empty;
}

class WeeklyCalendar extends StatefulWidget {
  const WeeklyCalendar({
    required this.household,
    required this.tasks,
    required this.onAddTask,
    super.key,
  });

  final Household household;
  final List<ConviveTask> tasks;
  final void Function(DateTime day) onAddTask;

  @override
  State<WeeklyCalendar> createState() => _WeeklyCalendarState();
}

class _WeeklyCalendarState extends State<WeeklyCalendar> {
  int _weekOffset = 0;
  int _monthOffset = 0;
  bool _expandido = false;
  late DateTime _selectedDay = _todayMidnight();

  static DateTime _todayMidnight() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _alternarExpandido() {
    setState(() {
      _expandido = !_expandido;
      _weekOffset = 0;
      _monthOffset = 0;
      _selectedDay = _todayMidnight();
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayMidnight();

    final List<DateTime> diasSemana;
    final List<DateTime> diasMes;
    final DateTime primerDiaMes;
    if (_expandido) {
      final base = DateTime(today.year, today.month + _monthOffset);
      primerDiaMes = DateTime(base.year, base.month, 1);
      final ultimoDia = DateTime(base.year, base.month + 1, 0);
      diasMes = List.generate(ultimoDia.day, (i) => DateTime(base.year, base.month, i + 1));
      diasSemana = const [];
    } else {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final weekStart = monday.add(Duration(days: 7 * _weekOffset));
      diasSemana = List.generate(7, (i) => weekStart.add(Duration(days: i)));
      diasMes = const [];
      primerDiaMes = today;
    }
    final diasVisibles = _expandido ? diasMes : diasSemana;
    if (!diasVisibles.any((d) => _sameDay(d, _selectedDay))) {
      _selectedDay = diasVisibles.first;
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
                          onPressed: () => setState(() =>
                              _expandido ? _monthOffset-- : _weekOffset--),
                        ),
                        Text(
                          _expandido
                              ? '${_mesesLargos[primerDiaMes.month - 1]} ${primerDiaMes.year}'
                              : (_weekOffset == 0
                                  ? 'Esta semana'
                                  : '${diasSemana.first.day} ${_meses[diasSemana.first.month - 1]} — ${diasSemana.last.day} ${_meses[diasSemana.last.month - 1]}'),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: ConviveColors.paper),
                          onPressed: () => setState(() =>
                              _expandido ? _monthOffset++ : _weekOffset++),
                        ),
                      ],
                    ),
                    if (_expandido) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _diasSemana
                            .map((l) => SizedBox(
                                  width: 30,
                                  child: Text(l,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.w700, color: ConviveColors.paperMuted)),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 4),
                      _MonthGrid(
                        primerDiaMes: primerDiaMes,
                        dias: diasMes,
                        today: today,
                        selectedDay: _selectedDay,
                        estadoParaDia: (d) => _estadoParaDia(d, widget.tasks, completions),
                        tieneRecordatorio: (d) => reminders.any((r) => _reminderOcurreEnDia(r, d)),
                        onTap: (d) => setState(() => _selectedDay = d),
                      ),
                    ] else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (i) {
                          final day = diasSemana[i];
                          return _DayDot(
                            label: _diasSemana[i],
                            number: day.day,
                            esHoy: _sameDay(day, today),
                            seleccionado: _sameDay(day, _selectedDay),
                            estado: _estadoParaDia(day, widget.tasks, completions),
                            tieneRecordatorio: reminders.any((r) => _reminderOcurreEnDia(r, day)),
                            onTap: () => setState(() => _selectedDay = day),
                          );
                        }),
                      ),
                    const SizedBox(height: 12),
                    _DayDetail(
                      household: widget.household,
                      tasks: widget.tasks,
                      day: _selectedDay,
                      completions: completions
                          .where((c) => c.occurrenceDate != null && _sameDay(c.occurrenceDate!, _selectedDay))
                          .toList(),
                      reminders: reminders.where((r) => _reminderOcurreEnDia(r, _selectedDay)).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => widget.onAddTask(_selectedDay),
                            icon: const Icon(Icons.add, size: 16, color: ConviveColors.amber),
                            label: Text(
                              'Añadir tarea para el ${_diasSemana[_selectedDay.weekday - 1]} ${_selectedDay.day}',
                              style: const TextStyle(color: ConviveColors.amber, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _alternarExpandido,
                          icon: Icon(
                            _expandido ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: ConviveColors.paperMuted,
                          ),
                          label: Text(
                            _expandido ? 'Semana' : 'Mes',
                            style: const TextStyle(color: ConviveColors.paperMuted, fontSize: 12.5),
                          ),
                        ),
                      ],
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

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.primerDiaMes,
    required this.dias,
    required this.today,
    required this.selectedDay,
    required this.estadoParaDia,
    required this.tieneRecordatorio,
    required this.onTap,
  });

  final DateTime primerDiaMes;
  final List<DateTime> dias;
  final DateTime today;
  final DateTime selectedDay;
  final _DayState Function(DateTime) estadoParaDia;
  final bool Function(DateTime) tieneRecordatorio;
  final void Function(DateTime) onTap;

  @override
  Widget build(BuildContext context) {
    final huecosIniciales = primerDiaMes.weekday - 1; // lunes=1 -> 0 huecos
    final celdas = <Widget>[
      for (var i = 0; i < huecosIniciales; i++) const SizedBox(),
      for (final dia in dias)
        _MonthDayCell(
          number: dia.day,
          esHoy: _sameDay(dia, today),
          seleccionado: _sameDay(dia, selectedDay),
          estado: estadoParaDia(dia),
          tieneRecordatorio: tieneRecordatorio(dia),
          onTap: () => onTap(dia),
        ),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      childAspectRatio: 0.85,
      children: celdas,
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.number,
    required this.esHoy,
    required this.seleccionado,
    required this.estado,
    required this.tieneRecordatorio,
    required this.onTap,
  });

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
      _DayState.scheduled => ConviveColors.paperMuted,
      _DayState.empty => ConviveColors.paperMuted.withValues(alpha: 0.3),
    };
    final relleno = estado != _DayState.scheduled;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: seleccionado ? ConviveColors.amber.withValues(alpha: 0.18) : null,
          borderRadius: BorderRadius.circular(8),
          border: seleccionado ? Border.all(color: ConviveColors.amber, width: 1.2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$number',
              style: TextStyle(
                fontSize: 12.5,
                color: esHoy ? ConviveColors.amber : ConviveColors.paper,
                fontWeight: esHoy ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: relleno ? dotColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: relleno ? null : Border.all(color: dotColor, width: 0.8),
                  ),
                ),
                if (tieneRecordatorio) ...[
                  const SizedBox(width: 2),
                  const Icon(Icons.attach_money, size: 7, color: ConviveColors.mint),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
      _DayState.scheduled => ConviveColors.paperMuted,
      _DayState.empty => ConviveColors.paperMuted.withValues(alpha: 0.4),
    };
    final relleno = estado != _DayState.scheduled;
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
                  decoration: BoxDecoration(
                    color: relleno ? dotColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: relleno ? null : Border.all(color: dotColor, width: 1),
                  ),
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
    required this.completions,
    required this.reminders,
  });

  final Household household;
  final List<ConviveTask> tasks;
  final DateTime day;
  final List<TaskCompletion> completions;
  final List<PaymentReminder> reminders;

  @override
  Widget build(BuildContext context) {
    final programadas = tasks
        .where((t) => t.ocurreEnDia(day) && !completions.any((c) => c.taskId == t.id))
        .toList();

    if (completions.isEmpty && programadas.isEmpty && reminders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Nada programado ese día.',
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
        ...programadas.map((t) => _DetailRow(
              texto: t.title,
              persona: _nameForMember(household, t.asignadoEnDia(day)),
              color: _colorForMember(household, t.asignadoEnDia(day)),
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
