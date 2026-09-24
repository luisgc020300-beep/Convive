// lib/services/notification_prefs_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_prefs.dart';

class NotificationPrefsService {
  static final _db = FirebaseFirestore.instance;

  static Stream<NotificationPrefs> streamPrefs() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const NotificationPrefs());
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map(NotificationPrefs.fromDoc);
  }

  static Future<void> savePrefs(NotificationPrefs prefs) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .set({'notificationPrefs': prefs.toMap()}, SetOptions(merge: true));
  }
}
