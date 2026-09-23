// lib/services/conflict_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/conflict.dart';

class ConflictService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  /// La regla de Firestore exige request.auth.uid in participants — sin un
  /// where que lo refleje, Firestore rechaza la consulta entera (no la
  /// filtra en silencio), así que el arrayContains es obligatorio aquí.
  static Stream<List<Conflict>> streamConflicts(String householdId) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return Stream.value([]);
    return _db
        .collection('households')
        .doc(householdId)
        .collection('conflicts')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snap) => snap.docs.map(Conflict.fromDoc).toList());
  }

  static Stream<Conflict> streamConflict(String householdId, String conflictId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('conflicts')
        .doc(conflictId)
        .snapshots()
        .where((doc) => doc.exists)
        .map(Conflict.fromDoc);
  }

  static Future<String> startConflict({
    required String householdId,
    required String otherUid,
    required String text,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region)
        .httpsCallable('startConflict');
    final result = await callable.call<Map<String, dynamic>>({
      'householdId': householdId,
      'otherUid': otherUid,
      'text': text,
    });
    return result.data['conflictId'] as String;
  }

  /// Comprueba si el usuario actual ya envió su versión de este conflicto
  /// (cada versión es privada — solo su autor puede leerla).
  static Future<bool> yaEnvieMiVersion({
    required String householdId,
    required String conflictId,
    required String myUid,
  }) async {
    final doc = await _db
        .collection('households')
        .doc(householdId)
        .collection('conflicts')
        .doc(conflictId)
        .collection('sides')
        .doc(myUid)
        .get();
    return doc.exists;
  }

  static Future<void> submitSide({
    required String householdId,
    required String conflictId,
    required String text,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: _region)
        .httpsCallable('submitConflictSide');
    await callable.call<Map<String, dynamic>>({
      'householdId': householdId,
      'conflictId': conflictId,
      'text': text,
    });
  }
}
