// lib/screens/conflict_detail_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/conflict.dart';
import '../models/household.dart';
import '../models/task.dart';
import '../services/conflict_service.dart';
import '../services/task_service.dart';

class ConflictDetailScreen extends StatelessWidget {
  const ConflictDetailScreen({
    required this.household,
    required this.conflictId,
    super.key,
  });

  final Household household;
  final String conflictId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conflicto')),
      body: StreamBuilder<Conflict>(
        stream: ConflictService.streamConflict(household.id, conflictId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final conflict = snapshot.data!;
          return switch (conflict.status) {
            ConflictStatus.mediated ||
            ConflictStatus.followedUp ||
            ConflictStatus.closed =>
              _MediationResult(household: household, conflict: conflict),
            ConflictStatus.readyForMediation =>
              const _Generando(),
            ConflictStatus.awaitingOtherSide =>
              _EsperandoORespondiendo(household: household, conflict: conflict),
          };
        },
      ),
    );
  }
}

class _Generando extends StatelessWidget {
  const _Generando();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Generando la mediación...'),
        ],
      ),
    );
  }
}

class _EsperandoORespondiendo extends StatefulWidget {
  const _EsperandoORespondiendo({required this.household, required this.conflict});

  final Household household;
  final Conflict conflict;

  @override
  State<_EsperandoORespondiendo> createState() => _EsperandoORespondiendoState();
}

class _EsperandoORespondiendoState extends State<_EsperandoORespondiendo> {
  bool? _yaEnvieMiVersion;
  final _textCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _comprobar();
  }

  Future<void> _comprobar() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    final ya = await ConflictService.yaEnvieMiVersion(
      householdId: widget.household.id,
      conflictId: widget.conflict.id,
      myUid: myUid,
    );
    if (mounted) setState(() => _yaEnvieMiVersion = ya);
  }

  Future<void> _enviar() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _enviando = true);
    try {
      await ConflictService.submitSide(
        householdId: widget.household.id,
        conflictId: widget.conflict.id,
        text: text,
      );
      if (mounted) setState(() => _yaEnvieMiVersion = true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_yaEnvieMiVersion == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final otroUid = widget.conflict
        .otherParticipant(FirebaseAuth.instance.currentUser?.uid ?? '');
    final otroNombre =
        widget.household.memberProfiles[otroUid]?.displayName ?? 'tu compañero';

    if (_yaEnvieMiVersion!) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top, size: 48),
            const SizedBox(height: 16),
            Text('Esperando la versión de $otroNombre',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'En cuanto responda, el mediador generará un resumen imparcial '
              'para los dos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _HistorialCard(householdId: widget.household.id),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$otroNombre ha abierto un conflicto contigo',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Cuenta tu versión — un mediador neutral leerá las dos y hará un resumen imparcial.'),
          const SizedBox(height: 12),
          TextField(
            controller: _textCtrl,
            maxLines: 6,
            maxLength: 4000,
            decoration: const InputDecoration(alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _enviando ? null : _enviar,
            child: _enviando
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Enviar mi versión'),
          ),
        ],
      ),
    );
  }
}

class _MediationResult extends StatelessWidget {
  const _MediationResult({required this.household, required this.conflict});

  final Household household;
  final Conflict conflict;

  @override
  Widget build(BuildContext context) {
    final m = conflict.mediation;
    if (m == null) {
      return const Center(child: Text('Sin resultado todavía.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (m.oneSided)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Solo hay una versión disponible por ahora. Este resumen es '
                'provisional — cuando la otra persona añada la suya, se '
                'actualizará.',
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (m.summaryRaw != null) ...[
          Text('Mediación', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(m.summaryRaw!),
        ] else ...[
          _Seccion(titulo: 'Versión de cada parte', children: [
            if (m.summaryA != null) Text(m.summaryA!),
            if (m.summaryB != null) ...[const SizedBox(height: 8), Text(m.summaryB!)],
          ]),
          _Seccion(titulo: 'Puntos en común', children: [
            Text(m.commonGround ?? ''),
          ]),
          _Seccion(titulo: 'Sugerencia', children: [
            Text(m.suggestion ?? ''),
          ]),
        ],
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text('Datos que consideró el mediador'),
          children: [_HistorialCard(householdId: household.id)],
        ),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _HistorialCard extends StatelessWidget {
  const _HistorialCard({required this.householdId});

  final String householdId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskCompletion>>(
      stream: TaskService.streamHistory(householdId, limit: 15),
      builder: (context, snapshot) {
        final historial = snapshot.data ?? [];
        if (historial.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Sin historial de tareas todavía.'),
          );
        }
        return Column(
          children: historial.map((c) {
            final icon = c.status == 'done'
                ? Icons.check_circle_outline
                : Icons.remove_circle_outline;
            return ListTile(
              dense: true,
              leading: Icon(icon, size: 18),
              title: Text(c.taskTitle),
              subtitle: Text(c.status == 'done' ? 'Hecha' : 'No hecha'),
            );
          }).toList(),
        );
      },
    );
  }
}
