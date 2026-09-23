// lib/models/household.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MemberProfile {
  final String uid;
  final String displayName;
  final String? photoUrl;

  const MemberProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl,
  });
}

class Household {
  final String id;
  final String name;
  final String joinCode;
  final String ownerUid;
  final List<String> members;
  final Map<String, MemberProfile> memberProfiles;

  const Household({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.ownerUid,
    required this.members,
    required this.memberProfiles,
  });

  factory Household.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final rawProfiles = (d['memberProfiles'] as Map<String, dynamic>?) ?? {};
    return Household(
      id: doc.id,
      name: d['name'] as String? ?? '',
      joinCode: d['joinCode'] as String? ?? '',
      ownerUid: d['ownerUid'] as String? ?? '',
      members: (d['members'] as List?)?.cast<String>() ?? [],
      memberProfiles: rawProfiles.map((uid, v) {
        final m = v as Map<String, dynamic>;
        return MapEntry(uid, MemberProfile(
          uid: uid,
          displayName: m['displayName'] as String? ?? 'Runner',
          photoUrl: m['photoUrl'] as String?,
        ));
      }),
    );
  }
}
