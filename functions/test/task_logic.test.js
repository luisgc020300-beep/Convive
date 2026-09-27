// functions/test/task_logic.test.js
//
// Espejo de test/models/task_test.dart -- misma aritmética, dos lenguajes.
// Si un caso cambia aquí, cambia también allá (y viceversa).
const test = require('node:test');
const assert = require('node:assert/strict');

const {
  medianocheUTC,
  diaSemanaISO,
  ocurreEnDia,
  asignadoEnDia,
  asignadosEnDia,
  claveDia,
} = require('../task_logic');

const DIA_MS = 24 * 60 * 60 * 1000;

function ts(ms) {
  return { toMillis: () => ms };
}

function tarea({
  tipo = 'daily',
  anchorMs,
  intervalDays,
  dayOfWeek,
  rotationOrder = [],
  assigneeUids = [],
}) {
  return {
    anchorDate: ts(anchorMs),
    recurrence: { type: tipo, intervalDays, dayOfWeek },
    rotationOrder,
    assigneeUids,
  };
}

// Lunes 2026-01-05 00:00 UTC.
const ANCLA = Date.UTC(2026, 0, 5);

test('diaSemanaISO: domingo es 7, no 0', () => {
  assert.equal(diaSemanaISO(ANCLA), 1); // lunes
  assert.equal(diaSemanaISO(ANCLA + 6 * DIA_MS), 7); // domingo
});

test('ocurreEnDia: daily ocurre todos los dias desde el ancla, nunca antes', () => {
  const t = tarea({ anchorMs: ANCLA });
  assert.equal(ocurreEnDia(t, ANCLA), true);
  assert.equal(ocurreEnDia(t, ANCLA + DIA_MS), true);
  assert.equal(ocurreEnDia(t, ANCLA + 40 * DIA_MS), true);
  assert.equal(ocurreEnDia(t, ANCLA - DIA_MS), false);
});

test('ocurreEnDia: weekly ocurre solo el dia de la semana indicado', () => {
  const t = tarea({ tipo: 'weekly', anchorMs: ANCLA, dayOfWeek: 4 }); // jueves
  const jueves = ANCLA + 3 * DIA_MS;
  assert.equal(ocurreEnDia(t, jueves), true);
  assert.equal(ocurreEnDia(t, jueves + 7 * DIA_MS), true);
  assert.equal(ocurreEnDia(t, ANCLA), false); // lunes
  assert.equal(ocurreEnDia(t, jueves + DIA_MS), false); // viernes
});

test('ocurreEnDia: every_n_days ocurre cada N dias exactos desde el ancla', () => {
  const t = tarea({ tipo: 'every_n_days', anchorMs: ANCLA, intervalDays: 3 });
  assert.equal(ocurreEnDia(t, ANCLA), true);
  assert.equal(ocurreEnDia(t, ANCLA + 3 * DIA_MS), true);
  assert.equal(ocurreEnDia(t, ANCLA + 6 * DIA_MS), true);
  assert.equal(ocurreEnDia(t, ANCLA + DIA_MS), false);
  assert.equal(ocurreEnDia(t, ANCLA + 2 * DIA_MS), false);
});

test('asignadoEnDia: rota entre los miembros dia a dia para daily', () => {
  const t = tarea({ anchorMs: ANCLA, rotationOrder: ['a', 'b', 'c'] });
  assert.equal(asignadoEnDia(t, ANCLA), 'a');
  assert.equal(asignadoEnDia(t, ANCLA + DIA_MS), 'b');
  assert.equal(asignadoEnDia(t, ANCLA + 2 * DIA_MS), 'c');
  assert.equal(asignadoEnDia(t, ANCLA + 3 * DIA_MS), 'a'); // vuelve a empezar
});

test('asignadoEnDia: rota una vez por semana para weekly', () => {
  const t = tarea({
    tipo: 'weekly',
    anchorMs: ANCLA,
    dayOfWeek: 1, // lunes
    rotationOrder: ['a', 'b'],
  });
  assert.equal(asignadoEnDia(t, ANCLA), 'a');
  assert.equal(asignadoEnDia(t, ANCLA + 7 * DIA_MS), 'b');
  assert.equal(asignadoEnDia(t, ANCLA + 14 * DIA_MS), 'a');
});

test('asignadoEnDia: sin rotationOrder no hay asignado', () => {
  const t = tarea({ anchorMs: ANCLA });
  assert.equal(asignadoEnDia(t, ANCLA), null);
});

test('asignadoEnDia: un dia que no toca no tiene asignado', () => {
  const t = tarea({
    tipo: 'weekly',
    anchorMs: ANCLA,
    dayOfWeek: 1,
    rotationOrder: ['a', 'b'],
  });
  assert.equal(asignadoEnDia(t, ANCLA + DIA_MS), null); // martes
});

test('asignadosEnDia: sin assigneeUids, envuelve la rotacion clasica en una lista', () => {
  const t = tarea({ anchorMs: ANCLA, rotationOrder: ['a', 'b'] });
  assert.deepEqual(asignadosEnDia(t, ANCLA), ['a']);
  assert.deepEqual(asignadosEnDia(t, ANCLA + DIA_MS), ['b']);
});

test('asignadosEnDia: con assigneeUids fijo (una persona), siempre es esa persona, no rota', () => {
  const t = tarea({ anchorMs: ANCLA, rotationOrder: ['a', 'b'], assigneeUids: ['c'] });
  assert.deepEqual(asignadosEnDia(t, ANCLA), ['c']);
  assert.deepEqual(asignadosEnDia(t, ANCLA + DIA_MS), ['c']);
  assert.deepEqual(asignadosEnDia(t, ANCLA + 5 * DIA_MS), ['c']);
});

test('asignadosEnDia: con assigneeUids compartido (varias personas), siempre son todas, todos los dias', () => {
  const t = tarea({ anchorMs: ANCLA, assigneeUids: ['a', 'b'] });
  assert.deepEqual(asignadosEnDia(t, ANCLA), ['a', 'b']);
  assert.deepEqual(asignadosEnDia(t, ANCLA + 3 * DIA_MS), ['a', 'b']);
});

test('asignadosEnDia: un dia que no toca no tiene asignados, ni siquiera en modo fijo', () => {
  const t = tarea({
    tipo: 'weekly',
    anchorMs: ANCLA,
    dayOfWeek: 1,
    assigneeUids: ['a', 'b'],
  });
  assert.deepEqual(asignadosEnDia(t, ANCLA + DIA_MS), []); // martes
});

test('medianocheUTC: trunca a las 00:00 UTC del mismo dia', () => {
  const conHora = ANCLA + 13 * 60 * 60 * 1000 + 45 * 60 * 1000; // 13:45 UTC
  assert.equal(medianocheUTC(conHora), ANCLA);
});

test('claveDia: misma clave para dos horas distintas del mismo dia UTC', () => {
  const manana = ANCLA + 2 * 60 * 60 * 1000;
  const noche = ANCLA + 22 * 60 * 60 * 1000;
  assert.equal(claveDia(manana), claveDia(noche));
  assert.notEqual(claveDia(manana), claveDia(manana + DIA_MS));
});
