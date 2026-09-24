// functions/index.js
// Cloud Functions para Convive — piso y tareas rotativas.
// Deploy: firebase deploy --only functions

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule }         = require('firebase-functions/v2/scheduler');
const { onDocumentCreated }  = require('firebase-functions/v2/firestore');
const { initializeApp }      = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging }       = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

// =============================================================================
// NOTIFICACIONES — helpers compartidos
// =============================================================================
const PREFS_POR_DEFECTO = {
  tareaHoy: true,
  tareaFallada: false,
  pagoManana: true,
  nuevoGasto: true,
  nuevaNota: true,
  nuevoMensaje: true,
  resumenSemanalDeudas: false,
};

async function prefsDe(uid) {
  const snap = await db.collection('users').doc(uid).get();
  const guardadas = snap.exists ? snap.data().notificationPrefs : null;
  return { ...PREFS_POR_DEFECTO, ...(guardadas || {}) };
}

// No lanza si falla -- un token caducado o sin permiso de un usuario no debe
// tumbar el envío al resto ni la función que lo llama.
async function enviarPush(uid, title, body, data) {
  try {
    const snap = await db.collection('users').doc(uid).get();
    const token = snap.data()?.fcmToken;
    if (!token) return;
    await getMessaging().send({ token, notification: { title, body }, data: data || {} });
  } catch (e) {
    console.error('enviarPush: fallo notificando a', uid, e);
  }
}

function calcularBalances(expenses) {
  const balances = {};
  for (const e of expenses) {
    balances[e.paidByUid] = (balances[e.paidByUid] || 0) + e.amount;
    for (const [uid, valor] of Object.entries(e.splits || {})) {
      balances[uid] = (balances[uid] || 0) - valor;
    }
  }
  return balances;
}

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
// NICKNAME — cambia el nombre visible en notas/tareas/chat
// =============================================================================
// households/{hid} solo se puede escribir vía Cloud Function (ver
// firestore.rules), así que un cambio de nickname necesita pasar por aquí
// para sincronizarse también en el piso activo -- si no, el cambio se
// quedaría solo en users/{uid} y nunca se vería reflejado en las notas o
// tareas ya existentes de tu piso.
exports.updateNickname = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const nickname = typeof request.data?.nickname === 'string' ? request.data.nickname.trim() : '';
  if (!nickname || nickname.length > 40) {
    throw new HttpsError('invalid-argument', 'Nombre inválido.');
  }

  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  const activeHouseholdId = userSnap.exists ? userSnap.data().activeHouseholdId : null;

  const batch = db.batch();
  batch.set(userRef, { displayName: nickname }, { merge: true });
  if (activeHouseholdId) {
    batch.update(db.collection('households').doc(activeHouseholdId), {
      [`memberProfiles.${uid}.displayName`]: nickname,
    });
  }
  await batch.commit();

  return { ok: true };
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

// =============================================================================
// 5. NOTIFICAR TAREAS DEL DÍA — cada día a las 09:00 hora de España
// =============================================================================
// Un solo mensaje por persona agrupando todas sus tareas de hoy (no uno por
// tarea) -- justo el criterio de "sin exceso de notificaciones" que se
// acordó. También avisa de lo que se quedó sin hacer ayer, si esa persona
// tiene esa categoría activada (OFF por defecto, es la única "regañina").
exports.notificarTareasDelDia = onSchedule(
  { schedule: 'every day 09:00', timeZone: 'Europe/Madrid', region: REGION },
  async () => {
    const hoyMs = Date.now();
    const ayerMs = hoyMs - DIA_MS;
    const householdsSnap = await db.collection('households').get();

    for (const houseDoc of householdsSnap.docs) {
      const tasksSnap = await houseDoc.ref.collection('tasks').where('active', '==', true).get();
      if (tasksSnap.empty) continue;

      const hoyPorUid = {};
      const ayerPorUid = {};
      for (const taskDoc of tasksSnap.docs) {
        const task = taskDoc.data();
        if (!task.anchorDate) continue;

        const hoyUid = asignadoEnDia(task, hoyMs);
        if (hoyUid) (hoyPorUid[hoyUid] ||= []).push(task.title || 'tarea');

        if (ocurreEnDia(task, ayerMs) && task.lastCompletionDay !== claveDia(ayerMs)) {
          const ayerUid = asignadoEnDia(task, ayerMs);
          if (ayerUid) (ayerPorUid[ayerUid] ||= []).push(task.title || 'tarea');
        }
      }

      const uids = new Set([...Object.keys(hoyPorUid), ...Object.keys(ayerPorUid)]);
      for (const uid of uids) {
        const prefs = await prefsDe(uid);
        if (prefs.tareaHoy && hoyPorUid[uid]?.length) {
          await enviarPush(uid, 'Convive', `Hoy te toca: ${hoyPorUid[uid].join(', ')}`, { type: 'tareaHoy' });
        }
        if (prefs.tareaFallada && ayerPorUid[uid]?.length) {
          await enviarPush(uid, 'Convive', `Ayer se quedó sin hacer: ${ayerPorUid[uid].join(', ')}`, { type: 'tareaFallada' });
        }
      }
    }
  }
);

