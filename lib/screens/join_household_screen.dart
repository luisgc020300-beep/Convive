// lib/screens/join_household_screen.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../services/household_service.dart';

class JoinHouseholdScreen extends StatefulWidget {
  const JoinHouseholdScreen({super.key});

  @override
  State<JoinHouseholdScreen> createState() => _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends State<JoinHouseholdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _unirse() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _cargando = true; _error = null; });
    final l10n = context.l10n;
    try {
      await HouseholdService.joinHousehold(_codeCtrl.text.trim());
      // La HouseholdGateScreen reacciona sola al stream de activeHouseholdId
      // -- pero si esta pantalla se abrió por encima de otra (desde el
      // selector de pisos, no solo desde el arranque en frío), hay que
      // cerrarla para que se vea lo de debajo ya actualizado.
      if (mounted) Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = switch (e.code) {
        'not-found' => l10n.joinHouseholdNotFound,
        'failed-precondition' => l10n.joinHouseholdFull,
        _ => l10n.joinHouseholdError(e.message ?? e.code),
      });
    } catch (e) {
      setState(() => _error = l10n.joinHouseholdError(e.toString()));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinHouseholdTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: l10n.joinHouseholdCodeLabel,
                  hintText: l10n.joinHouseholdCodeHint,
                ),
                validator: (v) => (v == null || v.trim().length < 4)
                    ? l10n.joinHouseholdCodeRequired
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _cargando ? null : _unirse,
                child: _cargando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.joinHouseholdButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
