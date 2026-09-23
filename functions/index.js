// functions/index.js
// Cloud Functions para Convive — piso, tareas, conflictos y mediación con IA.
// Deploy: firebase deploy --only functions

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule }         = require('firebase-functions/v2/scheduler');
const { defineSecret }       = require('firebase-functions/params');
const { initializeApp }      = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging }       = require('firebase-admin/messaging');

const _anthropicKey = defineSecret('ANTHROPIC_API_KEY');

initializeApp();
const db = getFirestore();

const REGION = 'europe-west1';
const MAX_MIEMBROS_PISO = 10;
const CONFLICT_TIMEOUT_HORAS = 48;
const FOLLOWUP_DELAY_DIAS = 3;
const HISTORIAL_MEDIACION_DIAS = 14;
const MEDIATION_MODEL = 'claude-sonnet-5';

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

// =============================================================================
// CONFLICTOS — mediación con IA
// =============================================================================

// Agrega el historial de tareas de los últimos HISTORIAL_MEDIACION_DIAS días
// por persona y tarea — el dato objetivo que evita que el mediador arbitre
// "él dice, ella dice" a ciegas.
async function resumenHistorialTareas(householdId) {
  const desde = Timestamp.fromMillis(Date.now() - HISTORIAL_MEDIACION_DIAS * 24 * 60 * 60 * 1000);
  const snap = await db.collection('households').doc(householdId)
      .collection('completions')
      .where('completedAt', '>=', desde)
      .get();

  const porUid = {};
  snap.forEach((doc) => {
    const d = doc.data();
    const uid = d.completedBy || d.assigneeUid;
    if (!uid) return;
    const titulo = d.taskTitle || 'tarea';
    porUid[uid] = porUid[uid] || {};
    porUid[uid][titulo] = porUid[uid][titulo] || { done: 0, missed: 0 };
    if (d.status === 'done') porUid[uid][titulo].done++;
    else if (d.status === 'missed') porUid[uid][titulo].missed++;
  });
  return porUid;
}

function formatearHistorialPersona(nombre, tareas) {
  if (!tareas || Object.keys(tareas).length === 0) {
    return `${nombre}: sin datos de tareas en los últimos ${HISTORIAL_MEDIACION_DIAS} días.`;
  }
  const lineas = Object.entries(tareas)
      .map(([titulo, s]) => `  - ${titulo}: hecha ${s.done} veces, no hecha ${s.missed} veces`);
  return `${nombre}:\n${lineas.join('\n')}`;
}

const SYSTEM_PROMPT_MEDIADOR = `Eres un mediador neutral de conflictos de convivencia en un piso compartido. Nunca tomas partido. Tu única base son lo que cada persona ha escrito y los datos objetivos de tareas que se te dan.

Instrucciones:
1. Resume la versión de cada persona parafraseando — nunca cites textualmente, porque la otra persona leerá ese resumen y una cita textual suena a munición contra ella.
2. Señala los puntos en común entre ambas versiones.
3. Da UNA sugerencia concreta y accionable, no un consejo genérico tipo "comunicaos mejor".
4. Si una afirmación de alguna de las partes choca con los datos objetivos de tareas, señálalo explícitamente y con respeto (ej: "Persona A dice que siempre friega, pero el registro muestra que lo hizo 2 de las últimas 8 veces que le tocaba").
5. Si falta la versión de una de las partes, dilo claramente, usa un tono con reservas ("con la información disponible por ahora..."), no repartas culpas, e invita a que la otra persona añada su versión cuando pueda.
6. Tono calmado, sin moralizar, dirigido a ambas personas por igual.
7. Responde ÚNICAMENTE con JSON válido, sin bloques de código markdown ni texto fuera del JSON, con esta forma exacta:
{"resumen_a": "...", "resumen_b": "...", "puntos_comunes": "...", "sugerencia": "...", "certeza": "alta" | "una_sola_parte"}`;

