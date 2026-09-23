// lib/screens/conflicts_tab.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/conflict.dart';
import '../models/household.dart';
import 'conflict_detail_screen.dart';
import 'new_conflict_screen.dart';
import '../services/conflict_service.dart';

class ConflictsTab extends StatelessWidget {
  const ConflictsTab({required this.household, super.key});

  final Household household;

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      body: StreamBuilder<List<Conflict>>(
        stream: ConflictService.streamConflicts(household.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final conflicts = snapshot.data ?? [];
          if (conflicts.isEmpty) {
            return const Center(child: Text('Sin conflictos abiertos. Bien por vosotros.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: conflicts.map((c) {
              final otro = household.memberProfiles[c.otherParticipant(myUid ?? '')]
                      ?.displayName ??
                  'Compañero';
              final (label, color) = switch (c.status) {
                ConflictStatus.mediated ||
                ConflictStatus.followedUp ||
                ConflictStatus.closed =>
                  ('Mediado', Colors.green),
                ConflictStatus.readyForMediation =>
                  ('Generando...', Colors.orange),
                ConflictStatus.awaitingOtherSide => c.initiatorUid == myUid
                    ? ('Esperando a $otro', Colors.orange)
                    : ('Esperándote', Colors.red),
                ConflictStatus.mediationFailed => ('Error', Colors.red),
              };
              return Card(
                child: ListTile(
                  title: Text('Con $otro'),
                  trailing: Chip(
                    label: Text(label),
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ConflictDetailScreen(
                      household: household,
                      conflictId: c.id,
                    ),
                  )),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => NewConflictScreen(household: household),
        )),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo conflicto'),
      ),
    );
  }
}
