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
import 'create_household_screen.dart';
import 'join_household_screen.dart';
import 'notification_prefs_screen.dart';
import 'payments_tab.dart';
import 'settings_screen.dart';
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

const _nombresPestanas = ['Tareas', 'Chat', 'Pagos', 'Piso'];

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
        toolbarHeight: 44,
        title: Text(_nombresPestanas[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationPrefsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        height: 56,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: context.colors.wall,
        indicatorColor: context.colors.amber.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
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

class _PisoTab extends StatefulWidget {
  const _PisoTab({required this.household});

  final Household household;

  @override
  State<_PisoTab> createState() => _PisoTabState();
}

class _PisoTabState extends State<_PisoTab> {
  late final _nicknameCtrl = TextEditingController(text: _miNombreActual());
  bool _guardando = false;

  String _miNombreActual() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return widget.household.memberProfiles[uid]?.displayName ?? '';
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarNickname() async {
    final nombre = _nicknameCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _guardando = true);
    try {
      await HouseholdService.updateNickname(nombre);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = widget.household;
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Tu nombre en el piso', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nicknameCtrl,
                decoration: const InputDecoration(hintText: 'Cómo te ven tus compañeros'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _guardando ? null : _guardarNickname,
              child: _guardando
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Tus pisos', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _MisPisos(activeHouseholdId: household.id),
        const SizedBox(height: 24),
        Text('Código de invitación: ${household.joinCode}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Text('Compañeros (${household.members.length})',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...household.members.map((uid) {
          final profile = household.memberProfiles[uid];
          return ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(profile?.displayName ?? 'Runner'),
            trailing: uid == household.ownerUid ? const Chip(label: Text('Dueño')) : null,
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _confirmarSalir(context, household),
          icon: Icon(Icons.logout, size: 18, color: colors.rust),
          label: Text('Salir de este piso', style: TextStyle(color: colors.rust)),
        ),
      ],
    );
  }

  Future<void> _confirmarSalir(BuildContext context, Household household) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir de este piso?'),
        content: Text('Dejarás de ver "${household.name}". Podrás volver a unirte con el código si lo necesitas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.rust),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await HouseholdService.leaveHousehold(household.id);
    }
  }
}

class _MisPisos extends StatelessWidget {
  const _MisPisos({required this.activeHouseholdId});

  final String activeHouseholdId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<List<String>>(
      stream: HouseholdService.streamMyHouseholdIds(),
      builder: (context, snapshot) {
        final ids = snapshot.data ?? [activeHouseholdId];
        return Container(
          decoration: BoxDecoration(color: colors.cork, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              ...ids.map((id) => _PisoRow(householdId: id, esActivo: id == activeHouseholdId)),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.add, color: colors.amber),
                title: Text('Crear o unirme a otro piso', style: TextStyle(color: colors.amber)),
                onTap: () => _mostrarOpciones(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _mostrarOpciones(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.cork,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_home_outlined),
              title: const Text('Crear un piso nuevo'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateHouseholdScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.meeting_room_outlined),
              title: const Text('Unirme con un código'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinHouseholdScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PisoRow extends StatelessWidget {
  const _PisoRow({required this.householdId, required this.esActivo});

  final String householdId;
  final bool esActivo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<Household>(
      stream: HouseholdService.streamHousehold(householdId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final household = snapshot.data!;
        return ListTile(
          leading: Icon(Icons.home_outlined, color: esActivo ? colors.amber : colors.paperMuted),
          title: Text(household.name, style: TextStyle(color: esActivo ? colors.amber : colors.paper)),
          subtitle: Text('${household.members.length} ${household.members.length == 1 ? 'persona' : 'personas'}'),
          trailing: esActivo
              ? Chip(label: const Text('Activo'), backgroundColor: colors.amber.withValues(alpha: 0.18))
              : null,
          onTap: esActivo ? null : () => HouseholdService.switchActiveHousehold(householdId),
        );
      },
    );
  }
}