async function ejecutarMediacion(householdId, conflictId) {
  const conflictRef = db.collection('households').doc(householdId)
      .collection('conflicts').doc(conflictId);
  const [conflictSnap, householdSnap, sidesSnap] = await Promise.all([
    conflictRef.get(),
    db.collection('households').doc(householdId).get(),
    conflictRef.collection('sides').get(),
  ]);
  if (!conflictSnap.exists) return;
  const conflict = conflictSnap.data();
  const [uidA, uidB] = conflict.participants;

  const textosPorUid = {};
  sidesSnap.forEach((doc) => { textosPorUid[doc.id] = doc.data().text; });
  const textoA = textosPorUid[uidA] || null;
  const textoB = textosPorUid[uidB] || null;
  const unaSolaParte = !textoA || !textoB;

  const profiles = householdSnap.data()?.memberProfiles || {};
  const nombreA = profiles[uidA]?.displayName || 'Persona A';
  const nombreB = profiles[uidB]?.displayName || 'Persona B';

  const historial = await resumenHistorialTareas(householdId);
  const historialTexto = [
    formatearHistorialPersona(nombreA, historial[uidA]),
    formatearHistorialPersona(nombreB, historial[uidB]),
  ].join('\n');

  const userMessage = `DATOS OBJETIVOS DE TAREAS (últimos ${HISTORIAL_MEDIACION_DIAS} días):
${historialTexto}

VERSIÓN DE ${nombreA}:
${textoA || '(no ha respondido todavía)'}

VERSIÓN DE ${nombreB}:
${textoB || '(no ha respondido todavía)'}`;

  const apiKey = _anthropicKey.value();
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: MEDIATION_MODEL,
      // 1024 se quedaba corto y cortaba el JSON a mitad de un campo,
      // haciendo que fallara el parseo y cayera al camino de repliegue.
      max_tokens: 2048,
      system: SYSTEM_PROMPT_MEDIADOR,
      messages: [{ role: 'user', content: userMessage }],
    }),
  });

  if (!res.ok) {
    console.error('ejecutarMediacion: Anthropic respondió', res.status, await res.text());
    throw new HttpsError('internal', `Error del servicio de IA: ${res.status}`);
  }
  const data = await res.json();
  // No asumir que content[0] es el bloque de texto — los modelos más nuevos
  // pueden devolver un bloque de "thinking" antes del de texto.
  const textBlock = (data.content || []).find((b) => b.type === 'text');
  const rawText = textBlock?.text;
  if (data.stop_reason === 'max_tokens') {
    console.warn('ejecutarMediacion: la respuesta se cortó por max_tokens — probable JSON incompleto');
  }

  let mediation;
  if (!rawText) {
    // Sin texto utilizable no hay nada que parsear ni que degradar — se
    // registra el cuerpo completo para diagnóstico y se falla con claridad
    // en vez de intentar escribir "undefined" en Firestore (que lo rechaza).
    console.error('ejecutarMediacion: sin bloque de texto en la respuesta', JSON.stringify(data));
    throw new HttpsError('internal', 'El mediador no devolvió una respuesta utilizable.');
  }

  try {
    const limpio = rawText.trim().replace(/^```json\s*/i, '').replace(/```$/, '');
    const parsed = JSON.parse(limpio);
    mediation = {
      summaryA: parsed.resumen_a || '',
      summaryB: parsed.resumen_b || '',
      commonGround: parsed.puntos_comunes || '',
      suggestion: parsed.sugerencia || '',
      oneSided: unaSolaParte,
      generatedAt: FieldValue.serverTimestamp(),
    };
  } catch (e) {
    // Degradación defensiva: si el JSON no parsea, no reventamos la función
    // entera — guardamos el texto crudo para no perder la mediación.
    console.error('ejecutarMediacion: fallo al parsear JSON', e, rawText);
    mediation = {
      summaryRaw: rawText,
      oneSided: unaSolaParte,
      generatedAt: FieldValue.serverTimestamp(),
    };
  }

  await conflictRef.update({ status: 'mediated', mediation });
}

