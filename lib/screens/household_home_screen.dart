// lib/screens/household_home_screen.dart
//
// Fase 3: pestañas de Tareas (+ notas), Conflictos y Piso.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/household.dart';
import '../services/household_service.dart';
import 'conflicts_tab.dart';
import 'tasks_tab.dart';

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
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(household.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
              ],
              bottom: const TabBar(tabs: [
                Tab(text: 'Tareas'),
                Tab(text: 'Conflictos'),
                Tab(text: 'Piso'),
              ]),
            ),
            body: TabBarView(children: [
              TasksTab(household: household),
              ConflictsTab(household: household),
              _PisoTab(household: household),
            ]),
          ),
        );
      },
    );
  }
}

class _PisoTab extends StatelessWidget {
  const _PisoTab({required this.household});

  final Household household;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}
