// functions/index.js
// Cloud Functions para Convive — piso, tareas, conflictos y mediación con IA.
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
// TAREAS — utilidades de periodo/rotación compartidas
// =============================================================================

// Misma lógica en ms para las tres recurrencias — nada de calendario "real"
// (meses de distinta duración, etc.), un piso no lo necesita.
function duracionPeriodoMs(recurrence) {
  const DIA_MS = 24 * 60 * 60 * 1000;
  switch (recurrence?.type) {
    case 'daily': return DIA_MS;
    case 'weekly': return 7 * DIA_MS;
    case 'every_n_days': {
      const dias = Number(recurrence.intervalDays) || 1;
      return Math.max(1, dias) * DIA_MS;
    }
    default: return DIA_MS;
  }
}

// Avanza la rotación de una tarea una posición y calcula el nuevo periodo.
// Devuelve el objeto de campos a escribir sobre el doc de la tarea.
function siguienteEstadoRotacion(taskData, desdeMs) {
  const orden = taskData.rotationOrder || [];
  const actual = typeof taskData.rotationIndex === 'number' ? taskData.rotationIndex : 0;
  const nuevoIndex = orden.length > 0 ? (actual + 1) % orden.length : 0;
  const nuevoAsignado = orden.length > 0 ? orden[nuevoIndex] : null;
  const duracion = duracionPeriodoMs(taskData.recurrence);
  return {
    rotationIndex: nuevoIndex,
    currentAssigneeUid: nuevoAsignado,
    currentPeriodStart: Timestamp.fromMillis(desdeMs),
    currentPeriodEnd: Timestamp.fromMillis(desdeMs + duracion),
  };
}

// =============================================================================
// 3. COMPLETAR TAREA
// =============================================================================
// Transaccional: escribe el registro de historial Y avanza la rotación a la
// vez — si dos compañeros le dan a "hecho" casi al mismo tiempo, solo uno
// de los dos debe contar y avanzar la rotación, nunca los dos.
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
    const completionRef = householdRef.collection('completions').doc();
    tx.set(completionRef, {
      taskId,
      taskTitle: task.title || '',
      assigneeUid: task.currentAssigneeUid || null,
      periodStart: task.currentPeriodStart || null,
      periodEnd: task.currentPeriodEnd || null,
      status: 'done',
      completedAt: FieldValue.serverTimestamp(),
      completedBy: uid,
    });

    tx.update(taskRef, siguienteEstadoRotacion(task, ahoraMs));
    return { completionId: completionRef.id };
  });

  return { ok: true, ...resultado };
});

// =============================================================================
// 4. CERRAR PERIODOS VENCIDOS — cada día a las 04:00 UTC
// =============================================================================
// Si nadie marcó una tarea como hecha antes de que acabara su periodo, se
// registra como "missed" (dato real para el mediador: "no se hizo", no
// "se hizo tarde") y se avanza igualmente la rotación para que no se quede
// bloqueada en la misma persona para siempre.
exports.generateRecurringPeriods = onSchedule(
  { schedule: 'every day 04:00', timeZone: 'UTC', region: REGION },
  async () => {
    const ahoraMs = Date.now();
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
        const periodEndMs = task.currentPeriodEnd?.toMillis?.();
        if (typeof periodEndMs !== 'number' || periodEndMs > ahoraMs) continue;

        const completionRef = houseDoc.ref.collection('completions').doc();
        batch.set(completionRef, {
          taskId: taskDoc.id,
          taskTitle: task.title || '',
          assigneeUid: task.currentAssigneeUid || null,
          periodStart: task.currentPeriodStart || null,
          periodEnd: task.currentPeriodEnd || null,
          status: 'missed',
          completedAt: null,
          completedBy: null,
        });
        batch.update(taskDoc.ref, siguienteEstadoRotacion(task, periodEndMs));
        cambios++;
      }

      if (cambios > 0) await batch.commit();
    }
  }
);
