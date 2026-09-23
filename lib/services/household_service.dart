// lib/services/household_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/household.dart';

class HouseholdService {
  static final _db = FirebaseFirestore.instance;
  static const _region = 'europe-west1';

  /// Stream del piso activo del usuario actual (null si no tiene ninguno).
  static Stream<String?> streamActiveHouseholdId() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map(
        (doc) => doc.data()?['activeHouseholdId'] as String?);
  }

  static Stream<Household> streamHousehold(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .snapshots()
        .where((doc) => doc.exists)
        .map(Household.fromDoc);
  }

  static Future<({String householdId, String joinCode})> createHousehold(
      String nombre) async {
    final callable = FirebaseFunctions.instanceFor(region: _region)
        .httpsCallable('createHousehold');
    final result = await callable.call<Map<String, dynamic>>({'name': nombre});
    final data = result.data;
    return (
      householdId: data['householdId'] as String,
      joinCode: data['joinCode'] as String,
    );
  }

  static Future<String> joinHousehold(String joinCode) async {
    final callable = FirebaseFunctions.instanceFor(region: _region)
        .httpsCallable('joinHousehold');
    final result = await callable.call<Map<String, dynamic>>(
        {'joinCode': joinCode});
    return result.data['householdId'] as String;
  }

  /// Crea (o actualiza) el documento de perfil del usuario tras el login.
  static Future<void> asegurarPerfilUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    final displayName = (user.email ?? 'Runner').split('@').first;
    await ref.set({
      'displayName': displayName,
      'photoUrl': null,
      'activeHouseholdId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