// =============================================================================
// 6. NOTIFICAR PAGOS QUE VENCEN MAÑANA — cada día a las 19:00 hora de España
// =============================================================================
exports.notificarPagosManana = onSchedule(
  { schedule: 'every day 19:00', timeZone: 'Europe/Madrid', region: REGION },
  async () => {
    const mananaMs = Date.now() + DIA_MS;
    const mananaDate = new Date(mananaMs);
    const householdsSnap = await db.collection('households').get();

    for (const houseDoc of householdsSnap.docs) {
      const remindersSnap = await houseDoc.ref.collection('reminders').get();
      if (remindersSnap.empty) continue;

      const claveManana = claveDia(mananaMs);
      const titulosDeManana = [];
      const refsAActualizar = [];

      for (const remDoc of remindersSnap.docs) {
        const rem = remDoc.data();
        if (rem.lastNotifiedDay === claveManana) continue; // ya avisado para ese día
        const ocurreManana = rem.recurring
          ? mananaDate.getUTCDate() === Math.min(Math.max(Number(rem.dueDay) || 1, 1), 28)
          : rem.dueDate && claveDia(rem.dueDate.toMillis()) === claveManana;
        if (!ocurreManana) continue;
        titulosDeManana.push(rem.title || 'recordatorio');
        refsAActualizar.push(remDoc.ref);
      }
      if (titulosDeManana.length === 0) continue;

      const houseData = houseDoc.data();
      for (const uid of houseData.members || []) {
        const prefs = await prefsDe(uid);
        if (!prefs.pagoManana) continue;
        await enviarPush(uid, 'Convive', `Mañana vence: ${titulosDeManana.join(', ')}`, { type: 'pagoManana' });
      }
      await Promise.all(refsAActualizar.map((ref) => ref.update({ lastNotifiedDay: claveManana })));
    }
  }
);

// =============================================================================
// 7. NOTIFICAR RESUMEN SEMANAL DE DEUDAS — domingos a las 18:00 hora de España
// =============================================================================
exports.notificarResumenSemanal = onSchedule(
  { schedule: '0 18 * * 0', timeZone: 'Europe/Madrid', region: REGION },
  async () => {
    const householdsSnap = await db.collection('households').get();
    for (const houseDoc of householdsSnap.docs) {
      const expensesSnap = await houseDoc.ref.collection('expenses').get();
      if (expensesSnap.empty) continue;
      const balances = calcularBalances(expensesSnap.docs.map((d) => d.data()));

      for (const [uid, saldo] of Object.entries(balances)) {
        if (Math.abs(saldo) < 0.005) continue;
        const prefs = await prefsDe(uid);
        if (!prefs.resumenSemanalDeudas) continue;
        const mensaje = saldo > 0
          ? `Te deben ${saldo.toFixed(2)}€`
          : `Debes ${Math.abs(saldo).toFixed(2)}€`;
        await enviarPush(uid, 'Convive', mensaje, { type: 'resumenSemanalDeudas' });
      }
    }
  }
);

// =============================================================================
// 8. NOTIFICAR GASTO NUEVO — al crearse un gasto
// =============================================================================
exports.notificarGastoNuevo = onDocumentCreated(
  { document: 'households/{householdId}/expenses/{expenseId}', region: REGION },
  async (event) => {
    const gasto = event.data.data();
    const { householdId } = event.params;
    const houseSnap = await db.collection('households').doc(householdId).get();
    if (!houseSnap.exists) return;
    const nombrePagador = houseSnap.data().memberProfiles?.[gasto.paidByUid]?.displayName || 'Alguien';

    for (const uid of Object.keys(gasto.splits || {})) {
      if (uid === gasto.paidByUid) continue; // no hace falta avisar a quien ya lo sabe -- lo pagó él
      const prefs = await prefsDe(uid);
      if (!prefs.nuevoGasto) continue;
      await enviarPush(uid, 'Convive', `${nombrePagador} ha añadido un gasto: ${gasto.description} (${Number(gasto.amount).toFixed(2)}€)`, { type: 'nuevoGasto' });
    }
  }
);

// =============================================================================
// 9. NOTIFICAR NOTA NUEVA — al clavar una nota
// =============================================================================
exports.notificarNotaNueva = onDocumentCreated(
  { document: 'households/{householdId}/notes/{noteId}', region: REGION },
  async (event) => {
    const nota = event.data.data();
    const { householdId } = event.params;
    const houseSnap = await db.collection('households').doc(householdId).get();
    if (!houseSnap.exists) return;
    const houseData = houseSnap.data();
    const nombreAutor = houseData.memberProfiles?.[nota.authorUid]?.displayName || 'Alguien';

    for (const uid of houseData.members || []) {
      if (uid === nota.authorUid) continue;
      const prefs = await prefsDe(uid);
      if (!prefs.nuevaNota) continue;
      await enviarPush(uid, 'Convive', `${nombreAutor} ha clavado una nota: ${nota.text}`, { type: 'nuevaNota' });
    }
  }
);

// =============================================================================
// 10. NOTIFICAR MENSAJE NUEVO — al enviar un mensaje de chat
// =============================================================================
exports.notificarMensajeNuevo = onDocumentCreated(
  { document: 'households/{householdId}/messages/{messageId}', region: REGION },
  async (event) => {
    const mensaje = event.data.data();
    const { householdId } = event.params;
    const houseSnap = await db.collection('households').doc(householdId).get();
    if (!houseSnap.exists) return;
    const houseData = houseSnap.data();
    const nombreAutor = houseData.memberProfiles?.[mensaje.authorUid]?.displayName || 'Alguien';

    for (const uid of houseData.members || []) {
      if (uid === mensaje.authorUid) continue;
      const prefs = await prefsDe(uid);
      if (!prefs.nuevoMensaje) continue;
      await enviarPush(uid, nombreAutor, mensaje.text, { type: 'nuevoMensaje' });
    }
  }
);