// =============================================================================
// 5. INICIAR UN CONFLICTO
// =============================================================================
exports.startConflict = onCall({ region: REGION, secrets: [_anthropicKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const householdId = request.data?.householdId;
  const otherUid = request.data?.otherUid;
  const text = typeof request.data?.text === 'string' ? request.data.text.trim() : '';

  if (!householdId || !otherUid || !text) {
    throw new HttpsError('invalid-argument', 'Faltan datos.');
  }
  if (uid === otherUid) {
    throw new HttpsError('invalid-argument', 'No puedes abrir un conflicto contigo mismo.');
  }
  if (text.length > 4000) {
    throw new HttpsError('invalid-argument', 'El texto es demasiado largo.');
  }

  const householdSnap = await db.collection('households').doc(householdId).get();
  if (!householdSnap.exists) throw new HttpsError('not-found', 'El piso no existe.');
  const members = householdSnap.data().members || [];
  if (!members.includes(uid) || !members.includes(otherUid)) {
    throw new HttpsError('permission-denied', 'Ambas personas deben pertenecer al piso.');
  }

  const conflictRef = db.collection('households').doc(householdId).collection('conflicts').doc();
  const timeoutAt = Timestamp.fromMillis(Date.now() + CONFLICT_TIMEOUT_HORAS * 60 * 60 * 1000);

  await db.runTransaction(async (tx) => {
    tx.set(conflictRef, {
      participants: [uid, otherUid],
      initiatorUid: uid,
      status: 'awaiting_other_side',
      timeoutAt,
      mediation: null,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(conflictRef.collection('sides').doc(uid), {
      text,
      submittedAt: FieldValue.serverTimestamp(),
    });
  });

  return { ok: true, conflictId: conflictRef.id };
});

// =============================================================================
// 6. RESPONDER A UN CONFLICTO
// =============================================================================
exports.submitConflictSide = onCall({ region: REGION, secrets: [_anthropicKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const householdId = request.data?.householdId;
  const conflictId = request.data?.conflictId;
  const text = typeof request.data?.text === 'string' ? request.data.text.trim() : '';

  if (!householdId || !conflictId || !text) {
    throw new HttpsError('invalid-argument', 'Faltan datos.');
  }
  if (text.length > 4000) {
    throw new HttpsError('invalid-argument', 'El texto es demasiado largo.');
  }

  const conflictRef = db.collection('households').doc(householdId).collection('conflicts').doc(conflictId);
  const conflictSnap = await conflictRef.get();
  if (!conflictSnap.exists) throw new HttpsError('not-found', 'El conflicto no existe.');
  const conflict = conflictSnap.data();
  if (!(conflict.participants || []).includes(uid)) {
    throw new HttpsError('permission-denied', 'No formas parte de este conflicto.');
  }
  if (conflict.status !== 'awaiting_other_side') {
    throw new HttpsError('failed-precondition', 'Este conflicto ya no está esperando una respuesta.');
  }

  await conflictRef.collection('sides').doc(uid).set({
    text,
    submittedAt: FieldValue.serverTimestamp(),
  });

  const sidesSnap = await conflictRef.collection('sides').get();
  if (sidesSnap.size >= 2) {
    await conflictRef.update({ status: 'ready_for_mediation' });
    try {
      await ejecutarMediacion(householdId, conflictId);
    } catch (e) {
      // Sin esto, un fallo de la IA deja el conflicto atascado en
      // "generando..." para siempre, sin ninguna salida para el usuario.
      await conflictRef.update({ status: 'mediation_failed' });
      throw e;
    }
  }

  return { ok: true };
});

// =============================================================================
// 7. CERRAR CONFLICTOS SIN RESPUESTA — cada hora
// =============================================================================
// Si pasan 48h y la otra persona no ha escrito su versión, se genera una
// mediación con lo único que hay disponible en vez de dejarlo esperando
// para siempre. ejecutarMediacion ya sabe manejar el caso de una sola parte.
exports.checkConflictTimeouts = onSchedule(
  { schedule: 'every 60 minutes', timeZone: 'UTC', region: REGION, secrets: [_anthropicKey] },
  async () => {
    const ahora = Timestamp.now();
    const vencidosSnap = await db.collectionGroup('conflicts')
        .where('status', '==', 'awaiting_other_side')
        .where('timeoutAt', '<=', ahora)
        .get();

    for (const doc of vencidosSnap.docs) {
      // doc.ref.parent.parent es el household — collectionGroup no da el id directo.
      const householdId = doc.ref.parent.parent.id;
      try {
        await doc.ref.update({ status: 'ready_for_mediation' });
        await ejecutarMediacion(householdId, doc.id);
      } catch (e) {
        console.error('checkConflictTimeouts: fallo mediando', householdId, doc.id, e);
        await doc.ref.update({ status: 'mediation_failed' }).catch(() => {});
      }
    }
  }
);

// =============================================================================
// 8. SEGUIMIENTO — cada día, a los pocos días de mediar
// =============================================================================
// Pregunta si la sugerencia funcionó, por notificación push, unos días
// después de que se generara la mediación — no tiene sentido preguntar el
// mismo día, hace falta que haya pasado tiempo para saberlo de verdad.
exports.sendFollowUp = onSchedule(
  { schedule: 'every day 10:00', timeZone: 'UTC', region: REGION },
  async () => {
    const limite = Timestamp.fromMillis(Date.now() - FOLLOWUP_DELAY_DIAS * 24 * 60 * 60 * 1000);
    const candidatosSnap = await db.collectionGroup('conflicts')
        .where('status', '==', 'mediated')
        .where('mediation.generatedAt', '<=', limite)
        .get();

    for (const doc of candidatosSnap.docs) {
      const conflict = doc.data();
      if (conflict.followUp?.sentAt) continue; // ya se envió antes

      const householdId = doc.ref.parent.parent.id;
      await doc.ref.update({
        status: 'followed_up',
        'followUp.scheduledAt': FieldValue.serverTimestamp(),
        'followUp.sentAt': FieldValue.serverTimestamp(),
      });

      // Notificar a los dos participantes — el fallo al notificar no debe
      // impedir que se marque como enviado (evita reintentos infinitos por
      // un token caducado de un solo usuario).
      for (const uid of conflict.participants || []) {
        try {
          const userSnap = await db.collection('users').doc(uid).get();
          const token = userSnap.data()?.fcmToken;
          if (!token) continue;
          await getMessaging().send({
            token,
            notification: {
              title: 'Convive',
              body: '¿Funcionó la sugerencia del mediador? Cuéntanoslo.',
            },
            data: { type: 'conflict_followup', householdId, conflictId: doc.id },
          });
        } catch (e) {
          console.error('sendFollowUp: fallo notificando a', uid, e);
        }
      }
    }
  }
);

// =============================================================================
// 9. RESPONDER AL SEGUIMIENTO
// =============================================================================
exports.respondToFollowUp = onCall({ region: REGION }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const householdId = request.data?.householdId;
  const conflictId = request.data?.conflictId;
  const worked = request.data?.worked;
  const comment = typeof request.data?.comment === 'string' ? request.data.comment.trim() : '';

  if (!householdId || !conflictId || typeof worked !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Faltan datos.');
  }

  const conflictRef = db.collection('households').doc(householdId).collection('conflicts').doc(conflictId);
  const conflictSnap = await conflictRef.get();
  if (!conflictSnap.exists) throw new HttpsError('not-found', 'El conflicto no existe.');
  const conflict = conflictSnap.data();
  if (!(conflict.participants || []).includes(uid)) {
    throw new HttpsError('permission-denied', 'No formas parte de este conflicto.');
  }

  await conflictRef.update({
    [`followUp.responses.${uid}`]: {
      worked,
      comment,
      respondedAt: FieldValue.serverTimestamp(),
    },
  });

  return { ok: true };
});
