// functions/index.js
// Cloud Functions para Convive — piso y tareas rotativas.
// Deploy: firebase deploy --only functions

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule }         = require('firebase-functions/v2/scheduler');
const { onDocumentCreated }  = require('firebase-functions/v2/firestore');
const { initializeApp }      = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging }       = require('firebase-admin/messaging');
const {
  DIA_MS,
  medianocheUTC,
  ocurreEnDia,
  asignadoEnDia,
  asignadosEnDia,
  claveDia,
} = require('./task_logic');

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
  // Clave de idempotencia que genera el cliente una vez por intento de
  // creación y reutiliza en cualquier reintento (p.ej. si el timeout salta
  // en el cliente por mala cobertura pero la función ya había terminado en
  // el servidor) -- sin esto, cada reintento crea un piso duplicado de
  // verdad, con el mismo nombre y un solo miembro. Ver
  // householdCreateRequests más abajo.
  const requestId = typeof request.data?.requestId === 'string' ? request.data.requestId : null;

  if (requestId) {
    const reqSnap = await db.collection('householdCreateRequests').doc(requestId).get();
    if (reqSnap.exists) {
      const { householdId, joinCode } = reqSnap.data();
      return { ok: true, householdId, joinCode };
    }
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
    tx.set(db.collection('users').doc(uid), {
      activeHouseholdId: householdRef.id,
      householdIds: FieldValue.arrayUnion(householdRef.id),
    }, { merge: true });
    if (requestId) {
      tx.set(db.collection('householdCreateRequests').doc(requestId), {
        householdId: householdRef.id,
        joinCode,
        uid,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  });

  return { ok: true, householdId: householdRef.id, joinCode };
});

// Límite de intentos por cuenta -- el espacio de códigos (32 caracteres ^ 6
// ≈ 1070 millones de combinaciones) ya es una defensa razonable por sí solo,
// pero esto añade una segunda capa contra ir probando códigos al azar desde
// una sola cuenta. Solo cuentan los intentos FALLIDOS (código equivocado),
// para no penalizar a alguien que de verdad se une a varios pisos seguidos.
const JOIN_RATE_LIMIT_VENTANA_MS = 15 * 60 * 1000;
const JOIN_RATE_LIMIT_MAX_INTENTOS = 10;

async function joinEstaBloqueado(uid) {
  const snap = await db.collection('joinAttempts').doc(uid).get();
  if (!snap.exists) return false;
  const data = snap.data();
  if (Date.now() - data.ventanaInicio >= JOIN_RATE_LIMIT_VENTANA_MS) return false;
  return data.intentos >= JOIN_RATE_LIMIT_MAX_INTENTOS;
}

async function joinRegistrarIntentoFallido(uid) {
  const ref = db.collection('joinAttempts').doc(uid);
  const ahoraMs = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : null;
    const dentroDeVentana = data && ahoraMs - data.ventanaInicio < JOIN_RATE_LIMIT_VENTANA_MS;
    tx.set(ref, {
      intentos: dentroDeVentana ? data.intentos + 1 : 1,
      ventanaInicio: dentroDeVentana ? data.ventanaInicio : ahoraMs,
    });
  });
}

// =============================================================================
// 2. UNIRSE A UN PISO
// =============================================================================
exports.joinHousehold = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  }
  const uid = request.auth.uid;
  if (await joinEstaBloqueado(uid)) {
    throw new HttpsError('resource-exhausted', 'Demasiados intentos. Espera unos minutos y vuelve a intentarlo.');
  }
  const raw = typeof request.data?.joinCode === 'string' ? request.data.joinCode : '';
  const joinCode = raw.trim().toUpperCase();
  if (!joinCode) {
    throw new HttpsError('invalid-argument', 'Código de piso inválido.');
  }

  const codeSnap = await db.collection('joinCodes').doc(joinCode).get();
  if (!codeSnap.exists) {
    await joinRegistrarIntentoFallido(uid);
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
    yaEraMiembro = (data.members || []).includes(uid);
    if (!yaEraMiembro) {
      if ((data.members || []).length >= MAX_MIEMBROS_PISO) {
        throw new HttpsError('failed-precondition', 'Este piso ya tiene el máximo de miembros.');
      }
      tx.update(householdRef, {
        members: FieldValue.arrayUnion(uid),
        [`memberProfiles.${uid}`]: { displayName, photoUrl, joinedAt: FieldValue.serverTimestamp() },
      });
    }
    // Entrar con un código, aunque ya fueras miembro, se trata como "quiero
    // cambiar a este piso ahora" -- cambia el activo siempre.
    tx.set(db.collection('users').doc(uid), {
      activeHouseholdId: householdId,
      householdIds: FieldValue.arrayUnion(householdId),
    }, { merge: true });
  });

  // Código correcto -- se olvida cualquier racha de intentos fallidos previa.
  await db.collection('joinAttempts').doc(uid).delete().catch(() => {});

  return { ok: true, householdId, yaEraMiembro };
});

