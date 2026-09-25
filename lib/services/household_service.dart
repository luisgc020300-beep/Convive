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

  /// Todos los pisos a los que pertenece el usuario (a diferencia del
  /// activo, que es solo el que tiene abierto ahora mismo).
  static Stream<List<String>> streamMyHouseholdIds() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db.collection('users').doc(uid).snapshots().map(
        (doc) => (doc.data()?['householdIds'] as List?)?.cast<String>() ?? const []);
  }

  static Future<void> switchActiveHousehold(String householdId) async {
    final callable = FirebaseFunctions.instanceFor(region: _region)
        .httpsCallable('switchActiveHousehold');
    await callable.call<Map<String, dynamic>>({'householdId': householdId});
  }

  static Future<void> leaveHousehold(String householdId) async {
    final callable = FirebaseFunctions.instanceFor(region: _region)
        .httpsCallable('leaveHousehold');
    await callable.call<Map<String, dynamic>>({'householdId': householdId});
  }

  /// Cuándo viste por última vez el chat/las notas de cada piso -- mapas
  /// {householdId: Timestamp} en users/{uid}, para que el contador de
  /// "nuevo" en la barra de abajo sea por piso, no global (con varios pisos,
  /// un mensaje nuevo en la casa rural no debería marcar el piso de Granada).
  static Stream<Map<String, dynamic>> streamLastSeen() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const {});
    return _db.collection('users').doc(uid).snapshots().map((doc) => {
          'chat': (doc.data()?['lastSeenChat'] as Map<String, dynamic>?) ?? {},
          'notes': (doc.data()?['lastSeenNotes'] as Map<String, dynamic>?) ?? {},
        });
  }

  static Future<void> markChatSeen(String householdId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // Ruta con punto -- Firestore la trata como el campo anidado exacto,
    // sin pisar los timestamps de otros pisos guardados en el mismo mapa.
    await _db.collection('users').doc(uid).set({
      'lastSeenChat.$householdId': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> markNotesSeen(String householdId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'lastSeenNotes.$householdId': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  /// Cambia el nombre visible en notas/tareas/chat -- se sincroniza también
  /// en el piso activo, no solo en el perfil del usuario.
  static Future<void> updateNickname(String nickname) async {
    final callable = FirebaseFunctions.instanceFor(region: _region)
        .httpsCallable('updateNickname');
    await callable.call<Map<String, dynamic>>({'nickname': nickname});
  }

  /// Repara `householdIds` para cuentas que ya tenían un piso antes de que
  /// existiera el soporte multi-piso: ese piso vive en `members` del propio
  /// piso pero nunca se escribió en el array del usuario, así que al crear
  /// un segundo piso (primer arrayUnion real de esa cuenta) el array
  /// arrancaba vacío y solo quedaba el nuevo -- el piso viejo no se borra,
  /// solo deja de listarse en "Tus pisos". Barata (una query) e idempotente,
  /// se ejecuta en cada arranque igual que [asegurarPerfilUsuario].
  static Future<void> reconciliarHouseholdIds() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final query = await _db.collection('households').where('members', arrayContains: uid).get();
    if (query.docs.isEmpty) return;
    final idsReales = query.docs.map((d) => d.id).toSet();
    final userSnap = await _db.collection('users').doc(uid).get();
    final idsActuales = (userSnap.data()?['householdIds'] as List?)?.cast<String>().toSet() ?? {};
    final faltantes = idsReales.difference(idsActuales);
    if (faltantes.isEmpty) return;
    await _db.collection('users').doc(uid).set({
      'householdIds': FieldValue.arrayUnion(faltantes.toList()),
    }, SetOptions(merge: true));
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
      'householdIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
