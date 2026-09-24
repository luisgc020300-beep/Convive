// lib/core/service_locator.dart
//
// Service Locator — punto único de acceso a los servicios de la app.
// Mismo patrón que RiskRunner (c:\dev\mi_app\lib\core\service_locator.dart).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';

import '../services/connectivity_service.dart';

final GetIt sl = GetIt.instance;

Future<void> setupLocator() async {
  final connectivity = ConnectivityService.instance;
  await connectivity.init();
  sl.registerSingleton<ConnectivityService>(connectivity);

  await _saveFcmToken();
  FirebaseMessaging.instance.onTokenRefresh.listen(_updateFcmToken);
}

Future<void> _saveFcmToken() async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  } catch (e, st) {
    debugPrint('FCM token save failed: $e');
    FirebaseCrashlytics.instance.recordError(e, st, reason: 'saveFcmToken');
  }
}

Future<void> _updateFcmToken(String token) async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  } catch (e, st) {
    debugPrint('FCM token update failed: $e');
    FirebaseCrashlytics.instance.recordError(e, st, reason: 'updateFcmToken');
  }
}
