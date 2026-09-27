// functions/task_logic.js
//
// Aritmética de tareas -- separada de index.js para poder testearla sin
// levantar el emulador de Cloud Functions. Es la MISMA lógica que
// ConviveTask.ocurreEnDia/asignadoEnDia/asignadosEnDia en
// lib/models/task.dart -- si se cambia una, hay que cambiar la otra (y sus
// tests: test/models/task_test.dart en Dart, functions/test/task_logic.test.js
// aquí).
const DIA_MS = 24 * 60 * 60 * 1000;

function medianocheUTC(ms) {
  const d = new Date(ms);
  d.setUTCHours(0, 0, 0, 0);
  return d.getTime();
}

// 1=lunes .. 7=domingo, igual que DateTime.weekday en Dart (Date.getUTCDay()
// de JS usa 0=domingo, hay que convertir).
function diaSemanaISO(ms) {
  const dow = new Date(ms).getUTCDay();
  return dow === 0 ? 7 : dow;
}

function ocurreEnDia(task, diaMs) {
  const anclaMs = medianocheUTC(task.anchorDate.toMillis());
  const dMs = medianocheUTC(diaMs);
  if (dMs < anclaMs) return false;
  const dias = Math.round((dMs - anclaMs) / DIA_MS);
  switch (task.recurrence?.type) {
    case 'weekly':
      return diaSemanaISO(dMs) === (task.recurrence.dayOfWeek || diaSemanaISO(anclaMs));
    case 'every_n_days': {
      const n = Math.max(1, Math.min(365, Number(task.recurrence.intervalDays) || 1));
      return dias % n === 0;
    }
    default: // daily
      return true;
  }
}

function asignadoEnDia(task, diaMs) {
  const orden = task.rotationOrder || [];
  if (orden.length === 0 || !ocurreEnDia(task, diaMs)) return null;
  const anclaMs = medianocheUTC(task.anchorDate.toMillis());
  const dMs = medianocheUTC(diaMs);
  const dias = Math.round((dMs - anclaMs) / DIA_MS);
  let ocurrencia;
  switch (task.recurrence?.type) {
    case 'weekly':
      ocurrencia = Math.round(dias / 7);
      break;
    case 'every_n_days': {
      const n = Math.max(1, Math.min(365, Number(task.recurrence.intervalDays) || 1));
      ocurrencia = Math.floor(dias / n);
      break;
    }
    default:
      ocurrencia = dias;
  }
  return orden[ocurrencia % orden.length];
}

// Igual que asignadoEnDia (Dart) -- si la tarea tiene gente fija en
// assigneeUids, esa gente SIEMPRE es la respuesta (sin rotar); si no, se
// envuelve el resultado de la rotación clásica en una lista de 1.
function asignadosEnDia(task, diaMs) {
  if (!ocurreEnDia(task, diaMs)) return [];
  if ((task.assigneeUids || []).length > 0) return task.assigneeUids;
  const unico = asignadoEnDia(task, diaMs);
  return unico ? [unico] : [];
}

// Clave de día en UTC -- mismo criterio horario que usa el cron (04:00 UTC),
// para no mezclar dos formas distintas de decidir "qué día es hoy".
function claveDia(ms) {
  const d = new Date(ms);
  return `${d.getUTCFullYear()}-${d.getUTCMonth() + 1}-${d.getUTCDate()}`;
}

module.exports = {
  DIA_MS,
  medianocheUTC,
  diaSemanaISO,
  ocurreEnDia,
  asignadoEnDia,
  asignadosEnDia,
  claveDia,
};
