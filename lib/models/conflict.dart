// lib/models/conflict.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ConflictStatus {
  awaitingOtherSide,
  readyForMediation,
  mediated,
  followedUp,
  closed,
  mediationFailed,
}

extension ConflictStatusX on ConflictStatus {
  static ConflictStatus fromWire(String? v) => switch (v) {
        'ready_for_mediation' => ConflictStatus.readyForMediation,
        'mediated' => ConflictStatus.mediated,
        'followed_up' => ConflictStatus.followedUp,
        'closed' => ConflictStatus.closed,
        'mediation_failed' => ConflictStatus.mediationFailed,
        _ => ConflictStatus.awaitingOtherSide,
      };
}

class ConflictMediation {
  final String? summaryA;
  final String? summaryB;
  final String? commonGround;
  final String? suggestion;
  final String? summaryRaw; // fallback si el JSON del modelo no parseó
  final bool oneSided;

  const ConflictMediation({
    this.summaryA,
    this.summaryB,
    this.commonGround,
    this.suggestion,
    this.summaryRaw,
    required this.oneSided,
  });

  factory ConflictMediation.fromMap(Map<String, dynamic> m) => ConflictMediation(
        summaryA: m['summaryA'] as String?,
        summaryB: m['summaryB'] as String?,
        commonGround: m['commonGround'] as String?,
        suggestion: m['suggestion'] as String?,
        summaryRaw: m['summaryRaw'] as String?,
        oneSided: m['oneSided'] as bool? ?? false,
      );
}

class FollowUpResponse {
  final bool worked;
  final String? comment;

  const FollowUpResponse({required this.worked, this.comment});

  factory FollowUpResponse.fromMap(Map<String, dynamic> m) => FollowUpResponse(
        worked: m['worked'] as bool? ?? false,
        comment: m['comment'] as String?,
      );
}

class Conflict {
  final String id;
  final List<String> participants;
  final String initiatorUid;
  final ConflictStatus status;
  final DateTime? timeoutAt;
  final ConflictMediation? mediation;
  final Map<String, FollowUpResponse> followUpResponses;

  const Conflict({
    required this.id,
    required this.participants,
    required this.initiatorUid,
    required this.status,
    this.timeoutAt,
    this.mediation,
    this.followUpResponses = const {},
  });

  factory Conflict.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final mediationMap = d['mediation'] as Map<String, dynamic>?;
    final followUpMap = d['followUp'] as Map<String, dynamic>?;
    final responsesMap = followUpMap?['responses'] as Map<String, dynamic>?;
    return Conflict(
      id: doc.id,
      participants: (d['participants'] as List?)?.cast<String>() ?? [],
      initiatorUid: d['initiatorUid'] as String? ?? '',
      status: ConflictStatusX.fromWire(d['status'] as String?),
      timeoutAt: (d['timeoutAt'] as Timestamp?)?.toDate(),
      mediation: mediationMap != null ? ConflictMediation.fromMap(mediationMap) : null,
      followUpResponses: (responsesMap ?? {}).map(
        (uid, v) => MapEntry(uid, FollowUpResponse.fromMap(v as Map<String, dynamic>)),
      ),
    );
  }

  String otherParticipant(String myUid) =>
      participants.firstWhere((p) => p != myUid, orElse: () => '');

  bool wasFollowedUp(String myUid) => followUpResponses.containsKey(myUid);
}