// =============================================================================
// NICKNAME — cambia el nombre visible en notas/tareas/chat
// =============================================================================
// households/{hid} solo se puede escribir vía Cloud Function (ver
// firestore.rules), así que un cambio de nickname necesita pasar por aquí
// para sincronizarse en todos los pisos del usuario -- no solo el activo,
// porque con varios pisos (ver más abajo) el mismo nombre debe verse igual
// en cada uno, no solo en el que tengas abierto ahora mismo.
exports.updateNickname = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const nickname = typeof request.data?.nickname === 'string' ? request.data.nickname.trim() : '';
  if (!nickname || nickname.length > 40) {
    throw new HttpsError('invalid-argument', 'Nombre inválido.');
  }

  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  const householdIds = userSnap.exists ? (userSnap.data().householdIds || []) : [];

  const batch = db.batch();
  batch.set(userRef, { displayName: nickname }, { merge: true });
  for (const hid of householdIds) {
    batch.update(db.collection('households').doc(hid), {
      [`memberProfiles.${uid}.displayName`]: nickname,
    });
  }
  await batch.commit();

  return { ok: true };
});

// =============================================================================
// PISOS — cambiar de piso activo y salir de un piso
// =============================================================================
exports.switchActiveHousehold = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const householdId = request.data?.householdId;
  if (!householdId) throw new HttpsError('invalid-argument', 'Falta el piso.');

  const houseSnap = await db.collection('households').doc(householdId).get();
  if (!houseSnap.exists || !(houseSnap.data().members || []).includes(uid)) {
    throw new HttpsError('permission-denied', 'No perteneces a ese piso.');
  }
  await db.collection('users').doc(uid).set({ activeHouseholdId: householdId }, { merge: true });
  return { ok: true };
});

exports.leaveHousehold = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const householdId = request.data?.householdId;
  if (!householdId) throw new HttpsError('invalid-argument', 'Falta el piso.');

  const householdRef = db.collection('households').doc(householdId);
  const userRef = db.collection('users').doc(uid);

  let quedaVacio = false;

  await db.runTransaction(async (tx) => {
    const [houseSnap, userSnap] = await Promise.all([tx.get(householdRef), tx.get(userRef)]);
    if (houseSnap.exists) {
      const restantes = (houseSnap.data().members || []).filter((m) => m !== uid);
      quedaVacio = restantes.length === 0;
      tx.update(householdRef, {
        members: FieldValue.arrayRemove(uid),
        [`memberProfiles.${uid}`]: FieldValue.delete(),
      });
    }
    const householdIds = ((userSnap.data() || {}).householdIds || []).filter((id) => id !== householdId);
    const eraActivo = (userSnap.data() || {}).activeHouseholdId === householdId;
    tx.set(userRef, {
      householdIds: FieldValue.arrayRemove(householdId),
      // Si te vas del que tenías abierto, se cambia solo a otro que te
      // quede (o a ninguno) -- no puedes quedarte "viendo" un piso del que
      // ya no formas parte.
      activeHouseholdId: eraActivo ? (householdIds[0] || null) : (userSnap.data() || {}).activeHouseholdId,
    }, { merge: true });
  });

  // Si ya no le queda nadie dentro, el piso no sirve para nada -- caso real
  // que motivó esto: un piso temporal de una semana con amigos que nadie
  // quiere seguir teniendo ahí una vez termina. Se borra de verdad
  // (tareas/notas/chat/gastos/recordatorios incluidos), no se deja como
  // basura huérfana en Firestore para siempre. Fuera de la transacción
  // porque recursiveDelete no es transaccional.
  if (quedaVacio) {
    await db.recursiveDelete(householdRef);
    const codigosViejos = await db.collection('joinCodes').where('householdId', '==', householdId).get();
    await Promise.all(codigosViejos.docs.map((d) => d.ref.delete()));
  }

  return { ok: true };
});

