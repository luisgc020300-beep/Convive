// lib/screens/household_home_screen.dart
//
// Pestañas: Tareas (+ calendario semanal y notas), Chat, Pagos (gastos
// comunes + recordatorios) y Piso. Navegación abajo, como la mayoría de apps.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/chat_message.dart';
import '../models/household.dart';
import '../models/note.dart';
import '../services/chat_service.dart';
import '../services/household_service.dart';
import '../services/note_service.dart';
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

List<String> _nombresPestanas(AppLocalizations l10n) =>
    [l10n.tabTasks, l10n.tabChat, l10n.tabPayments, l10n.tabHousehold];

class _HouseholdShellState extends State<_HouseholdShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // La pestaña por defecto es Tareas -- "entrar" en ella ya cuenta como
    // haber visto las notas, igual que tocarla a mano.
    HouseholdService.markNotesSeen(widget.household.id);
  }

  @override
  void didUpdateWidget(covariant _HouseholdShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.household.id != widget.household.id) {
      // Cambiaste de piso -- "entrar" en él marca como vista la pestaña que
      // ya tuvieras seleccionada, en ese piso nuevo.
      if (_index == 0) HouseholdService.markNotesSeen(widget.household.id);
      if (_index == 1) HouseholdService.markChatSeen(widget.household.id);
    }
  }

  void _cambiarPestana(int i) {
    setState(() => _index = i);
    if (i == 0) HouseholdService.markNotesSeen(widget.household.id);
    if (i == 1) HouseholdService.markChatSeen(widget.household.id);
  }

  @override
  Widget build(BuildContext context) {
    final household = widget.household;
    final l10n = context.l10n;
    final tabs = [
      TasksTab(household: household),
      ChatTab(household: household),
      PaymentsTab(household: household),
      _PisoTab(household: household),
    ];
    return StreamBuilder<Map<String, dynamic>>(
      stream: HouseholdService.streamLastSeen(),
      builder: (context, lastSeenSnapshot) {
        final lastSeenChat = lastSeenSnapshot.data?['chat'] as Map<String, dynamic>? ?? const {};
        final lastSeenNotes = lastSeenSnapshot.data?['notes'] as Map<String, dynamic>? ?? const {};
        final desdeChat = (lastSeenChat[household.id] as Timestamp?)?.toDate();
        final desdeNotas = (lastSeenNotes[household.id] as Timestamp?)?.toDate();

        return StreamBuilder<List<ChatMessage>>(
          stream: ChatService.streamMessages(household.id),
          builder: (context, chatSnapshot) {
            final myUid = FirebaseAuth.instance.currentUser?.uid;
            final sinLeerChat = (chatSnapshot.data ?? [])
                .where((m) => m.authorUid != myUid)
                .where((m) => desdeChat == null || (m.createdAt?.isAfter(desdeChat) ?? false))
                .length;

            return StreamBuilder<List<ConviveNote>>(
              stream: NoteService.streamNotes(household.id),
              builder: (context, notesSnapshot) {
                final sinLeerNotas = (notesSnapshot.data ?? [])
                    .where((n) => n.authorUid != myUid)
                    .where((n) => desdeNotas == null || (n.createdAt?.isAfter(desdeNotas) ?? false))
                    .length;

                return Scaffold(
                  appBar: AppBar(
                    toolbarHeight: 44,
                    title: Text(_nombresPestanas(l10n)[_index]),
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
                    onDestinationSelected: _cambiarPestana,
                    backgroundColor: context.colors.wall,
                    indicatorColor: context.colors.amber.withValues(alpha: 0.18),
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                    destinations: [
                      NavigationDestination(
                        icon: Badge(
                          label: Text('$sinLeerNotas'),
                          isLabelVisible: sinLeerNotas > 0,
                          child: const Icon(Icons.checklist_rounded),
                        ),
                        label: l10n.tabTasks,
                      ),
                      NavigationDestination(
                        icon: Badge(
                          label: Text('$sinLeerChat'),
                          isLabelVisible: sinLeerChat > 0,
                          child: const Icon(Icons.forum_outlined),
                        ),
                        label: l10n.tabChat,
                      ),
                      NavigationDestination(icon: const Icon(Icons.payments_outlined), label: l10n.tabPayments),
                      NavigationDestination(icon: const Icon(Icons.home_outlined), label: l10n.tabHousehold),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.householdYourName, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nicknameCtrl,
                decoration: InputDecoration(hintText: l10n.householdNameHint),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _guardando ? null : _guardarNickname,
              child: _guardando
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.save),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(l10n.householdYourHouseholds, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _MisPisos(activeHouseholdId: household.id),
        const SizedBox(height: 24),
        Text(l10n.householdJoinCode(household.joinCode),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Text(l10n.householdMembers(household.members.length),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...household.members.map((uid) {
          final profile = household.memberProfiles[uid];
          return ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(profile?.displayName ?? l10n.memberUnknown),
            trailing: uid == household.ownerUid ? Chip(label: Text(l10n.householdOwner)) : null,
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _confirmarSalir(context, household),
          icon: Icon(Icons.logout, size: 18, color: colors.rust),
          label: Text(l10n.householdLeave, style: TextStyle(color: colors.rust)),
        ),
      ],
    );
  }

  Future<void> _confirmarSalir(BuildContext context, Household household) async {
    final l10n = context.l10n;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.householdLeaveConfirmTitle),
        content: Text(l10n.householdLeaveConfirmBody(household.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.rust),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.leave),
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
    final l10n = context.l10n;
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
                title: Text(l10n.householdAddAnother, style: TextStyle(color: colors.amber)),
                onTap: () => _mostrarOpciones(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _mostrarOpciones(BuildContext context) async {
    final l10n = context.l10n;
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
              title: Text(l10n.householdCreateNew),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateHouseholdScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.meeting_room_outlined),
              title: Text(l10n.householdJoinWithCode),
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
    final l10n = context.l10n;
    return StreamBuilder<Household>(
      stream: HouseholdService.streamHousehold(householdId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final household = snapshot.data!;
        return ListTile(
          leading: Icon(Icons.home_outlined, color: esActivo ? colors.amber : colors.paperMuted),
          title: Text(household.name, style: TextStyle(color: esActivo ? colors.amber : colors.paper)),
          subtitle: Text(l10n.householdPeopleCount(household.members.length)),
          trailing: esActivo
              ? Chip(label: Text(l10n.householdActive), backgroundColor: colors.amber.withValues(alpha: 0.18))
              : null,
          onTap: esActivo ? null : () => HouseholdService.switchActiveHousehold(householdId),
        );
      },
    );
  }
}
