// lib/screens/new_conflict_screen.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/household.dart';
import '../services/conflict_service.dart';

class NewConflictScreen extends StatefulWidget {
  const NewConflictScreen({required this.household, super.key});

  final Household household;

  @override
  State<NewConflictScreen> createState() => _NewConflictScreenState();
}

class _NewConflictScreenState extends State<NewConflictScreen> {
  final _textCtrl = TextEditingController();
  String? _otherUid;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final text = _textCtrl.text.trim();
    if (_otherUid == null || text.isEmpty || myUid == null) return;
    setState(() { _enviando = true; _error = null; });
    try {
      await ConflictService.startConflict(
        householdId: widget.household.id,
        otherUid: _otherUid!,
        text: text,
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'No se pudo enviar: ${e.code}');
    } catch (e) {
      setState(() => _error = 'No se pudo enviar: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final otros = widget.household.members.where((u) => u != myUid).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo conflicto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cuéntalo con tus propias palabras. Tu compañero no verá este '
              'texto tal cual — un mediador neutral leerá las dos versiones y '
              'hará un resumen imparcial de la situación.',
            ),
            const SizedBox(height: 16),
            if (otros.isEmpty)
              const Text('No hay más compañeros en este piso todavía.')
            else
              DropdownButtonFormField<String>(
                initialValue: _otherUid,
                decoration: const InputDecoration(labelText: 'Con quién'),
                items: otros
                    .map((uid) => DropdownMenuItem(
                          value: uid,
                          child: Text(widget.household.memberProfiles[uid]
                                  ?.displayName ??
                              'Runner'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _otherUid = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _textCtrl,
              maxLines: 6,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'Qué ha pasado',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: (_enviando || otros.isEmpty) ? null : _enviar,
              child: _enviando
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }
}