// =============================================================================
// TAREAS — aritmética de ancla compartida (ver ./task_logic.js -- mismas
// reglas que ConviveTask.ocurreEnDia/asignadoEnDia en lib/models/task.dart,
// si se cambia una hay que cambiar la otra)
// =============================================================================

// =============================================================================
// 3. COMPLETAR TAREA
// =============================================================================
// Ya no "avanza una rotación" -- la asignación es pura aritmética sobre la
// fecha ancla (ver arriba), así que completar solo dos cosas: registra el
// historial de hoy y anota que hoy ya se completó, para que no se pueda
// repetir. Transaccional para que dos toques casi simultáneos no cuenten
// los dos.
// [occurrenceDateMs] es opcional -- si no se manda, es "hoy" (comportamiento
// de siempre). Si se manda un día pasado (hasta CORRECCION_MAX_DIAS atrás),
// permite corregir "se me olvidó pulsar Hecho ese día" sin tener que dejar
// la tarea marcada como "missed" para siempre -- queja real encontrada en
// apps de la competencia (Sweepy: no se puede marcar hecha una tarea de un
// día anterior).
const CORRECCION_MAX_DIAS = 7;

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
  const ahoraMs = Date.now();
  const ocurrenciaMs = typeof request.data?.occurrenceDateMs === 'number'
      ? request.data.occurrenceDateMs
      : ahoraMs;
  const esHoy = claveDia(ocurrenciaMs) === claveDia(ahoraMs);
  if (medianocheUTC(ocurrenciaMs) > medianocheUTC(ahoraMs)) {
    throw new HttpsError('invalid-argument', 'No se puede completar un día futuro.');
  }
  if (medianocheUTC(ahoraMs) - medianocheUTC(ocurrenciaMs) > CORRECCION_MAX_DIAS * DIA_MS) {
    throw new HttpsError('invalid-argument', `Solo se puede corregir hasta ${CORRECCION_MAX_DIAS} días atrás.`);
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

    if (esHoy && task.lastCompletionDay === claveDia(ahoraMs)) {
      // Sin este freno, cada toque de "Hecho" crea una compleción nueva sin
      // límite -- se puede completar la misma tarea decenas de veces
      // seguidas en segundos.
      throw new HttpsError('failed-precondition', 'Esta tarea ya se ha marcado como hecha hoy.');
    }
    if (task.anchorDate && !ocurreEnDia(task, ocurrenciaMs)) {
      // Defensivo -- la UI no debería dejar llegar aquí si ese día no le
      // tocaba, pero si pasa no debe colar un dato falso.
      throw new HttpsError('failed-precondition', 'Esta tarea no toca ese día.');
    }

    if (!esHoy) {
      // El historial es append-only (no se puede reescribir un "missed"
      // existente para ese día), así que hay que comprobar a mano que no
      // se esté duplicando un "done" que ya se corrigió antes.
      const historialSnap = await tx.get(householdRef.collection('completions').where('taskId', '==', taskId));
      const claveOcurrencia = claveDia(ocurrenciaMs);
      const yaHecho = historialSnap.docs.some((docSnap) => {
        const c = docSnap.data();
        return c.status === 'done' && c.occurrenceDate && claveDia(c.occurrenceDate.toMillis()) === claveOcurrencia;
      });
      if (yaHecho) {
        throw new HttpsError('failed-precondition', 'Ese día ya estaba marcado como hecho.');
      }
    }

    const completionRef = householdRef.collection('completions').doc();
    tx.set(completionRef, {
      taskId,
      taskTitle: task.title || '',
      assigneeUids: task.anchorDate ? asignadosEnDia(task, ocurrenciaMs) : [],
      occurrenceDate: Timestamp.fromMillis(medianocheUTC(ocurrenciaMs)),
      status: 'done',
      completedAt: FieldValue.serverTimestamp(),
      completedBy: uid,
    });

    if (esHoy) {
      tx.update(taskRef, { lastCompletionDay: claveDia(ahoraMs) });
    }

    // Mensaje de sistema en el chat -- feed de actividad del piso, para que
    // el chat de Convive muestre cosas que WhatsApp no puede (que alguien
    // completó una tarea), sin generar un push nuevo (ver notificarMensajeNuevo).
    const nombreCompletador = houseSnap.data().memberProfiles?.[uid]?.displayName || 'Alguien';
    tx.set(householdRef.collection('messages').doc(), {
      type: 'system',
      event: 'taskCompleted',
      eventData: { memberName: nombreCompletador, taskTitle: task.title || '' },
      createdAt: FieldValue.serverTimestamp(),
    });

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
          assigneeUids: asignadosEnDia(task, ayerMs),
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

        for (const hoyUid of asignadosEnDia(task, hoyMs)) {
          (hoyPorUid[hoyUid] ||= []).push(task.title || 'tarea');
        }

        if (ocurreEnDia(task, ayerMs) && task.lastCompletionDay !== claveDia(ayerMs)) {
          for (const ayerUid of asignadosEnDia(task, ayerMs)) {
            (ayerPorUid[ayerUid] ||= []).push(task.title || 'tarea');
          }
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
    const houseData = houseSnap.data();

    // Un settlement (botón "He cobrado") es un gasto especial que salda una
    // deuda, no una compra nueva -- avisar de eso como "gasto nuevo" sería
    // engañoso (hablaría de una compra que no existió). Aviso y mensaje de
    // chat propios en su lugar.
    if (gasto.isSettlement) {
      const deudorUid = gasto.paidByUid;
      const acreedorUid = Object.keys(gasto.splits || {})[0];
      const nombreDeudor = houseData.memberProfiles?.[deudorUid]?.displayName || 'Alguien';
      const nombreAcreedor = houseData.memberProfiles?.[acreedorUid]?.displayName || 'Alguien';

      const prefs = await prefsDe(deudorUid);
      if (prefs.nuevoGasto) {
        await enviarPush(
          deudorUid,
          'Convive',
          `${nombreAcreedor} ha confirmado que le pagaste ${Number(gasto.amount).toFixed(2)}€`,
          { type: 'deudaSaldada' },
        );
      }

      await db.collection('households').doc(householdId).collection('messages').add({
        type: 'system',
        event: 'debtSettled',
        eventData: { fromName: nombreDeudor, toName: nombreAcreedor, amount: Number(gasto.amount) || 0 },
        createdAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    const nombrePagador = houseData.memberProfiles?.[gasto.paidByUid]?.displayName || 'Alguien';

    for (const uid of Object.keys(gasto.splits || {})) {
      if (uid === gasto.paidByUid) continue; // no hace falta avisar a quien ya lo sabe -- lo pagó él
      const prefs = await prefsDe(uid);
      if (!prefs.nuevoGasto) continue;
      await enviarPush(uid, 'Convive', `${nombrePagador} ha añadido un gasto: ${gasto.description} (${Number(gasto.amount).toFixed(2)}€)`, { type: 'nuevoGasto' });
    }

    await db.collection('households').doc(householdId).collection('messages').add({
      type: 'system',
      event: 'expenseAdded',
      eventData: { memberName: nombrePagador, description: gasto.description || '', amount: Number(gasto.amount) || 0 },
      createdAt: FieldValue.serverTimestamp(),
    });
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

    await db.collection('households').doc(householdId).collection('messages').add({
      type: 'system',
      event: 'noteAdded',
      eventData: { memberName: nombreAutor, text: nota.text || '' },
      createdAt: FieldValue.serverTimestamp(),
    });
  }
);

// =============================================================================
// 9b. FEED DE ACTIVIDAD — recordatorio nuevo (sin push propio todavía, solo
// mensaje de sistema en el chat)
// =============================================================================
exports.agregarMensajeRecordatorioNuevo = onDocumentCreated(
  { document: 'households/{householdId}/reminders/{reminderId}', region: REGION },
  async (event) => {
    const recordatorio = event.data.data();
    const { householdId } = event.params;
    const houseSnap = await db.collection('households').doc(householdId).get();
    if (!houseSnap.exists) return;
    const nombreAutor = houseSnap.data().memberProfiles?.[recordatorio.createdBy]?.displayName || 'Alguien';

    await db.collection('households').doc(householdId).collection('messages').add({
      type: 'system',
      event: 'reminderAdded',
      eventData: { memberName: nombreAutor, title: recordatorio.title || '' },
      createdAt: FieldValue.serverTimestamp(),
    });
  }
);

// =============================================================================
// 10. NOTIFICAR MENSAJE NUEVO — al enviar un mensaje de chat
// =============================================================================
exports.notificarMensajeNuevo = onDocumentCreated(
  { document: 'households/{householdId}/messages/{messageId}', region: REGION },
  async (event) => {
    const mensaje = event.data.data();
    // Los mensajes de sistema (feed de actividad: tarea completada, gasto/
    // nota nuevos) ya generan su propio aviso específico donde corresponde
    // -- avisar aquí también sería un push duplicado para quien tenga las
    // dos categorías activadas.
    if (mensaje.type === 'system') return;
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
