// functions/index.js
// Cloud Functions para Convive — piso y tareas rotativas.
// Deploy: firebase deploy --only functions

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule }         = require('firebase-functions/v2/scheduler');
const { initializeApp }      = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();

const REGION = 'europe-west1';
const MAX_MIEMBROS_PISO = 10;

// Sin 0/O/1/I/L — se confunden fácil al leer un código en voz alta o a mano.
const JOIN_CODE_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

async function generarCodigoUnico() {
  for (let intento = 0; intento < 10; intento++) {
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += JOIN_CODE_CHARS[Math.floor(Math.random() * JOIN_CODE_CHARS.length)];
    }
    const existe = await db.collection('joinCodes').doc(code).get();
    if (!existe.exists) return code;
  }
  throw new HttpsError('internal', 'No se pudo generar un código de piso único.');
}

// =============================================================================
// 1. CREAR PISO
// =============================================================================
exports.createHousehold = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  }
  const uid = request.auth.uid;
  const nombre = typeof request.data?.name === 'string' ? request.data.name.trim() : '';
  if (!nombre || nombre.length > 60) {
    throw new HttpsError('invalid-argument', 'Nombre de piso inválido.');
  }

  const userSnap = await db.collection('users').doc(uid).get();
  const userData = userSnap.exists ? userSnap.data() : {};
  const displayName = userData.displayName || 'Runner';
  const photoUrl = userData.photoUrl || null;

  const joinCode = await generarCodigoUnico();
  const householdRef = db.collection('households').doc();

  await db.runTransaction(async (tx) => {
    tx.set(householdRef, {
      name: nombre,
      joinCode,
      ownerUid: uid,
      members: [uid],
      memberProfiles: {
        [uid]: { displayName, photoUrl, joinedAt: FieldValue.serverTimestamp() },
      },
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('joinCodes').doc(joinCode), { householdId: householdRef.id });
    tx.set(db.collection('users').doc(uid), { activeHouseholdId: householdRef.id }, { merge: true });
  });

  return { ok: true, householdId: householdRef.id, joinCode };
});

// =============================================================================
// 2. UNIRSE A UN PISO
// =============================================================================
exports.joinHousehold = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  }
  const uid = request.auth.uid;
  const raw = typeof request.data?.joinCode === 'string' ? request.data.joinCode : '';
  const joinCode = raw.trim().toUpperCase();
  if (!joinCode) {
    throw new HttpsError('invalid-argument', 'Código de piso inválido.');
  }

  const codeSnap = await db.collection('joinCodes').doc(joinCode).get();
  if (!codeSnap.exists) {
    throw new HttpsError('not-found', 'No existe ningún piso con ese código.');
  }
  const householdId = codeSnap.data().householdId;
  const householdRef = db.collection('households').doc(householdId);

  const userSnap = await db.collection('users').doc(uid).get();
  const userData = userSnap.exists ? userSnap.data() : {};
  const displayName = userData.displayName || 'Runner';
  const photoUrl = userData.photoUrl || null;

  let yaEraMiembro = false;

  await db.runTransaction(async (tx) => {
    const houseSnap = await tx.get(householdRef);
    if (!houseSnap.exists) {
      throw new HttpsError('not-found', 'El piso ya no existe.');
    }
    const data = houseSnap.data();
    if ((data.members || []).includes(uid)) {
      yaEraMiembro = true;
      return;
    }
    if ((data.members || []).length >= MAX_MIEMBROS_PISO) {
      throw new HttpsError('failed-precondition', 'Este piso ya tiene el máximo de miembros.');
    }
    tx.update(householdRef, {
      members: FieldValue.arrayUnion(uid),
      [`memberProfiles.${uid}`]: { displayName, photoUrl, joinedAt: FieldValue.serverTimestamp() },
    });
    tx.set(db.collection('users').doc(uid), { activeHouseholdId: householdId }, { merge: true });
  });

  return { ok: true, householdId, yaEraMiembro };
});

// =============================================================================
// TAREAS — aritmética de ancla compartida (mismas reglas que
// ConviveTask.ocurreEnDia/asignadoEnDia en lib/models/task.dart -- si se
// cambia una, hay que cambiar la otra)
// =============================================================================

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

// Clave de día en UTC -- mismo criterio horario que usa el cron (04:00 UTC),
// para no mezclar dos formas distintas de decidir "qué día es hoy".
function claveDia(ms) {
  const d = new Date(ms);
  return `${d.getUTCFullYear()}-${d.getUTCMonth() + 1}-${d.getUTCDate()}`;
}

