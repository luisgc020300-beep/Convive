// lib/screens/household_home_screen.dart
//
// Pestañas: Tareas (+ calendario semanal y notas), Chat, Pagos (gastos
// comunes + recordatorios) y Piso. Navegación abajo, como la mayoría de apps.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/household.dart';
import '../services/household_service.dart';
import '../theme/design_tokens.dart';
import 'chat_tab.dart';
import 'payments_tab.dart';
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
        return _HouseholdShell(household: snapshot.data!);
      },
    );
  }
}

class _HouseholdShell extends StatefulWidget {
  const _HouseholdShell({required this.household});

  final Household household;

  @override
  State<_HouseholdShell> createState() => _HouseholdShellState();
}

class _HouseholdShellState extends State<_HouseholdShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final household = widget.household;
    final tabs = [
      TasksTab(household: household),
      ChatTab(household: household),
      PaymentsTab(household: household),
      _PisoTab(household: household),
    ];
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: ConviveColors.wall,
        indicatorColor: ConviveColors.amber.withValues(alpha: 0.18),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist_rounded), label: 'Tareas'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Pagos'),
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Piso'),
        ],
      ),
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
