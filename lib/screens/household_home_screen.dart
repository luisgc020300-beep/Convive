// lib/screens/household_home_screen.dart
//
// Placeholder de la Fase 1 — muestra el piso y sus miembros en vivo.
// La Fase 2 añade aquí las pestañas de Tareas/Notas; la Fase 3, Conflictos.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/household.dart';
import '../services/household_service.dart';

class HouseholdHomeScreen extends StatelessWidget {
  const HouseholdHomeScreen({required this.householdId, super.key});

  final String householdId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Household>(
      stream: HouseholdService.streamHousehold(householdId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final household = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: Text(household.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Código de invitación: ${household.joinCode}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Text('Compañeros (${household.members.length})',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: household.members.map((uid) {
                      final profile = household.memberProfiles[uid];
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(profile?.displayName ?? 'Runner'),
                        trailing: uid == household.ownerUid
                            ? const Chip(label: Text('Dueño'))
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