// =============================================================================
// 3. COMPLETAR TAREA
// =============================================================================
// Ya no "avanza una rotación" -- la asignación es pura aritmética sobre la
// fecha ancla (ver arriba), así que completar solo dos cosas: registra el
// historial de hoy y anota que hoy ya se completó, para que no se pueda
// repetir. Transaccional para que dos toques casi simultáneos no cuenten
// los dos.
exports.completeTask = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  }
  const uid = request.auth.uid;
  const householdId = request.data?.householdId;
  const taskId = request.data?.taskId;
  if (!householdId || !taskId) {
    throw new HttpsError('invalid-argument', 'Faltan datos.');
  }

  const householdRef = db.collection('households').doc(householdId);
  const taskRef = householdRef.collection('tasks').doc(taskId);

  const resultado = await db.runTransaction(async (tx) => {
    const [houseSnap, taskSnap] = await Promise.all([tx.get(householdRef), tx.get(taskRef)]);
    if (!houseSnap.exists) throw new HttpsError('not-found', 'El piso no existe.');
    if (!(houseSnap.data().members || []).includes(uid)) {
      throw new HttpsError('permission-denied', 'No perteneces a este piso.');
    }
    if (!taskSnap.exists) throw new HttpsError('not-found', 'La tarea no existe.');
    const task = taskSnap.data();

    const ahoraMs = Date.now();
    if (task.lastCompletionDay === claveDia(ahoraMs)) {
      // Sin este freno, cada toque de "Hecho" crea una compleción nueva sin
      // límite -- se puede completar la misma tarea decenas de veces
      // seguidas en segundos.
      throw new HttpsError('failed-precondition', 'Esta tarea ya se ha marcado como hecha hoy.');
    }
    if (task.anchorDate && !ocurreEnDia(task, ahoraMs)) {
      // Defensivo -- la UI no debería dejar llegar aquí si hoy no le toca,
      // pero si pasa (p.ej. dos pestañas abiertas) no debe colar un dato falso.
      throw new HttpsError('failed-precondition', 'Esta tarea no toca hoy.');
    }

    const completionRef = householdRef.collection('completions').doc();
    tx.set(completionRef, {
      taskId,
      taskTitle: task.title || '',
      assigneeUid: task.anchorDate ? asignadoEnDia(task, ahoraMs) : (task.currentAssigneeUid || null),
      occurrenceDate: Timestamp.fromMillis(medianocheUTC(ahoraMs)),
      status: 'done',
      completedAt: FieldValue.serverTimestamp(),
      completedBy: uid,
    });

    tx.update(taskRef, { lastCompletionDay: claveDia(ahoraMs) });
    return { completionId: completionRef.id };
  });

  return { ok: true, ...resultado };
});

// =============================================================================
// 4. REGISTRAR TAREAS FALLADAS — cada día a las 04:00 UTC
// =============================================================================
// Ya no hace falta "cerrar periodos" ni avanzar nada -- la asignación es
// aritmética pura. El cron solo comprueba si la ocurrencia de AYER de cada
// tarea se completó; si no, la registra como "missed" para que el
// calendario e historial reflejen la realidad.
exports.generateRecurringPeriods = onSchedule(
  { schedule: 'every day 04:00', timeZone: 'UTC', region: REGION },
  async () => {
    const ayerMs = Date.now() - DIA_MS;
    const claveAyer = claveDia(ayerMs);
    const householdsSnap = await db.collection('households').get();

    for (const houseDoc of householdsSnap.docs) {
      const tasksSnap = await houseDoc.ref.collection('tasks')
          .where('active', '==', true)
          .get();
      if (tasksSnap.empty) continue;

      const batch = db.batch();
      let cambios = 0;

      for (const taskDoc of tasksSnap.docs) {
        const task = taskDoc.data();
        if (!task.anchorDate) continue; // tarea antigua sin sistema de ancla
        if (task.lastCompletionDay === claveAyer) continue; // se completó ayer
        if (!ocurreEnDia(task, ayerMs)) continue; // a esta tarea no le tocaba ayer

        const completionRef = houseDoc.ref.collection('completions').doc();
        batch.set(completionRef, {
          taskId: taskDoc.id,
          taskTitle: task.title || '',
          assigneeUid: asignadoEnDia(task, ayerMs),
          occurrenceDate: Timestamp.fromMillis(medianocheUTC(ayerMs)),
          status: 'missed',
          completedAt: null,
          completedBy: null,
        });
        cambios++;
      }

      if (cambios > 0) await batch.commit();
    }
  }
);
