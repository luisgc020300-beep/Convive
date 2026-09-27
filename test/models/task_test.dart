// test/models/task_test.dart
//
// Aritmética de tareas -- si esto falla, alguien no ve la tarea que le
// toca ese día, o le toca a la persona equivocada. Es la lógica más
// crítica de la app (y la que vive duplicada en functions/index.js, ver
// el comentario en lib/models/task.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:convive/models/task.dart';

ConviveTask _tarea({
  RecurrenceType tipo = RecurrenceType.daily,
  required DateTime anchor,
  int? intervalDays,
  int? dayOfWeek,
  List<String> rotationOrder = const [],
  List<String> assigneeUids = const [],
}) {
  return ConviveTask(
    id: 't1',
    title: 'Test',
    recurrenceType: tipo,
    intervalDays: intervalDays,
    dayOfWeek: dayOfWeek,
    anchorDate: anchor,
    rotationOrder: rotationOrder,
    assigneeUids: assigneeUids,
    active: true,
  );
}

void main() {
  group('RecurrenceType wire round trip', () {
    test('cada valor sobrevive ida y vuelta', () {
      for (final tipo in RecurrenceType.values) {
        expect(RecurrenceTypeX.fromWire(tipo.wireValue), tipo);
      }
    });

    test('un valor desconocido cae en daily, no revienta', () {
      expect(RecurrenceTypeX.fromWire('algo-que-no-existe'), RecurrenceType.daily);
      expect(RecurrenceTypeX.fromWire(null), RecurrenceType.daily);
    });
  });

  group('TaskCategory wire round trip', () {
    test('cada valor sobrevive ida y vuelta', () {
      for (final cat in TaskCategory.values) {
        expect(TaskCategoryX.fromWire(cat.wireValue), cat);
      }
    });

    test('un valor desconocido cae en other, no revienta', () {
      expect(TaskCategoryX.fromWire('inventado'), TaskCategory.other);
      expect(TaskCategoryX.fromWire(null), TaskCategory.other);
    });
  });

  group('ocurreEnDia', () {
    final ancla = DateTime(2026, 1, 5); // lunes

    test('daily ocurre todos los días desde el ancla, nunca antes', () {
      final t = _tarea(anchor: ancla);
      expect(t.ocurreEnDia(ancla), isTrue);
      expect(t.ocurreEnDia(ancla.add(const Duration(days: 1))), isTrue);
      expect(t.ocurreEnDia(ancla.add(const Duration(days: 40))), isTrue);
      expect(t.ocurreEnDia(ancla.subtract(const Duration(days: 1))), isFalse);
    });

    test('weekly ocurre solo el día de la semana indicado', () {
      final t = _tarea(tipo: RecurrenceType.weekly, anchor: ancla, dayOfWeek: DateTime.thursday);
      // El jueves de esa misma semana sí, cualquier otro día no.
      final jueves = ancla.add(const Duration(days: 3));
      expect(t.ocurreEnDia(jueves), isTrue);
      expect(t.ocurreEnDia(jueves.add(const Duration(days: 7))), isTrue); // jueves siguiente
      expect(t.ocurreEnDia(ancla), isFalse); // el lunes, no
      expect(t.ocurreEnDia(jueves.add(const Duration(days: 1))), isFalse); // viernes, no
    });

    test('every_n_days ocurre cada N días exactos desde el ancla', () {
      final t = _tarea(tipo: RecurrenceType.everyNDays, anchor: ancla, intervalDays: 3);
      expect(t.ocurreEnDia(ancla), isTrue);
      expect(t.ocurreEnDia(ancla.add(const Duration(days: 3))), isTrue);
      expect(t.ocurreEnDia(ancla.add(const Duration(days: 6))), isTrue);
      expect(t.ocurreEnDia(ancla.add(const Duration(days: 1))), isFalse);
      expect(t.ocurreEnDia(ancla.add(const Duration(days: 2))), isFalse);
    });
  });

  group('asignadoEnDia (rotación clásica, un solo nombre)', () {
    final ancla = DateTime(2026, 1, 5);

    test('rota entre los miembros día a día para daily', () {
      final t = _tarea(anchor: ancla, rotationOrder: ['a', 'b', 'c']);
      expect(t.asignadoEnDia(ancla), 'a');
      expect(t.asignadoEnDia(ancla.add(const Duration(days: 1))), 'b');
      expect(t.asignadoEnDia(ancla.add(const Duration(days: 2))), 'c');
      expect(t.asignadoEnDia(ancla.add(const Duration(days: 3))), 'a'); // vuelve a empezar
    });

    test('rota una vez por semana para weekly', () {
      final t = _tarea(
        tipo: RecurrenceType.weekly,
        anchor: ancla,
        dayOfWeek: DateTime.monday,
        rotationOrder: ['a', 'b'],
      );
      expect(t.asignadoEnDia(ancla), 'a');
      expect(t.asignadoEnDia(ancla.add(const Duration(days: 7))), 'b');
      expect(t.asignadoEnDia(ancla.add(const Duration(days: 14))), 'a');
    });

    test('sin rotationOrder no hay asignado', () {
      final t = _tarea(anchor: ancla);
      expect(t.asignadoEnDia(ancla), isNull);
    });

    test('un día que no toca no tiene asignado', () {
      final t = _tarea(
        tipo: RecurrenceType.weekly,
        anchor: ancla,
        dayOfWeek: DateTime.monday,
        rotationOrder: ['a', 'b'],
      );
      expect(t.asignadoEnDia(ancla.add(const Duration(days: 1))), isNull); // martes
    });
  });

  group('asignadosEnDia (rotación o fija/compartida)', () {
    final ancla = DateTime(2026, 1, 5);

    test('sin assigneeUids, envuelve la rotación clásica en una lista', () {
      final t = _tarea(anchor: ancla, rotationOrder: ['a', 'b']);
      expect(t.asignadosEnDia(ancla), ['a']);
      expect(t.asignadosEnDia(ancla.add(const Duration(days: 1))), ['b']);
    });

    test('con assigneeUids fijo (una persona), siempre es esa persona, no rota', () {
      final t = _tarea(anchor: ancla, rotationOrder: ['a', 'b'], assigneeUids: ['c']);
      expect(t.asignadosEnDia(ancla), ['c']);
      expect(t.asignadosEnDia(ancla.add(const Duration(days: 1))), ['c']);
      expect(t.asignadosEnDia(ancla.add(const Duration(days: 5))), ['c']);
    });

    test('con assigneeUids compartido (varias personas), siempre son todas, todos los días', () {
      final t = _tarea(anchor: ancla, assigneeUids: ['a', 'b']);
      expect(t.asignadosEnDia(ancla), ['a', 'b']);
      expect(t.asignadosEnDia(ancla.add(const Duration(days: 3))), ['a', 'b']);
    });

    test('un día que no toca no tiene asignados, ni siquiera en modo fijo', () {
      final t = _tarea(
        tipo: RecurrenceType.weekly,
        anchor: ancla,
        dayOfWeek: DateTime.monday,
        assigneeUids: ['a', 'b'],
      );
      expect(t.asignadosEnDia(ancla.add(const Duration(days: 1))), isEmpty); // martes
    });
  });

  group('completadaHoy', () {
    test('true si lastCompletionDay coincide con la clave de hoy en UTC', () {
      final hoy = DateTime.now().toUtc();
      final clave = '${hoy.year}-${hoy.month}-${hoy.day}';
      final t = ConviveTask(
        id: 't1',
        title: 'Test',
        recurrenceType: RecurrenceType.daily,
        anchorDate: DateTime(2026, 1, 1),
        rotationOrder: const [],
        active: true,
        lastCompletionDay: clave,
      );
      expect(t.completadaHoy, isTrue);
    });

    test('false si lastCompletionDay es de otro día', () {
      final t = _tarea(anchor: DateTime(2026, 1, 1));
      expect(t.completadaHoy, isFalse);
    });
  });
}
